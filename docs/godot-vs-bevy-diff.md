# Godot 实现与原始 Bevy 实现差异对比文档

> 本文档逐条对比 `jump-jump-godot` 与原始 `jump-jump-bevy` 的实现差异，标注「严重」与「轻微」级别，供修复参考。

---

## 一、窗口与显示设置

### 1. [轻微] 默认窗口大小未配置
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| 窗口大小 | 1280×720 | 未设置，使用 Godot 默认（通常为 1152×648） |

**建议修复**：在 `project.godot` 的 `[display]` 段添加：
```ini
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
```

### 2. [轻微] 环境背景色被显式设置
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| 背景 | 无显式设置（默认天空/空白） | `background_mode = 1` + `background_color = Color(0.39, 0.58, 0.93)`（天蓝色） |

**说明**：由于摄像机俯视角度，地面覆盖了大部分视野，此差异通常不可见。但若边缘入镜，会看到蓝色背景而非 Bevy 的默认背景。

---

## 二、摄像机（Camera3D）

### 3. [轻微] 摄像机初始朝向目标点 Y 坐标不一致
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| look_at 目标 | `(0, 0, 0)` | `(0, 1, 0)` |

**影响**：摄像机初始角度有微小差异，玩家初始位置 `(0, 1.5, 0)` 在画面中可能略偏下。

### 4. [轻微] 摄像机平滑跟随算法不同
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| 算法 | 每帧向目标移动剩余距离的固定 `5%`（`0.05 * delta`） | 指数阻尼平滑：`lerp(target, 1.0 - exp(-5.0 * delta))` |

**影响**：两种算法视觉差异较小，但 Godot 版本在远距离瞬移时会更缓慢地接近目标，而 Bevy 版本是线性比例逼近。

---

## 三、光影配置

### 5. [严重] 平行光动态阴影可能未启用
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| 阴影 | `shadows_enabled = true` | 仅设置 `directional_shadow_mode = 0`，未设置 `shadow_enabled = true` |

**说明**：在 Godot 4 中，`DirectionalLight3D` 必须显式设置 `shadow_enabled = true` 才会投射阴影。当前场景文件中缺少该属性，动态阴影可能完全不生效。

**建议修复**：在 `main.tscn` 的 DirectionalLight3D 节点添加：
```
shadow_enabled = true
```

### 6. [轻微] 平行光能量值差异
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| 光照强度 | `illuminance = 15000.0` | `light_energy = 10.0` |

**说明**：Bevy 与 Godot 的光照单位不同，此差异属于引擎换算范畴，无需强制一致，但 `10.0` 在 Godot 中可能偏亮。

---

## 四、场景对象

### 7. [严重] 玩家胶囊体 Y 轴偏移错误，导致玩家悬空
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| 玩家节点位置 | `(0, 1.5, 0)`（胶囊体中心） | `(0, 1.5, 0)`（Player 节点） |
| MeshInstance3D 偏移 | 无（`Transform::IDENTITY`） | `(0, 0.75, 0)`（额外向上偏移） |
| 胶囊体实际中心 Y | `1.5` | `1.5 + 0.75 = 2.25` |
| 胶囊体底部 Y | `1.5 - 0.45 ≈ 1.05` | `2.25 - 0.45 ≈ 1.8` |
| 平台顶面 Y | `1.0` | `1.0` |
| 与平台关系 | 底部轻微嵌入/贴紧平台 | **底部悬空约 0.8 单位** |

**根因**：`player.tscn` 中 `MeshInstance3D` 的 `transform` 包含 `(0, 0.75, 0)` 偏移，但 Bevy 实现中无此偏移。

**建议修复**：将 `player.tscn` 中 `MeshInstance3D` 的 `transform` 改为 `Transform3D.IDENTITY`（或删除偏移），保持玩家中心在 `(0, 1.5, 0)`。

### 8. [中等] 地面位置偏移，平台与地面之间有空隙
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| 地面 Y 坐标 | `0.0`（Plane 在原点） | `-0.5`（Ground 节点 transform 有 `(0, -0.5, 0)` 偏移） |
| 平台底部 Y | `0.0`（中心 0.5 - 高度/2 = 0.0） | `0.0` |
| 地面与平台关系 | 平台底部贴紧地面 | **平台底部与地面之间有空隙 0.5** |

**建议修复**：将 `main.tscn` 中 Ground 节点的 `transform` 改为原点（删除 `(0, -0.5, 0)` 偏移），或调整平台/地面尺寸使二者自然衔接。

### 9. [轻微] 地面尺寸大幅缩小
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| 地面尺寸 | `1,000,000 × 1,000,000` | `100 × 100` |

