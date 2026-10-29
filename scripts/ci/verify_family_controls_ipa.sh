#!/usr/bin/env bash
# ==============================================================================
# verify_family_controls_ipa.sh
#
# Authoritative post-build CI verification script for iOS IPAs & archives.
# Verifies that any target using Apple Screen Time APIs (FamilyControls,
# DeviceActivity, ManagedSettings, ManagedSettingsUI) is correctly signed
# with the approved Family Controls distribution entitlement:
#
#   com.apple.developer.family-controls = true
#
# Prevents App Store Connect / TestFlight rejection under Apple Guideline 2.5.1.
# Runs on macOS GitHub Actions runners before TestFlight upload.
# ==============================================================================

set -euo pipefail

# ANSI color codes for clear CI log output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}==============================================================================${NC}"
echo -e "${CYAN}${BOLD}   Apple Family Controls Entitlement Verification for Signed iOS Build       ${NC}"
echo -e "${CYAN}${BOLD}==============================================================================${NC}"

OS_NAME="$(uname -s)"
if [[ "$OS_NAME" != "Darwin" ]]; then
  echo -e "${YELLOW}Warning: Full signature and CMS verification requires macOS code-signing tools.${NC}"
  echo -e "${YELLOW}Running on '$OS_NAME'. Static structure diagnostics will execute with Python fallback.${NC}"
fi

