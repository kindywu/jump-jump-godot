# 跳一跳 实现指南

## 概述

跳一跳是一款 3D 蓄力跳跃游戏：玩家按住鼠标蓄力，松开后角色跳跃到下一个平台，踩中得 1 分，踩空则游戏结束。本文档按实现流程逐步讲解。

引擎：Godot 4.6，物理：Jolt Physics 3D，渲染：D3D12。

---

## 一、项目初始化

### 1.1 创建项目与基础配置

在 `project.godot` 中配置以下关键项：

```
[application]
config/name="Jump Jump"
run/main_scene="res://scenes/main.tscn"

[autoload]
GameState="*res://scripts/game_state.gd"

[display/window]
size/viewport_width=1280
size/viewport_height=720

[rendering]
renderer/rendering_method="forward_plus"
anti_aliasing/quality/msaa_3d=2
```

要点：
- 入口场景设为 `main.tscn`
- `GameState` 注册为 autoload 全局单例，负责状态管理和分数

### 1.2 目录结构

```
jump-jump-godot/
├── project.godot
├── scenes/
│   ├── main.tscn          # 主场景（灯光、相机、地面、UI）
│   ├── player.tscn        # 玩家场景（模型、粒子、音效）
│   └── platform.tscn      # 平台场景（长方体/圆柱体二选一）
├── scripts/
│   ├── game_state.gd      # autoload 单例：状态机 + 分数
│   ├── main.gd            # 主场景脚本：场景管理、平台生成
│   ├── player.gd          # 玩家脚本：蓄力、跳跃、掉落
│   ├── platform.gd        # 平台脚本：随机形状和颜色
│   ├── camera.gd          # 相机脚本：等距视角、平滑跟随
│   └── ui/
│       ├── main_menu.gd   # 主菜单 UI
│       ├── game_over.gd   # 游戏结束 UI
│       └── scoreboard.gd  # 计分板 UI
└── assets/
    ├── fonts/num.ttf
    ├── sounds/{accumulation,fall,start,success}.mp3
    └── texture/{btn_start,btn_restart,btn_home,title}.png
```

---

## 二、全局状态机（GameState autoload）

### 2.1 为什么先做状态机

状态机是整个游戏的骨架。所有模块——输入处理、相机行为、UI 显隐——全部通过状态切换来驱动。先定义好状态，后续每个模块只需检查当前状态即可。

### 2.2 实现

```gdscript
# scripts/game_state.gd
extends Node

enum State { MAIN_MENU, PLAYING, GAME_OVER }

var current_state: State = State.MAIN_MENU
var score: int = 0

signal state_changed(new_state: State)
signal score_changed(new_score: int)
signal score_up(landing_pos: Vector3)

func change_state(new_state: State) -> void:
    current_state = new_state
    state_changed.emit(new_state)

func add_score() -> void:
    score += 1
    score_changed.emit(score)
    # score_up 由调用方在用 3D 位置参数 emit，用于 "+1" 浮动文字

func reset_score() -> void:
    score = 0
    score_changed.emit(score)
```

状态流转：

```
MAIN_MENU  →  PLAYING  →  GAME_OVER
    ↑           ↑              |
    └───────────┴──────────────┘
       (Home 按钮)  (Restart / Home)
```

三个信号的作用：
- `state_changed`：通知主场景切换 UI 和生成/清除游戏对象
- `score_changed`：计分板更新数字
- `score_up`：在落地位置显示 "+1" 浮动文字

---

## 三、主场景搭建（main.tscn）

### 3.1 场景树结构

```
Main (Node3D)
├── DirectionalLight3D          # 方向光，开启阴影
├── WorldEnvironment            # 天蓝色背景 + 环境光
├── Camera3D                    # 等距视角相机
├── Ground (MeshInstance3D)     # 大平面作为地面参考
├── StartSound (AudioStreamPlayer)  # 开局音效
├── Platforms (Node3D)          # 空容器，运行时动态添加平台
├── PrepareTimer (Timer)        # 开局 200ms 防误触延迟
└── UI (CanvasLayer)
    ├── MainMenu (Control)
    ├── GameOver (Control)
    └── Scoreboard (Control)
```

