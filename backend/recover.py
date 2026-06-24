import json

transcript_path = r"C:\Users\tarun\.gemini\antigravity-ide\brain\a61097ea-14c0-403d-8b8f-69c7a16627e7\.system_generated\logs\transcript.jsonl"
target_file = r"c:\Users\tarun\Downloads\Social-study-app\social-studying-app\backend\app\api\workspaces.py"

content = None
with open(transcript_path, "r", encoding="utf-8") as f:
    for line in f:
        try:
            data = json.loads(line)
            if data.get("type") == "TOOL_CALL" and "replace_file_content" in json.dumps(data):
                # We need the full file content. `replace_file_content` doesn't log full content.
                pass
            if data.get("type") == "TOOL_RESPONSE":
                # Check view_file output
                out = str(data.get("content", ""))
                if "File Path: `file:///c:/Users/tarun/Downloads/Social-study-app/social-studying-app/backend/app/api/workspaces.py`" in out:
                    if "Total Lines: 362" in out or "Total Lines: 355" in out:
                        content = out
        except Exception as e:
            pass

if content:
    with open("recovered_workspaces.txt", "w", encoding="utf-8") as f:
        f.write(content)
    print("Recovered to recovered_workspaces.txt!")
else:
    print("Could not find full file content in logs.")
