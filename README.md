# 💌 TimeCapsule

> Write heartfelt messages today. Deliver them to the people you love — on any future date.

**Stack:** Next.js · PostgreSQL · n8n · Brevo · Razorpay · Cloudflare R2 · Hetzner VPS

---

## 🗂️ Project Structure

```
timecapsule/
├── docker-compose.yml      # PostgreSQL + n8n + Nginx on Hetzner
├── schema.sql              # Full DB schema (auto-runs on first boot)
├── n8n-workflow.json       # Import this into n8n
├── nginx/nginx.conf        # Reverse proxy for n8n
├── .env.example            # Copy to .env and fill in values
├── deploy.sh               # One-shot Hetzner setup script
└── nextjs/                 # Next.js 14 app (deploy to Vercel)
    ├── app/
    │   ├── page.tsx                    # Landing page
    │   ├── login/page.tsx              # Login
    │   ├── register/page.tsx           # Register
    │   ├── dashboard/page.tsx          # User dashboard
    │   ├── capsule/create/page.tsx     # Create capsule
    │   ├── pricing/page.tsx            # Pricing + Razorpay
    │   └── api/
    │       ├── auth/[...nextauth]/     # NextAuth
    │       ├── auth/register/          # Email registration
    │       ├── capsules/               # CRUD
    │       ├── upload/                 # R2 presigned URLs
    │       ├── payment/create-order/   # Razorpay order
    │       └── webhook/razorpay/       # Payment webhook
    ├── components/
    │   ├── SessionProvider.tsx
    │   ├── DashboardClient.tsx
    │   └── CreateCapsuleForm.tsx
    └── lib/
        ├── db.ts       # PostgreSQL pool + helpers
        ├── auth.ts     # NextAuth config
        └── r2.ts       # Cloudflare R2 storage
```

---

## 🚀 Deployment Guide

### 1. Hetzner VPS (PostgreSQL + n8n)

```bash
# 1. Create a Hetzner CX22 (cheapest, 2GB RAM) — or use your existing one
# 2. SSH into your server
ssh root@YOUR_HETZNER_IP

# 3. Upload project files
scp -r ./timecapsule/* root@YOUR_HETZNER_IP:/opt/timecapsule/

# 4. Run setup script
cd /opt/timecapsule
chmod +x deploy.sh && sudo ./deploy.sh
```

### 2. Configure n8n

1. Open `https://n8n.yourdomain.com`
2. Go to **Workflows → Import** → upload `n8n-workflow.json`
3. Add a **Postgres credential** (host: `postgres`, port: `5432`, db: `timecapsule`)
4. Add `BREVO_API_KEY` to n8n environment or use HTTP header auth
5. Activate the workflow

### 3. Deploy Next.js to Vercel

```bash
cd nextjs
npm install
# Push to GitHub first
git init && git add . && git commit -m "init"
git remote add origin YOUR_GITHUB_REPO
git push -u origin main
```

Then in Vercel:
1. Import the repo
2. Set all env vars from your `.env` file
3. Deploy ✅

### 4. Point DNS

| Record | Type | Value |
|--------|------|-------|
| `yourdomain.com`      | A | Vercel IP (auto via Vercel) |
| `n8n.yourdomain.com`  | A | Your Hetzner IP |

---

## 🔧 Environment Variables

Copy `.env.example` → `.env` and fill in:

| Variable | Where to get it |
|----------|----------------|
| `DATABASE_URL` | Your Hetzner PostgreSQL |
| `NEXTAUTH_SECRET` | Run: `openssl rand -base64 32` |
| `GOOGLE_CLIENT_ID/SECRET` | [console.cloud.google.com](https://console.cloud.google.com) |
| `RAZORPAY_KEY_ID/SECRET` | [dashboard.razorpay.com](https://dashboard.razorpay.com) |
| `RAZORPAY_WEBHOOK_SECRET` | Razorpay Dashboard → Webhooks |
| `BREVO_API_KEY` | [app.brevo.com](https://app.brevo.com) → SMTP & API |
| `R2_*` | Cloudflare Dashboard → R2 |

---

## 💰 Plan Limits

| Plan | Capsules | Media | Price |
|------|----------|-------|-------|
| Free | 3 | ❌ | ₹0 |
| Plus | 20 | Photos + Audio | ₹199/mo |
| Pro | 100 | Photos + Video + Audio | ₹499/mo |

---

## 🔁 n8n Workflow Logic

```
Every day at 9 AM IST
  → Query PostgreSQL for capsules where deliver_at <= NOW() AND status = 'pending'
  → For each capsule: send email via Brevo API
  → Mark capsule status = 'sent'

Razorpay webhook (payment.captured)
  → Verify signature
  → Update payment status = 'paid'
  → Upgrade user plan for 30 days
```

---

## 🔒 Security Notes

- All passwords hashed with `bcrypt` (12 rounds)
- Razorpay webhooks verified with HMAC-SHA256
- Postgres only accessible on `127.0.0.1` (not exposed publicly)
- n8n protected with basic auth + behind Nginx SSL
- File uploads use presigned R2 URLs (never pass through your server)

---

## 📬 Email Template

The email sent by n8n uses a warm, parchment-style HTML template with:
- Sender's name in the subject line
- Full message content
- Attached media (if any)
- Delivery date footer

Customise in the `n8n-workflow.json` → `Send via Brevo` node → `htmlContent` field.

---

## 🛠️ Local Development

```bash
cd nextjs
cp .env.example .env.local   # Fill in values
npm install
npm run dev                   # http://localhost:3000
```

For local PostgreSQL:
```bash
docker run -d \
  --name timecapsule_db \
  -e POSTGRES_DB=timecapsule \
  -e POSTGRES_USER=capsule_user \
  -e POSTGRES_PASSWORD=localpass \
  -p 5432:5432 \
  postgres:16-alpine

# Then run schema
psql postgresql://capsule_user:localpass@localhost/timecapsule < schema.sql
```
