# Pickplan Cloudflare Push Worker

This is the only Web Push backend kept in the Pickplan repository.

It exposes the following API endpoints:

- `GET /health`
- `GET /api/push/public-key`
- `POST /api/push/subscribe`
- `POST /api/push/unsubscribe`
- `POST /api/push/schedule`
- `POST /api/push/cancel`
- `POST /api/push/test`

## What it uses

- Cloudflare Workers
- Workers KV for subscriptions and scheduled jobs
- Cron Trigger for processing due jobs once per minute
- `web-push` for sending VAPID push messages

## Important behavior

This Worker uses a Cron Trigger every minute, so reminder delivery is usually
within about 1 minute of the scheduled time.

If you later want tighter delivery windows, the next upgrade path is Durable
Objects or Workflows.

## 1) Install

```bash
cd tools/cloudflare-push-worker
npm install
```

## 2) Local development

Create a local env file:

```powershell
Copy-Item .dev.vars.example .dev.vars
```

Then fill in:

```env
VAPID_SUBJECT=mailto:you@example.com
VAPID_PUBLIC_KEY=YOUR_VAPID_PUBLIC_KEY
VAPID_PRIVATE_KEY=YOUR_VAPID_PRIVATE_KEY
CORS_ORIGIN=http://localhost:8090,https://your-project.pages.dev
```

Run locally:

```powershell
npm run dev
```

Test the scheduled handler:

```powershell
curl "http://127.0.0.1:8787/__scheduled?cron=*+*+*+*+*"
```

## 3) Deploy

Login first:

```powershell
npx wrangler login
```

Set production secrets:

```powershell
npx wrangler secret put VAPID_SUBJECT
npx wrangler secret put VAPID_PUBLIC_KEY
npx wrangler secret put VAPID_PRIVATE_KEY
npx wrangler secret put CORS_ORIGIN
```

Deploy:

```powershell
npm run deploy
```

With Wrangler `4.45.0+`, the KV namespaces in `wrangler.toml` can be created
for you automatically during deployment.

## 4) Connect the Flutter web app

The frontend now supports two modes:

- Local dev: defaults to `http://localhost:8787`
- Production: defaults to `window.location.origin` if your Worker is mounted on the same domain

If your Worker runs on a separate `workers.dev` domain, set an explicit
backend URL before the app starts:

```html
<script>
  window.PICKPLAN_PUSH_BACKEND_BASE_URL =
    'https://your-worker-name.your-subdomain.workers.dev';
</script>
```

Or edit `web/push_config.js` directly.

The frontend can also fetch the public VAPID key from
`GET /api/push/public-key`, so you do not need to hardcode it into the web app.

## 5) GitHub deployment

The repository includes a GitHub Actions workflow:

- `.github/workflows/deploy-worker.yml`

It deploys this Worker on pushes to `main` when files under
`tools/cloudflare-push-worker/` change.

GitHub secrets needed:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_WORKERS_API_TOKEN`

Runtime secrets still need to exist on the Worker:

- `VAPID_SUBJECT`
- `VAPID_PUBLIC_KEY`
- `VAPID_PRIVATE_KEY`
- `CORS_ORIGIN`
