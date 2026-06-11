# Zero-Downtime Blue-Green Deployment — GenAI Copilot RAG Index

Updating a live GenAI Copilot's RAG index on **Azure Container Apps** without dropping a single request. New code is deployed as an inactive **Green** revision, health-verified on its private revision URL, then traffic is switched atomically at the ingress layer — the old **Blue** revision drains gracefully and is deactivated.

**[▶ Interactive demo](https://ray98872.github.io/zerodowntime/)** · C# / .NET 8 · Docker · GitHub Actions · GHCR · Azure Container Apps (uksouth)

## Architecture

```
git push ─→ GitHub Actions ─→ build image ─→ ghcr.io
                  │
                  ├─ deploy Green revision (0% traffic)
                  ├─ GET https://<green-revision-fqdn>/health  → must be 200
                  ├─ ingress traffic set: Green = 100%
                  └─ deactivate Blue revision
```

## Repository layout

| Path | Purpose |
|---|---|
| `backend/` | Minimal C# Web API (`/query`, `/health`) + Dockerfile |
| `infra/provision.sh` | One-shot Azure provisioning (free-tier Consumption plan) |
| `.github/workflows/deploy.yml` | Blue-green CI/CD pipeline |
| `frontend/` | Self-contained animated dashboard for GitHub Pages |

## Setup

1. `bash infra/provision.sh` (requires `az login`) — creates `portfolio-bluegreen-rg`, a Consumption Container Apps environment with **no Log Analytics ingestion**, and the `copilot-api` app in **multiple revision mode**.
2. Add the generated `azure-credentials.json` contents as repo secret **`AZURE_CREDENTIALS`** (never commit the file).
3. Make the GHCR package public after the first pipeline run (repo → Packages → `copilot-api` → settings → change visibility), or attach registry credentials to the app — Azure must be able to pull the image.
4. Push to `main` (or run the workflow manually) — each run alternates `RAG_INDEX_VERSION` V1 ↔ V2.
5. Set `API_URL` in `frontend/index.html` to the app's FQDN so the demo page queries the real backend.

## Cost

Consumption plan with `min-replicas 0` (scale-to-zero) stays inside the ACA free grant (180k vCPU-s + 360k GiB-s + 2M requests/month). Logs go to the `azure-monitor` destination with no diagnostic settings attached, so there is no Log Analytics ingestion charge. GHCR is free for public repos.

## Zero-downtime guarantee

Traffic weights are changed only after the Green revision returns `200` on `/health` from its revision-specific FQDN. The cutover is a control-plane operation — existing connections to Blue complete normally while new requests route to Green. Rollback is a single `az containerapp ingress traffic set` back to Blue.
