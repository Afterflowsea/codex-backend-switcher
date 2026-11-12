# 发布到 GitHub

给第一次发布用的清单，照着做即可。

---

## 1. 仓库名

`codex-backend-switcher`

理由：

- 包含 `codex` 和 `switcher` 两个最常被搜到的词
- `backend` 说明切的是"后端 / 供应商"，不是"账号"
- 有短横线，读起来清楚，也方便在 URL 里看

> 以后想改名随时可以在 Settings 里改，GitHub 会自动重定向旧地址。

---

## 2. 仓库描述（About）

GitHub 仓库页右上角 "About" 的 Description，最多 350 字，**会进搜索引擎**：

```
Windows 上一键切换 Codex 的后端：ChatGPT 官方账号 ⇄ 多个第三方 API 中转站。
切换前自动校验 key 与模型，失败不写盘；切回账号无需重新登录。
One-click backend switcher for Codex on Windows (ChatGPT account <-> API relays).
```

---

## 3. Topics（标签）

About 里的齿轮 → Topics，逐个添加。这些直接影响 GitHub 站内搜索结果：

```
codex
codex-cli
chatgpt
openai
switcher
api-relay
openai-api
powershell
windows
cli-tool
```

---

## 4. 首次推送

先在 https://github.com/new 建一个 **空** 仓库：

- 名字：`codex-backend-switcher`
- 可见性：Public
- **不要勾** Add a README / .gitignore / license（本地已经有，勾了会冲突）

然后在本地：

```powershell
cd E:\ppt\codex-backend-switcher
git remote -v                      # 应该是 https://github.com/Afterflowsea/codex-backend-switcher.git
git push -u origin main
```

第一次推可能弹浏览器让你登录（已装 Git Credential Manager）。

---

## 5. 发一个 Release（可选，但推荐）

有 Release 的项目更容易被信任。两种做法：

**A. 只打 tag（简单）**

```powershell
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
```

再到 GitHub 的 Releases → Draft a new release → 选中 tag → 贴一段更新说明。

**B. 附带 zip 包（用户免克隆）**

```powershell
cd E:\ppt
git -C codex-backend-switcher archive --format=zip --prefix=codex-backend-switcher/ `
    -o codex-backend-switcher-v1.0.0.zip HEAD
```

把 zip 拖到 Release 的附件里。别人下载解压后直接跑 `bin\install.ps1` 就能用。

---

## 6. 提高被搜到的概率

已经做了的：

- README 里有中英双语标题和一句话简介
- 末尾有一整段关键词
- 目录、文档、测试都齐全（GitHub 搜索会看文件结构）

还可以做的：

- 在 README 顶部加一张 GIF / 截图（演示菜单和切换过程），点击率差别很大
- 在相关讨论区（Codex 用户群、V2EX、即刻）发一条，带一句"解决什么问题"
- 给仓库加 `good first issue` 之类的标签，方便别人参与

---

## 7. 开源前的自检

```powershell
# 确认没有密钥类文件被提交
git ls-files | Select-String -Pattern 'key|auth|providers\.json'

# 只有 example 是正常的：
#   config/providers.example.json
```

仓库里应该**没有**：

- `*.key`
- `auth*.json`
- 你的真实 `providers.json`
- 任何 `sk-` 开头的长字符串

`.gitignore` 已经覆盖这些，但提交前扫一眼更稳妥。