# Helper: Read key from plist using PlistBuddy -> plutil -> python3
read_plist_val() {
  local key="$1"
  local file="$2"
  local default="${3:-}"

  if [[ ! -f "$file" ]]; then
    echo "$default"
    return
  fi

  # Method 1: /usr/libexec/PlistBuddy (macOS standard)
  if [[ -x /usr/libexec/PlistBuddy ]]; then
    local val
    val=$(/usr/libexec/PlistBuddy -c "Print :$key" "$file" 2>/dev/null || true)
    if [[ -n "$val" ]]; then
      echo "$val"
      return
    fi
  fi

  # Method 2: plutil (macOS standard)
  if command -v plutil >/dev/null 2>&1; then
    local val
    val=$(plutil -extract "$key" raw -o - "$file" 2>/dev/null || true)
    if [[ -n "$val" ]]; then
      echo "$val"
      return
    fi
  fi

  # Method 3: python3 / py (cross-platform fallback)
  local py_cmd=""
  if command -v python3 >/dev/null 2>&1; then
    py_cmd="python3"
  elif command -v py >/dev/null 2>&1; then
    py_cmd="py"
  elif command -v python >/dev/null 2>&1; then
    py_cmd="python"
  fi

  if [[ -n "$py_cmd" ]]; then
    local val
    val=$($py_cmd -c "
import plistlib, sys
try:
    with open('''$file''', 'rb') as f:
        pl = plistlib.load(f)
    keys = '$key'.split(':')
    cur = pl
    for k in keys:
        if not k: continue
        if isinstance(cur, dict):
            cur = cur.get(k)
        elif isinstance(cur, list) and k.isdigit():
            cur = cur[int(k)]
        else:
            cur = None
            break
    if cur is not None:
        if isinstance(cur, bool):
            print('true' if cur else 'false')
        else:
            print(cur)
except Exception:
    pass
" 2>/dev/null || true)
    if [[ -n "$val" ]]; then
      echo "$val"
      return
    fi
  fi

  echo "$default"
}

# 1. Discover target IPA or xcarchive
TARGET_PATH="${1:-${IPA_PATH:-}}"

if [[ -z "$TARGET_PATH" || "$TARGET_PATH" == *"*"* || ! -e "$TARGET_PATH" ]]; then
  echo -e "${BLUE}Searching for built IPA or xcarchive artifacts...${NC}"
  SEARCH_CANDIDATES=(
    "build/ios/ipa/*.ipa"
    "flutter_app/build/ios/ipa/*.ipa"
    "../build/ios/ipa/*.ipa"
    "../flutter_app/build/ios/ipa/*.ipa"
    "build/ios/archive/*.xcarchive"
    "flutter_app/build/ios/archive/*.xcarchive"
    "../build/ios/archive/*.xcarchive"
    "../flutter_app/build/ios/archive/*.xcarchive"
  )

  for pattern in "${SEARCH_CANDIDATES[@]}"; do
    # shellcheck disable=SC2086
    found=$(ls -1 $pattern 2>/dev/null | head -n 1 || true)
    if [[ -n "$found" && -e "$found" ]]; then
      TARGET_PATH="$found"
      break
    fi
  done
fi

if [[ -z "$TARGET_PATH" || ! -e "$TARGET_PATH" ]]; then
  echo -e "${RED}${BOLD}[ERROR] No IPA or xcarchive found to verify!${NC}" >&2
  echo -e "Provide the path as an argument: ${BOLD}./verify_family_controls_ipa.sh path/to/app.ipa${NC}" >&2
  echo -e "Or set the ${BOLD}IPA_PATH${NC} environment variable." >&2
  exit 1
fi

echo -e "Target build artifact: ${BOLD}${TARGET_PATH}${NC}"

# 2. Setup safe temporary working directory with automatic trap cleanup
TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'verify_fc_ipa')
cleanup() {
  local exit_code=$?
  if [[ -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

# 3. Locate .app bundle (extract IPA if needed)
APP_BUNDLE=""
if [[ "$TARGET_PATH" == *.ipa ]]; then
  echo -e "${BLUE}Extracting IPA safely into temporary directory...${NC}"
  unzip -q "$TARGET_PATH" -d "$TMP_DIR/extracted"
  PAYLOAD_DIR="$TMP_DIR/extracted/Payload"
  if [[ ! -d "$PAYLOAD_DIR" ]]; then
    echo -e "${RED}[ERROR] Invalid IPA archive: missing 'Payload/' directory!${NC}" >&2
    exit 1
  fi
  APP_BUNDLE=$(find "$PAYLOAD_DIR" -maxdepth 1 -name "*.app" -print -quit)
elif [[ "$TARGET_PATH" == *.xcarchive ]]; then
  echo -e "${BLUE}Inspecting xcarchive Products/Applications...${NC}"
  APP_BUNDLE=$(find "$TARGET_PATH/Products/Applications" -maxdepth 1 -name "*.app" -print -quit)
elif [[ -d "$TARGET_PATH" && "$TARGET_PATH" == *.app ]]; then
  APP_BUNDLE="$TARGET_PATH"
else
  echo -e "${RED}[ERROR] Unrecognized artifact format: $TARGET_PATH${NC}" >&2
  exit 1
fi

if [[ -z "$APP_BUNDLE" || ! -d "$APP_BUNDLE" ]]; then
  echo -e "${RED}[ERROR] Could not find .app bundle in target artifact!${NC}" >&2
  exit 1
fi

echo -e "Located application bundle: ${BOLD}${APP_BUNDLE}${NC}"

# 4. Discover all targets: Main app + any embedded app extensions (.appex)
declare -a ALL_TARGETS=()
ALL_TARGETS+=("$APP_BUNDLE")

if [[ -d "$APP_BUNDLE/PlugIns" ]]; then
  while IFS= read -r appex; do
    if [[ -d "$appex" ]]; then
      ALL_TARGETS+=("$appex")
    fi
  done < <(find "$APP_BUNDLE/PlugIns" -maxdepth 1 -name "*.appex")
fi

echo -e "Discovered ${BOLD}${#ALL_TARGETS[@]}${NC} target bundle(s) inside build:"
for t in "${ALL_TARGETS[@]}"; do
  echo "  - $(basename "$t")"
done
echo ""

# Tracking overall verification state
TOTAL_VERIFIED=0
FAILED_TARGETS=()
declare -a FAILURE_DETAILS=()
declare -a REMEDIATION_STEPS=()

# 5. Diagnostic examination for each target
for bundle in "${ALL_TARGETS[@]}"; do
  TARGET_NAME=$(basename "$bundle")
  INFO_PLIST="$bundle/Info.plist"
  TOTAL_VERIFIED=$((TOTAL_VERIFIED + 1))

  echo -e "${CYAN}------------------------------------------------------------------------------${NC}"
  echo -e "${CYAN}Target [${TOTAL_VERIFIED}/${#ALL_TARGETS[@]}]: ${BOLD}${TARGET_NAME}${NC}"
  echo -e "${CYAN}------------------------------------------------------------------------------${NC}"

  if [[ ! -f "$INFO_PLIST" ]]; then
    echo -e "${RED}[ERROR] Missing Info.plist in $bundle!${NC}" >&2
    FAILED_TARGETS+=("$TARGET_NAME")
    FAILURE_DETAILS+=("Target '$TARGET_NAME' is missing Info.plist.")
    continue
  fi

  # Target metadata from Info.plist
  BUNDLE_ID=$(read_plist_val "CFBundleIdentifier" "$INFO_PLIST" "UNKNOWN")
  BUNDLE_VERSION=$(read_plist_val "CFBundleShortVersionString" "$INFO_PLIST" "UNKNOWN")
  BUNDLE_BUILD=$(read_plist_val "CFBundleVersion" "$INFO_PLIST" "UNKNOWN")
  EXECUTABLE_NAME=$(read_plist_val "CFBundleExecutable" "$INFO_PLIST" "")
  EXTENSION_POINT=$(read_plist_val "NSExtension:NSExtensionPointIdentifier" "$INFO_PLIST" "none")

  echo "  Bundle Identifier:  ${BUNDLE_ID}"
  echo "  Marketing Version:  ${BUNDLE_VERSION}"
  echo "  Build Number:       ${BUNDLE_BUILD}"
  echo "  Executable:         ${EXECUTABLE_NAME}"
  if [[ "$EXTENSION_POINT" != "none" ]]; then
    echo "  Extension Point:    ${EXTENSION_POINT}"
  fi

  # Determine if target uses Apple Screen Time APIs
  USES_SCREEN_TIME=false
  SCREEN_TIME_REASONS=()

  # Check 1: Extension point identifier
  case "$EXTENSION_POINT" in
    com.apple.deviceactivity.monitor-extension)
      USES_SCREEN_TIME=true
      SCREEN_TIME_REASONS+=("NSExtensionPointIdentifier=com.apple.deviceactivity.monitor-extension (DeviceActivityMonitor)")
      ;;
    com.apple.ManagedSettingsUI.shield-configuration-service)
      USES_SCREEN_TIME=true
      SCREEN_TIME_REASONS+=("NSExtensionPointIdentifier=com.apple.ManagedSettingsUI.shield-configuration-service (ShieldConfiguration)")
      ;;
    com.apple.ManagedSettings.shield-action-service)
      USES_SCREEN_TIME=true
      SCREEN_TIME_REASONS+=("NSExtensionPointIdentifier=com.apple.ManagedSettings.shield-action-service (ShieldAction)")
      ;;
    com.apple.deviceactivity.report-extension)
      USES_SCREEN_TIME=true
      SCREEN_TIME_REASONS+=("NSExtensionPointIdentifier=com.apple.deviceactivity.report-extension (DeviceActivityReport)")
      ;;
  esac

  # Check 2: Binary linkages and symbols
  TARGET_EXEC="$bundle/$EXECUTABLE_NAME"
  if [[ -f "$TARGET_EXEC" && "$OS_NAME" == "Darwin" ]]; then
    LINKED_FRAMEWORKS=$(otool -L "$TARGET_EXEC" 2>/dev/null || true)
    if echo "$LINKED_FRAMEWORKS" | grep -qE "FamilyControls|DeviceActivity|ManagedSettings"; then
      USES_SCREEN_TIME=true
      matched_fws=$(echo "$LINKED_FRAMEWORKS" | grep -oE "(FamilyControls|DeviceActivity|ManagedSettings)[^ ]*" | sort -u | tr '\n' ' ')
      SCREEN_TIME_REASONS+=("Linked frameworks: $matched_fws")
    fi

    # Check for Screen Time symbol strings if framework is dynamically loaded
    EXEC_STRINGS=$(strings "$TARGET_EXEC" 2>/dev/null || true)
    if echo "$EXEC_STRINGS" | grep -qE "AuthorizationCenter|DeviceActivityMonitor|ManagedSettingsStore"; then
      if [[ "$USES_SCREEN_TIME" == false ]]; then
        USES_SCREEN_TIME=true
        SCREEN_TIME_REASONS+=("Contains Screen Time API symbols (AuthorizationCenter/DeviceActivityMonitor/ManagedSettingsStore)")
      fi
    fi
  fi

  if [[ "$USES_SCREEN_TIME" == true ]]; then
    echo -e "  Screen Time APIs:   ${YELLOW}${BOLD}YES${NC} (${SCREEN_TIME_REASONS[*]})"
    echo -e "  Family Controls:    ${YELLOW}${BOLD}REQUIRED (com.apple.developer.family-controls = true)${NC}"
  else
    echo -e "  Screen Time APIs:   ${GREEN}NO (Target does not use Screen Time APIs)${NC}"
    echo -e "  Family Controls:    NOT REQUIRED"
  fi

  # Extract signed entitlements from Mach-O code signature using codesign
  SIGNED_FC="missing"
  SIGNED_APP_ID="missing"
  SIGNED_TEAM_ID="missing"
  SIGNED_APS="missing"
  SIGNED_TASK_ALLOW="missing"
  SIGNED_APP_GROUPS="missing"
  CODESIGN_OK=false

  if [[ "$OS_NAME" == "Darwin" ]]; then
    ENTITLEMENTS_PLIST="$TMP_DIR/${TARGET_NAME}_signed_entitlements.plist"
    # Extract embedded signature entitlements in raw XML format
    if codesign -d --entitlements :- "$bundle" > "$ENTITLEMENTS_PLIST" 2>/dev/null; then
      if [[ -s "$ENTITLEMENTS_PLIST" ]]; then
        # Ensure it's valid XML plist
        plutil -convert xml1 "$ENTITLEMENTS_PLIST" 2>/dev/null || true
        CODESIGN_OK=true
        SIGNED_FC=$(read_plist_val "com.apple.developer.family-controls" "$ENTITLEMENTS_PLIST" "missing")
        SIGNED_APP_ID=$(read_plist_val "application-identifier" "$ENTITLEMENTS_PLIST" "missing")
        SIGNED_TEAM_ID=$(read_plist_val "com.apple.developer.team-identifier" "$ENTITLEMENTS_PLIST" "missing")
        SIGNED_APS=$(read_plist_val "aps-environment" "$ENTITLEMENTS_PLIST" "missing")
        SIGNED_TASK_ALLOW=$(read_plist_val "get-task-allow" "$ENTITLEMENTS_PLIST" "missing")
        SIGNED_APP_GROUPS=$(read_plist_val "com.apple.security.application-groups:0" "$ENTITLEMENTS_PLIST" "missing")
      fi
    fi
  fi

  # Decode embedded provisioning profile if available
  EMBEDDED_PROFILE="$bundle/embedded.mobileprovision"
  HAS_EMBEDDED_PROFILE=false
  PROFILE_NAME="none"
  PROFILE_UUID="none"
  PROFILE_APP_ID="none"
  PROFILE_FC="missing"
  PROFILE_TASK_ALLOW="missing"
  PROFILE_EXPIRATION="unknown"

  if [[ -f "$EMBEDDED_PROFILE" && "$OS_NAME" == "Darwin" ]]; then
    HAS_EMBEDDED_PROFILE=true
    PROFILE_PLIST="$TMP_DIR/${TARGET_NAME}_decoded_profile.plist"
    if security cms -D -i "$EMBEDDED_PROFILE" > "$PROFILE_PLIST" 2>/dev/null; then
      PROFILE_NAME=$(read_plist_val "Name" "$PROFILE_PLIST" "unknown")
      PROFILE_UUID=$(read_plist_val "UUID" "$PROFILE_PLIST" "unknown")
      PROFILE_APP_ID=$(read_plist_val "Entitlements:application-identifier" "$PROFILE_PLIST" "unknown")
      PROFILE_FC=$(read_plist_val "Entitlements:com.apple.developer.family-controls" "$PROFILE_PLIST" "missing")
      PROFILE_TASK_ALLOW=$(read_plist_val "Entitlements:get-task-allow" "$PROFILE_PLIST" "missing")
      PROFILE_EXPIRATION=$(read_plist_val "ExpirationDate" "$PROFILE_PLIST" "unknown")
    fi
  fi

  # Print diagnostic findings for this target
  echo "  --- Code-Signing & Entitlement Diagnostics ---"
  if [[ "$CODESIGN_OK" == true ]]; then
    if [[ "$SIGNED_FC" == "true" ]]; then
      echo -e "  Signed com.apple.developer.family-controls: ${GREEN}${BOLD}true (VERIFIED)${NC}"
    elif [[ "$SIGNED_FC" == "missing" ]]; then
      echo -e "  Signed com.apple.developer.family-controls: ${RED}${BOLD}MISSING${NC}"
    else
      echo -e "  Signed com.apple.developer.family-controls: ${RED}${BOLD}${SIGNED_FC}${NC}"
    fi
    echo "  Signed application-identifier:               ${SIGNED_APP_ID}"
    echo "  Signed aps-environment:                      ${SIGNED_APS}"
    echo "  Signed get-task-allow (debug flag):          ${SIGNED_TASK_ALLOW}"
    echo "  Signed App Group:                            ${SIGNED_APP_GROUPS}"
  else
    if [[ "$OS_NAME" == "Darwin" ]]; then
      echo -e "  ${YELLOW}Warning: codesign could not extract signed entitlements from Mach-O header.${NC}"
    else
      echo -e "  ${YELLOW}Skipping codesign Mach-O inspection (requires Darwin runner).${NC}"
    fi
  fi

  echo "  --- Embedded Provisioning Profile Diagnostics ---"
  if [[ "$HAS_EMBEDDED_PROFILE" == true ]]; then
    echo "  Profile Name:       ${PROFILE_NAME}"
    echo "  Profile UUID:       ${PROFILE_UUID}"
    echo "  Profile App ID:     ${PROFILE_APP_ID}"
    if [[ "$PROFILE_FC" == "true" ]]; then
      echo -e "  Profile Authorized Family Controls: ${GREEN}${BOLD}true (AUTHORIZED)${NC}"
    elif [[ "$PROFILE_FC" == "missing" ]]; then
      echo -e "  Profile Authorized Family Controls: ${RED}${BOLD}MISSING FROM PROFILE${NC}"
    else
      echo -e "  Profile Authorized Family Controls: ${RED}${BOLD}${PROFILE_FC}${NC}"
    fi
    echo "  Profile get-task-allow (Development flag): ${PROFILE_TASK_ALLOW}"
    echo "  Profile Expiration: ${PROFILE_EXPIRATION}"
  else
    echo -e "  ${YELLOW}Note: No embedded.mobileprovision present directly in this bundle.${NC}"
    echo "  (App Store distribution export may strip embedded profile or manage via archive)."
  fi

  # Evaluation against Apple rejection criteria
  TARGET_IS_DEFECTIVE=false

  if [[ "$USES_SCREEN_TIME" == true ]]; then
    # Defect 1: Signed entitlement missing or not true (macOS authoritative check)
    if [[ "$CODESIGN_OK" == true && "$SIGNED_FC" != "true" ]]; then
      TARGET_IS_DEFECTIVE=true
      FAILURE_DETAILS+=("Target '${TARGET_NAME}' (${BUNDLE_ID}) uses Screen Time APIs, but its signed code signature does NOT contain 'com.apple.developer.family-controls = true'. Current value: '${SIGNED_FC}'.")
      REMEDIATION_STEPS+=("Ensure target '${TARGET_NAME}' is configured with CODE_SIGN_ENTITLEMENTS containing <key>com.apple.developer.family-controls</key><true/>, and ensure the target is signed with an approved distribution provisioning profile authorizing Family Controls.")
    fi

    # Defect 2: Embedded profile explicitly lacks Family Controls authorization
    if [[ "$HAS_EMBEDDED_PROFILE" == true && "$PROFILE_FC" != "true" ]]; then
      TARGET_IS_DEFECTIVE=true
      FAILURE_DETAILS+=("Target '${TARGET_NAME}' (${BUNDLE_ID}) has an embedded provisioning profile '${PROFILE_NAME}' that does NOT authorize 'com.apple.developer.family-controls'. Apple will reject any build signed with this profile under Guideline 2.5.1.")
      REMEDIATION_STEPS+=("Regenerate the distribution provisioning profile for bundle ID '${BUNDLE_ID}' in the Apple Developer Portal after verifying that 'Family Controls (Distribution)' is Assigned and checked under Additional Capabilities. Then update the corresponding GitHub Actions secret.")
    fi

    # Defect 3: Signed with development get-task-allow=true instead of distribution
    if [[ "$SIGNED_TASK_ALLOW" == "true" || "$PROFILE_TASK_ALLOW" == "true" ]]; then
      TARGET_IS_DEFECTIVE=true
      FAILURE_DETAILS+=("Target '${TARGET_NAME}' (${BUNDLE_ID}) was signed with 'get-task-allow = true' (Development configuration). App Store Connect submissions require App Store distribution signing ('get-task-allow = false').")
      REMEDIATION_STEPS+=("Sign target '${TARGET_NAME}' with an App Store Distribution provisioning profile, not a Development profile.")
    fi
  else
    # Target does not use Screen Time: ensure it does not accidentally have unapproved entitlements
    if [[ "$CODESIGN_OK" == true && "$SIGNED_FC" == "true" ]]; then
      echo -e "  ${YELLOW}Warning: Target does not appear to use Screen Time APIs but has Family Controls entitlement.${NC}"
    fi
  fi

  if [[ "$TARGET_IS_DEFECTIVE" == true ]]; then
    echo -e "\n  Target Status: ${RED}${BOLD}[FAIL - REJECTION DEFECT CONFIRMED]${NC}"
    FAILED_TARGETS+=("$TARGET_NAME")
  else
    echo -e "\n  Target Status: ${GREEN}${BOLD}[PASS - FAMILY CONTROLS VALID]${NC}"
  fi
  echo ""
