# Deploy Study Session & UX Fixes to Azure Container Apps
$ErrorActionPreference = "Stop"

$img = "acrssadevxumnzboir5vz2.azurecr.io/social-study-api:20260919-algebra-dedup-v3"
$rg = "rg-ssa2-dev"
$apps = @("ca-api-dev", "ca-worker-dev", "ca-topic-extractor-dev", "ca-chunker-dev", "ca-vectorizer-dev")

Write-Host "================================================="
Write-Host "Deploying image: $img"
Write-Host "Resource Group: $rg"
Write-Host "================================================="

foreach ($app in $apps) {
    Write-Host "Updating Container App: $app ..."
    az containerapp update --name $app --resource-group $rg --image $img --no-wait
}

Write-Host "All update requests dispatched. Waiting 35s for revisions to activate..."
Start-Sleep -Seconds 35

Write-Host "Checking Container Apps Status..."
az containerapp list -g $rg --query "[].{name:name, image:properties.template.containers[0].image, status:properties.provisioningState, fqdn:properties.configuration.ingress.fqdn}" --output table

Write-Host "Verifying ca-api-dev Health Endpoint..."
$fqdn = (az containerapp show --resource-group $rg --name "ca-api-dev" --query properties.configuration.ingress.fqdn --output tsv).Trim()
if ($fqdn) {
    Write-Host "Calling https://${fqdn}/health ..."
    try {
        $resp = Invoke-RestMethod -Uri "https://${fqdn}/health" -Method Get -TimeoutSec 15
        Write-Host "Health Check Succeeded: $($resp | ConvertTo-Json -Compress)"
    } catch {
        Write-Warning "Initial health check probe error: $_"
        Write-Host "Retrying after 15s..."
        Start-Sleep -Seconds 15
        $resp = Invoke-RestMethod -Uri "https://${fqdn}/health" -Method Get -TimeoutSec 15
        Write-Host "Health Check Succeeded on retry: $($resp | ConvertTo-Json -Compress)"
    }
}
Write-Host "Backend deployment completed successfully!"
