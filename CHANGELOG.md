# 版本记录

## v1.0.0 — 2026-11-12

首个可发布版本。

### 功能

- 多后端切换：ChatGPT 账号 + 任意数量中转站
- 切换前校验：连通性、key 有效性、模型可用性（含真实 `/responses` 探测）
- 校验失败不写盘，当前配置零改动
- 账号凭据备份与还原，切回账号无需重新登录
- 按站点记忆模型（界面里换过的模型会被记录）
- 按站点设置代理环境变量（`HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`）
- 附加根级配置项（`extra`），例如 `web_search`、`model_context_window`
- 菜单从 `providers.json` 动态生成，增删站点无需改代码
- 安装 / 卸载脚本，带自定义图标

### 已知限制

- 仅 Windows（依赖 `%LOCALAPPDATA%`、WScript.Shell、`codex.exe` 路径）
- 切换必须重启 Codex，当前会话会中断
- 账号登录首次仍需人工在浏览器授权，无法完全自动化
- 需要 PowerShell 5.1（系统自带，不需要 7）
