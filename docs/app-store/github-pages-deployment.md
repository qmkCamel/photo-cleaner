# GitHub Pages deployment

Date: 2026-10-25 (Asia/Shanghai)

## Published destinations

- Repository: `qmkCamel/photo-cleaner` (public)
- Source branch: `dev`
- Home: https://qmkcamel.github.io/photo-cleaner/
- Support: https://qmkcamel.github.io/photo-cleaner/support.html
- Privacy: https://qmkcamel.github.io/photo-cleaner/privacy.html
- Approved support contact: `qmkhaust@gmail.com`

## Scope and source

The workflow `.github/workflows/app-store-pages.yml` deploys only the three HTML pages, shared stylesheet, and `.nojekyll` from `docs/app-store/site-template/`. Native app code and other repository files are outside the Pages artifact. App Store URL fields are recorded in both metadata locales.

## Local verification

- `python3 docs/app-store/check_site.py`: passed.
- `openspec validate publish-app-store-pages --type change --strict --no-interactive`: passed using repository-pinned OpenSpec 1.2.0.
- `python3 openspec/check.py`: 12/12 passed.
- `git diff --check`: passed.
- Browser navigation: Home → Support → Privacy → Home passed.
- Mail links resolve to the approved address. No mail was sent.
- Desktop and 390 × 844 mobile inspection passed; no horizontal overflow on the support or privacy pages.
- Named screenshots: `validation/2026-10-25/support-desktop.jpg`, `support-mobile.jpg`, `privacy-mobile.jpg`, and `home-mobile.jpg`.

## Deployment verification

- Deployed source commit: `6d60ee0cbc02f6efad1448805c6116c546b4f712`.
- GitHub Actions: https://github.com/qmkCamel/photo-cleaner/actions/runs/40197095947 — success, attempt 2.
- The first build passed; the first deployment was blocked by the newly created environment's default `main` branch rule. The environment now permits only `dev`, and retrying the deployment succeeded.
- GitHub Pages build mode: `workflow`; HTTPS enforcement: enabled.
- Public verification at 2026-10-25 21:22 +08:00: homepage, privacy policy, support page, and stylesheet all returned HTTP 200 without authentication. Response bytes matched the deployed source files; all HTML pages contained the approved support email.
- Exact HTTP results and SHA-256 values: `validation/2026-10-25/public-http-checks.json`.
- Live browser screenshot: `validation/2026-10-25/support-live.jpg`.
- OpenSpec CI for the deployed source commit passed: https://github.com/qmkCamel/photo-cleaner/actions/runs/40197095880.

This completes website hosting and repository URL preparation. It does not claim App Store Connect submission or native-app integration. Native app data practices must be reconciled with this policy before publishing future app changes.
