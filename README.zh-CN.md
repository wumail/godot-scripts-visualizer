# Godot Visualizer Native

[![Godot 4](https://img.shields.io/badge/Godot-4.x-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE.md)
[![Version](https://img.shields.io/badge/version-0.1.2-blue.svg)](CHANGELOG.md)

一个独立的 Godot 4 编辑器插件，用来可视化并编辑项目的**脚本关系**与**场景结构**，
全部由 Godot 编辑器内部托管，无需任何外部服务器。

[English](README.md) | 简体中文

> 打开 **Script Map** 查看类之间的继承与引用关系，浏览 **Scene Map** 和场景树，
> 在交互式浏览器视图里编辑脚本和场景节点，并对 AI agent 暴露一套只读 JSON API。

## 为什么会有这个项目

这个插件把 [tomyud1/godot-mcp](https://github.com/tomyud1/godot-mcp) 中的**可视化**能力
抽离出来，做成一个不依赖 MCP 的独立 Godot 插件。

原因是：

- 在 **MCP 集成**本身上，我更倾向于使用
  [yurineko73/Godot-MCP-Native](https://github.com/yurineko73/Godot-MCP-Native)
  它原生运行在 Godot 内部。
  但 `tomyud1/godot-mcp` 里的**可视化**确实很有用，而在原项目中它与那套 Node.js MCP 服务器是强耦合的。

与其为了几张关系图就背上整套 MCP 栈，不如把可视化单独拆出来。它可以独立运行，并能**与任意 MCP 服务器（或完全不用 MCP）共存**——包括 `Godot-MCP-Native`。

## 相比原可视化做了哪些改变

| 方面 | `tomyud1/godot-mcp` | Godot Visualizer Native |
| --- | --- | --- |
| 宿主 | 由 Node.js MCP 服务器（`mcp-server`）提供页面 | 纯 GDScript 插件，在编辑器内自托管全部能力 |
| 传输 | 浏览器 ↔ Node 经 WebSocket，再桥接到 Godot | 浏览器 ↔ Godot 经 localhost HTTP `POST /command` |
| 运行时依赖 | 需要 Node MCP 服务器常驻 | 运行时无 Node 进程；Node 仅用于构建 |
| AI 访问 | 内部 WebSocket，未对外暴露 | 只读 `GET /api/v1` JSON API（manifest、摘要、lookup、fingerprint） |
| 图布局 | 力导向（自写 canvas） | 脚本：用 [force-graph](https://github.com/vasturiano/force-graph) 做力导向；场景树：从左到右的 [dagre](https://github.com/dagrejs/dagre) 布局 |
| 静态导出 | — | 可从 dock 导出只读快照 HTML |

## 功能

- **脚本图谱** — GDScript 关系图：`extends`、`preload`、信号连接，并附带每个脚本的变量、函数、信号。
- **场景图谱** — 场景、实例化场景、脚本引用，以及场景树浏览。
- **就地编辑** — 修改变量、信号、函数体；新增/删除/重命名/移动/复制/重排场景节点；读取与设置节点属性。
- **交互式浏览器 visualizer** — 从编辑器 dock 启动，由插件直接驱动。
- **静态预览导出** — 脚本图谱的只读 HTML 快照。
- **结构化 `/api/v1` JSON API** — 面向 AI / 自动化客户端的稳定只读协议。

## 环境要求

- Godot **4.x**
- Node.js **18+**（仅在构建浏览器前端或插件 zip 时需要）

## 安装

### 使用 release zip（推荐）

1. 从 [Releases](https://github.com/wumail/godot-scripts-visualizer/releases)
   页面下载 `godot_visualizer_native-<version>.zip`。
2. 在 Godot 中：**AssetLib → Import**，选择该 zip，确认解压到
   `addons/godot_visualizer_native`。
3. **Project Settings → Plugins** → 启用 **Godot Visualizer Native**。

### 从源码

1. 克隆本仓库。
2. 构建前端（见下文），或从某个 release 取用 `visualizer.html`。
3. 把 `addons/godot_visualizer_native` 复制到目标项目的 `addons/` 目录。
4. 在 **Project Settings → Plugins** 中启用插件。

## 构建前端

浏览器 visualizer 会被打包成单个
`addons/godot_visualizer_native/web/visualizer.html`。该文件**不纳入版本控制**——
请自行构建（或从 release 获取）：

```bash
cd web
npm install
npm run build          # → addons/godot_visualizer_native/web/visualizer.html
```

生成可分发的插件 zip：

```bash
cd web
npm run package:addon  # 先重建前端，再 → dist/godot_visualizer_native-<version>.zip
```

## 使用方式

启用插件后，使用右侧的 **Visualizer** dock：

- **Build Script Map** / **Build Scene Map** — 扫描并在 dock 中显示统计。
- **Open Browser Visualizer** — 启动 localhost 宿主并打开交互页面。
- **Stop Live Visualizer** — 停止宿主并释放端口。
- **Export Static Preview** — 把只读快照写入 `user://godot_visualizer_native/`。
- **Refresh Status** — 刷新运行时/服务摘要。

在 live 浏览器 visualizer 中可以浏览脚本与场景图、新建脚本、编辑变量/信号/函数体、
编辑场景节点。静态预览为只读模式，并会禁用场景视图。

## 结构化 API（`/api/v1`）

live 宿主运行时，同一个端口会提供一套稳定的只读 JSON API，面向 AI / 自动化客户端。
所有响应使用统一 envelope（`ok`、`protocol`、`version`、`resource`、`generated_at`、`query`、`data`）。

主要端点：

| 端点 | 用途 |
| --- | --- |
| `GET /api/v1` | 协议 manifest：受众、解析提示、推荐读取顺序、schemas |
| `GET /api/v1/runtime` | 宿主状态、端口、URL、capabilities |
| `GET /api/v1/project-summary` | 紧凑脚本摘要，含 `fingerprint` 用于低成本变更检测 |
| `GET /api/v1/scene-summary` | 紧凑场景摘要，含 `fingerprint` |
| `GET /api/v1/lookup` | 按 path、class、function、signal、scene、node 等定点查询 |
| `GET /api/v1/project-map` | 完整结构化脚本图 |
| `GET /api/v1/scene-map` | 完整结构化场景图 |

AI 客户端推荐流程：先读 manifest 和 summary（token 成本低），缓存 `fingerprint`，
下次以 `if_fingerprint` 回传来判断是否有变化，只有在需要更深入细节时才拉取完整 map 或 `lookup`。

```bash
curl http://127.0.0.1:6510/api/v1
curl http://127.0.0.1:6510/api/v1/project-summary
curl "http://127.0.0.1:6510/api/v1/lookup?class_name=MyNode"
```

也可以在不打开浏览器的情况下只启动 API：

```gdscript
var result = visualizer_manager.start_structured_api()
print(result.api_base_url)
```

## 命令面

浏览器宿主通过 `POST /command` 接受以下命令：

`map_project`、`refresh_map`、`map_scenes`、`create_script_file`、
`modify_variable`、`modify_signal`、`modify_function`、`modify_function_delete`、
`find_usages`、`get_scene_hierarchy`、`get_scene_node_properties`、
`set_scene_node_property`、`add_node`、`remove_node`、`rename_node`、
`move_node`、`duplicate_node`、`reorder_node`。

## 验证

仓库提供了 headless 烟雾测试 `tests/visualizer_cli_smoke.gd`：

```bash
/path/to/Godot --headless --path /absolute/path/to/this/repo \
  -s res://tests/visualizer_cli_smoke.gd
```

它会启动 localhost 宿主（不打开浏览器），依次请求 `/health`、`/api/v1` 系列端点、
以及一次 `refresh_map` 命令，然后停止宿主并通过退出码返回结果。

## 项目结构

```text
addons/godot_visualizer_native/   # 可分发的插件
  services/                       # 脚本与场景扫描 / 编辑服务
  transport/browser_bridge.gd     # localhost 宿主 + /command + /api/v1
  ui/visualizer_dock.gd           # 编辑器 dock
  visualizer_manager.gd           # 服务接线 + API 响应
web/                              # 浏览器前端源码与构建脚本
docs/                             # 架构与 AssetLib 说明
tests/                            # headless 烟雾测试
```

分层设计详见 [docs/architecture.md](docs/architecture.md)。

## 版本与发布

版本号位于 `addons/godot_visualizer_native/plugin.cfg` 和 `web/package.json`。
推送 `v*` tag 会触发
[release 工作流](.github/workflows/release.yml)，自动构建插件 zip 并附加到 GitHub Release。
详见 [CHANGELOG.md](CHANGELOG.md)。

## 致谢

- [tomyud1/godot-mcp](https://github.com/tomyud1/godot-mcp) — 这些可视化能力的原始来源。

## 许可证

MIT，见 [LICENSE.md](LICENSE.md)。
