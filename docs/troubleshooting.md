# 故障排查

先跑这两条看状态：

```powershell
powershell -File "$env:LOCALAPPDATA\CodexSwitcher\src\CodexSwitcher.ps1" status
powershell -File "$env:LOCALAPPDATA\CodexSwitcher\src\CodexSwitcher.ps1" list
```

---

## 401 / invalid_api_key

```
unexpected status 401 Unauthorized: Incorrect API key provided: sk-xxxx
```

**含义**：请求发到的服务不认这把 key。

常见原因（按概率）：

1. **key 属于 A 站，`base_url` 指向了 B 站** —— 中转 key 不跨站通用
2. **`base_url` 没配对**，请求打到了 `api.openai.com`，而你用的是中转 key
3. key 被撤销 / 重新生成过，本地存的是旧的
4. 复制时带了空格或换行

排查：

```powershell
# 看当前基准
powershell -File ...\CodexSwitcher.ps1 status

# 直接测这个站
curl.exe -H "Authorization: Bearer <你的key>" https://<base_url>/models
```

返回 `200` 说明 key 与站点匹配。返回 401 就是第 2、3 条。

**修**：删掉旧 key 重新输入

```powershell
Remove-Item "$env:USERPROFILE\.codex\.switch\keys\<id>.key"
```

下次切换会重新提示。

---

## Model "xxx" is not supported by any configured account in this group

**这句话是重点**：`in this group`。

意思不是 key 无效，也不是余额不足，而是**这把 key 所属的"分组"里没有这个模型的账号**。

中转站通常把上游账号按分组管理（比如"图像组""订阅组""官方组"），不同分组的 key 只能访问各自分组的模型。
表现就是：`/v1/models` 只列出图像模型，或者列了文本模型但请求报 404。

**修**：

1. 去站点后台看这把 key 的**分组 / 可用模型**设置
2. 如果有文本分组，在那里新建一把 key
3. 没有就找客服开通

余额不足的报错是 `insufficient quota` 之类，不会是 `model_not_found`。

---

## 直连超时 / 请求发不出去

```
curl: (28) Failed to connect to xxx:443 after 21044 ms
```

先分清两件事：

| 现象 | 说明 |
|---|---|
| 浏览器能打开这个站 | 浏览器走系统代理，不代表程序能连 |
| `curl` 直连超时，`curl -x 127.0.0.1:7890` 正常 | 说明域名被墙，必须走代理 |

**关键认知**：Windows 的"系统代理"开关只对读 WinINET 的程序生效。`curl`、Codex 这类程序看的是
`HTTPS_PROXY` 环境变量。

**修**：给这个站点在 `providers.json` 里加 `proxy`：

```json
{ "id": "apimart", "proxy": "http://127.0.0.1:7890" }
```

然后重新切换一次（脚本会写环境变量并重开 Codex）。

验证代理是否真的活着：

```powershell
curl.exe -x http://127.0.0.1:7890 -o NUL -w "%{http_code}" https://www.google.com/generate_204
# 204 = 代理正常
```

端口没监听的表现是**立刻**失败（几毫秒），而不是超时。用这个区分"代理没开"和"网速慢"：

```powershell
Get-NetTCPConnection -State Listen | Where-Object LocalPort -eq 7890
```

---

## 切换成功但 Codex 还是旧配置

配置只在**启动时**读取。切换流程会自动关闭并重开 Codex，如果你加了 `-NoClose` / `-NoLaunch`，
需要手动重启 App（托盘图标 → 退出，只关窗口不算）。

---

## 切换后模型不对

三种情况：

1. **站点没配 `model`** → 脚本自动挑了一个，看 `list` 输出里的模型
2. **你在界面里换过模型** → 切换前会被记到该站点名下，切回来会恢复；想改默认值就编辑 `providers.json`
3. **模型确实不存在** → 切换时校验会报错，不会写进去

---

## 切回账号后提示要重新登录

说明 `.switch/auth.account.json` 丢失或已失效（比如你在别处登出过）。

**修**：重新登录一次，之后又会自动备份。

```powershell
codex login --device-auth
```

> OAuth 授权必须本人在浏览器点确认，工具只能替你打开页面和显示验证码。

---

## 切换时提示"需要关闭 Codex"

这是保护机制。Codex 退出时会把内存里的设置写回 `config.toml`，如果先改文件再让它退出，改动会被覆盖。

按回车让它关掉即可；有未发送的输入会丢。想跳过确认加 `-Yes`。

---

## 中文乱码

所有 `.ps1` 必须是 **UTF-8 with BOM**。没有 BOM 时 PowerShell 5.1 会按 ANSI 解码，中文变成
`鐧诲綍鏂瑰紡` 这种乱码，甚至导致语法错误。

批量修复：

```powershell
$bom = New-Object Text.UTF8Encoding($true)
Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object {
    $t = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($_.FullName, $t, $bom)
}
```

---

## 图标没刷新

- 桌面按 `F5`
- 或执行 `ie4uinit.exe -show` 重建图标缓存

---

## 恢复成手动配置

所有改动都在两个文件里，删掉相关行即可：

- `~/.codex/config.toml`：删 `model_provider` 行和 `[model_providers.*]` 表
- `~/.codex/auth.json`：换成你要的凭据

或者直接运行卸载脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\bin\uninstall.ps1
```

卸载默认**保留** `~/.codex/.switch`（含 key 与登录备份）；要一并删除加 `-PurgeState`。