### 3.2 关键节点说明

**灯光：** `DirectionalLight3D` 置于 `(2, 10, 8)`，能量 1.5，开启阴影，最大阴影距离 50。

**环境：** `WorldEnvironment` 设为纯色背景 `(0.95, 0.87, 0.88)`（暖粉白），环境光能量 0.3。

**地面：** 一个 `PlaneMesh(1000×1000)` 的 `MeshInstance3D`，材质颜色与背景相同，置于原点。它不是碰撞体，仅作视觉参考。

**输入延迟：** `PrepareTimer` 设 wait_time=0.2 秒，one_shot=true。作用是开局后给 200ms 缓冲，防止玩家在场景切换瞬间误触。

### 3.3 主场景脚本核心逻辑

```gdscript
# scripts/main.gd
extends Node3D

var player_scene = preload("res://scenes/player.tscn")
var platform_scene = preload("res://scenes/platform.tscn")

var player: Node3D = null
var current_platform: Node3D = null
var next_platform: Node3D = null
var input_ready: bool = false

func _ready() -> void:
    GameState.state_changed.connect(_on_state_changed)
    $PrepareTimer.timeout.connect(_on_prepare_timer_timeout)
    _enter_main_menu()

func _on_state_changed(new_state: GameState.State) -> void:
    match new_state:
        GameState.State.MAIN_MENU:  _enter_main_menu()
        GameState.State.PLAYING:    _enter_playing()
        GameState.State.GAME_OVER:  _enter_game_over()
```

三个 enter 方法的职责：

| 方法 | 清除旧对象 | UI 显隐 | 额外操作 |
|------|-----------|---------|---------|
| `_enter_main_menu()` | 清除玩家+平台 | 显示 MainMenu，隐藏其他 | — |
| `_enter_playing()` | 清除玩家+平台 | 显示 Scoreboard，隐藏其他 | 重置分数，生成初始两个平台，实例化玩家，启动延迟计时器，播放开局音效 |
| `_enter_game_over()` | — | 显示 GameOver，隐藏 Scoreboard | — |

---

## 四、平台系统

### 4.1 平台场景（platform.tscn）

```
Platform (Node3D)
├── BoxMesh (MeshInstance3D)       # BoxMesh(1.5, 1.0, 1.5)，offset (0, 0.5, 0)
└── CylinderMesh (MeshInstance3D)  # CylinderMesh(r=0.75, h=1.0)，offset (0, 0.5, 0)
```

注意：两个网格的 transform 原点都上移了 0.5，这样平台节点的 `(0, 0.5, 0)` 处平台顶面在 Y=1.0，底面在 Y=0。

### 4.2 平台脚本

```gdscript
# scripts/platform.gd
extends Node3D

var shape: String = "box"
var is_current: bool = false

func _ready() -> void:
    _randomize()

func _randomize() -> void:
    if randi() % 2 == 0:
        shape = "box"
        $BoxMesh.visible = true
        $CylinderMesh.visible = false
    else:
        shape = "cylinder"
        $BoxMesh.visible = false
        $CylinderMesh.visible = true

    var color = Color(randf(), randf(), randf())
    if shape == "box":
        $BoxMesh.material_override = StandardMaterial3D.new()
        $BoxMesh.material_override.albedo_color = color
    else:
        $CylinderMesh.material_override = StandardMaterial3D.new()
        $CylinderMesh.material_override.albedo_color = color

    set_meta("shape", shape)
```

- 50% 概率生成长方体或圆柱体，两个网格互斥显示
- 颜色完全随机
- 碰撞检测用 `meta("shape")` 判断是哪种形状（当前实现中两种形状使用相同的方形碰撞判定）

### 4.3 平台生成逻辑（main.gd）

