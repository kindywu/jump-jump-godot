# 跳一跳 — 可改用 Godot 内置机制的条目

本文列出项目中用手动计算实现、但 Godot 已有内置方案的功能点。每个条目给出 **方案 A（Tween）** + **方案 B（AnimationPlayer / 物理 / 其他）** 的多选对比，以及各自的收益和适用场景。

---

## 1. 属性动画：_process 手改值 → Tween / AnimationPlayer

### 当前做法

在 `_process(delta)` 中每帧手动修改 scale、position 等属性，用 `minf/maxf/lerpf` 控制边界，用布尔标志管理动画生命周期。涉及 4 处：

| 动画 | 文件 | 行数 | 动态参数 |
|------|------|------|---------|
| 蓄力缩放 | player.gd:148-153 | 6 | 时长未知（玩家按多久不定） |
| 平台压缩/回弹 | main.gd:21-29 | 10 | 时长未知（与蓄力同步） |
| 跳跃圆弧 | player.gd:155-180 | 26 | 落点/时长均运行时决定 |
| "+1" 漂浮 | scoreboard.gd | 15 | 固定时长 1 秒 |

---

### 方案 A：Tween

**原理：** `create_tween()` 声明式地描述"把属性 X 从当前值变到目标值 B，持续 C 秒，用 D 缓动曲线"。

#### A.1 蓄力缩放

```gdscript
# 之前：_process 每帧
scale.x = minf(scale.x + CHARGE_XZ_RATE * delta, MAX_SCALE_XZ)
scale.y = maxf(scale.y - CHARGE_Y_RATE * delta, MIN_SCALE_Y)
scale.z = minf(scale.z + CHARGE_XZ_RATE * delta, MAX_SCALE_XZ)
position.y = INITIAL_POS.y + (scale.y - 1.0) * 0.25

# 之后：松手时创建回弹 Tween，蓄力阶段保留 _process
# （蓄力时长未知，Tween 不适合描述"持续到松手"的动画，但松手后的回弹适合）
var t = create_tween()
t.set_parallel(true)
t.tween_property(self, "scale", Vector3.ONE, 0.15)
t.tween_property(self, "position:y", INITIAL_POS.y, 0.15)
```

**蓄力阶段 Tween 的局限：** Tween 需要知道目标值和时长，而蓄力"按多久"是玩家决定的。可以用 `tween_property` 设一个很长的时长 + `kill()` 中断，但这就退化成了手动控制，没有发挥 Tween 的优势。

#### A.2 平台压缩与回弹

```gdscript
# 之前：_process 里判断 charging 标志
if player and player.get("charging"):
    current_platform.scale.y = maxf(current_platform.scale.y - 0.15 * delta, 0.6)
elif current_platform.scale.y < 1.0:
    current_platform.scale.y = lerpf(current_platform.scale.y, 1.0, 5.0 * delta)

# 之后：蓄力时保留 _process（同蓄力原因），回弹用 Tween
var t = create_tween()
t.tween_property(current_platform, "scale:y", 1.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
```

#### A.3 跳跃圆弧

跳跃的落点和时长都是运行时算出来的——这正是 Tween 的强项：

```gdscript
# 之前：26 行，手算 Quaternion 绕中点旋转 + 手判落地时机
var quat := Quaternion(rotate_axis, angle)
var offset := position - around_point
position = around_point + quat * offset
if new_pos.y < INITIAL_POS.y:
    # ...落地逻辑

# 之后：5 行
var t = create_tween()
t.set_parallel(true)
t.tween_property(self, "position", landing_pos, jump_duration) \
    .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
t.tween_property(self, "rotation:y", TAU, jump_duration) \
    .set_trans(Tween.TRANS_LINEAR)
t.finished.connect(_on_jump_finished)
```

**收益：**
- 26 行 → 5 行
- `TRANS_QUAD` + `EASE_OUT` 自然产生起跳快→到顶慢的弧线感
- `finished` 信号天然是落地回调
- 不再需要 `jump_start_pos`、`jump_duration`、`_animate_jump` 函数

