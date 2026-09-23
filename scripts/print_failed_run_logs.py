import json
import re
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

class NoAuthOnRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new_req = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new_req and "github.com" not in newurl:
            if "Authorization" in new_req.headers:
                del new_req.headers["Authorization"]
        return new_req

opener = urllib.request.build_opener(NoAuthOnRedirect)

def print_job_errors(run_id: int):
    token = get_github_token()
    req = urllib.request.Request(
        f"https://api.github.com/repos/DreamIT-CodeBase/social-studying-app/actions/runs/{run_id}/jobs",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "Antigravity",
        },
    )
    with opener.open(req) as resp:
        jobs_data = json.loads(resp.read().decode())

    for j in jobs_data.get("jobs", []):
        if j.get("conclusion") == "failure":
            job_id = j["id"]
            job_name = j["name"]
            print(f"================ Log for failed job {job_name} ({job_id}) ================")
            log_req = urllib.request.Request(
                f"https://api.github.com/repos/DreamIT-CodeBase/social-studying-app/actions/jobs/{job_id}/logs",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/vnd.github+json",
                    "User-Agent": "Antigravity",
                },
            )
            try:
                with opener.open(log_req) as log_resp:
                    lines = log_resp.read().decode("utf-8", errors="replace").splitlines()
                    error_indices = []
                    for i, line in enumerate(lines):
                        if re.search(r"Error: |: error: |FAILURE:|BUILD FAILED|##\[error\]", line, re.IGNORECASE):
                            error_indices.append(i)

                    if error_indices:
                        for idx in error_indices[:10]:
                            start = max(0, idx - 2)
                            end = min(len(lines), idx + 5)
                            print(f"\n--- Around line {idx} ---")
                            for l in lines[start:end]:
                                print(l)
                    else:
                        for line in lines[-50:]:
                            print(line)
            except Exception as exc:
                print(f"Failed to fetch logs for job {job_id}: {exc}")

if __name__ == "__main__":
    run_id = int(sys.argv[1])
    print_job_errors(run_id)
