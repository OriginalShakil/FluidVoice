# Cloudflare Workers AI Whisper Large v3 Turbo Setup

This guide provides everything needed to run **OpenAI Whisper Large v3 Turbo (`@cf/openai/whisper-large-v3-turbo`)** on Cloudflare Workers AI with **full Bangla (বাংলা) and multilingual support**, completely free (up to 10,000 Neurons/day).

---

## Method 1: Direct Integration in FluidVoice (Recommended — Zero Deployment)

FluidVoice now supports Cloudflare Workers AI natively. You don't even need to deploy a worker:

1. **Get your Cloudflare Account ID & API Token**:
   - Go to [Cloudflare Dashboard](https://dash.cloudflare.com/).
   - Click on your account or **Workers & Pages**.
   - Your **Account ID** is displayed on the right sidebar (a 32-character hex string).
   - Go to **My Profile > API Tokens** (or [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)).
   - Click **Create Token** > Use the **"Workers AI"** template (Permissions: `Account > Workers AI > Read/Edit`).
2. **In FluidVoice**:
   - Open **Settings > Voice Engine**.
   - Under **AI Provider**, select **Cloudflare Workers AI (Whisper Large v3 Turbo)**.
   - Enter your **Cloudflare Account ID**.
   - Enter your **Cloudflare API Token**.
   - Set **Spoken Language** to **"Bengali / Bangla (বাংলা)"** or **"Auto-Detect"**.
   - Click **Test AI Transcriber** to verify the live connection.
   - Click **Activate Cloud AI**.

---

## Method 2: Deploy Your Own Cloudflare Worker (Custom Endpoint)

If you prefer your own custom URL endpoint (e.g. `https://whisper.yourdomain.workers.dev/v1/audio/transcriptions`):

### 1. Install Dependencies & Login
```bash
cd tools/cloudflare-whisper-worker
npm install
npx wrangler login
```

### 2. (Optional) Set an Auth Secret
```bash
npx wrangler secret put AUTH_TOKEN
```

### 3. Deploy
```bash
npx wrangler deploy
```

You will receive your live Worker URL:
```
https://fluidvoice-whisper-worker.<your-subdomain>.workers.dev
```

### 4. Configure in FluidVoice
- Select **Custom Endpoint** in FluidVoice.
- Base URL: `https://fluidvoice-whisper-worker.<your-subdomain>.workers.dev/v1`
- Model: `@cf/openai/whisper-large-v3-turbo`
- API Key: Your `AUTH_TOKEN` (if configured, or leave empty).
