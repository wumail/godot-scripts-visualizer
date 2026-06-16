# Godot Visualizer Native

一个独立的 Godot 原生插件工程，用来完整承接 godot-mcp 中与可视化相关的能力。

当前工程目标不是继续把可视化当成 MCP 的附属能力，而是把它收敛为一个独立插件产品：

- 脚本关系图谱
- 场景总览与场景树浏览
- 脚本内联编辑能力
- 场景节点属性查看与编辑
- 浏览器可视化前端资源与构建链路
- 插件内本地浏览器宿主链路
- 后续可继续扩展原生 Dock UI

## 项目结构

```text
godot-visualizer-native/
├── addons/godot_visualizer_native/
│   ├── docs/
│   ├── plugin.cfg
│   ├── plugin.gd
│   ├── visualizer_manager.gd
│   ├── services/
│   │   ├── project_map_service.gd
│   │   ├── scene_map_service.gd
│   │   ├── script_edit_service.gd
│   │   └── scene_visualizer_service.gd
│   ├── transport/
│   │   └── browser_bridge.gd
│   ├── ui/
│   │   └── visualizer_dock.gd
│   └── web/
├── docs/
│   ├── architecture.md
│   └── migration-plan.md
├── dist/
├── web/
│   ├── package-lock.json
│   ├── package.json
│   ├── scripts/build-visualizer.mjs
│   ├── scripts/package-addon.mjs
│   └── src/visualizer/
├── LICENSE.md
├── icon.png
├── project.godot
└── icon.svg
```

## AssetLib 发布状态

当前仓库已经补齐 AssetLib 常见的发布结构：

- 根目录 [LICENSE.md](LICENSE.md)
- 根目录 [.gitattributes](.gitattributes)
- 插件目录内的 [addons/godot_visualizer_native/README.md](addons/godot_visualizer_native/README.md)
- 插件目录内的 [addons/godot_visualizer_native/LICENSE.md](addons/godot_visualizer_native/LICENSE.md)
- 提交表单说明 [docs/assetlib-submission.md](docs/assetlib-submission.md)

这意味着：

- 仓库源码可以作为 AssetLib 提交源。
- 插件目录本身也保留了 README 和许可证副本。
- GitHub 源码归档可以排除 web、tests、docs 等非运行时目录。

仍需你在正式提交 AssetLib 时填写：

- 仓库公开地址
- issues 地址
- 目标提交 commit
- AssetLib 列表图标 URL，可直接指向 [icon.png](icon.png)

## 能力范围

### 已在工程中建立的能力边界

- 脚本图谱服务：扫描 GDScript，解析变量、函数、信号、extends、preload、signal connect。
- 场景图谱服务：扫描 tscn，提取场景、实例关系、脚本引用。
- 脚本编辑服务：变量、信号、函数体、删除函数、查引用。
- 场景可视化服务：场景树、节点属性、节点增删改名、复制、重排、重挂父节点。
- 浏览器桥接：既支持导出静态预览，也支持在插件内启动本地 HTTP 命令宿主并打开可交互浏览器 visualizer。

### 当前交付状态

- Godot 插件入口已经建立，可在编辑器右侧看到 Dock。
- 可视化前端源码已从原项目迁入 web 子项目。
- 插件可以启动本地浏览器 visualizer，并通过本地 HTTP 命令接口驱动脚本图谱、场景图谱、脚本编辑和场景编辑。
- 前端仍保留静态预览模式，便于快速导出只读快照。

## 当前能力状态

- 已完整接入浏览器端命令宿主：脚本图谱、场景图谱、脚本编辑、场景节点结构修改、节点属性修改。
- 当前主交互 UI 是浏览器 visualizer，由 Godot 插件负责启动和命令处理。
- Godot 原生 Dock 目前仍是启动器和状态面板，不是完整图形编辑界面。

## 使用方式

### 1. 打开工程

1. 用 Godot 打开 [godot-visualizer-native/project.godot](godot-visualizer-native/project.godot)。
2. 在 Project Settings > Plugins 中启用 Godot Visualizer Native。
3. 启用后，编辑器右侧会出现插件 Dock。

### 2. 构建浏览器前端

进入 [godot-visualizer-native/web](godot-visualizer-native/web) 执行：

```bash
npm install
npm run build
```

构建完成后会生成：

- [godot-visualizer-native/addons/godot_visualizer_native/web/visualizer.html](godot-visualizer-native/addons/godot_visualizer_native/web/visualizer.html)

### 3. 打包插件分发 zip

