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
| 对战 | `scenes/game/game.tscn` | 负责一局对战的组合与流程编排。 |

## 3. 节点结构

| 节点 | 职责 |
| --- | --- |
| `CharacterSelect` | 角色选择页总控，负责生成选项、处理双方按键与开始游戏。 |
| `CharacterOption` | 单个角色选项，用彩色方块表示一个角色。 |
| `SelectionFrame` | 选中标记，用彩色方框框住被选中的选项。 |
| `PongGame` | 对战总控，负责初始化、回合胜负、发球方和重新开始。 |
| `Background` | 负责黑色背景。 |
| `Divider` | 负责中央分界线及其边界范围；选择页与对战共用。 |
| `Player` | 负责移动、输入和边界限制；Player 1 使用 WASD，Player 2 使用方向键。 |
| `Ball` | 负责附着待发、发球、移动、反弹和左右越界信号。 |

## 4. 角色数据与状态

| 脚本 | 文件 | 职责 |
| --- | --- | --- |
| `CharacterDef` | `scripts/data/character.gd` | 角色定义，包含 id、名称和身体颜色。 |
| `CharacterLibrary` | `scripts/data/character_library.gd` | 角色注册表，集中定义全部可选角色，并提供按 id 查询。 |
| `GameSession` | `scripts/data/game_session.gd` | 自动加载单例，保存双方所选角色，供对战场景读取。 |

## 5. 回合与发球流程

- `PongGame` 用 `serving_side` 保存当前发球方：`-1` 为 Player 1，`1` 为 Player 2；开局值为 `-1`。
- 球处于 `attached` 状态时速度为零。`PongGame` 每帧根据发球方位置，将球贴在其朝向对手的一侧，因此球会跟随玩家移动。
- Player 1 持球时按 `J`，或 Player 2 持球时按小键盘 `1`，才调用 `Ball.serve()` 发球；其他玩家的发球键无效。
- 发球方向由发球方决定：Player 1 向右，Player 2 向左；竖直角度随机。
- `Ball.out_of_bounds(exit_side)` 上报出界方向，左侧为 `-1`，右侧为 `1`。
- `PongGame` 取出界方向的反方作为赢家，重置双方位置，并调用 `start_round(winner_side)`，让赢家进入持球待发状态。

## 6. 技术约束

- 使用 Godot 实现。
- 使用 1280×720 的恒定逻辑分辨率和初始窗口尺寸，保持 16:9 画面比例。
- 角色选项、挡板和小球保持原尺寸，不随界面放大而缩放。
- 主场景为角色选择页，对战场景由选择页在按下空格后加载。
- 角色只定义颜色等数据差异，颜色之外的行为与初始角色一致。
- 背景、分界线、玩家、小球、角色选项和选中标记必须是独立节点或场景，不能由单一节点统一绘制。
- 各节点只处理自身职责，根节点负责组合与流程编排。
- 使用基础几何图形，不依赖外部美术素材。

## 7. 技术验收标准

- 逻辑分辨率与初始窗口为 1280×720。
- 角色选项、挡板和小球尺寸与上一版一致。
- 核心对象分别由独立节点或场景实现，职责清晰。
- 场景、脚本和资源引用在目录迁移后保持有效。
- 角色选择页与对战场景均由根节点编排，双方按键互不干扰。
- 选择结果通过对战场景读取 `GameSession` 生效，角色颜色作用于挡板。
- 进入对战或开始新一轮时，球处于附着状态，不能自行移动。
- 球附着时与发球方朝向对手的一侧紧贴，并随发球方移动。
- 持球方的指定发球键可发球；非持球方的发球键无效。
- 球从左、右任一侧出界后，赢家正确切换为下一轮发球方。
- 节点职责、目录结构和引用关系符合本文档要求。
