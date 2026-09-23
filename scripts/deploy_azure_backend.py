import subprocess
import sys

image = "acrssadevxumnzboir5vz2.azurecr.io/social-study-api:4ddb150"
rg = "rg-ssa2-dev"
apps = ["ca-api-dev", "ca-worker-dev", "ca-topic-extractor-dev", "ca-chunker-dev", "ca-vectorizer-dev"]

for app in apps:
    print(f"Updating {app}...")
    cmd = ["az", "containerapp", "update", "--resource-group", rg, "--name", app, "--image", image, "--output", "none"]
    res = subprocess.run(cmd, capture_output=True, text=True, shell=True)
    if res.returncode != 0:
        print(f"Error updating {app}: {res.stderr}")
    else:
        print(f"Successfully updated {app}")

# Verify API health
print("Verifying ca-api-dev health...")
cmd = ["az", "containerapp", "show", "--resource-group", rg, "--name", "ca-api-dev", "--query", "properties.configuration.ingress.fqdn", "-o", "tsv"]
res = subprocess.run(cmd, capture_output=True, text=True, shell=True)
fqdn = res.stdout.strip()
print(f"API FQDN: {fqdn}")

import urllib.request
url = f"https://{fqdn}/health"
req = urllib.request.Request(url, headers={"User-Agent": "Antigravity"})
try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        print(f"Health response: {resp.status} {resp.read().decode()}")
except Exception as e:
    print(f"Health check warning: {e}")
