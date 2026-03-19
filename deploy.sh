#!/bin/bash
# ─────────────────────────────────────────────────────────────
# TimeCapsule — Hetzner VPS Deployment Script
# Run this once on a fresh Ubuntu 24.04 Hetzner server
# Usage: chmod +x deploy.sh && sudo ./deploy.sh
# ─────────────────────────────────────────────────────────────
set -e

DOMAIN="yourdomain.com"
N8N_DOMAIN="n8n.yourdomain.com"
EMAIL="your@email.com"   # For Let's Encrypt

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TimeCapsule — Server Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. System update
apt update && apt upgrade -y

# 2. Docker
echo "→ Installing Docker..."
curl -fsSL https://get.docker.com | sh
systemctl enable docker

# 3. Certbot (SSL)
echo "→ Installing Certbot..."
apt install -y certbot

# 4. Create project dir
mkdir -p /opt/timecapsule/nginx/certs
cd /opt/timecapsule

# 5. Copy files (assumes you've SCP'd the project here)
# scp -r ./timecapsule/* root@YOUR_IP:/opt/timecapsule/

# 6. Generate SSL certs
echo "→ Getting SSL certificates..."
certbot certonly --standalone \
  -d "$N8N_DOMAIN" \
  --non-interactive --agree-tos -m "$EMAIL"

cp /etc/letsencrypt/live/$N8N_DOMAIN/fullchain.pem /opt/timecapsule/nginx/certs/
cp /etc/letsencrypt/live/$N8N_DOMAIN/privkey.pem   /opt/timecapsule/nginx/certs/

# 7. Create .env if not exists
if [ ! -f .env ]; then
  cp .env.example .env
  # Generate a strong postgres password
  PGPASS=$(openssl rand -base64 24 | tr -d '/+=')
  sed -i "s/change_me_strong_password/$PGPASS/g" .env
  echo ""
  echo "⚠️  Edit /opt/timecapsule/.env before continuing!"
  echo "   Fill in: NEXTAUTH_SECRET, GOOGLE_CLIENT_*, RAZORPAY_*, BREVO_API_KEY"
  echo ""
  read -p "Press Enter when .env is ready..."
fi

# 8. Start containers
echo "→ Starting Docker containers..."
docker compose up -d

# 9. Auto-renew SSL
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && cp /etc/letsencrypt/live/$N8N_DOMAIN/*.pem /opt/timecapsule/nginx/certs/ && docker restart timecapsule_nginx") | crontab -

# 10. Setup DB backup cron
mkdir -p /opt/backups
(crontab -l 2>/dev/null; echo "0 2 * * * docker exec timecapsule_db pg_dump -U capsule_user timecapsule > /opt/backups/db_\$(date +\%F).sql && find /opt/backups -name '*.sql' -mtime +7 -delete") | crontab -

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Setup complete!"
echo ""
echo "  n8n:      https://$N8N_DOMAIN"
echo "  Next.js:  Deploy to Vercel at https://vercel.com"
echo ""
echo "  Next steps:"
echo "  1. Import n8n-workflow.json into your n8n instance"
echo "  2. Add Postgres credentials in n8n"
echo "  3. Add BREVO_API_KEY to n8n env"
echo "  4. Push nextjs/ to GitHub → deploy to Vercel"
echo "  5. Set Vercel env vars (copy from .env)"
echo "  6. Point your domain DNS to this server IP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
