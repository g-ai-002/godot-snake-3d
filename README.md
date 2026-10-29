# 贪吃蛇 3D 🐍

基于 **Godot 4.7.2 + GDScript** 的 3D 贪吃蛇。玩法与同目录的 `godot-snake-2d`、
`flutter-snake` 一致，重点展示 Godot 的 PBR、屏幕空间效果与多实例能力。

## 特性

- 六种关卡：空旷、边墙、立柱阵、十字回廊、回字迷宫、传送门
- 五种道具：加速、减速、护盾、磁铁、双倍分，HUD 显示剩余时间
- 三套配色：霓虹、糖果、经典，天空、雾、棋盘、灯光与后处理会整体换色
- 圆柱拼接的平滑蛇身 + 球形关节，清漆高光、菲涅耳边光与流动能量环
- 高细节蛇头：吻部、下颌、发光眼睛、背鳍与吐信动画，自带移动聚光灯
- 湿滑金属棋盘：发光缝隙、扫光、微表面法线扰动，开启 SSR 时反射蛇身
- 程序化星空天幕、四角光柱与体积雾光锥、ACES 色调映射与七级泛光
- 屏幕后处理：色差、暗角、电影调色、胶片颗粒，死亡时降饱和 + 闪红
- 自由视角：右键拖动环绕、滚轮缩放、Q/E 转动，进食推镜与死亡抖动
- 开局倒计时、暂停、结算、新纪录、最高分持久化，键盘与触屏滑动操作

## 下载

### v0.2.0（当前版本）