#### A.4 漂浮 "+1" 文字

```gdscript
# 之前：_process 每帧手改 position.y 和 modulate.a + 数组管理
label.position.y -= 100.0 * delta
label.modulate.a *= 0.97
if label.modulate.a < 0.05:
    label.queue_free()

# 之后：创建标签时绑定 Tween，完成自动销毁
var t = create_tween().set_parallel(true)
t.tween_property(label, "position:y", label.position.y - 60, 1.0)
t.tween_property(label, "modulate:a", 0.0, 1.0)
t.finished.connect(label.queue_free)
```

**收益：**
- 删掉 `scoreboard.gd:_process` 整个函数
- 删掉 `score_up_labels` 数组
- 可用缓动曲线表现更自然的淡出

#### A 方案收益汇总

| 指标 | 之前 | 之后 |
|------|------|------|
| `_process` 函数数 | 3 个 | 0 个（或只保留状态检查，不做数值运算） |
| 代码行数 | ~55 行动画逻辑 | ~15 行 Tween 声明 |
| 缓动效果 | 仅 linear/lerp | 任意内置曲线 |
| 可中断性 | 手动标志位 | `tween.kill()` 一行 |

---

### 方案 B：AnimationPlayer

**原理：** 在编辑器中为节点定义基于关键帧的动画轨道，代码中 `$AnimationPlayer.play("name")` 触发。

#### B.1 AnimationPlayer 与 Tween 的本质区别

```
Tween:
  目标值 → 运行时传入（代码计算）
  时长   → 运行时传入（代码计算）
  曲线   → 运行时指定

AnimationPlayer:
  目标值 → 资源内固定（在编辑器中画好）
  时长   → 资源内固定（关键帧间距决定）
  曲线   → 资源内固定（在曲线编辑器里拉）
```

**一句话：Tween 适合 "把 A 变到未知的 B，持续未知的 C 秒"（程序化动画）；AnimationPlayer 适合 "播放攻击动画，0.3 秒挥刀，0.5 秒收刀"（预定义动画资源）。**

#### B.2 逐功能适用性分析

**蓄力：不适合。** 蓄力时长和终点值都由玩家决定，不是预定义的。

**平台回弹：适合但过度。** 定义 0.2 秒的 "spring_back" 动画很简单，但 3 行 Tween 就能搞定的事，创建一个 `.tres` 动画资源有点重。

**跳跃：部分适合。** 可以拆成 3 段混合使用：

```gdscript
# 起跳姿势（AnimationPlayer：预定义的 squash & stretch）
$AnimationPlayer.play("jump_takeoff")     # 0.15s
await $AnimationPlayer.animation_finished

# 空中位移（Tween：距离和时长运行时确定）
var t = create_tween()
t.tween_property(self, "position", landing_pos, jump_duration)
await t.finished

# 落地姿势（AnimationPlayer：预定义的压缩回弹）
$AnimationPlayer.play("jump_land")        # 0.15s
```

**掉落：适合。** 定义循环的翻滚动画：

```gdscript
$AnimationPlayer.play("fall_loop")
# body_entered 触发时:
$AnimationPlayer.stop()
```

**"+1" 文字：可以但不必要。** Label 是运行时动态创建的，给动态节点挂 AnimationPlayer 虽然可行，但不如 Tween 直接在代码里创建来得直接。

#### B.3 B 方案收益

| 优势 | 说明 |
|------|------|
| 编辑器可视化 | 时间轴面板直观看到每个属性如何变化，可以拖拽关键帧 |
| 曲线编辑器 | 精细控制每段插值曲线，所见即所得 |
| 资源复用 | 一个动画资源可以被多个对象引用 |
| 过渡混合 | `AnimationTree` 可以在动画间做 blend（如 idle→walk→run 的平滑切换） |

| 局限 | 说明 |
|------|------|
| 运行时动态性差 | 目标值和时长写死，改动需要 `speed_scale`、`seek()` 等变通手段 |
| 文件碎片 | 每个动画是一个 `.tres` 资源，动画多了管理成本上升 |
| 过度设计 | 简单动画（如 scale:y=0.6→1.0）建资源反而增加复杂度 |

