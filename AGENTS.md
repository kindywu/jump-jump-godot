# Jump Jump Godot — Agent Guide

> 本文件面向 AI 编程助手。阅读者被假定为对该项目一无所知。

---

## 项目概览

**Jump Jump**（跳一跳）是一个 3D 休闲小游戏，从 Bevy 0.18 版本 1:1 移植到 Godot 4.6。

核心玩法：按住鼠标左键蓄力，松开后玩家朝下一个平台跳跃。准确落到平台中心得 1 分，掉落则游戏结束。

- **引擎**：Godot 4.6（Forward Plus 渲染器）
- **语言**：GDScript（强类型标注）
- **物理**：Jolt Physics（已配置，但游戏逻辑未使用物理引擎，全部采用数学碰撞检测）
- **项目路径**：`C:/ws/game/jump-jump-godot`
- **入口场景**：`res://scenes/main.tscn`

---

## 项目结构

```
res://
├── project.godot              # 引擎项目配置
├── scenes/
│   ├── main.tscn              # 主场景：灯光、摄像机、地面、UI CanvasLayer、动态实例容器
│   ├── player.tscn            # 玩家场景：胶囊体、粒子、音效
│   └── platform.tscn          # 平台场景：Box / Cylinder 双 Mesh
├── scripts/
│   ├── game_state.gd          # Autoload：全局状态机与分数管理
│   ├── main.gd                # 主逻辑：场景生命周期、平台生成、状态切换
│   ├── player.gd              # 玩家逻辑：蓄力、跳跃、掉落、碰撞判定
│   ├── platform.gd            # 平台逻辑：随机形状与颜色
│   ├── camera.gd              # 摄像机平滑跟随
│   └── ui/
│       ├── main_menu.gd       # 主菜单：标题图 + 开始按钮
│       ├── game_over.gd       # 结束界面：标题图 + 返回主页/重新开始
│       └── scoreboard.gd      # 计分板：分数显示与 +1 飘字特效
├── assets/
│   ├── fonts/num.ttf          # 计分板数字字体
│   ├── sounds/                # start.mp3, accumulation.mp3, success.mp3, fall.mp3
│   └── texture/               # title.png, btn_start.png, btn_home.png, btn_restart.png, btn_back.png, player.png
└── docs/                      # 设计文档与差异对比（非运行时必须）
    ├── godot-vs-bevy-diff.md
    └── superpowers/
        ├── specs/2026-05-31-jump-jump-godot-design.md
        └── plans/2026-05-31-jump-jump-godot-plan.md
```

---

## 技术栈与运行时架构

### 状态机（GameState Autoload）

`scripts/game_state.gd` 以 Autoload 形式挂载，提供全局状态与信号：

- `enum State { MAIN_MENU, PLAYING, GAME_OVER }`
- `state_changed(new_state)` — 状态切换信号
- `score_changed(new_score)` / `score_up(landing_pos)` — 分数变化信号

所有游戏模块通过 `GameState.current_state` 判断是否响应输入或执行动画。

### 场景层级

`main.tscn` 运行时层级：

```
Main (Node3D) [scripts/main.gd]
├── DirectionalLight3D
├── WorldEnvironment
├── Camera3D [scripts/camera.gd]
├── Ground (MeshInstance3D)
├── StartSound (AudioStreamPlayer)
├── Platforms (Node3D)          ← 动态平台挂载点
├── PrepareTimer (Timer)        ← 200ms 输入延迟
└── UI (CanvasLayer)
    ├── MainMenu [scripts/ui/main_menu.gd]
    ├── GameOver [scripts/ui/game_over.gd]
    └── Scoreboard [scripts/ui/scoreboard.gd]
```

Player 与 Platform 均为运行时 `instantiate()` 动态创建，非场景树常驻节点。

### 碰撞检测

不使用 Godot 物理体（RigidBody/Area3D），完全采用数学 AABB / 圆形边界判定：

- 平台着陆判定：`player.gd` 中 `_is_landed_on()` 与 `_is_touched()`
- Box 形状：`|pos.x - ppos.x| < 0.75` 且 `|pos.z - ppos.z| < 0.75`
- Cylinder 形状：与 Box 使用相同阈值（简化处理）

### 动画方式

所有动画均在 `_process(delta)` 中手动计算：