```gdscript
func _generate_next_platform() -> void:
    var distance = randf() * 1.5 + 2.5       # 2.5 ~ 4.0 单位
    var direction = randi() % 2               # 0 = +X, 1 = -Z
    var pos: Vector3
    if direction == 0:
        pos = Vector3(current_platform.position.x + distance, 0.5, 0)
    else:
        pos = Vector3(0, 0.5, current_platform.position.z - distance)
    next_platform = _spawn_platform(pos, false)
```

关键设计：
- 生成方向只沿 +X 或 -Z，保证两个平台的连线只有一条轴变化，跳跃时方向判断简单
- 距离在 2.5~4.0 之间随机，蓄力越久跳得越远
- 初始两个平台：current 在 `(0, 0.5, 0)`，next 在随机方向

### 4.4 平台动画

在 `main.gd:_process(delta)` 中处理当前平台的压缩/回弹：

- **蓄力时压缩：** `scale.y` 以 `0.15/秒` 速度线性减小，最低到 0.6（沿 Y 轴压扁）
- **跳跃后回弹：** 用 `lerp` 以 5.0/秒速度恢复 `scale.y` 到 1.0

---

## 五、玩家系统

### 5.1 玩家场景（player.tscn）

```
Player (Node3D)
├── MeshInstance3D          # CapsuleMesh(r=0.2, mid_height=0.5)，粉色
├── ChargeParticles (GPUParticles3D)  # 蓄力粒子特效
├── ChargeParticleTimer (Timer)       # 每 200ms 触发粒子爆发
├── AccumulationSound (AudioStreamPlayer3D)
├── SuccessSound (AudioStreamPlayer3D)
└── FallSound (AudioStreamPlayer3D)
```

**粒子配置要点：**
- `amount=3`，`one_shot=true`，`lifetime=2.0`
- 发射形状：球体，半径 1.0
- 无重力，`damping=8.0`（快速减速悬浮）
- 颜色渐变：白→黄→红→透明
- 大小渐变：0→0.05（维持到 30% 生命）→0
- Timer 每 200ms 重启粒子系统，产生持续爆发效果

### 5.2 玩家状态机

玩家有四种内部状态，通过 `_process(delta)` 按条件分发：

```
IDLE  →  CHARGING  →  JUMPING  →  IDLE（成功落地）
                              ↘  FALLING  →  GAME_OVER
```

实现方式不是显式枚举，而是用布尔标志组合：
- `charging` — 正在蓄力
- `jump_active` — 正在空中跳跃
- `fall_active` — 正在下落

三个状态互斥，`_process` 中通过 if-elif 链分发到对应动画函数。

### 5.3 输入处理

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if GameState.current_state != GameState.State.PLAYING:
        return
    if not get_parent().input_ready:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and not jump_active and not fall_active:
            _start_charge()
        elif not event.pressed and charging:
            _do_jump()
```

三层守卫：
1. 非 PLAYING 状态不响应
2. `input_ready=false` 时不响应（开局 200ms 延迟）
3. 仅处理鼠标左键

### 5.4 蓄力机制

```gdscript
const MAX_SCALE_XZ: float = 1.3       # 横向最大拉伸
const MIN_SCALE_Y: float = 0.6        # 纵向最小压缩
const CHARGE_XZ_RATE: float = 0.12    # 横向缩放速率
const CHARGE_Y_RATE: float = 0.15     # 纵向缩放速率

func _start_charge() -> void:
    charging = true
    charge_start_time = Time.get_ticks_msec() / 1000.0
    charge_particles.emitting = true
    charge_particle_timer.start()
    accumulation_player.play()

func _animate_charge(delta: float) -> void:
    # 横向拉宽
    scale.x = min(scale.x + CHARGE_XZ_RATE * delta, MAX_SCALE_XZ)
    scale.z = min(scale.z + CHARGE_XZ_RATE * delta, MAX_SCALE_XZ)
    # 纵向压扁
    scale.y = max(scale.y - CHARGE_Y_RATE * delta, MIN_SCALE_Y)
    # 保持底部贴地
    position.y = INITIAL_POS.y + (scale.y - 1.0) * 0.25
