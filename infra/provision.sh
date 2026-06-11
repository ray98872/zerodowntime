#!/usr/bin/env bash
# ============================================================
# Provision Azure Container Apps for Blue-Green deployments
# Free-tier friendly: Consumption plan, scale-to-zero,
# no Log Analytics ingestion (logs-destination: azure-monitor).
# ============================================================
set -euo pipefail

RG="portfolio-bluegreen-rg"
LOCATION="uksouth"
ENV_NAME="portfolio-bluegreen-env"
APP_NAME="copilot-api"
# Placeholder image so the app exists before the first pipeline run.
BOOTSTRAP_IMAGE="mcr.microsoft.com/k8se/quickstart:latest"

echo "==> Using subscription:"
az account show --query "{name:name, id:id}" -o table

echo "==> [1/4] Creating resource group $RG in $LOCATION..."
az group create --name "$RG" --location "$LOCATION" -o none

echo "==> [2/4] Creating Container Apps environment (Consumption, no Log Analytics ingestion)..."
az containerapp env create \
  --name "$ENV_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --logs-destination azure-monitor \
  -o none

echo "==> [3/4] Creating container app '$APP_NAME' (revision mode: MULTIPLE)..."
az containerapp create \
  --name "$APP_NAME" \
  --resource-group "$RG" \
  --environment "$ENV_NAME" \
  --image "$BOOTSTRAP_IMAGE" \
  --ingress external \
  --target-port 80 \
  --revisions-mode multiple \
  --revision-suffix bootstrap \
  --min-replicas 0 \
  --max-replicas 1 \
  --cpu 0.25 \
  --memory 0.5Gi \
  -o none

echo "==> [4/4] Creating service principal for GitHub Actions (scoped to $RG only)..."
SUB_ID=$(az account show --query id -o tsv)
az ad sp create-for-rbac \
  --name "portfolio-bluegreen-github" \
  --role contributor \
  --scopes "/subscriptions/$SUB_ID/resourceGroups/$RG" \
  --json-auth > azure-credentials.json

FQDN=$(az containerapp show -n "$APP_NAME" -g "$RG" --query properties.configuration.ingress.fqdn -o tsv)

echo ""
echo "============================================================"
echo " DONE. App URL:        https://$FQDN"
echo " GitHub secret:        paste azure-credentials.json contents"
echo "                       as repo secret AZURE_CREDENTIALS"
echo " (azure-credentials.json is gitignored - never commit it)"
echo "============================================================"