- 蓄力：逐帧修改 `scale` 与 `position.y`
- 跳跃：基于四元数 `Quaternion` 的弧线路径旋转 + 自转翻转
- 掉落：直线下落 或 绕支点倾斜后下落
- 摄像机：仅在玩家 idle 时做 `lerp` 平滑跟随

---

## 构建与运行

### 开发环境

- **Godot 版本**：4.6（Forward Plus）
- **打开方式**：在 Godot Editor 中打开项目根目录（`project.godot` 所在目录）
- **运行**：编辑器内按 **F5** 或点击「运行项目」

### 无外部构建步骤

Godot 项目无需 `npm install`、`cargo build` 或 `pip install` 等外部构建流程。资源文件（`.mp3`、`.png`、`.ttf`）的 `.import` 文件已由 Godot 自动生成并提交到版本库。

### 导出/发布

使用 Godot 编辑器菜单 **项目 > 导出** 配置导出模板。本项目未配置 CI/CD 导出流水线。

---

## 代码风格规范

### 命名约定

| 类型 | 规范 | 示例 |
|------|------|------|
| 常量 | `CONSTANT_CASE` | `INITIAL_POS`, `JUMP_SPEED` |
| 变量 / 函数 | `snake_case` | `charging`, `_do_jump()` |
| 类 / 枚举 | `PascalCase` | `GameState`, `FallType` |
| 信号 | `snake_case` | `state_changed`, `score_up` |
| 节点引用 | `snake_case`，带类型标注 | `@onready var charge_particles: GPUParticles3D` |

### GDScript 类型标注

所有脚本均使用强类型：

- 函数参数与返回值标注：`func _do_jump() -> void:`、`func _is_landed_on(platform: Node3D, pos: Vector3) -> bool:`
- 成员变量标注：`var charging := false`、`var fall_type: FallType = FallType.STRAIGHT`
- 节点引用使用 `@onready var` + 显式类型

### 代码组织

- 脚本顶部声明常量和成员变量，按功能分组（Jump / Fall / Audio refs / Particle ref）
- 私有函数以下划线 `_` 开头
- 状态变更统一通过 `GameState.change_state()` 触发，避免直接修改 `GameState.current_state`

---

## 测试策略

**本项目目前没有自动化测试。**

验证方式完全依赖手动在 Godot 编辑器内运行（F5）：

1. 主菜单显示标题与开始按钮
2. 点击开始 → 进入游戏，玩家出现在初始平台
3. 按住左键 → 玩家压扁（X/Z 放大、Y 缩小），平台下陷，粒子喷发，蓄力音效播放
4. 松开左键 → 玩家朝下一平台跳跃，翻转动画，成功着陆后播放 success 音效、分数 +1、飘字 "+1"
5. 未落平台 → 掉落动画，播放 fall 音效，进入 Game Over
6. Game Over 界面「返回主页」与「重新开始」按钮功能正常

---

## 开发注意事项

### 输入延迟

进入 `PLAYING` 状态后，`PrepareTimer`（200ms `one_shot`）才会将 `main.gd` 的 `input_ready` 设为 `true`。玩家脚本会检查此标志，避免状态切换瞬间误触输入。

### 粒子系统

蓄力粒子使用 `GPUParticles3D`，通过 `ChargeParticleTimer`（200ms）周期性 `restart()`。当前粒子配置已包含 `ParticleProcessMaterial` 的 `emission_shape`、`damping`、`scale_curve`、`color_ramp`。

### 平台生成

下一平台在 `_generate_next_platform()` 中生成：

- 方向：50% 概率沿 +X，50% 概率沿 -Z
- 距离：`randf() * 1.5 + 2.5`（2.5 ~ 4.0）
- 形状与颜色：平台 `_ready()` 时随机决定

### 音效节点类型

项目中同时使用 `AudioStreamPlayer`（2D，如 `StartSound`）和 `AudioStreamPlayer3D`（3D，如玩家身上的蓄力/成功/掉落音效）。修改时需注意空间化与距离衰减差异。

### 资源冗余

`assets/texture/btn_back.png` 与 `assets/texture/player.png` 存在于项目中但当前代码未引用，属于历史遗留或备用资源。

---

## 安全与部署

- 无网络通信、无用户敏感数据、无外部依赖库
- `.godot/` 与 `android/` 已加入 `.gitignore`
- 版本控制使用 Git，无特殊提交前钩子