done

# 6. Overall Verification Summary Report
echo -e "${CYAN}${BOLD}==============================================================================${NC}"
echo -e "${CYAN}${BOLD}                       VERIFICATION SUMMARY REPORT                            ${NC}"
echo -e "${CYAN}${BOLD}==============================================================================${NC}"
echo -e "Total targets inspected: ${BOLD}${#ALL_TARGETS[@]}${NC}"
echo -e "Defective targets:       ${BOLD}${#FAILED_TARGETS[@]}${NC}"

if [[ ${#FAILED_TARGETS[@]} -gt 0 ]]; then
  echo -e "\n${RED}${BOLD}==============================================================================${NC}"
  echo -e "${RED}${BOLD}   [BUILD VERIFICATION FAILED] - TESTFLIGHT SUBMISSION BLOCKED               ${NC}"
  echo -e "${RED}${BOLD}==============================================================================${NC}"
  echo -e "The following target(s) failed Apple Family Controls signing verification:\n"
  for f in "${FAILED_TARGETS[@]}"; do
    echo -e "  ${RED}${BOLD}* ${f}${NC}"
  done

  echo -e "\n${BOLD}Failure Details:${NC}"
  for d in "${FAILURE_DETAILS[@]}"; do
    echo -e "  - ${RED}${d}${NC}"
  done

  echo -e "\n${YELLOW}${BOLD}Required Remediation Actions:${NC}"
  for r in "${REMEDIATION_STEPS[@]}"; do
    echo -e "  ${YELLOW}-> ${r}${NC}"
  done
  echo ""
  exit 1
else
  echo -e "\n${GREEN}${BOLD}==============================================================================${NC}"
  echo -e "${GREEN}${BOLD}   [BUILD VERIFICATION PASSED] - FAMILY CONTROLS SIGNING IS VALID            ${NC}"
  echo -e "${GREEN}${BOLD}==============================================================================${NC}"
  echo -e "${GREEN}All Screen Time API targets are correctly signed with the approved Family Controls${NC}"
  echo -e "${GREEN}entitlement and authorized provisioning profiles. Safe to upload to TestFlight.${NC}\n"
  exit 0
fi
