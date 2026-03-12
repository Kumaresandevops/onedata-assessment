# GitLab CI/CD – Multi-Stage Pipeline with Environments & Rollback

## Repository Structure

```
.
├── .gitlab-ci.yml              # Main pipeline definition
├── Dockerfile                  # Multi-stage Docker build
├── app/
│   ├── server.js               # Node.js sample application
│   ├── package.json
│   └── test.js                 # Unit tests
├── k8s/
│   ├── staging-deployment.yaml     # Kubernetes manifests – staging
│   ├── production-deployment.yaml  # Kubernetes manifests – production
│   └── review-deployment.yaml      # Kubernetes manifests – review apps
└── README.md
```

---

## Pipeline Stages

| Stage | Job(s) | Trigger |
|---|---|---|
| `build` | `build:image` | Every push |
| `test` | `test:unit`, `test:container-scan` | Every push |
| `staging:deploy` | `staging:deploy`, `rollback:staging`, Review Apps | `main`/`develop` / MR |
| `production:deploy` | `production:deploy` *(manual gate)*, `rollback:production` | `main` only |
| `dora-metrics` | `dora:metrics` | After successful production deploy |

---

## Required GitLab CI/CD Variables

Navigate to **Settings → CI/CD → Variables** and add:

| Variable | Type | Masked | Description |
|---|---|---|---|
| `KUBECONFIG_B64` | File | ✅ Yes | Base64-encoded kubeconfig for Minikube/kind |
| `CI_REGISTRY_USER` | Variable | ✅ Yes | GitLab registry username |
| `CI_REGISTRY_PASSWORD` | Variable | ✅ Yes | GitLab registry password / token |
| `GITLAB_API_TOKEN` | Variable | ✅ Yes | Personal access token (read_api scope) for DORA job |

> **How to get KUBECONFIG_B64:**
> ```bash
> # Start Minikube
> minikube start
> # Encode the kubeconfig
> cat ~/.kube/config | base64 | tr -d '\n'
> # Paste the output as KUBECONFIG_B64 in GitLab (masked variable)
> ```

---

## Key Design Decisions

### 1. Image Tags — Never 'latest'
All Docker images are tagged with:
```
<pipeline_id>-<commit_short_sha>   e.g. 12345-abc1def2
```
This ensures every image is fully traceable and immutable.

### 2. Automated Rollback on Staging Failure
`rollback:staging` uses `when: on_failure` and `kubectl rollout undo` — it fires
automatically if `staging:deploy` exits non-zero, restoring the previous ReplicaSet.

### 3. Manual Gate for Production
`production:deploy` has `when: manual` — a human must click ▶️ in the GitLab UI
to promote from staging to production.

### 4. GitLab Review Apps
On every Merge Request a dedicated ephemeral environment is created:
- Environment name: `review/<branch-slug>`
- Auto-stopped when the MR is merged/closed (`on_stop: review:stop`)
- Safety TTL: `auto_stop_in: 1 day`

### 5. DORA Metrics
The `dora:metrics` job queries the GitLab Deployments API, calculates deployment
frequency over the last 30 days, and saves a `dora-metrics.json` artifact for
the GitLab Environments dashboard.

---

## Local Setup (Minikube)

```bash
# 1. Start Minikube
minikube start --driver=docker

# 2. Create namespaces
kubectl create namespace staging
kubectl create namespace production
kubectl create namespace review

# 3. Enable GitLab registry (in your GitLab project)
#    Settings → Packages & Registries → Container Registry → Enable

# 4. Push to main branch to trigger the pipeline
git add . && git commit -m "initial commit" && git push origin main
```

---

## Environments Dashboard

After deployments run, visit **Deployments → Environments** in your GitLab project to see:
- Live environment status (staging / production)
- Deployment history with commit SHAs
- One-click rollback button
- Review App list (auto-cleaned after MR merge)
