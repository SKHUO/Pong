# Pong 技术设计文档

产品需求见 [PRODUCT_DESIGN.md](PRODUCT_DESIGN.md)。

## 1. 项目结构

```text
Pong/
├─ project.godot
├─ scenes/
│  ├─ character_select/
│  │  ├─ character_select.tscn
│  │  ├─ character_option.tscn
│  │  └─ selection_frame.tscn
│  ├─ game/
│  │  ├─ game.tscn
│  │  ├─ player.tscn
│  │  └─ ball.tscn
│  └─ shared/
│     ├─ background.tscn
│     └─ divider.tscn
└─ scripts/
   ├─ character_select/
   │  ├─ character_select.gd
   │  ├─ character_option.gd
   │  └─ selection_frame.gd
   ├─ game/
   │  ├─ game.gd
   │  ├─ player.gd
   │  └─ ball.gd
   ├─ shared/
   │  ├─ background.gd
   │  └─ divider.gd
   └─ data/
      ├─ character.gd
      ├─ character_library.gd
      └─ game_session.gd
```

组织原则：

- `scenes` 与 `scripts` 使用相同的功能模块层级。
- 仅被单个功能使用的场景和脚本放入对应模块。
- 角色选择与对战共用的背景、分界线放入 `shared`。
- 角色定义、角色库和游戏会话状态放入 `data`。
- `.gd.uid` 文件跟随脚本移动，不单独管理。

## 2. 场景

| 场景 | 文件 | 职责 |
| --- | --- | --- |
| 角色选择页 | `scenes/character_select/character_select.tscn` | 游戏主场景，负责角色选择的界面与输入，确认后切换到对战场景。 |
| 对战 | `scenes/game/game.tscn` | 负责一局对战的组合、物理模拟与流程编排。 |

## 3. 节点结构

| 节点 | 职责 |
| --- | --- |
| `CharacterSelect` | 角色选择页总控，负责生成选项、处理双方按键与开始游戏。 |
| `CharacterOption` | 单个角色选项，用彩色方块表示一个角色。 |
| `SelectionFrame` | 选中标记，用彩色方框框住被选中的选项。 |
| `PongGame` | 对战总控，负责初始化、回合胜负、发球方和重新开始。 |
| `Background` | 负责黑色背景。 |
| `Divider` | 负责中央分界线及其边界范围；选择页与对战共用。 |
| `Player` | 负责移动、输入和边界限制；记录每帧实际速度，供发球与碰撞使用。 |
| `Ball` | 负责待发、速度、旋转、空气阻力、Magnus 力、碰撞反弹和左右越界信号。 |

## 4. 角色数据与状态

| 脚本 | 文件 | 职责 |
| --- | --- | --- |
| `CharacterDef` | `scripts/data/character.gd` | 角色定义，包含 id、名称和身体颜色。 |
| `CharacterLibrary` | `scripts/data/character_library.gd` | 角色注册表，集中定义全部可选角色，并提供按 id 查询。 |
| `GameSession` | `scripts/data/game_session.gd` | 自动加载单例，保存双方所选角色，供对战场景读取。 |
| `PongPlayer` | `scripts/game/player.gd` | 运行时保存实际位移速度 `velocity`，重置回合时清零。 |
| `PongBall` | `scripts/game/ball.gd` | 运行时保存线速度 `velocity` 和角速度 `angular_velocity`。 |

## 5. 回合与发球流程

- `PongGame` 用 `serving_side` 保存当前发球方：`-1` 为 Player 1，`1` 为 Player 2；开局值为 `-1`。
- 球处于 `attached` 状态时线速度与角速度为零。`PongGame` 每帧根据发球方位置，将球贴在其朝向对手的一侧，因此球会跟随玩家移动。
- Player 1 持球时按 `J`，或 Player 2 持球时按小键盘 `1`，才调用 `Ball.serve()` 发球；其他玩家的发球键无效。
- 发球时传入发球者的瞬时速度与最大移动速度。球以朝对手方向为基准，叠加随机上下角和按发球者速度比例缩放的转向角；总偏角限制在 ±70°。
- 出球速度为 `540 + 玩家速度 × 0.18`，上限为 1100；玩家切向速度还会产生少量初始旋转。
- `Ball.out_of_bounds(exit_side)` 上报出界方向，左侧为 `-1`，右侧为 `1`。
- `PongGame` 取出界方向的反方作为赢家，重置双方位置，并调用 `start_round(winner_side)`，让赢家进入持球待发状态。

## 6. 物理模型

- 球在俯视平面内运动，不施加重力。每帧施加二次空气阻力和 Magnus 加速度：`a_M = magnus_strength × (ω × v)`。
- 角速度按 `spin_damping` 持续衰减，并限制在 ±35 rad/s；线速度限制在 1100 px/s。
- 挡板碰撞先按表面法向计算相对速度，再以 `paddle_restitution = 0.9` 反射；玩家速度作为挡板表面速度参与计算。
- 上下边界使用 `wall_restitution = 0.96` 反射，保留部分法向速度。
- 切向摩擦使用球接触点速度与挡板/边界表面速度之差计算。摩擦冲量同时改变球的切向线速度与角速度；因此挡板挥动方向、球原有旋转和接触位置都会影响反弹。
- 挡板接触位置提供少量边缘偏转，反弹后保证朝向场内的最小水平速度。
- 每帧按球半径细分移动步长，高球速下仍逐段检测边界与挡板，避免穿透。
- 物理参数均通过 `PongBall` 的导出属性配置，便于后续调校。

## 7. 技术约束

- 使用 Godot 实现。
- 使用 1280×720 的恒定逻辑分辨率和初始窗口尺寸，保持 16:9 画面比例。
- 角色选项、挡板和小球保持原尺寸，不随界面放大而缩放。
- 主场景为角色选择页，对战场景由选择页在按下空格后加载。
- 角色只定义颜色等数据差异，颜色之外的行为与初始角色一致。
- 背景、分界线、玩家、小球、角色选项和选中标记必须是独立节点或场景，不能由单一节点统一绘制。
- 各节点只处理自身职责，根节点负责组合与流程编排。
- 使用基础几何图形，不依赖外部美术素材。
- 使用自定义确定性二维物理，不引入额外物理引擎插件。

## 8. 技术验收标准

- 逻辑分辨率与初始窗口为 1280×720。
- 角色选项、挡板和小球尺寸与上一版一致。
- 核心对象分别由独立节点或场景实现，职责清晰。
- 场景、脚本和资源引用在目录迁移后保持有效。
- 角色选择页与对战场景均由根节点编排，双方按键互不干扰。
- 选择结果通过对战场景读取 `GameSession` 生效，角色颜色作用于挡板。
- 进入对战或开始新一轮时，球处于附着状态，线速度和角速度为零。
- 球附着时与发球方朝向对手的一侧紧贴，并随发球方移动。
- 持球方的指定发球键可发球；非持球方的发球键无效。
- 发球方向始终朝向对手，并随发球者瞬时速度方向在限定角度内偏转；速度大小影响出球速度和初始旋转。
- 空气阻力会降低球速，旋转会通过 Magnus 力改变轨迹，并在衰减后减弱影响。
- 挡板碰撞使用法向恢复与切向摩擦，挡板速度、球速和球旋转会共同影响出射速度、方向与旋转。
- 上下边界碰撞按恢复系数和摩擦处理，不会简单无损反向。
- 球在最高速度下仍能可靠触发挡板碰撞，不穿透挡板。
- 球从左、右任一侧出界后，赢家正确切换为下一轮发球方。
- 节点职责、目录结构和引用关系符合本文档要求。
