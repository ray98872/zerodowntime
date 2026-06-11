# ============================================================
# Provision Azure Container Apps for Blue-Green deployments
# Free-tier friendly: Consumption plan, scale-to-zero,
# no Log Analytics ingestion (logs-destination: azure-monitor).
#
# Run from the repo root in a terminal where `az login` is done:
#   powershell -ExecutionPolicy Bypass -File infra\provision.ps1
# ============================================================
$ErrorActionPreference = "Stop"

$RG = "portfolio-bluegreen-rg"
$LOCATION = "uksouth"
$ENV_NAME = "portfolio-bluegreen-env"
$APP_NAME = "copilot-api"
$BOOTSTRAP_IMAGE = "mcr.microsoft.com/k8se/quickstart:latest"

Write-Host "==> Using subscription:"
az account show --query "{name:name, id:id}" -o table

Write-Host "==> [1/4] Creating resource group $RG in $LOCATION..."
az group create --name $RG --location $LOCATION -o none

Write-Host "==> [2/4] Creating Container Apps environment (Consumption, no Log Analytics ingestion)..."
az containerapp env create `
  --name $ENV_NAME `
  --resource-group $RG `
  --location $LOCATION `
  --logs-destination azure-monitor `
  -o none

Write-Host "==> [3/4] Creating container app '$APP_NAME' (revision mode: MULTIPLE)..."
az containerapp create `
  --name $APP_NAME `
  --resource-group $RG `
  --environment $ENV_NAME `
  --image $BOOTSTRAP_IMAGE `
  --ingress external `
  --target-port 80 `
  --revisions-mode multiple `
  --revision-suffix bootstrap `
  --min-replicas 0 `
  --max-replicas 1 `
  --cpu 0.25 `
  --memory 0.5Gi `
  -o none

Write-Host "==> [4/4] Creating service principal for GitHub Actions (scoped to $RG only)..."
$SUB_ID = az account show --query id -o tsv
az ad sp create-for-rbac `
  --name "portfolio-bluegreen-github" `
  --role contributor `
  --scopes "/subscriptions/$SUB_ID/resourceGroups/$RG" `
  --json-auth | Out-File -Encoding utf8 "$PSScriptRoot\azure-credentials.json"

$FQDN = az containerapp show -n $APP_NAME -g $RG --query properties.configuration.ingress.fqdn -o tsv

# Machine-readable output so the assistant can pick up where this left off
@{ fqdn = $FQDN; resourceGroup = $RG; app = $APP_NAME; environment = $ENV_NAME; provisionedUtc = (Get-Date).ToUniversalTime().ToString("o") } |
  ConvertTo-Json | Out-File -Encoding utf8 "$PSScriptRoot\provision-output.json"

Write-Host ""
Write-Host "============================================================"
Write-Host " DONE. App URL:   https://$FQDN"
Write-Host " GitHub secret:   paste infra\azure-credentials.json contents"
Write-Host "                  as repo secret AZURE_CREDENTIALS"
Write-Host " (azure-credentials.json is gitignored - never commit it)"
Write-Host "============================================================"