如果你要把插件导入到别的 Godot 项目，而不是只在当前仓库里运行，进入 [godot-visualizer-native/web](godot-visualizer-native/web) 执行：

```bash
npm install
npm run package:addon
```

这会先重建浏览器前端，再生成一个只包含插件目录的分发包：

- [dist/godot_visualizer_native-0.1.0.zip](dist/godot_visualizer_native-0.1.0.zip)

zip 内部顶层结构直接是 `addons/godot_visualizer_native/...`，可以用于 Godot 编辑器的 Import Zip 流程。

如果你发布到官方 AssetLib，仓库源码也已经适合做提交源；具体提交字段可参考 [docs/assetlib-submission.md](docs/assetlib-submission.md)。

### 4. 在其他 Godot 项目中导入

在目标项目里：

1. 打开 AssetLib 面板。
2. 选择 Import，导入 [dist/godot_visualizer_native-0.1.0.zip](dist/godot_visualizer_native-0.1.0.zip)。
3. 确认解压目标仍然是项目根下的 `addons/godot_visualizer_native`。
4. 打开 Project Settings > Plugins，启用 Godot Visualizer Native。

### 5. 启动可交互浏览器 visualizer

在 Godot 的插件 Dock 中点击 `Open Browser Visualizer`：

- 插件会先扫描脚本并构建 project map
- 本地启动一个 `127.0.0.1` 上的 HTTP 命令宿主
- 自动打开浏览器页面
- 浏览器端通过 `/command` 直接调用插件服务

这个模式下可以使用的能力包括：

- 脚本关系图浏览
- 场景总览与场景树浏览
- 新建脚本
- 修改变量、信号、函数体
- 删除变量、信号、函数
- 查引用辅助删除
- 读取和修改场景节点属性
- 新增、删除、重命名、复制、重排场景节点

如果只想启动给外部工具消费的 API，而不自动打开浏览器，可以在插件侧调用：

```gdscript
var result = visualizer_manager.start_structured_api()
print(result.api_base_url)
```

这里的“外部工具”优先面向 AI / 大模型 / agent：

- 用稳定的只读 JSON 协议读取项目结构
- 先发现协议，再按资源类型抓取数据
- 不需要理解浏览器前端内部命令协议

### 6. 导出静态预览

在 Godot 的插件 Dock 中点击 `Export Static Preview`：

- 会把当前脚本图谱注入到 HTML 模板中
- 输出到 `user://godot_visualizer_native/project_preview.html`
- 自动在浏览器打开

静态预览模式下：

- 可以浏览脚本图谱
- 不能执行编辑命令
- 场景视图会被禁用

### 7. Dock 按钮说明

- `Build Script Map`
	只在 Dock 中执行脚本扫描并显示统计信息。
- `Build Scene Map`
	只在 Dock 中执行场景扫描并显示统计信息。
- `Open Browser Visualizer`
	启动本地浏览器交互模式。
- `Stop Live Visualizer`
	停止 localhost live 宿主并释放当前端口。
- `Export Static Preview`
	导出只读快照。
- `Open Migration Doc`
	打开迁移说明。
- `Refresh Status`
	刷新服务状态摘要。

Dock 中还会持续显示：

- live server 是否运行中
- 当前绑定端口
- 当前本地 URL
- 最近一次错误信息

浏览器页面顶部现在也会显示 transport 状态：

- 当前连接状态
- 连接失败原因
- localhost HTTP / WebSocket transport 的运行模式
- 失败后的 Reconnect 入口

## 前端构建

在 [godot-visualizer-native/web](godot-visualizer-native/web) 目录执行：

```bash
npm install
npm run build
```

构建结果会输出到 [godot-visualizer-native/addons/godot_visualizer_native/web/visualizer.html](godot-visualizer-native/addons/godot_visualizer_native/web/visualizer.html)。

这个文件是浏览器前端模板产物，可以直接打开做空数据预览；真正带项目数据的静态预览由插件内的 `Export Static Preview` 生成。

如果要产出可导入别的项目的插件 zip，则执行：

```bash
npm run package:addon
```

该命令会自动重建前端，并输出 [dist/godot_visualizer_native-0.1.0.zip](dist/godot_visualizer_native-0.1.0.zip)。

## 工作方式

### 交互浏览器模式

- Godot 插件负责扫描项目、修改脚本和场景
- 本地 HTTP 宿主负责向浏览器提供页面和命令接口
- 浏览器前端只负责图形展示与交互

### 结构化 API 模式

- 复用同一个 localhost 宿主，不额外起第二个服务
- 面向外部工具提供只读 JSON 接口
- 可以不打开浏览器，仅作为数据接口启动

