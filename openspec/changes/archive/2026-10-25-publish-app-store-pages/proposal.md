## Why

App Store 隐私政策和支持网址仍为占位符。当前公开仓库可以直接托管 GitHub Pages，需要把现有模板更新为与当前 App 行为一致、可公开访问的正式页面。

## What Changes

- 使用当前 `qmkCamel/photo-cleaner` 仓库，从 `dev` 分支自动发布限定的网站文件。
- 发布中英双语首页、隐私政策和支持页，使用用户指定的支持邮箱 `qmkhaust@gmail.com`。
- 说明本地分析、确认保留记录、两种删除入口、有限权限、iCloud 风险、网站托管及主动邮件联系的边界。
- 验证页面、联系方式、链接与移动端布局，将实际网址同步至仓库上架材料。
- 非目标：修改照片分析或删除实现、代填 App Store Connect、上传 App、执行真实照片删除。

## Capabilities

### New Capabilities

- `app-store-support-site`: 在当前仓库托管公开可访问的隐私政策和支持页面。

### Modified Capabilities

- 无。

## Impact

涉及 `docs/app-store/`、上架网址材料和 `.github/workflows/app-store-pages.yml`。只发布静态网页白名单，不发布整个工程目录；不新增 App 网络请求或 SDK。
