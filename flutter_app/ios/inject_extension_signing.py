#!/usr/bin/env python3
"""
inject_extension_signing.py

Injects PROVISIONING_PROFILE_SPECIFIER build settings into project.pbxproj
for iOS app extension targets (ScreenTimeExtension, ShieldConfigurationExtension,
ShieldActionExtension) without relying on BSD/GNU sed escaping quirks.
"""

import os
import sys

def find_pbxproj():
    candidates = [
        "ios/Runner.xcodeproj/project.pbxproj",
        "flutter_app/ios/Runner.xcodeproj/project.pbxproj",
        "Runner.xcodeproj/project.pbxproj",
        "../Runner.xcodeproj/project.pbxproj",
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None

def main():
    pbx_path = find_pbxproj()
    if not pbx_path:
        print("Error: project.pbxproj not found in expected locations!", file=sys.stderr)
        sys.exit(1)

    ext_profile = os.environ.get("IOS_EXT_PROFILE_NAME", "").strip()
    sc_profile = os.environ.get("IOS_SHIELD_CONFIG_PROFILE_NAME", "").strip()
    sa_profile = os.environ.get("IOS_SHIELD_ACTION_PROFILE_NAME", "").strip()

    with open(pbx_path, "r", encoding="utf-8") as f:
        content = f.read()

    replacements = [
        ("ai.socialstudying.app.ScreenTimeExtension", ext_profile, "ScreenTimeExtension"),
        ("ai.socialstudying.app.ShieldConfigurationExtension", sc_profile, "ShieldConfigurationExtension"),
        ("ai.socialstudying.app.ShieldActionExtension", sa_profile, "ShieldActionExtension"),
    ]

    modified = False
    for bundle_id, profile_name, target_name in replacements:
        if not profile_name:
            continue

        target_pattern = f'PRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";'
        if target_pattern not in content:
            print(f"Warning: pattern '{target_pattern}' not found in {pbx_path}", file=sys.stderr)
            continue

        replacement = (
            f'PRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";\n'
            f'\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{profile_name}";'
        )

        content = content.replace(target_pattern, replacement)
        modified = True
        print(f"Injected PROVISIONING_PROFILE_SPECIFIER = '{profile_name}' for {target_name} ({bundle_id})")

    if modified:
        with open(pbx_path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Updated {pbx_path} successfully.")
    else:
        print("No extension provisioning profiles injected.")

if __name__ == "__main__":
    main()
