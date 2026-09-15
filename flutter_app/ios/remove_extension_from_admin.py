import os

pbx_path = "ios/Runner.xcodeproj/project.pbxproj"
if not os.path.exists(pbx_path) and os.path.exists("Runner.xcodeproj/project.pbxproj"):
    pbx_path = "Runner.xcodeproj/project.pbxproj"

if os.path.exists(pbx_path):
    with open(pbx_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Remove the Embed App Extensions build phase from Runner target
    target1 = "\t\t\t\tSTX50000000000000000001 /* Embed App Extensions */,\n"
    # Remove the ScreenTimeExtension, ShieldConfigurationExtension, and ShieldActionExtension target dependencies
    dep_targets = [
        "\t\t\t\tSTXD0000000000000000001 /* PBXTargetDependency */,\n",
        "\t\t\t\tSCXD0000000000000000001 /* PBXTargetDependency */,\n",
        "\t\t\t\tSAXD0000000000000000001 /* PBXTargetDependency */,\n",
    ]
    
    # Also handle CRLF if on Windows
    content = content.replace(target1, "").replace(target1.replace("\n", "\r\n"), "")
    for dep in dep_targets:
        content = content.replace(dep, "").replace(dep.replace("\n", "\r\n"), "")
    
    with open(pbx_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Cleanly removed ScreenTime, ShieldConfiguration, and ShieldAction extensions from Runner target for admin build.")
else:
    print(f"File not found: {pbx_path}")
