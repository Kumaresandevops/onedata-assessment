# DevOps Stack — Full-Stack Automation with Docker Compose

> **Bitbucket Pipelines** · **Docker Compose** · **Prometheus + Grafana** · **Nginx Rate Limiting** · **Alertmanager → webhook.site**

---

## 📦 Services

| Service | Port | Description |
|---------|------|-------------|
| **API** (Flask + Gunicorn) | `80` (via Nginx) | REST API with Redis session store |
| **Redis** | internal | Session store & visit counter |
| **Nginx** | `80` | Reverse proxy + rate limiting (10 req/s) |
| **Prometheus** | `9090` | Metrics + alerting rules |
| **Alertmanager** | `9093` | Routes alerts → webhook.site |
| **Grafana** | `3000` | Pre-provisioned dashboard |
| **Redis Exporter** | internal | Redis metrics → Prometheus |
| **Nginx Exporter** | internal | Nginx metrics → Prometheus |
| **Node Exporter** | internal | System metrics → Prometheus |

---

## 🚀 Quick Start

```bash
# 1. Clone the repo
git clone https://bitbucket.org/<your-workspace>/<your-repo>.git
cd <your-repo>

# 2. Run setup (validates deps, creates .env, starts stack, waits for health)
chmod +x setup.sh smoke-test.sh load-test.sh
bash setup.sh

# 3. Open Grafana
open http://localhost:3000   # admin / admin123  (change in .env)
```

---

## 🧪 Running Tests

```bash
# Smoke tests (curl checks on every endpoint)
bash smoke-test.sh

# 30-second load test (k6 preferred, Apache Bench fallback)
bash load-test.sh
```

---

## ⚙️ Configuration

Copy `.env.template` → `.env` and set:

| Variable | Default | Description |
|----------|---------|-------------|
| `GRAFANA_ADMIN_PASSWORD` | `changeme_secure_password` | Grafana admin password |
| `WEBHOOK_SITE_ID` | `your-webhook-site-uuid-here` | UUID from [webhook.site](https://webhook.site) |
| `NGINX_HTTP_PORT` | `80` | Nginx listen port |
| `PROMETHEUS_PORT` | `9090` | Prometheus port |
| `GRAFANA_PORT` | `3000` | Grafana port |

---

## 🔀 Nginx Rate Limiting

Nginx enforces:
- **API endpoints** (`/api/*`): **10 req/s** per IP, burst of 20
- **General traffic** (`/`, `/health`): **30 req/s** per IP, burst of 50

Exceeding limits returns `HTTP 429` with a JSON error body.

Validate it:
```bash
# Send 30 rapid requests — you should see 429s
for i in $(seq 1 30); do curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost/api/visits; done
```

---

## 🔔 Prometheus Alerting

Alerts defined in `prometheus/alerts.yml`:
- `ServiceDown` — any scraped service goes down for > 30s
- `HighErrorRate` — API 5xx rate > 10%
- `NginxRateLimitHigh` — > 5 rate-limit rejections/s
- `RedisDown` — Redis unreachable
- `HighMemoryUsage` — memory > 90%
- `SlowAPIResponse` — p95 latency > 1s

Alerts route to **webhook.site** via Alertmanager. Set `WEBHOOK_SITE_ID` in `.env`.

Test an alert manually:
```bash
curl -X POST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"TestAlert","severity":"warning"},"annotations":{"summary":"Manual test alert"}}]'
```

---

## 📊 Grafana Dashboard

The dashboard auto-provisions on startup from `grafana/dashboards/devops-stack.json`.

Panels cover:
- Service health status (UP/DOWN)
- API request rate + error rate
- Response time percentiles (p50/p90/p99)
- Nginx connections + rate-limited requests
- Redis commands/s, memory, connected clients
- CPU + memory + network I/O

---

## 🗂️ Project Structure

```
.
├── app/                         # Flask REST API
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── nginx/
│   └── nginx.conf               # Rate limiting config
├── prometheus/
│   ├── prometheus.yml
│   ├── alerts.yml               # Alerting rules
│   └── alertmanager.yml         # Webhook routing
├── grafana/
│   ├── dashboards/
│   │   └── devops-stack.json    # Auto-provisioned dashboard
│   └── provisioning/
│       ├── datasources/prometheus.yml
│       └── dashboards/dashboards.yml
├── docker-compose.yml
├── bitbucket-pipelines.yml
├── setup.sh
├── smoke-test.sh
├── load-test.sh
├── .env.template
└── .gitignore
```

---

## 📋 Deliverables Checklist

- [x] `bitbucket-pipelines.yml` with full pipeline
- [x] `docker-compose.yml` with all services
- [x] `setup.sh` — validates deps, creates .env, starts + health-checks
- [x] Health checks on every service (60s deadline)
- [x] Smoke tests (`smoke-test.sh`)
- [x] Load test — k6 (fallback: Apache Bench) (`load-test.sh`)
- [x] Grafana dashboard auto-provisions from JSON
- [x] **Bonus**: Nginx rate limiting + pipeline validation
- [x] **Bonus**: Prometheus alerting → webhook.site
