# 贪吃蛇 3D 🐍

基于 **Godot 4.7.2 + GDScript** 的 3D 贪吃蛇。玩法与同目录的 `godot-snake-2d`、
`flutter-snake` 一致，重点展示 Godot 的 3D 渲染、光照与多实例能力。

## 特性

- 六种关卡：空旷、边墙、立柱阵、十字回廊、回字迷宫、传送门
- 五种道具：加速、减速、护盾、磁铁、双倍分，HUD 显示剩余时间
- 三套配色：霓虹、糖果、经典，天空、雾、棋盘与灯光会整体换色
- 平滑 3D 蛇身：盒状身体 + 球形关节，实例颜色由蛇头到蛇尾渐变
- 自发光棋盘网格、发光边框、投影与景深雾，食物带悬浮光环与点光源
- 自由视角：右键拖动环绕、滚轮缩放、Q/E 左右转动，死亡时镜头抖动
- 开局倒计时、暂停、结算、新纪录、最高分持久化，键盘与触屏滑动操作

## 下载

### v0.2.0（当前版本）

- [Windows ZIP](https://github.com/g-ai-002/godot-snake-3d/releases/tag/v0.2.0)
- [Web 在线试玩](https://g-ai-002.github.io/godot-snake-3d/v0.2.0/)

### 历史版本

- [v0.1.0](https://github.com/g-ai-002/godot-snake-3d/releases/tag/v0.1.0)

## 3D 引擎能力点

| 能力                | 位置                        | 说明                                                   |
| ------------------- | --------------------------- | ------------------------------------------------------ |
| MultiMeshInstance3D | `scripts/snake_view.gd`     | 身体与关节各一个 MultiMesh，预分配 1200 实例，按帧更新 |
| 实例颜色            | `scripts/snake_view.gd`     | `use_colors` + `set_instance_color`，着色器读 `COLOR`  |
| 空间着色器          | `shaders/board.gdshader`    | 世界坐标网格线、随距离变化的脉冲、中心辉光             |
| 自发光材质          | `shaders/emissive.gdshader` | 同一着色器供蛇身（顶点色）与蛇头（常量色）复用         |
| WorldEnvironment    | `scripts/game.gd`           | ProceduralSky、ACES 色调映射、Glow、SSAO、深度雾       |
| DirectionalLight3D  | `scripts/game.gd`           | 52° 俯角主光 + 软阴影；另加 OmniLight3D 补色           |
| GPUParticles3D      | `scripts/game.gd`           | 吃食物/死亡爆散粒子；食物周围另有常驻粒子              |
| OmniLight3D         | `scripts/food_view.gd`      | 食物与传送门各带一盏点光源，随呼吸脉冲                 |
| Camera3D 轨道相机   | `scripts/camera_rig.gd`     | 阻尼跟随、俯仰限制、滚轮缩放、屏幕偏移抖动             |
| Label3D             | `scripts/game.gd`           | 世界空间飘分文字，始终朝向相机且不受深度遮挡           |
| 程序化天空          | `scripts/game.gd`           | 三套配色切换天空顶/地平线/地面颜色与雾色               |

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

渲染器使用 `forward_plus`，以启用 Glow、SSAO 与软阴影。

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

Web 版由 `project.godot` 的 `renderer/rendering_method.web="gl_compatibility"`
切成 Compatibility 渲染器，桌面端仍是 Forward+，因此网页里没有 Glow、SSAO
与软阴影细节，玩法与桌面端一致。预设关闭了线程支持
（`variant/thread_support=false`），可以直接部署到 GitHub Pages 这类无法设置
COOP/COEP 响应头的静态托管。

推送 `v*` tag 或手动触发工作流后，CI 会把 Web 产物发布到 `gh-pages` 分支
（首次使用需在仓库 Settings → Pages 中选择该分支）：tag 构建进入
`vX.Y.Z/` 目录并保留历史版本，手动触发进入 `debug/`，同时重新生成站点索引页
与 `versions.json`，Web ZIP 也会作为 Release 附件上传。

## 目录结构

```text
.
├── scenes/main.tscn      # 主场景：棋盘、食物、蛇、轨道相机、HUD
├── scripts/
│   ├── board_logic.gd    # 纯逻辑：关卡布局、出生点、随机空格
│   ├── board_view.gd     # 地面着色器、底座、边框、MultiMesh 墙体、传送门
│   ├── snake_view.gd     # MultiMesh 蛇身 + 球形关节 + 蛇头/护盾/灯光
│   ├── food_view.gd      # 食物网格、光环、点光源与环绕粒子
│   ├── camera_rig.gd     # 3D 轨道相机与抖动
│   ├── hud.gd            # HUD、菜单、暂停、结算
│   ├── game.gd           # 状态机、网格推进、输入、环境与特效
│   ├── palette.gd        # 三套配色
│   ├── synth.gd          # PCM 合成
│   ├── sfx.gd            # 音效播放器池（Autoload）
│   └── save_data.gd      # 配置与最高分（Autoload）
├── shaders/
│   ├── board.gdshader
│   ├── emissive.gdshader
│   └── food.gdshader
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
- 蛇身不再是一条折线，而是「盒段 + 球关节」两套 MultiMesh，传送时跳过跨屏段
- 食物、传送门、墙体都成为真实几何体，自带光源与阴影
- 镜头由 2D 的缩放改为 3D 轨道相机，死亡抖动通过相机 `h_offset/v_offset` 实现

## 字体

界面不自带字体文件，由 `scripts/ui_font.gd` 通过 `SystemFont` 读取系统字体：
Windows 微软雅黑、macOS 苹方、Linux 思源黑体/文泉驿，最后回退到 `sans-serif`。
仓库因此不含字体二进制，克隆体积更小。

Web 端拿不到系统字体，所以 `scripts/ui_font.gd` 会优先加载
`res://assets/fonts/web_cjk.otf`：CI 导出前下载 Noto Sans SC，按源码里实际
出现的字符裁剪成子集（通常几百 KB，不入库），桌面端没有该文件时仍用系统字体。

## 版本历史

### v0.2.0（当前版本）

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