### 静态导出模式

- Godot 只把脚本图谱数据注入 HTML
- 不启动命令宿主
- 浏览器页面进入只读模式

## 结构化 API

稳定协议从 `v1` 开始，canonical base path 是 `GET /api/v1`。

`/api/*` 仍然保留为兼容别名，但新的 AI / agent 客户端应优先使用 `/api/v1/*`。

所有 `v1` 成功响应都使用统一 envelope：

```json
{
	"ok": true,
	"protocol": "godot_visualizer_native.v1",
	"version": "v1",
	"resource": "project_map",
	"generated_at": "2026-06-08T16:09:57",
	"query": {
		"root": "res://"
	},
	"data": {
	}
}
```

所有 `v1` 失败响应都使用统一 envelope：

```json
{
	"ok": false,
	"protocol": "godot_visualizer_native.v1",
	"version": "v1",
	"resource": "error",
	"generated_at": "2026-06-08T16:09:57",
	"query": {},
	"error": {
		"code": "not_found",
		"message": "Unknown API route",
		"path": "/api/v1/unknown"
	}
}
```

建议 AI / LLM 客户端按这个顺序读取：

1. `GET /api/v1`
2. `GET /api/v1/runtime`
3. `GET /api/v1/project-summary`
4. `GET /api/v1/scene-summary`
5. `GET /api/v1/project-map`
6. `GET /api/v1/scene-map`

推荐策略：

- AI 首轮感知项目时，优先读取 `manifest + summary`，先拿低 token 的全局摘要。
- 保存 `project-summary` 和 `scene-summary` 里的 `fingerprint`，下一次轮询时带上 `if_fingerprint` 判断摘要是否变化。
- 只有在需要深入脚本关系、函数体、场景节点明细时，再读取完整 `project-map` 或 `scene-map`。
- 需要定点查某个脚本、类、函数、信号、场景或节点时，优先走 `lookup`，避免整图扫描。
- 读取任何资源前，都可以用 manifest 里的 `schemas` 和 endpoint `response_schema` 做字段校验。

在 live host 运行时，可从同一个端口访问这些接口：

- `GET /api/v1`
	返回协议 manifest，包含 audience、解析提示、推荐读取顺序和 endpoint 描述。适合作为 AI 客户端的第一跳。
- `GET /api/v1/runtime`
	返回当前 host runtime 状态、端口、URL、capabilities。
- `GET /api/v1/capabilities`
	返回能力摘要。
- `GET /api/v1/status-lines`
	返回状态面板使用的人类可读摘要。
- `GET /api/v1/lookup`
	返回定点查询结果，支持按 path、class_name、function_name、signal_name、scene_path、node_name、root_type、script_path、instance_path 做只读检索。
- `GET /api/v1/project-summary`
	返回面向 AI 首轮读取的紧凑脚本摘要，包含 `fingerprint`，以及 totals、top folders、relationship types 和 script highlights。
- `GET /api/v1/project-map`
	返回结构化 project map。
- `GET /api/v1/scene-summary`
	返回面向 AI 首轮读取的紧凑场景摘要，包含 `fingerprint`，以及 totals、root types、instanced scene paths 和 scene highlights。
- `GET /api/v1/scene-map`
	返回结构化 scene map。

支持的查询参数：

- `root`
	可用于 `project-summary`、`project-map`、`scene-summary` 和 `scene-map`，默认是 `res://`。
- `include_addons`
	可用于 `project-summary`、`project-map`、`scene-summary` 和 `scene-map`，布尔值。
- `if_fingerprint`
	可用于 `project-summary` 和 `scene-summary`。如果与当前摘要的 fingerprint 一致，则响应中的 `data.unchanged` 会是 `true`。
- `kind`
	用于 `lookup`，可选 `any`、`script`、`scene`。
- `path` / `path_contains` / `class_name` / `function_name` / `signal_name` / `scene_path` / `node_name` / `root_type` / `script_path` / `instance_path`
	用于 `lookup` 的精确或子串筛选。
- `limit`
	用于 `lookup`，限制返回条数。

示例：

```bash
curl http://127.0.0.1:6510/api/v1
curl http://127.0.0.1:6510/api/v1/runtime
curl http://127.0.0.1:6510/api/v1/lookup?path=res://tests/visualizer_cli_smoke.gd
curl http://127.0.0.1:6510/api/v1/project-summary
curl "http://127.0.0.1:6510/api/v1/project-summary?if_fingerprint=<cached>"
curl http://127.0.0.1:6510/api/v1/scene-summary
curl http://127.0.0.1:6510/api/v1/project-map
curl "http://127.0.0.1:6510/api/v1/project-map?include_addons=true"
curl http://127.0.0.1:6510/api/v1/scene-map
```

