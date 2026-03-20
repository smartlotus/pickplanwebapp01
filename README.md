# Pickplan

Pickplan is a Flutter project with two client targets:

- Android native app
- Mobile web / iOS PWA

The Web Push backend in this repository now keeps only one deployment path:

- Cloudflare Worker: `tools/cloudflare-push-worker`

## Key directories

- `lib/`: Flutter application code
- `assets/`: app images and static assets
- `web/`: Flutter Web shell, PWA files, push bridge, cache guard
- `tools/cloudflare-push-worker/`: Cloudflare Workers push backend
- `.github/workflows/`: GitHub Actions for Pages + Worker deployment

## Local build

```bash
flutter pub get
flutter build web --release
```

Build output:

```text
build/web
```

## Web Push architecture

Frontend:

- `web/push_config.js`
- `web/push_client.js`
- `web/push/push_sw.js`
- `web/cache_guard.js`

Backend:

- `tools/cloudflare-push-worker/src/index.js`
- `tools/cloudflare-push-worker/wrangler.toml`

The frontend defaults are:

- local development: `http://localhost:8787`
- production: current site origin, unless you inject an explicit backend URL

If your Worker is deployed on a separate `workers.dev` domain, set the GitHub
secret `PICKPLAN_PUSH_BACKEND_BASE_URL`. The Pages deployment workflow will
inject it into the built web app automatically.

## Upload to GitHub

Upload source code and configuration:

- `lib/`
- `assets/`
- `web/`
- `android/`
- `ios/`
- `test/`
- `tools/cloudflare-push-worker/`
- `.github/workflows/`
- `pubspec.yaml`
- `pubspec.lock`
- `analysis_options.yaml`
- `.gitignore`
- `README.md`

Do not upload generated artifacts or caches:

- `build/`
- `dist/`
- `.dart_tool/`
- `.idea/`
- `.npm-cache/`
- `.npm-cache-netlify/`
- logs and local analysis files
- `tools/cloudflare-push-worker/node_modules/`
- `tools/cloudflare-push-worker/.dev.vars*`

## GitHub -> Cloudflare deployment

This repository is set up for a GitHub-based deployment flow:

1. Push the repository to GitHub.
2. GitHub Actions builds Flutter Web and deploys `build/web` to Cloudflare Pages.
3. GitHub Actions deploys the Cloudflare Worker from
   `tools/cloudflare-push-worker`.

### GitHub secrets you need

For Pages:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_PAGES_API_TOKEN`
- `CLOUDFLARE_PAGES_PROJECT_NAME`

For Worker:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_WORKERS_API_TOKEN`

Optional for frontend binding:

- `PICKPLAN_PUSH_BACKEND_BASE_URL`
  - set this if your Worker uses a separate URL such as
    `https://pickplan-push.<subdomain>.workers.dev`

### Worker runtime secrets

These must be configured on the deployed Worker itself:

- `VAPID_SUBJECT`
- `VAPID_PUBLIC_KEY`
- `VAPID_PRIVATE_KEY`
- `CORS_ORIGIN`

Optional security controls for traffic filtering:

- `BLOCK_COUNTRIES`
  - comma-separated country codes (ISO 3166-1 alpha-2), default: `FR`
  - example: `FR,RU`
- `BLOCK_AI_CRAWLERS`
  - `1` to enable AI crawler UA blocking (default), `0` to disable
- `EXTRA_BLOCKED_AI_BOTS`
  - optional extra bot UA tokens, comma-separated
- `ALLOW_CRAWLER_PATHS`
  - optional allowlist paths for blocked crawler traffic, default: `/health`
- `LOG_BLOCKED_REQUESTS`
  - `1` to log blocked requests in Worker logs (default), `0` to disable

You can add them from the Cloudflare dashboard or via Wrangler:

```bash
cd tools/cloudflare-push-worker
npx wrangler secret put VAPID_SUBJECT
npx wrangler secret put VAPID_PUBLIC_KEY
npx wrangler secret put VAPID_PRIVATE_KEY
npx wrangler secret put CORS_ORIGIN
```

## Cloudflare setup order

1. Create a Cloudflare Pages project name.
2. Create the Worker once from `tools/cloudflare-push-worker`.
3. Add the Worker runtime secrets.
4. Add the GitHub repository secrets.
5. Push to `main`.

## Important notes

- iOS PWA behavior is still not 100% identical to a native app.
- Web Push on the web depends on the Cloudflare Worker being deployed and
  configured correctly.
- For production AI calls, use a backend proxy instead of exposing private API
  keys in the web client.