---

### 建议选择

| 动画 | 推荐方案 | 原因 |
|------|---------|------|
| 蓄力缩放 | 保留手动 | 时长和进度由玩家实时输入驱动，Tween/AnimationPlayer 都不擅长 |
| 平台回弹 | **Tween** | 动画简单（单属性），代码一行搞定 |
| 跳跃 | **Tween** | 落点和时长运行时计算，Tween 的原生场景 |
| 漂浮文字 | **Tween** | 对象是动态创建的，Tween 跟着对象走 |
| 未来：角色待机/落地弹跳 | **AnimationPlayer** | 固定循环动画，编辑器可视化有优势 |
| 未来：UI 切换过渡 | **AnimationPlayer** | 多属性精细时序控制 |

---

## 2. 碰撞检测：坐标比较 → Area3D / PhysicsBody3D

### 当前做法

```gdscript
# player.gd:224-244 — 手动比较 X/Z 坐标
static func _is_landed_on(platform, pos):
    return abs(pos.x - platform.x) < 0.75 and abs(pos.z - platform.z) < 0.75
```

### 方案 A：Area3D + body_entered 信号

```gdscript
# 平台侧：在 platform.tscn 或 _ready() 中加节点
var area = Area3D.new()
var shape = CollisionShape3D.new()
if self.shape == "box":
    shape.shape = BoxShape3D.new()
    shape.shape.size = Vector3(1.5, 1.0, 1.5)
else:
    shape.shape = CylinderShape3D.new()
    shape.shape.radius = 0.75
    shape.shape.height = 1.0
area.add_child(shape)
add_child(area)

# 玩家侧：连接信号
func _ready():
    for platform in get_tree().get_nodes_in_group("platforms"):
        platform.area.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
    if body == self and not jump_failed:
        # 成功落地
```

**收益：**
- 圆柱用 CylinderShape3D 做真正的圆形判定，不再用矩形近似
- 碰撞体在编辑器中可见线框，方便可视化调试
- 不需要 `_is_landed_on`、`_is_touched` 两个静态函数
- 信号驱动，不依赖跳跃终点那一帧的判断

### 方案 B：RigidBody3D + 物理模拟

```gdscript
# 玩家根节点改为 RigidBody3D
# 平台加 StaticBody3D + CollisionShape3D
# 掉落时 free_mode=true，自动受重力加速
# 碰撞自动处理
```

**收益：**
- 掉落有真实重力加速度（不再匀速 0.7/秒）
- 碰撞发生时自动回调，不需要 `_is_touched`
- 可以在编辑器里用 Jolt Physics 的可视化调试工具

**代价：**
- 需要调参（质量、重力、阻尼）
- 引入不确定性（物理帧和非物理帧的差异）
- 对回合制休闲游戏来说过重

### 建议选择

| | Area3D | RigidBody3D | 手算坐标 |
|---|--------|------------|----------|
| 复杂度 | 中 | 高 | 低 |
| 精度 | 真实形状 | 真实形状+物理 | 矩形近似 |
| 确定性 | 高 | 中 | 100% |
| 当前适用 | **推荐** | 不推荐 | 当前够用 |

---

## 3. 粒子发射：Timer + restart() → GPUParticles3D emitting / AnimationPlayer

### 当前做法

```gdscript
# player.tscn: Timer 每 200ms 触发
# player.gd:144-146
func _on_charge_particle_timeout():
    if charging:
        charge_particles.restart()
```

### 方案 A：GPUParticles3D 持续发射模式

```gdscript
# player.tscn 粒子节点配置改为:
#   one_shot = false     ← 持续发射
#   amount = 3
#   lifetime = 2.0
#   explosiveness = 0.0  ← 均匀发射（非爆发）

# player.gd:
func _start_charge():
    charge_particles.emitting = true

func _do_jump():
    charge_particles.emitting = false
```

