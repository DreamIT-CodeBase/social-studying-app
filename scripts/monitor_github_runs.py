import json
import subprocess
import sys
import urllib.request

def get_github_token() -> str:
    p = subprocess.run(
        ["git", "credential", "fill"],
        input=b"protocol=https\nhost=github.com\n",
        capture_output=True,
    )
    for line in p.stdout.decode().splitlines():
        if line.startswith("password="):
            return line.split("=", 1)[1]
    raise RuntimeError("Could not find GitHub token in git credential helper")

def api_get(url: str):
    token = get_github_token()
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "Antigravity",
        },
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode())

def inspect_run(run_id: int):
    run = api_get(f"https://api.github.com/repos/DreamIT-CodeBase/social-studying-app/actions/runs/{run_id}")
    jobs = api_get(f"https://api.github.com/repos/DreamIT-CodeBase/social-studying-app/actions/runs/{run_id}/jobs")
    print(f"=== RUN {run_id}: {run['name']} ({run['status']} - {run['conclusion']}) ===")
    for j in jobs.get("jobs", []):
        print(f"  Job: {j['name']} ({j['status']} - {j['conclusion']})")
        for s in j.get("steps", []):
            if s.get("conclusion") in ("failure", "cancelled"):
                print(f"    FAILED Step: {s['name']} (conclusion: {s['conclusion']})")
            elif s.get("status") == "in_progress":
                print(f"    RUNNING Step: {s['name']}")

def list_runs(per_page: int = 10):
    data = api_get(f"https://api.github.com/repos/DreamIT-CodeBase/social-studying-app/actions/runs?per_page={per_page}")
    runs = data.get("workflow_runs", [])
    print(f"{'ID':<14} | {'NAME':<35} | {'BRANCH':<20} | {'STATUS':<12} | {'CONCLUSION':<12} | {'CREATED_AT':<20}")
    print("-" * 125)
    for r in runs:
        print(f"{r['id']:<14} | {r['name']:<35} | {r['head_branch']:<20} | {r['status']:<12} | {str(r['conclusion']):<12} | {r['created_at']:<20}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1].isdigit() and len(sys.argv[1]) > 5:
        inspect_run(int(sys.argv[1]))
    else:
        per_page = int(sys.argv[1]) if len(sys.argv) > 1 else 10
        list_runs(per_page)