```

视觉效果：
- 玩家像弹簧一样被压扁拉宽
- 粒子每 200ms 爆发一次
- 平台同步下压
- 蓄力音效播放

### 5.5 跳跃机制

**跳跃距离计算：**
```gdscript
const JUMP_SPEED: float = 3.0

func _do_jump() -> void:
    var charge_time = Time.get_ticks_msec() / 1000.0 - charge_start_time
    charging = false
    # 停止粒子、音效，恢复缩放
    scale = Vector3.ONE
    position.y = INITIAL_POS.y

    # 计算落点
    var current_platform = get_parent().current_platform
    var next_platform = get_parent().next_platform
    var landing_pos = current_platform.position + Vector3(0, INITIAL_POS.y, 0)

    if next_platform.position.x != current_platform.position.x:
        # X 轴跳跃
        landing_pos.x = current_platform.position.x + JUMP_SPEED * charge_time
    else:
        # Z 轴跳跃
        landing_pos.z = current_platform.position.z - JUMP_SPEED * charge_time

    jump_active = true
    jump_start_pos = position
    jump_end_pos = Vector3(landing_pos.x, INITIAL_POS.y, landing_pos.z)
    jump_duration = max(charge_time / 2.0, 0.5)  # 最短 0.5 秒
```

核心逻辑：
- 蓄力越久 → `charge_time` 越大 → 跳跃距离越远
- 方向判断：比较 current 和 next 的 X/Z 值，沿不同的轴移动
- 最短跳跃时间 0.5 秒，防止瞬移

**跳跃动画（圆弧运动）：**

跳跃不是物理模拟，而是纯数学的圆弧旋转：

```gdscript
func _animate_jump(delta: float) -> void:
    var mid_point = (jump_start_pos + jump_end_pos) / 2.0
    mid_point.y = INITIAL_POS.y + 0.5  # 弧顶略高于起终点

    var axis = Vector3.RIGHT if jump_end_pos.z != jump_start_pos.z else Vector3.BACK
    var angle = -(1.0 / jump_duration) * PI * delta

    # 绕中点旋转，产生圆弧轨迹
    position = mid_point + (position - mid_point).rotated(axis, angle)

    # 同时自转（翻转一圈）
    rotation_degrees += Vector3(
        (1.0 / jump_duration) * 360.0 * delta * (1 if axis == Vector3.RIGHT else 0),
        0,
        (1.0 / jump_duration) * 360.0 * delta * (1 if axis == Vector3.BACK else 0)
    )
```

要点：不依赖物理引擎，用 `rotated()` 绕中点旋转产生半圆弧轨迹，同时绕自身轴翻转一圈。

### 5.6 落地检测

**不依赖物理引擎，完全用数学判定：**

```gdscript
const PLATFORM_HALF_SIZE: float = 0.75   # 平台半边长

static func _is_landed_on(platform: Node3D, pos: Vector3) -> bool:
    return abs(pos.x - platform.position.x) < PLATFORM_HALF_SIZE and \
           abs(pos.z - platform.position.z) < PLATFORM_HALF_SIZE

static func _is_touched(platform: Node3D, pos: Vector3, radius: float) -> bool:
    return abs(pos.x - platform.position.x) < PLATFORM_HALF_SIZE + radius and \
           abs(pos.z - platform.position.z) < PLATFORM_HALF_SIZE + radius
```

三种落地结果：

| 情况 | 判定条件 | 结果 |
|------|---------|------|
| 踩中 next 平台 | `_is_landed_on(next)` = true | +1 分，生成新平台 |
| 落回 current 平台 | `_is_landed_on(current)` = true | 不得分，留在原地 |
| 擦边 | `_is_touched(platform, pos, 0.2)` = true | 倾斜掉落 |
| 完全踩空 | 以上都不满足 | 垂直掉落 |

**成功落地后（player.gd → main.gd）：**
```gdscript
# main.gd
func _on_player_landed() -> void:
    current_platform.is_current = false
    next_platform.is_current = true
    current_platform = next_platform
    next_platform = null
    _generate_next_platform()