### 响应样例

`GET /api/v1` 响应示例：

```json
{
	"ok": true,
	"protocol": "godot_visualizer_native.v1",
	"version": "v1",
	"resource": "manifest",
	"generated_at": "2026-06-08T16:09:57",
	"query": {},
	"data": {
		"service": "godot_visualizer_native",
		"protocol": "godot_visualizer_native.v1",
		"version": "v1",
		"canonical_base_path": "/api/v1",
		"audience": ["ai_agent", "automation", "developer_tooling"],
		"read_only": true,
		"ai_entrypoints": [
			"/api/v1",
			"/api/v1/project-summary",
			"/api/v1/scene-summary",
			"/api/v1/lookup"
		],
		"recommended_sequence": [
			"GET /api/v1",
			"GET /api/v1/runtime",
			"GET /api/v1/project-summary",
			"GET /api/v1/scene-summary",
			"GET /api/v1/lookup?path=res://path/to/file.gd",
			"GET /api/v1/project-map",
			"GET /api/v1/scene-map"
		],
		"schemas": {
			"envelope_success": {
				"type": "object",
				"required": ["ok", "protocol", "version", "resource", "generated_at", "query", "data"]
			},
			"resources": {
				"lookup_response": {
					"resource": "lookup",
					"data_required": ["kind", "limit", "filters", "counts", "script_matches", "scene_matches"]
				},
				"project_summary_response": {
					"resource": "project_summary",
					"data_required": ["root", "include_addons", "fingerprint", "fingerprint_algorithm", "unchanged", "totals", "top_folders", "script_highlights", "relationship_types"]
				},
				"scene_summary_response": {
					"resource": "scene_summary",
					"data_required": ["root", "include_addons", "fingerprint", "fingerprint_algorithm", "unchanged", "totals", "root_types", "scene_highlights", "instanced_scene_paths"]
				}
			}
		]
	}
}
```

`GET /api/v1/runtime` 响应示例：

```json
{
	"ok": true,
	"protocol": "godot_visualizer_native.v1",
	"version": "v1",
	"resource": "runtime",
	"generated_at": "2026-06-08T16:09:57",
	"query": {},
	"data": {
		"ok": true,
		"mode": "live_server",
		"running": true,
		"port": 6510,
		"url": "http://127.0.0.1:6510/",
		"last_error": "",
		"capabilities": {
			"project_map": true,
			"scene_map": true,
			"browser_live_visualizer": true
		}
	}
}
```

`GET /api/v1/project-map` 响应示例：

```json
{
	"ok": true,
	"protocol": "godot_visualizer_native.v1",
	"version": "v1",
	"resource": "project_map",
	"generated_at": "2026-06-08T16:09:57",
	"query": {
		"include_addons": false,
		"root": "res://"
	},
	"data": {
		"nodes": [
			{
				"path": "res://tests/visualizer_cli_smoke.gd",
				"extends": "SceneTree",
				"functions": []
			}
		],
		"edges": [
			{
				"from": "res://tests/visualizer_cli_smoke.gd",
				"to": "res://addons/godot_visualizer_native/visualizer_manager.gd",
				"type": "preload"
			}
		],
		"total_scripts": 1,
		"total_connections": 1
	}
}
```

`GET /api/v1/project-summary` 响应示例：

```json
{
	"ok": true,
	"protocol": "godot_visualizer_native.v1",
	"version": "v1",
	"resource": "project_summary",
	"generated_at": "2026-06-08T16:14:20",
	"query": {},
	"data": {
		"root": "res://",
		"include_addons": false,
		"fingerprint": "86315e352d652275b7f92833b2e3bcc3",
		"fingerprint_algorithm": "md5-json-v1",
		"unchanged": false,
		"totals": {
			"scripts": 1,
			"relationships": 1,
			"classes": 0
		},
		"top_folders": [
			{"name": "res://tests", "count": 1}
		],
		"relationship_types": [
			{"name": "preload", "count": 1}
		],
		"script_highlights": [
			{
				"path": "res://tests/visualizer_cli_smoke.gd",
				"filename": "visualizer_cli_smoke.gd",
				"class_name": "",
				"extends": "SceneTree",
				"function_count": 4,
				"signal_count": 0,
				"variable_count": 1,
				"preload_count": 1,
				"connection_count": 0
			}
		]
	}
}
```

`GET /api/v1/lookup?path=res://tests/visualizer_cli_smoke.gd` 响应示例：