**收益：**
- 删掉 `ChargeParticleTimer` 节点
- 删掉 `_on_charge_particle_timeout` 回调
- 发射频率由粒子的 `amount`/`lifetime`/`speed_scale` 统一控制
- `emitting = true/false` 语义明确

### 方案 B：AnimationPlayer 控制粒子 + 其他效果

如果将来蓄力时还要同步触发其他效果（屏幕震动、颜色渐变），可以定义：

```
AnimationPlayer track "charge_loop":
  "ChargeParticles:emitting"     → true
  "ChargeParticles:speed_scale"  → 0.0→1.0  渐变加速
  "MeshInstance3D:material:albedo_color" → 白→红  渐变发热
```

```gdscript
func _start_charge():
    $AnimationPlayer.play("charge_loop")
func _do_jump():
    $AnimationPlayer.stop()
```

**收益：** 多效果同步编排，编辑器可视化调整节奏。

**代价：** 当前只有粒子一个效果，用 AnimationPlayer 过于复杂。

### 建议选择

当前用 **方案 A**（持续发射模式），一行改动，删一个节点。如果将来蓄力效果变复杂（粒子 + 屏幕震动 + 颜色 + 音效变调），切换到 **方案 B**。

---

## 4. 相机跟随：_process lerp → Tween / PhantomCamera3D

### 当前做法

```gdscript
# camera.gd:28 — _process 中每帧 lerp
position = position.lerp(INITIAL_POS + player_pos, 0.05)
```

### 方案 A：Tween 替代 lerp

```gdscript
# 玩家移动到新位置后，创建 Tween 让相机平滑追上
func follow_player(target_pos: Vector3):
    var destination = INITIAL_POS + Vector3(target_pos.x, 0, target_pos.z)
    var t = create_tween()
    t.tween_property(self, "position", destination, 0.5) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
```

**收益：**
- 删掉 `camera.gd:_process`
- 相机移动有加速/减速，比纯 lerp 自然
- 移动时长固定（0.5 秒），不依赖帧率

**局限：** 需要知道"玩家停下来了"的信号来触发 Tween，当前是在 `_process` 中连续跟的。

### 方案 B：PhantomCamera3D（插件）

