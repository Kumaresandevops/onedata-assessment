# cicd-demo-api

[![CI/CD — Build, Test & Deploy](https://github.com/<YOUR_USERNAME>/cicd-demo-api/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/<YOUR_USERNAME>/cicd-demo-api/actions/workflows/ci-cd.yml)

A simple Node.js REST API demonstrating a full GitHub Actions CI/CD pipeline that builds, tests, and deploys a Dockerised application to a local Kubernetes cluster (Minikube).

---

## 📦 Stack

| Layer | Technology |
|---|---|
| App | Node.js + Express |
| Tests | Jest + Supertest |
| Container | Docker (multi-stage) |
| Registry | GitHub Container Registry (GHCR) |
| Orchestration | Kubernetes (Minikube) |
| CI/CD | GitHub Actions |

---

## 🚀 Pipeline Jobs

```
push to main
     │
     ▼
┌─────────┐    ┌─────────────┐    ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  Lint   │───▶│ Unit Tests  │───▶│  Docker Build    │───▶│ Deploy Staging   │───▶│ Integration Tests│
│ ESLint  │    │ Jest + Cov  │    │  Push → GHCR     │    │  ⛩ Manual Gate   │    │ curl / bash      │
└─────────┘    └─────────────┘    └──────────────────┘    └──────────────────┘    └──────────────────┘
                                                                    │
                                                            Auto-rollback on fail
                                                         (kubectl rollout undo)
```

---

## 🔑 Key Features

- **Pinned image tags** — Docker images are tagged with the Git commit SHA (`${{ github.sha }}`), never `latest`
- **Manual approval gate** — The `deploy-staging` job uses a GitHub Environment (`staging`) with a required reviewer before any deployment proceeds
- **Auto-rollback** — If `kubectl rollout status` times out or fails, the workflow automatically runs `kubectl rollout undo`
- **Integration tests** — A parallel job runs a bash/curl test suite against the live deployed service
- **Code coverage** — Jest coverage report is uploaded as a workflow artifact

---

## 🛠 Local Setup

```bash
# Install dependencies
npm install

# Run unit tests
npm test

# Lint
npm run lint

# Run the app
npm start
# → http://localhost:3000
```

### Docker

```bash
docker build -t cicd-demo-api:local .
docker run -p 3000:3000 cicd-demo-api:local
```

### Minikube (manual deploy)

```bash
minikube start

# Apply manifests (substitute vars first)
export GITHUB_REPOSITORY=<your-username>/cicd-demo-api
export IMAGE_TAG=<git-sha>
envsubst < k8s/deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/service.yaml

# Check status
kubectl get pods
kubectl get svc

# Open in browser
minikube service cicd-demo-api-svc --url
```

---

## 🌐 API Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/api/items` | List all items |
| GET | `/api/items/:id` | Get item by ID |
| POST | `/api/items` | Create item `{ name, value }` |
| DELETE | `/api/items/:id` | Delete item |

---

## ⚙️ GitHub Setup Checklist

1. **Create a `staging` Environment** in *Settings → Environments → New environment*
   - Add yourself (or a reviewer) as a **Required reviewer**
   - This creates the manual approval gate before the deploy job runs

2. **No extra secrets needed** — The workflow uses `GITHUB_TOKEN` (auto-provided) to push/pull from GHCR

3. **Update the badge URL** — Replace `<YOUR_USERNAME>` in the badge at the top of this README with your actual GitHub username

---

## 📁 Project Structure

```
.
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # Main CI/CD pipeline
├── k8s/
│   ├── deployment.yaml        # Kubernetes Deployment (2 replicas, rolling update)
│   └── service.yaml           # Kubernetes NodePort Service
├── src/
│   └── app.js                 # Express REST API
├── tests/
│   ├── app.test.js            # Jest unit tests (8 tests)
│   └── integration_test.sh    # Bash/curl integration tests
├── .dockerignore
├── .eslintrc.json
├── Dockerfile                 # Multi-stage Docker build
├── package.json
└── README.md
```
