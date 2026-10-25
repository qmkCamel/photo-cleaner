## Context

仓库公开且有管理权限，默认分支为 `main`，当前产品开发与本次授权交付使用 `dev`。现有静态模板位于 `docs/app-store/site-template/`。

## Decisions

- 保留原有模板路径，避免破坏现有发布预检；以该目录为网页内容唯一来源。
- GitHub Pages 使用 Actions 构建模式；工作流仅在 `dev` 的网站路径变化时触发，发布环境限定该分支。
- 构建产物白名单仅包含 `index.html`、`privacy.html`、`support.html`、`styles.css`、`.nojekyll`。
- 固定网站根地址 `https://qmkcamel.github.io/photo-cleaner/`。隐私和支持分别为 `privacy.html`、`support.html`。
- 页面无需登录，不嵌入分析、外部字体、图片追踪或表单。使用 `mailto:` 联系用户确认的支持邮箱。
- 网站说明区分 App 本地处理与 GitHub 托管访问日志、用户主动邮件联系；不承诺第三方托管完全没有访问记录。
- 本次不改变原生 App 行为，因此不引入新的长耗时用户操作。

## Verification

使用静态发布检查、桌面和移动视口浏览器 smoke、命名截图、实际部署状态及公网 HTTP 校验。修复本变更内的失败；既有全仓 OpenSpec 问题单独记录。

## Rollback

通过正常提交回退网站文件或重新部署上一已验证提交。保留已公布 URL，避免因移动目录造成 App Store 链接失效。