[PhantomCamera](https://github.com/ramokz/phantom-camera) 是 Godot 社区最成熟的相机插件，提供：

```
PhantomCamera3D
  ├── follow_target: Node3D    ← 设置跟踪目标
  ├── follow_damping: Vector3  ← 各轴平滑系数
  ├── tween_on_start: bool     ← 切换时自动 Tween
  └── 边界限制 / 震动 / 多机位 等
```

**收益：**
- 零代码实现跟随、平滑、边界限制
- 编辑器内可视化相机视角预览
- 多机位切换（菜单一个相机、游戏中一个相机）天然支持

**代价：** 引入额外插件依赖。

### 建议选择

当前相机逻辑简单（只跟 XZ，跳跃时不跟），手写 `lerp` 或 Tween 就够了。如果将来有多机位（菜单/游戏/结束各一个相机角度 + 平滑切换）、屏幕震动等需求，**PhantomCamera3D** 会很划算。

---

## 5. 掉落：手写速度+旋转 → Tween / RigidBody3D

### 当前做法

```gdscript
# player.gd:182-208 — 手写两阶段掉落
# 匀速下降: position.y -= FALL_SPEED * delta
# 倾斜:    Quaternion 绕边缘旋转
```

### 方案 A：Tween 驱动掉落动画

```gdscript
var t = create_tween()
# 倾斜阶段
t.tween_property(self, "position:y", 0.5, 0.8)
t.parallel().tween_property(self, "rotation:x", PI/4, 0.8)
# 垂直下落阶段
t.tween_property(self, "position:y", -2.0, 0.5)
t.finished.connect(func(): GameState.change_state(GAME_OVER))
```

**收益：** 统一的动画管理方式，不额外引入物理。

### 方案 B：RigidBody3D

```gdscript
# 掉落时解除运动约束
freeze = false
free_mode = true
gravity_scale = 1.0
# 地面挂 StaticBody3D
# body_entered → game over
```

**收益：**
- 真实重力加速度（不再匀速）
- 如果撞到侧面平台会自然弹开/翻滚
- 不需要手写掉落逻辑

**代价：** 物理需要调试参数，结果是概率性的（比如不同帧率下碰撞响应略有不同）。

### 建议选择

跳一跳的掉落是纯演出，不影响玩法。**方案 A（Tween）** 足以获得比当前更好的缓动效果，且保持确定性。方案 B 只有期待掉落有物理交互（如撞到平台翻滚）时才值得。

---

## 6. 平台移动：手写方向判断 → Vector3 运算 / Path3D

### 当前做法

```gdscript
# main.gd:94-107 — if/else 判断走 X 还是 Z
if randi() % 2 == 0:
    next_pos = Vector3(current_pos.x + rand_distance, 0.5, current_pos.z)
else:
    next_pos = Vector3(current_pos.x, 0.5, current_pos.z - rand_distance)
```

同样，跳跃方向判断（player.gd:109-116）也是 if/else。

### 方案 A：Vector3 方向向量

```gdscript
# 平台生成
var directions = [Vector3.RIGHT, Vector3.BACK]
var dir = directions[randi() % 2]
next_pos = current_pos + dir * rand_distance + Vector3(0, 0.5, 0)

# 跳跃方向（自动从平台位置推导，不必硬编码两条分支）
var jump_dir = (next_pos - current_pos).normalized()
jump_dir.y = 0
landing_pos = player_pos + jump_dir * JUMP_SPEED * charge_time
landing_pos.y = INITIAL_POS.y
```

**收益：**
- 消除 if/else 分支
- 加新方向只需往 `directions` 数组加一个向量
- 跳跃方向从平台位置自动推导，不需要手动判断轴

### 方案 B：Path3D + PathFollow3D

如果平台不是随机离散生成，而是沿一条路线摆放：

```gdscript
# 在场景中画一条 Path3D 曲线
# 平台沿曲线生成
var path: Path3D = $PlatformPath
var pos = path.curve.sample_baked(progress)
_spawn_platform(pos)

# 玩家跳跃方向沿曲线切线
var tangent = path.curve.sample_baked(progress).direction_to(
    path.curve.sample_baked(progress + step)
)
```

**收益：** 平台位置可视化成曲线，可以设计环形、S 形等路径。

**代价：** 跳跃方向判断变复杂（曲线上的切线方向可能斜向）。

### 建议选择

当前只有 ±2 个方向，**方案 A** 是最小改动。如果将来想设计弯曲路径（不再是单调向外扩展），再考虑 **方案 B**。

---

## 总结

| # | 功能 | 方案 A | 方案 B | 推荐 |
|---|------|--------|--------|------|
| 1 | 属性动画 | **Tween** — 运行时创建，适合动态目标值 | AnimationPlayer — 预定义资源，适合固定动画 | 回弹/跳跃/漂浮用 Tween；蓄力保留手动 |
| 2 | 碰撞检测 | **Area3D** — 信号驱动，真实形状 | RigidBody3D — 物理模拟 | Area3D，当前项目够用 |
| 3 | 粒子发射 | **GPUParticles3D emitting** — 删 Timer | AnimationPlayer — 多效果同步编排 | 持续发射模式，一行改动 |
| 4 | 相机跟随 | **Tween** — 缓动曲线，删 _process | PhantomCamera3D — 零代码，需装插件 | Tween 够用，多机位时考虑插件 |
| 5 | 掉落动画 | **Tween** — 统一的动画管理 | RigidBody3D — 真实物理 | Tween，物理对休闲游戏过重 |
| 6 | 方向判断 | **Vector3 运算** — 消除分支 | Path3D — 曲线路径可视化 | Vector3 方向向量，两行改动 |

**性价比排序：** `1(跳跃+漂浮) > 2 > 3 > 4 > 6 > 5`
