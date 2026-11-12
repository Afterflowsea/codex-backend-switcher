# 配置说明

## providers.json

位置：`%USERPROFILE%\.codex\.switch\providers.json`

```json
[
  {
    "id": "account",
    "name": "ChatGPT 账号",
    "kind": "account",
    "base_url": "",
    "model": "gpt-6-luna",
    "proxy": "",
    "extra": {},
    "note": "官方登录"
  },
  {
    "id": "apimart",
    "name": "apimart",
    "kind": "relay",
    "base_url": "https://apimart.ai/v1",
    "model": "gpt-6.1-sol",
    "proxy": "http://127.0.0.1:7890",
    "extra": {},
    "note": "国际线路"
  }
]
```

### 字段详解

#### `id`（必填）

- 唯一标识，字母数字下划线
- 同时作为 `config.toml` 里的 `model_provider` 名和 `[model_providers.<id>]` 表名
- 命令行里也用它：`CodexSwitcher.ps1 apimart`

#### `kind`（必填）

| 值 | 行为 |
|---|---|
| `account` | 不写 provider 块，`auth.json` 用 chatgpt tokens |
| `relay` | 写 provider 块，`auth.json` 用 API key |

#### `base_url`

只对 `relay` 有效。两条经验：

- 大多数中转是 `https://域名/v1`（Codex 会自己拼 `/responses`）
- 少数按官方文档要求不带 `/v1`，例如 `https://www.fhl.mom`

不确定时**先按服务商文档填**。填错的表现通常是 404 或 `Invalid URL`。
校验阶段脚本会同时试 `{base}/models` 和 `{base}/v1/models`，但最终写进配置的是你填的原值。

#### `model`

- 填了就用它（前提是校验时确认该模型可用）
- 留空则自动挑选，优先级：
  `名字含 codex` → `gpt-6-luna` → `gpt-6-sol` → `gpt-6` → `gpt-5.6-*` → `gpt-6*` → `gpt-5*` → 第一个
- 图像/视频/向量类模型会被排除；`codex-auto-review`（代码审查专用）也会被排除

> 切换时脚本会同时写 `model` 和 `review_model`，避免 review 还指向上一个站点不存在的模型。

#### `proxy`

需要翻墙的站点填本地代理地址，例如：

```json
"proxy": "http://127.0.0.1:7890"
```

脚本会把 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` 写到**用户级环境变量**。
切换回直连站点时会清掉——但只清本工具设过的（记录在 `proxy-state.txt`）。

> 环境变量对**新启动的进程**生效。切换流程本来就会重开 Codex，所以能吃到新值。
> 如果你手动在别的终端里验证，需要新开一个终端窗口。

#### `extra`

按站点附加的根级配置项，例如：

```json
"extra": {
  "web_search": "live",
  "model_context_window": 1000000
}
```

- 字符串会加引号，数字/布尔原样写
- 切到别的站点时，这些键会被自动移除
- 所有站点 `extra` 里出现过的键名会被收集成"受管键名"，切换时统一清理

可以用 `-c` 预检某个键是否被当前 Codex 版本识别：

```powershell
codex -c 'web_search="live"' doctor
# 如果输出里出现 "unrecognized configuration settings"，说明该版本不认识这个键
```

#### `note`

纯备注，不参与逻辑。

---

## config.toml 会被改动哪些行

切换时只碰这些：

```toml
model_provider = "<id>"        # 根级，插在文件最前
model = "<model>"              # 覆盖
review_model = "<model>"       # 覆盖

[model_providers.<id>]         # 追加到文件末尾
name = "..."                   # 取 providers.json 的 name
base_url = "..."               # 取 providers.json 的 base_url
wire_api = "responses"
requires_openai_auth = true
```

以及 `extra` 里的键。

**其它内容全部保留**：`sandbox_mode`、`approval_policy`、`[projects.*]`、`[desktop]`、`[mcp_servers.*]`、`[plugins.*]`、`notify` 等。

---

## 环境变量

| 变量 | 何时设置 | 说明 |
|---|---|---|
| `HTTP_PROXY` | 站点配了 `proxy` | 用户级 |
| `HTTPS_PROXY` | 同上 | 用户级，Codex 主要看这个 |
| `ALL_PROXY` | 同上 | 用户级 |

脚本不设置 `OPENAI_API_KEY`。凭据统一走 `auth.json`，避免两个来源打架。

---

## 文件权限与备份

| 路径 | 内容 | 建议 |
|---|---|---|
| `~/.codex/config.toml` | Codex 主配置 | 切换前可自行备份 |
| `~/.codex/auth.json` | 当前凭据 | 脚本会写 |
| `~/.codex/.switch/auth.account.json` | 账号凭据备份 | 别删，删了要重新登录 |
| `~/.codex/.switch/keys/*.key` | 各站 API key | 明文，注意分享截图时遮挡 |

---

## 增加一个新站点

1. 在 `providers.json` 里加一个对象（`id` 唯一）
2. 双击菜单里就会多一项（菜单是动态生成的）
3. 第一次选它时会提示输入 key

不需要改任何脚本。
