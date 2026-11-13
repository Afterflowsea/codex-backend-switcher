# 工作原理

## 为什么需要"切换"

Codex 把登录凭据存在 `~/.codex/auth.json`，而且**只有一个槽位**：

```json
{ "auth_mode": "apikey",  "OPENAI_API_KEY": "sk-..." }   // 中转 / API key
{ "auth_mode": "chatgpt", "tokens": { ... } }            // ChatGPT 账号
```

也就是说：账号登录和中转 key **不能同时存在**。想换后端，必须换凭据。

同时，后端地址写在 `~/.codex/config.toml` 里：

```toml
model_provider = "my-relay"

[model_providers.my-relay]
name = "my-relay"
base_url = "https://api.example.com/v1"
wire_api = "responses"
requires_openai_auth = true
```

所以一次完整切换 = `config.toml` + `auth.json` + 代理环境变量，三者必须**成套**变。只改其中一个，就会变成"请求发到 A，凭据是 B"，表现为各种 401。

---

## 一次切换的五步

```
①校验 ──失败──> 原样退出（不动任何文件）
   │
   ▼
②关闭 Codex（它会回写配置，必须先关）
   │
   ▼
③写 config.toml / auth.json / 代理变量 / 状态
   │
   ▼
④账号模式：还原备份的 tokens；没有备份才拉起登录
   │
   ▼
⑤重新打开 Codex
```

### ① 校验（最关键的一步）

很多"切换工具"是先把文件改掉再看能不能用，结果一旦出错，用户就卡在坏配置里。

本工具反过来：**先证明能用，才写盘**。

```powershell
# 1) 能不能连上、key 有没有效
GET {base_url}/models

# 2) 模型列表可能不全（有些中转只列一部分），所以再真实打一发
POST {base_url}/responses  {"model":"...","input":"hi","max_output_tokens":8}
```

第二步能拿到厂商的**原始错误**，这是诊断的关键：

| 厂商返回 | 真实含义 |
|---|---|
| `invalid_api_key` | key 错了或已作废 |
| `Model "x" is not supported by any configured account in this group` | **key 所属"分组"里没有这个模型**，不是余额问题 |
| `No available compatible accounts` | 上游账号池空了（通常是服务商侧问题） |
| 连接超时 | 域名被墙或代理没生效 |

任何一条失败，脚本都以非 0 退出，`config.toml` 一个字节都不动。

### ② 为什么必须先关 Codex

Codex 桌面端在退出时会把内存里的设置序列化回 `config.toml`。如果顺序反了：

```
改文件(在) → App 退出(覆盖) → 配置丢失
```

所以脚本先 `Stop-Process`，等 1.5 秒，再写文件。

### ③ 写文件时只动该动的

`config.toml` 里还混着大量用户的个人设置（项目信任、主题、MCP、插件、notify 命令）。脚本做的是"外科手术"：

- 删：根级 `model_provider = "..."`、整个 `[model_providers.*]` 表、该站点的 `extra` 键
- 加：新的 `model_provider` + `[model_providers.<id>]` 表 + `extra`
- 改：`model`、`review_model`

其余部分逐行保留。

> TOML 有个硬规则：根级键必须写在任何 `[table]` 之前。
> 所以 `model_provider` 插在文件最前面，`[model_providers.x]` 表追加到文件末尾。

### ④ 账号模式为什么不用重新登录

首次用账号登录后，`auth.json` 里的 `tokens`（含 `refresh_token`）会被备份到
`.switch/auth.account.json`。之后切回账号只要把它复制回去即可，Codex 会自己刷新。

只有当备份不存在（比如你手动登出过）时，脚本才会：

1. 打开 `https://auth.openai.com/codex/device`
2. 执行 `codex login --device-auth`
3. 把验证码显示在控制台

**注意**：OAuth 授权必须由本人在浏览器点确认，这一步不可能全自动。

### ⑤ 重开

`codex app` 启动桌面端。因为配置是启动时读取的，所以必须重开才生效。

> **启动速度**：实测直接拉起 MSIX 主程序 `app\ChatGPT.exe` 约 **7.4 秒**，
> 而 `codex app` 要约 **13.5 秒**——包装器会先跑一轮 CLI 侧检查再开界面。
> 所以脚本优先直接启动主程序，只有找不到时才回退到 `codex app`。
> 主程序路径按 `Get-AppxPackage` 动态解析，不写死版本号（应用更新后路径会变）。

---

## 状态都放在哪

```
%USERPROFILE%\.codex\.switch\
├─ providers.json        站点清单（用户自己维护）
├─ state.txt             当前站点 id
├─ proxy-state.txt       本工具设置的代理（用于"只清理自己设的"）
├─ auth.account.json     账号登录凭据备份
└─ keys\
   ├─ apimart.key        API key（明文，权限同 auth.json）
   └─ ...
```

放在 `.codex` 下面是有意的：和 Codex 自己的配置在一起，备份、迁移、排查都方便。

---

## 为什么"模型记忆"要单独做

Codex 的模型选择器改动会**直接改写 `config.toml` 的 `model` 行**。也就是说这个字段是双方共写的：

- 你在界面里改 → App 写
- 切换站点 → 脚本写

如果脚本每次都用 `providers.json` 里的默认模型覆盖，你在界面上挑的模型就丢了。所以切换前会先把当前 `model` 记到该站点名下，切回来时再用它。

---

## 代理为什么不能只靠"系统代理"开关

Windows 的"系统代理"（Internet 选项里那个）只有读 WinINET 的程序（浏览器、部分 .NET 应用）会用到。
Codex 这类 Rust/命令行程序看的是 `HTTPS_PROXY` 环境变量。

所以对需要翻墙的站点，脚本会：

```powershell
[Environment]::SetEnvironmentVariable('HTTPS_PROXY', 'http://127.0.0.1:7890', 'User')
```

切到直连站点时再清掉——而且**只清自己设过的**（记录在 `proxy-state.txt`），不会动用户原有的代理配置。