```

### 5.7 掉落机制

**垂直掉落（完全踩空）：**
```gdscript
func _start_straight_fall(pos: Vector3) -> void:
    fall_active = true
    fall_type = FallType.STRAIGHT
    position = Vector3(pos.x, INITIAL_POS.y, pos.z)

func _animate_fall(delta: float) -> void:
    if not fall_played_sound:
        fall_player.play()
        fall_played_sound = true
    position.y -= FALL_SPEED * delta          # 每秒下降 0.7 单位
    if position.y < 0.5:
        fall_active = false
        GameState.change_state(State.GAME_OVER)
```

**倾斜掉落（踩到平台边缘）：**
```gdscript
func _start_tilt_fall(pos: Vector3, direction: Vector3) -> void:
    # 第一阶段：绕平台边缘旋转
    var pivot = Vector3(landing_pos.x, 1.0, landing_pos.z)
    # 使用四元数绕水平轴旋转
    position = pivot + (position - pivot).rotated(rotation_axis, PI / 2.0 * delta)
    # 当降到 pivot 以下后 → 第二阶段：垂直下落
```

两种掉落都会在 `position.y` 低于阈值后触发 `GAME_OVER` 状态。

---

## 六、相机系统

```gdscript
# scripts/camera.gd
extends Camera3D

const INITIAL_POS := Vector3(-5.0, 8.0, 5.0)

func _ready() -> void:
    position = INITIAL_POS
    look_at(Vector3.ZERO)

func _process(delta: float) -> void:
    if GameState.current_state != GameState.State.PLAYING:
        return

    var player = get_parent().player
    if not player or player.jump_active or player.fall_active:
        return   # 跳跃/掉落时相机不动

    var destination = INITIAL_POS + Vector3(player.position.x, 0, player.position.z)
    position = position.lerp(destination, 0.05)   # 平滑跟随
```

要点：
- 等距视角，从 `(-5, 8, 5)` 看向原点，约 45 度俯角
- 只在玩家**静止**时跟随（`jump_active=false && fall_active=false`）
- 跳跃和掉落过程中相机冻结，观众能看清跳跃轨迹
- 使用 `lerp` 做平滑插值，系数 0.05 产生缓冲效果

---

## 七、UI 系统

所有 UI 放在 `CanvasLayer` 下，确保渲染在 3D 场景之上。

### 7.1 主菜单（main_menu.gd）

```
CenterContainer
└── VBoxContainer
    ├── TextureRect (title.png)
    └── Button (btn_start.png) → 点击触发 GameState.change_state(PLAYING)
```

完全用代码构建 UI，不依赖场景文件中的节点布局。

### 7.2 游戏结束（game_over.gd）

```
CenterContainer
└── VBoxContainer
    ├── TextureRect (title.png)
    └── HBoxContainer
        ├── Button (btn_home.png)    → GameState.change_state(MAIN_MENU)
        └── Button (btn_restart.png) → GameState.change_state(PLAYING)
```

### 7.3 计分板（scoreboard.gd）

- **固定分数：** 左上角 `(30, 30)` 位置，字号 40，颜色 `(0.5, 0.5, 1.0)` 淡蓝
- **"+1" 浮动文字：** 成功落地时生成

浮动文字实现：
```gdscript
func _on_score_up(landing_pos: Vector3) -> void:
    var label = Label.new()
    label.text = "+1"
    var screen_pos = camera.unproject_position(landing_pos)
    label.position = screen_pos
    score_up_labels.append(label)
    add_child(label)

func _process(delta: float) -> void:
    for label in score_up_labels:
        label.position.y -= 100.0 * delta       # 向上浮动
        label.modulate.a *= 0.97                # 逐渐透明
        if label.modulate.a < 0.05:
            label.queue_free()