```json
{
	"ok": true,
	"protocol": "godot_visualizer_native.v1",
	"version": "v1",
	"resource": "lookup",
	"generated_at": "2026-06-08T16:20:25",
	"query": {
		"path": "res://tests/visualizer_cli_smoke.gd"
	},
	"data": {
		"kind": "any",
		"limit": 10,
		"filters": {
			"path": "res://tests/visualizer_cli_smoke.gd"
		},
		"counts": {
			"script_matches": 1,
			"scene_matches": 0
		},
		"script_matches": [
			{
				"path": "res://tests/visualizer_cli_smoke.gd",
				"filename": "visualizer_cli_smoke.gd",
				"class_name": "",
				"extends": "SceneTree",
				"line_count": 192,
				"matched_on": ["path"],
				"matched_functions": [],
				"matched_signals": []
			}
		],
		"scene_matches": []
	}
}
```

`GET /api/v1/scene-summary` 响应示例：

```json
{
	"ok": true,
	"protocol": "godot_visualizer_native.v1",
	"version": "v1",
	"resource": "scene_summary",
	"generated_at": "2026-06-08T16:14:20",
	"query": {},
	"data": {
		"root": "res://",
		"include_addons": false,
		"fingerprint": "686ea4f6fde6016a943b7e85904ead25",
		"fingerprint_algorithm": "md5-json-v1",
		"unchanged": false,
		"totals": {
			"scenes": 0,
			"instance_edges": 0,
			"nodes": 0,
			"script_refs": 0
		},
		"root_types": [],
		"instanced_scene_paths": [],
		"scene_highlights": []
	}
}
```

## 验证

### 编辑器联调清单

1. 启用插件后，确认 Dock 的 Runtime Status 显示 `stopped`。
2. 点击 `Open Browser Visualizer`，确认 Runtime Status 变成 running，并显示端口和 URL。
3. 浏览器打开后，确认脚本图谱能正常加载。
4. 点击页面里的刷新，确认不会报 transport 错误。
5. 修改一个脚本变量或函数体，确认命令返回成功。
6. 切到 `Scenes`，展开一个场景，确认层级可加载。
7. 修改一个节点属性，确认命令返回成功。
8. 点击 `Stop Live Visualizer`，确认 Dock 恢复 stopped。

### 命令行烟雾验证

项目内提供了 [godot-visualizer-native/tests/visualizer_cli_smoke.gd](godot-visualizer-native/tests/visualizer_cli_smoke.gd)。可以直接运行：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /absolute/path/to/godot-visualizer-native -s res://tests/visualizer_cli_smoke.gd
```

这个脚本会：

- 实例化 visualizer manager
- 启动 localhost 结构化 API / live 宿主，但不自动打开浏览器
- 请求 /health
- 请求 /api/v1、/api/v1/runtime、/api/v1/project-summary、/api/v1/scene-summary、/api/v1/lookup、/api/v1/project-map
- 请求 /command 的 refresh_map
- 停止 live 宿主并用退出码返回结果

启动后可额外验证：

```bash
curl http://127.0.0.1:6510/health
curl http://127.0.0.1:6510/api/v1
curl http://127.0.0.1:6510/api/v1/runtime
curl http://127.0.0.1:6510/api/v1/lookup?path=res://tests/visualizer_cli_smoke.gd
curl http://127.0.0.1:6510/api/v1/project-summary
curl "http://127.0.0.1:6510/api/v1/project-summary?if_fingerprint=<cached>"
curl http://127.0.0.1:6510/api/v1/scene-summary
curl -X POST http://127.0.0.1:6510/command -H 'Content-Type: application/json' -d '{"command":"refresh_map","args":{}}'
```

## 已承接的命令面

- `map_project`
- `refresh_map`
- `map_scenes`
- `create_script_file`
- `modify_variable`
- `modify_signal`
- `modify_function`
- `modify_function_delete`
- `find_usages`
- `get_scene_hierarchy`
- `get_scene_node_properties`
- `set_scene_node_property`
- `add_node`
- `remove_node`
- `rename_node`
- `move_node`
- `duplicate_node`
- `reorder_node`

## 设计原则

- 服务层不依赖 MCP。
- 浏览器前端不直接知道 Godot MCP 协议。
- 宿主链路由这个插件自己实现，不再依赖 godot-mcp 的 Node 服务器。
- 保留浏览器前端资产复用，但命令执行已经由独立插件接管。
- 原生 Dock 当前承担启动器与状态面板职责，后续可继续演进为完整原生 UI。# godot-scripts-visualizer