**影响**：100×100 在当前游戏尺度下通常足够，但若玩家跳到极远处，地面边缘可能入镜。

### 10. [轻微] 音效节点类型不一致
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| 音效维度 | 2D（`AudioPlayer` + `AudioSink`） | 3D（`AudioStreamPlayer3D`） |

**影响**：`AudioStreamPlayer3D` 具有距离衰减和 3D 空间化效果。当摄像机远离玩家时，音效音量可能降低或产生方位变化。建议使用 `AudioStreamPlayer`（2D）以完全还原原始体验。

---

## 五、玩家逻辑

### 11. [中等] 蓄力音效未循环播放
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| 蓄力音效 | `PlaybackSettings::LOOP` 循环播放 | `AudioStreamPlayer3D.play()` 单次播放 |

**影响**：长按蓄力时，若蓄力时间超过音频时长，音效会停止，无法持续反馈。原始实现中 accumulation.mp3 是循环的。

**建议修复**：将蓄力音效节点改为 `AudioStreamPlayer`（2D），并在 `_start_charge()` 中设置循环：
```gdscript
accumulation_player.stream.loop = true
accumulation_player.play()
```

### 12. [中等] 玩家 scale 恢复路径不完整
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| scale 恢复机制 | 每帧检查 accumulator，若 None 则强制 `scale = Vec3::ONE` | 仅在跳跃完成时 `scale = Vector3.ONE`，无全局恢复逻辑 |

**触发场景**：在 `player.gd` 的 `_do_jump()` 中，若 `next_platform == null`，函数直接 `return`，此时 `charging = false`，但 `scale` 保持蓄力后的形变状态不再恢复。

**建议修复**：在 `_process` 中添加全局恢复逻辑，或确保所有退出路径都恢复 scale：
```gdscript
if not charging and not jump_active:
    scale = scale.lerp(Vector3.ONE, 10.0 * delta)
```

### 13. [轻微] 玩家蓄力时位置修正公式等价但写法不同
- Bevy: `translation.y += scale_delta * 0.25`
- Godot: `position.y = INITIAL_POS.y + (scale.y - 1.0) * 0.25`

两者数学上等价，无行为差异。✅

### 14. [轻微] 跳跃动画旋转轴选择逻辑一致
- Bevy: `abs(end.x - start.x) < 0.1 ? Vec3::X : Vec3::Z`
- Godot: `abs(end.x - start.x) < 0.1 ? Vector3.RIGHT : Vector3.BACK`

在各自坐标系中等价。✅

---

## 六、平台逻辑

### 15. [轻微] 平台颜色与形状随机逻辑一致
- 形状：50% Box / 50% Cylinder ✅
- 颜色：`Color(randf(), randf(), randf())` ✅
- 生成距离：`randf() * 1.5 + 2.5` ✅
- 方向：50% +X / 50% -Z ✅

### 16. [轻微] 平台蓄力形变与回弹一致
- 形变速率：`scale.y -= 0.15 * delta`，下限 `0.6` ✅
- 回弹：`lerp(scale.y, 1.0, 5.0 * delta)` ✅

---

## 七、粒子特效（严重简化）

### 17. [严重] 蓄力粒子特效大幅简化，多项参数缺失
| 项目 | Bevy 原始实现（参考约束文档） | Godot 实现 |
|------|-----------------------------|-----------|
| 粒子数量 | 每次爆发 **3 颗** | `amount = 12`（单次发射 12 颗） |
| 发射频率 | 每 200ms **新建并销毁**一组粒子系统 | 每 200ms `restart()` 同一个粒子系统 |
| 发射形状 | 球体，半径 `1.0` | 未设置（默认可能是点发射或 Box） |
| 生命周期 | `2.0` 秒 | `lifetime = 2.0` ✅ |
| 线性阻力 | `8.0` | 未设置 |
| 颜色渐变 | 白(4,4,4) → 黄(4,4,0) → 红(4,0,0) → 透明 | 未设置（默认白色） |
| 大小渐变 | `0.05` → `0.05` → `0` | 固定 `0.05` BoxMesh，无渐变 |
| 发射模式 | `SpawnerSettings::once(3.0)` | `one_shot = true`, `explosiveness = 1.0` |

**影响**：视觉表现与原始实现差异巨大。原始实现是「按住时持续迸发的黄红火花」，Godot 实现是「白色方块喷发」。