```

- 用 `camera.unproject_position()` 将 3D 世界坐标转为屏幕坐标
- 每帧向上移动 100px，透明度乘以 0.97
- alpha < 0.05 时移除

注意：`Scoreboard` 节点的 `mouse_filter` 设为 `MOUSE_FILTER_IGNORE`，确保点击穿透到 3D 场景中的玩家输入处理。

---

## 八、音效系统

### 8.1 音效清单

| 文件 | 触发时机 | 播放器类型 |
|------|---------|-----------|
| `start.mp3` | 进入 PLAYING 状态 | `AudioStreamPlayer`（2D） |
| `accumulation.mp3` | 开始蓄力 | `AudioStreamPlayer3D`（3D 空间音效） |
| `success.mp3` | 成功落地 | `AudioStreamPlayer3D` |
| `fall.mp3` | 开始掉落 | `AudioStreamPlayer3D` |

开局音效用 2D 播放器（全局音效），其余用 3D 播放器（有空间距离衰减效果）。

### 8.2 播放时机

- **蓄力音效：** `_start_charge()` 中播放一次。注意：当前未设置为循环播放，长时间蓄力可能只播放一次。如需循环应设置 `$AccumulationSound.set_stream(load("res://..."))` 并在停止时调用 `stop()`。
- **成功音效：** 跳跃动画结束、确认未失败后播放
- **掉落音效：** 掉落第一帧播放，`fall_played_sound` 标志防止重复

---

## 九、完整游戏流程总结

```
1. 启动游戏
   └→ GameState 初始化 (MAIN_MENU, score=0)
   └→ main.tscn 加载，调用 _enter_main_menu()
   └→ 显示标题 + 开始按钮

2. 点击"开始"
   └→ GameState.change_state(PLAYING)
   └→ _enter_playing():
        ├→ 清除旧对象
        ├→ 显示计分板
        ├→ 重置分数
        ├→ 生成两个平台（current 在原点，next 在随机方向）
        ├→ 实例化玩家在 current 上方
        ├→ 播放开局音效
        └→ 启动 200ms 延迟计时器

3. 玩家蓄力
   └→ 按住鼠标左键
   └→ 玩家横向拉伸、纵向压缩
   └→ 平台同步下压
   └→ 粒子每 200ms 爆发
   └→ 蓄力音效播放

4. 玩家跳跃
   └→ 松开鼠标左键
   └→ 计算 charge_time → 算距离 → 算落点
   └→ 判定落点与平台的关系
   ├→ [踩中 next] → 加 1 分，显示 "+1"，播放成功音效
   │                → current 平台退役，next 升级为 current
   │                → 生成新的 next 平台
   │                → 回到步骤 3
   ├→ [落回 current] → 不弹 "+1"，无声继续，回到步骤 3
   ├→ [擦边] → 倾斜掉落动画 → 步骤 5
   └→ [完全踩空] → 垂直掉落动画 → 步骤 5

5. 游戏结束
   └→ 玩家降到 Y < 0.5（垂直掉落）或 Y < 0.2（倾斜掉落）
   └→ GameState.change_state(GAME_OVER)
   └→ 显示结束画面 + 分数
   └→ 玩家可选择：
        ├→ Home → 回到主菜单（步骤 1）
        └→ Restart → 重新开始（步骤 2）
```

---

## 十、关键设计决策

### 不依赖物理引擎

整个游戏不使用 Godot 物理引擎进行碰撞检测或运动模拟。跳跃轨迹用几何旋转计算，落地判定用坐标比较。这样做的优点：
- 确定性 100%，不受物理帧率影响
- 计算量小，适合低端设备
- 跳跃行为可精确调参

### 单向移动

平台只在 +X 和 -Z 两个方向生成，不转弯、不折返。这使得跳跃方向始终明确，简化了跳跃落点计算。

### 状态驱动架构

所有模块（玩家输入、相机行为、UI 显隐、平台生成）都通过 `GameState.current_state` 的值和 `state_changed` 信号来驱动，而不是互相调用方法。这降低了模块间的耦合。

### 纯代码构建 UI

菜单、游戏结束界面、计分板全部在脚本中用代码构建（而非在场景编辑器中手动摆放），因为 UI 结构简单，代码构建更直观且便于版本管理。