- [Windows ZIP](https://github.com/g-ai-002/godot-snake-3d/releases/tag/v0.2.0)
- [Web 在线试玩](https://g-ai-002.github.io/godot-snake-3d/v0.2.0/)

### 历史版本

- [v0.1.0](https://github.com/g-ai-002/godot-snake-3d/releases/tag/v0.1.0)

## 3D 引擎能力点

| 能力                | 位置                        | 说明                                                         |
| ------------------- | --------------------------- | ------------------------------------------------------------ |
| MultiMeshInstance3D | `scripts/snake_view.gd`     | 圆柱蛇段与关节各一个 MultiMesh，预分配 1200 实例，按帧更新   |
| 实例颜色 + 清漆     | `shaders/emissive.gdshader` | 顶点色渐变、菲涅耳边光、流动能量环、`CLEARCOAT` 高光         |
| 程序化天空          | `shaders/sky.gdshader`      | 球面星云 + 分形噪声 + 网格哈希星点，随时间缓慢漂移并闪烁     |
| PBR 地面            | `shaders/board.gdshader`    | 发光缝隙、扫光、噪声法线扰动，SSR 反射蛇身与灯光             |
| 墙体着色器          | `shaders/wall.gdshader`     | 顶部棱边发光、菲涅耳轮廓、上行扫描线                         |
| WorldEnvironment    | `scripts/game.gd`           | ACES、7 级 Glow、SSAO、SSR、体积雾、深度雾与颜色分级         |
| DirectionalLight3D  | `scripts/game.gd`           | 暖色主光（4 级级联阴影）+ 冷色轮廓光                         |
| SpotLight3D         | `scripts/board_view.gd`     | 四角光柱投射体积光锥；蛇头另有一盏随行聚光灯                 |
| 屏幕后处理          | `shaders/postfx.gdshader`   | 色差、暗角、电影调色、颗粒；Compatibility 下补偿缺失的 Glow  |
| CameraAttributes    | `scripts/camera_rig.gd`     | 景深、呼吸位移、进食推镜、死亡抖动                           |
| GPUParticles3D      | `scripts/game.gd`           | 吃食物/死亡爆散、环境浮尘、食物环绕粒子与冲天光柱            |
| ImmediateMesh       | `scripts/snake_view.gd`     | 每帧重建的地面能量拖尾，顶点色渐隐、传送时自动断开           |
| Label3D             | `scripts/game.gd`           | 世界空间飘分文字，始终朝向相机且不受深度遮挡                 |

## 操作

| 操作       | 按键 / 手势                         |
| ---------- | ----------------------------------- |
| 转向       | 方向键 / WASD，或按住鼠标左键滑动   |
| 旋转视角   | 按住鼠标右键拖动，或 Q / E          |
| 缩放视角   | 鼠标滚轮                            |
| 暂停、继续 | 空格 / Esc，或点击右上角「暂停」    |
| 重开       | R（游戏中）或回车（菜单、结算界面） |
| 静音       | M，或点击「音效」按钮               |
| 开始游戏   | 回车，或点击「开始游戏」            |

## 运行

需要 Godot **4.7.2**（标准版即可，无需 .NET），以及支持 Vulkan / D3D12 的桌面显卡。
用项目管理器导入 `project.godot`，按 F5 运行；也可以直接命令行启动：

```bash
godot --path .
```

桌面端使用 `forward_plus`，启用 Glow、SSAO、SSR、体积雾、景深与聚光灯阴影；
Web 端按 `project.godot` 的 `renderer/rendering_method.web="gl_compatibility"`
自动关闭这些特性，并由后处理着色器补偿泛光与暗角。

## 测试

无头冒烟测试覆盖关卡生成、吃食物、道具、护盾、传送门、暂停、重开与音频合成：

```bash
godot --headless --path . --import
godot --headless --path . res://tests/smoke_test.tscn
```

首次运行（或删除 `.godot` 后）需先执行 `--import` 生成全局类缓存，CI 已包含这一步。
测试场景为 `tests/smoke_test.tscn`，共 68 项断言，退出码非 0 表示失败。

## 导出

`export_presets.cfg` 提供 **Windows Desktop** 与 **Web** 两个预设：

- **Windows** → `build/windows/Snake3D.exe`（单文件，内嵌 PCK）
- **Web** → `build/web/index.html`（单线程，可静态托管）

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/Snake3D.exe
godot --headless --path . --export-release "Web" build/web/index.html
```

导出前需要安装对应版本的导出模板。Web 构建还需要中文字体子集
`assets/fonts/web_cjk.otf`：CI 会在构建时临时生成（不入库），本地可执行
`python tools/subset_web_font.py` 生成；否则 Web 页面中文会回退为方框。
本地预览需要走 HTTP，直接打开 `index.html` 会因浏览器安全策略失败：

```bash
python -m http.server 8000 --directory build/web
```

预设关闭了线程支持（`variant/thread_support=false`），可以直接部署到
GitHub Pages 这类无法设置 COOP/COEP 响应头的静态托管。

推送 `v*` tag 或手动触发工作流后，CI 会把 Web 产物发布到 `gh-pages` 分支
（首次使用需在仓库 Settings → Pages 中选择该分支）：tag 构建进入
`vX.Y.Z/` 目录并保留历史版本，手动触发进入 `debug/`，同时重新生成站点索引页
与 `versions.json`，Web ZIP 也会作为 Release 附件上传。

## 目录结构

```text
.
├── scenes/main.tscn      # 主场景：棋盘、食物、蛇、轨道相机、后处理、HUD
├── scripts/
│   ├── board_logic.gd    # 纯逻辑：关卡布局、出生点、随机空格
│   ├── board_view.gd     # 地面、底座、墙体、传送门与四角光柱
│   ├── snake_view.gd     # MultiMesh 蛇身 + 蛇头细节 + 护盾 + 拖尾 + 随行灯光
│   ├── food_view.gd      # 食物网格、光环、光柱、点光源与环绕粒子
│   ├── camera_rig.gd     # 3D 轨道相机、景深、推镜与抖动
│   ├── postfx.gd         # 屏幕后处理层（色差/暗角/调色/颗粒）
│   ├── hud.gd            # HUD、菜单、暂停、结算
│   ├── game.gd           # 状态机、网格推进、输入、环境与特效
│   ├── palette.gd        # 三套配色
│   ├── synth.gd          # PCM 合成
│   ├── sfx.gd            # 音效播放器池（Autoload）
│   └── save_data.gd      # 配置与最高分（Autoload）
├── shaders/
│   ├── board.gdshader    # 湿滑金属地面
│   ├── ground.gdshader   # 棋盘外的大地面
│   ├── wall.gdshader     # 墙体棱边发光
│   ├── emissive.gdshader # 蛇身/蛇头自发光与边光
│   ├── food.gdshader     # 食物内核
│   ├── beam.gdshader     # 食物光柱
│   ├── shield.gdshader   # 护盾能量球壳
│   ├── trail.gdshader    # 地面拖尾
│   ├── sky.gdshader      # 程序化星空
│   └── postfx.gdshader   # 屏幕后处理
├── tools/subset_web_font.py   # 生成 Web 中文字体子集（CI 使用）
├── .github/
│   ├── pages/index.template.html  # gh-pages 站点索引页模板
│   └── workflows/build.yml        # 冒烟测试 + Windows/Web 构建 + Release
└── tests/smoke_test.tscn
```

## 玩法参数

与 Flutter 版 `flutter-snake` 对齐：

| 项           | 值                                             |
| ------------ | ---------------------------------------------- |
| 棋盘尺寸     | 15×15 / 20×20 / 25×25，默认 20×20              |
| 步进间隔     | 300 / 200 / 100 ms，默认 200 ms                |
| 得分         | 普通食物 +10，双倍分期间 +20                   |
| 道具持续时间 | 加速 6s、减速 5s、护盾 10s、磁铁 6s、双倍 8s   |
| 道具出现概率 | 28%                                            |
| 加速 / 减速  | 步进间隔 ×0.65 / ×1.5（下限 60ms、上限 600ms） |

## 与 2D 版的实现差异

- 棋盘尺寸换成了世界单位：一格 1.0，蛇身中心高度 0.46
- 蛇身由圆柱段 + 球关节拼接，传送时跳过跨屏段，并在地面留下能量拖尾
- 食物、传送门、墙体都是真实几何体，自带光源、光柱与阴影
- 镜头是 3D 轨道相机，带景深、呼吸位移与进食推镜，死亡抖动通过 `h_offset/v_offset` 实现
- 桌面端开启 SSAO/SSR/体积雾/景深，Web 端由后处理补偿泛光与暗角

## 字体

界面不自带字体文件，由 `scripts/ui_font.gd` 通过 `SystemFont` 读取系统字体：
Windows 微软雅黑、macOS 苹方、Linux 思源黑体/文泉驿，最后回退到 `sans-serif`。
仓库因此不含字体二进制，克隆体积更小。

Web 端拿不到系统字体，所以 `scripts/ui_font.gd` 会优先加载
`res://assets/fonts/web_cjk.otf`：CI 导出前下载 Noto Sans SC，按源码里实际
出现的字符裁剪成子集（通常几百 KB，不入库），桌面端没有该文件时仍用系统字体。

## 版本历史

### 未发布（画面升级）

- 蛇身改为圆柱 + 球关节，加入清漆高光、菲涅耳边光、流动能量环与地面拖尾
- 蛇头补齐吻部、下颌、发光眼睛、背鳍与吐信，并挂载随行聚光灯
- 棋盘换成湿滑金属着色器，新增棋盘外大地面、发光墙棱与四角光柱
- 环境升级：程序化星空、7 级 Glow、SSAO、SSR、体积雾、景深与 ACES 分级
- 新增屏幕后处理层（色差、暗角、电影调色、颗粒），Compatibility 下补偿泛光
- 进食推镜、死亡降饱和与更克制的雾/环境光，暗部对比明显增强

### v0.2.0

- 新增 Web 导出预设，网页端切换到 Compatibility 渲染器并关闭线程支持，可直接静态托管
- CI 新增 Web 构建与 GitHub Pages 版本化发布：tag 构建进入 `vX.Y.Z/`，手动触发进入 `debug/`
- 复用分数飘字与爆散粒子节点、缓存食物网格，降低连续吃食物时的创建开销
- 修正出生蛇身顺序，蛇头回到数组首位，避免开局首格自撞
- 补齐飘字与粒子池成员声明，并在复用前校验 Tween 元数据
- 冒烟测试补充出生顺序与自撞用例，断言增至 68 项

### v0.1.0

- 首个正式版本：六种关卡、五种道具、三套配色、MultiMesh 蛇身、动态光影与运行时音频合成

## 许可证

MIT
