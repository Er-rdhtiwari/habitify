# Habitify – Personal Reminder + Habit Tracker

A minimal full-stack app with a Flask API and a statically-exported Next.js UI, packaged into a single container (port 8080) and deployable to Kubernetes/EKS via Helm.

## What’s inside
- Flask API (in-memory): `/health`, `/api/reminders`, `/api/habits`, `/api/habits/<id>/check`
- Next.js frontend (static export) served by Flask
- Dockerfile builds frontend + backend into one image
- Helm chart (`chart/habitify`) with Deployment, Service, Ingress, ConfigMap (frontend base URL), and optional HPA

## Local development
1) Install dependencies:
```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cd frontend && npm install
```
2) Build the frontend and export static assets:
```bash
cd frontend
npm run build
cd ..
```
`next build` (with `output: export`) writes static assets to `frontend/out`; copy or link to `./static` if running locally outside Docker.
3) Run the server:
```bash
python backend/app.py  # serves API + static on :8080
```
4) Smoke test:
```bash
curl http://localhost:8080/health
curl http://localhost:8080/api/reminders
```

## Container build
```bash
IMAGE_REPO=<your-registry>/habitify
IMAGE_TAG=latest
docker build -t ${IMAGE_REPO}:${IMAGE_TAG} .
docker push ${IMAGE_REPO}:${IMAGE_TAG}
```

### AWS ECR helper script
Use `scripts/build_and_push_ecr.sh` to build, create the ECR repo if needed, log in, push, and print the final image URI.
Prereqs: Docker, AWS CLI logged in with permissions for `ecr:*Repository` and `ecr:GetAuthorizationToken`.

```bash
# repo name required; tag defaults to "latest"
AWS_REGION=us-east-1 AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) \
  ./scripts/build_and_push_ecr.sh habitify latest
```
After success, the script echoes the pushed image (e.g., `123456789012.dkr.ecr.us-east-1.amazonaws.com/habitify:latest`) for Helm values.

## Helm chart (Kubernetes/EKS)
Chart path: `chart/habitify`. Defaults: `service.port=8080`, ingress fields under `.ingress`, ingress off by default, serviceAccount creation on.

Basic install:
```bash
helm install habitify ./chart/habitify \
  --set image.repository=${IMAGE_REPO} \
  --set image.tag=${IMAGE_TAG}
```

Enable AWS ALB ingress (internet-facing, target-type=ip):
```bash
ROOT_DOMAIN=<your-root-domain>
POC_ID=<id>
helm install habitify ./chart/habitify \
  --set image.repository=${IMAGE_REPO} \
  --set image.tag=${IMAGE_TAG} \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=${POC_ID}.poc.${ROOT_DOMAIN} \
  --set ingress.className=alb \
  --set ingress.annotations."alb\.ingress\.kubernetes\.io/scheme"=internet-facing \
  --set ingress.annotations."alb\.ingress\.kubernetes\.io/target-type"=ip
```
TLS is supported by populating `ingress.tls`.

Optional: set a different frontend API base (e.g., external ALB URL) via ConfigMap:
```bash
--set frontend.apiBaseUrl=https://api.example.com
```

Enable HPA:
```bash
--set autoscaling.enabled=true \
--set autoscaling.minReplicas=2 \
--set autoscaling.maxReplicas=5
```

## File map
- `backend/app.py` – Flask app + API + static serving
- `frontend/` – Next.js source (static export)
- `Dockerfile` – multi-stage build (Next.js → static, then Flask + gunicorn)
- `chart/habitify/` – Helm chart (Deployment, Service, Ingress, ConfigMap, HPA)
- `requirements.txt` – Python deps
