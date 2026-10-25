# TrueKeep App Store Pages

This directory is the source of the public bilingual support and privacy website.

- Home: https://qmkcamel.github.io/photo-cleaner/
- Support: https://qmkcamel.github.io/photo-cleaner/support.html
- Privacy: https://qmkcamel.github.io/photo-cleaner/privacy.html
- Contact: qmkhaust@gmail.com

## Publishing

The `App Store support pages` GitHub Actions workflow publishes website changes pushed to `dev`. GitHub Pages must use the Actions build mode. Only `index.html`, `privacy.html`, `support.html`, `styles.css`, and `.nojekyll` enter the deployment artifact. The repository's other documents, app source, and test artifacts are excluded.

Run `python3 docs/app-store/check_site.py` from the repository root before pushing. Preview with `python3 -m http.server 8765 --directory docs/app-store/site-template` and open http://127.0.0.1:8765/.

Keep URLs stable. Update the policy and date when app data practices change. Verify the public URLs after deployment before using them in App Store Connect. See `../github-pages-deployment.md` for deployment and validation evidence.