**建议修复**：使用 `GPUParticles3D` 的 `process_material`（ParticleProcessMaterial）配置：
- `emission_shape = SPHERE`，`emission_sphere_radius = 1.0`
- `gravity = Vector3.ZERO`
- `damping = 8.0`
- `scale_curve` 设置大小从 1.0 到 0.0 的渐变
- `color_ramp` 设置颜色从白/黄到红到透明的渐变
- `amount = 3`

---

## 八、UI

### 18. [中等] 计分板未使用自定义字体
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| 字体 | `assets/fonts/num.ttf` | 未加载，使用 Godot 默认字体 |
| 字号 | `40.0` | `40` ✅ |
| 颜色 | `Color(0.5, 0.5, 1.0)` | `Color(0.5, 0.5, 1.0)` ✅ |
| 位置 | `left: 30px, top: 30px` | `position = Vector2(30, 30)` ✅ |

**建议修复**：在 `scoreboard.gd` 中为 Label 设置字体：
```gdscript
score_label.add_theme_font_override("font", load("res://assets/fonts/num.ttf"))
```

### 19. [严重] +1 飘字方向错误（向下而非向上）
| 项目 | Bevy 原始实现 | Godot 实现 |
|------|--------------|-----------|
| 飘动方向 | **向上**（世界坐标 Y +1.0 * delta） | **向下**（屏幕坐标 y -= 100.0 * delta） |
| 销毁条件 | 世界坐标 Y > `INITIAL_PLAYER_POS.y + 1.2`（即 2.7） | 屏幕坐标 y < `-40` |
| 坐标同步 | 每帧将世界坐标转屏幕坐标更新 Label 位置 | **仅生成时计算一次**，之后不再同步 |

**影响**：飘字视觉表现完全相反，且摄像机移动时飘字会偏移（因未跟随 3D 世界坐标）。

**建议修复**：
1. 将飘字的世界坐标存储在 Label 的 `metadata` 中
2. 每帧用 `camera.unproject_position(world_pos)` 更新屏幕坐标
3. 世界坐标 Y 每帧 `+1.0 * delta`
4. 当世界坐标 Y > 2.7 时销毁

---

## 九、其他遗漏

### 20. [轻微] 缺少 `btn_back.png` 的使用场景
`assets/texture/btn_back.png` 存在于项目中，但代码中没有任何引用。Bevy 原始实现也没有对应按钮，属于项目资源冗余。

### 21. [轻微] 缺少 `player.png` 的使用场景
`assets/texture/player.png` 存在于项目中，但玩家使用的是 3D 胶囊体 Mesh，未引用此纹理。属于项目资源冗余。

---

## 十、差异汇总表

| 序号 | 差异点 | 严重程度 | 位置 |
|------|--------|---------|------|
| 1 | 默认窗口大小未设置 | 轻微 | `project.godot` |
| 2 | 环境背景色被显式设置 | 轻微 | `main.tscn` |
| 3 | 摄像机 look_at 目标 Y 不同 | 轻微 | `camera.gd` |
| 4 | 摄像机平滑算法不同 | 轻微 | `camera.gd` |
| 5 | 平行光动态阴影可能未启用 | **严重** | `main.tscn` |
| 6 | 平行光能量值差异 | 轻微 | `main.tscn` |
| 7 | 玩家胶囊体 Y 偏移导致悬空 | **严重** | `player.tscn` |
| 8 | 地面位置偏移导致空隙 | 中等 | `main.tscn` |
| 9 | 地面尺寸缩小 | 轻微 | `main.tscn` |
| 10 | 音效节点类型不一致（3D vs 2D） | 轻微 | `player.tscn`, `main.tscn` |
| 11 | 蓄力音效未循环 | 中等 | `player.gd` |
| 12 | 玩家 scale 恢复路径不完整 | 中等 | `player.gd` |
| 13 | 粒子特效大幅简化 | **严重** | `player.tscn`, `player.gd` |
| 14 | 计分板未使用 num.ttf | 中等 | `scoreboard.gd` |
| 15 | +1 飘字方向错误 | **严重** | `scoreboard.gd` |
| 16 | +1 飘字不跟随 3D 坐标 | 中等 | `scoreboard.gd` |

---

## 建议优先修复项（按影响排序）

1. **`player.tscn` MeshInstance3D 偏移** — 导致玩家明显悬空，视觉体验极差
2. **`scoreboard.gd` +1 飘字方向** — 完全违背原始设计意图
3. **`main.tscn` 阴影启用** — 丢失原始 3D 立体感
4. **`player.tscn` 粒子特效** — 蓄力反馈视觉缺失
5. **`main.tscn` 地面偏移** — 平台浮空感
6. **`scoreboard.gd` 字体加载** — 还原原始美术风格
7. **`player.gd` 蓄力音效循环** — 交互反馈不完整
