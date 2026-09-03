$img = "acrssadevxumnzboir5vz2.azurecr.io/social-study-api:20260902-fix-503-v2"
$apps = @("ca-api-dev","ca-worker-dev","ca-topic-extractor-dev","ca-chunker-dev","ca-vectorizer-dev")
foreach ($app in $apps) {
    Write-Host "Updating $app ..."
    az containerapp update --name $app --resource-group rg-ssa2-dev --image $img --no-wait
}
Write-Host "All updates dispatched. Waiting 30s for revisions to activate..."
Start-Sleep -Seconds 30
az containerapp list -g rg-ssa2-dev --query "[].{name:name, image:properties.template.containers[0].image, status:properties.provisioningState}" --output table
