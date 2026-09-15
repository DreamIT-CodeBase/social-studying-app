import os

pbx_path = "flutter_app/ios/Runner.xcodeproj/project.pbxproj"
if not os.path.exists(pbx_path):
    pbx_path = "ios/Runner.xcodeproj/project.pbxproj"

with open(pbx_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

content = "".join(lines)

# Check if already added
if "SCX60000000000000000001" in content:
    print("Shield extensions already present in project.pbxproj.")
    exit(0)

# 1. PBXBuildFile
build_files_to_add = """\
\t\tSCX10000000000000000001 /* ShieldConfigurationExtension.swift in Sources */ = {isa = PBXBuildFile; fileRef = SCX20000000000000000001 /* ShieldConfigurationExtension.swift */; };
\t\tSCX10000000000000000002 /* ShieldConfigurationExtension.appex in Embed App Extensions */ = {isa = PBXBuildFile; fileRef = SCX30000000000000000001 /* ShieldConfigurationExtension.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
\t\tSAX10000000000000000001 /* ShieldActionExtensionHandler.swift in Sources */ = {isa = PBXBuildFile; fileRef = SAX20000000000000000001 /* ShieldActionExtensionHandler.swift */; };
\t\tSAX10000000000000000002 /* ShieldActionExtension.appex in Embed App Extensions */ = {isa = PBXBuildFile; fileRef = SAX30000000000000000001 /* ShieldActionExtension.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
"""
content = content.replace(
    "/* End PBXBuildFile section */",
    build_files_to_add + "/* End PBXBuildFile section */"
)

# 2. PBXContainerItemProxy
container_proxies_to_add = """\
\t\tSCXC0000000000000000001 /* PBXContainerItemProxy */ = {
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = 97C146E61CF9000F007C117D /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = SCX60000000000000000001;
\t\t\tremoteInfo = ShieldConfigurationExtension;
\t\t};
\t\tSAXC0000000000000000001 /* PBXContainerItemProxy */ = {
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = 97C146E61CF9000F007C117D /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = SAX60000000000000000001;
\t\t\tremoteInfo = ShieldActionExtension;
\t\t};
"""
content = content.replace(
    "/* End PBXContainerItemProxy section */",
    container_proxies_to_add + "/* End PBXContainerItemProxy section */"
)

# 3. Embed App Extensions in PBXCopyFilesBuildPhase
embed_files_replacement = """\
\t\t\t\tSTX10000000000000000002 /* ScreenTimeExtension.appex in Embed App Extensions */,
\t\t\t\tSCX10000000000000000002 /* ShieldConfigurationExtension.appex in Embed App Extensions */,
\t\t\t\tSAX10000000000000000002 /* ShieldActionExtension.appex in Embed App Extensions */,
"""
content = content.replace(
    "\t\t\t\tSTX10000000000000000002 /* ScreenTimeExtension.appex in Embed App Extensions */,\n",
    embed_files_replacement
)

# 4. PBXFileReference
file_refs_to_add = """\
\t\tSCX20000000000000000001 /* ShieldConfigurationExtension.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ShieldConfigurationExtension.swift; sourceTree = "<group>"; };
\t\tSCX20000000000000000002 /* ShieldConfigurationExtension-Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "Info.plist"; sourceTree = "<group>"; };
\t\tSCX20000000000000000003 /* ShieldConfigurationExtension.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = "ShieldConfigurationExtension.entitlements"; sourceTree = "<group>"; };
\t\tSCX30000000000000000001 /* ShieldConfigurationExtension.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = ShieldConfigurationExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; };
\t\tSAX20000000000000000001 /* ShieldActionExtensionHandler.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ShieldActionExtensionHandler.swift; sourceTree = "<group>"; };
\t\tSAX20000000000000000002 /* ShieldActionExtension-Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "Info.plist"; sourceTree = "<group>"; };
\t\tSAX20000000000000000003 /* ShieldActionExtension.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = "ShieldActionExtension.entitlements"; sourceTree = "<group>"; };
\t\tSAX30000000000000000001 /* ShieldActionExtension.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = ShieldActionExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; };
"""
content = content.replace(
    "/* End PBXFileReference section */",
    file_refs_to_add + "/* End PBXFileReference section */"
)

# 5. PBXGroup
groups_to_add = """\
\t\tSCX40000000000000000001 /* ShieldConfigurationExtension */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tSCX20000000000000000001 /* ShieldConfigurationExtension.swift */,
\t\t\t\tSCX20000000000000000002 /* ShieldConfigurationExtension-Info.plist */,
\t\t\t\tSCX20000000000000000003 /* ShieldConfigurationExtension.entitlements */,
\t\t\t);
\t\t\tpath = ShieldConfigurationExtension;
\t\t\tsourceTree = "<group>";
\t\t};
\t\tSAX40000000000000000001 /* ShieldActionExtension */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tSAX20000000000000000001 /* ShieldActionExtensionHandler.swift */,
\t\t\t\tSAX20000000000000000002 /* ShieldActionExtension-Info.plist */,
\t\t\t\tSAX20000000000000000003 /* ShieldActionExtension.entitlements */,
\t\t\t);
\t\t\tpath = ShieldActionExtension;
\t\t\tsourceTree = "<group>";
\t\t};
"""
content = content.replace(
    "\t\tSTX40000000000000000001 /* ScreenTimeExtension */ = {",
    groups_to_add + "\t\tSTX40000000000000000001 /* ScreenTimeExtension */ = {"
)

# Add groups to main group CustomTemplate
content = content.replace(
    "\t\t\t\tSTX40000000000000000001 /* ScreenTimeExtension */,\n",
    "\t\t\t\tSTX40000000000000000001 /* ScreenTimeExtension */,\n\t\t\t\tSCX40000000000000000001 /* ShieldConfigurationExtension */,\n\t\t\t\tSAX40000000000000000001 /* ShieldActionExtension */,\n"
)

# Add appex to Products group
content = content.replace(
    "\t\t\t\tSTX30000000000000000001 /* ScreenTimeExtension.appex */,\n",
    "\t\t\t\tSTX30000000000000000001 /* ScreenTimeExtension.appex */,\n\t\t\t\tSCX30000000000000000001 /* ShieldConfigurationExtension.appex */,\n\t\t\t\tSAX30000000000000000001 /* ShieldActionExtension.appex */,\n"
)

# 6. PBXNativeTarget
targets_to_add = """\
\t\tSCX60000000000000000001 /* ShieldConfigurationExtension */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = SCX70000000000000000001 /* Build configuration list for PBXNativeTarget "ShieldConfigurationExtension" */;
\t\t\tbuildPhases = (
\t\t\t\tSCX80000000000000000001 /* Sources */,
\t\t\t\tSCX80000000000000000002 /* Frameworks */,
\t\t\t\tSCX80000000000000000003 /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = ShieldConfigurationExtension;
\t\t\tproductName = ShieldConfigurationExtension;
\t\t\tproductReference = SCX30000000000000000001 /* ShieldConfigurationExtension.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t};
\t\tSAX60000000000000000001 /* ShieldActionExtension */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = SAX70000000000000000001 /* Build configuration list for PBXNativeTarget "ShieldActionExtension" */;
\t\t\tbuildPhases = (
\t\t\t\tSAX80000000000000000001 /* Sources */,
\t\t\t\tSAX80000000000000000002 /* Frameworks */,
\t\t\t\tSAX80000000000000000003 /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = ShieldActionExtension;
\t\t\tproductName = ShieldActionExtension;
\t\t\tproductReference = SAX30000000000000000001 /* ShieldActionExtension.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t};
"""
content = content.replace(
    "/* End PBXNativeTarget section */",
    targets_to_add + "/* End PBXNativeTarget section */"
)

# 7. Add targets to PBXProject targets list and TargetAttributes
content = content.replace(
    "\t\t\t\tSTX60000000000000000001 /* ScreenTimeExtension */,\n",
    "\t\t\t\tSTX60000000000000000001 /* ScreenTimeExtension */,\n\t\t\t\tSCX60000000000000000001 /* ShieldConfigurationExtension */,\n\t\t\t\tSAX60000000000000000001 /* ShieldActionExtension */,\n"
)
target_attribs = """\
\t\t\t\t\tSCX60000000000000000001 = {
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t\tDevelopmentTeam = B7BJ5HC53B;
\t\t\t\t\t\tProvisioningStyle = Manual;
\t\t\t\t\t};
\t\t\t\t\tSAX60000000000000000001 = {
\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;
\t\t\t\t\t\tDevelopmentTeam = B7BJ5HC53B;
\t\t\t\t\t\tProvisioningStyle = Manual;
\t\t\t\t\t};
"""
content = content.replace(
    "\t\t\t\t\tSTX60000000000000000001 = {",
    target_attribs + "\t\t\t\t\tSTX60000000000000000001 = {"
)

# 8. Build Phases: Sources, Frameworks, Resources
phases_to_add = """\
\t\tSCX80000000000000000001 /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tSCX10000000000000000001 /* ShieldConfigurationExtension.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
\t\tSCX80000000000000000002 /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
\t\tSCX80000000000000000003 /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
\t\tSAX80000000000000000001 /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tSAX10000000000000000001 /* ShieldActionExtensionHandler.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
\t\tSAX80000000000000000002 /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
\t\tSAX80000000000000000003 /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
"""
content = content.replace(
    "/* End PBXSourcesBuildPhase section */",
    phases_to_add + "/* End PBXSourcesBuildPhase section */"
)

# 9. Target Dependencies on Runner
dependencies_to_add = """\
\t\tSCXD0000000000000000001 /* PBXTargetDependency */ = {
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = SCX60000000000000000001 /* ShieldConfigurationExtension */;
\t\t\ttargetProxy = SCXC0000000000000000001 /* PBXContainerItemProxy */;
\t\t};
\t\tSAXD0000000000000000001 /* PBXTargetDependency */ = {
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = SAX60000000000000000001 /* ShieldActionExtension */;
\t\t\ttargetProxy = SAXC0000000000000000001 /* PBXContainerItemProxy */;
\t\t};
"""
content = content.replace(
    "/* End PBXTargetDependency section */",
    dependencies_to_add + "/* End PBXTargetDependency section */"
)
# Add to Runner dependencies array
content = content.replace(
    "\t\t\t\tSTXD0000000000000000001 /* PBXTargetDependency */,\n",
    "\t\t\t\tSTXD0000000000000000001 /* PBXTargetDependency */,\n\t\t\t\tSCXD0000000000000000001 /* PBXTargetDependency */,\n\t\t\t\tSAXD0000000000000000001 /* PBXTargetDependency */,\n"
)

# 10. XCBuildConfiguration and XCConfigurationList
def make_config_blocks(prefix, name, bundle_id, ent_file, info_file):
    return f"""\
\t\t{prefix}90000000000000000001 /* Debug-student */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = {ent_file};
\t\t\t\tCODE_SIGN_IDENTITY = "Apple Development";
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tDEVELOPMENT_TEAM = B7BJ5HC53B;
\t\t\t\tINFOPLIST_FILE = {info_file};
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = "Debug-student";
\t\t}};
\t\t{prefix}90000000000000000002 /* Release-student */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = {ent_file};
\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tDEVELOPMENT_TEAM = B7BJ5HC53B;
\t\t\t\tINFOPLIST_FILE = {info_file};
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = "Release-student";
\t\t}};
\t\t{prefix}90000000000000000003 /* Profile-student */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = {ent_file};
\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tDEVELOPMENT_TEAM = B7BJ5HC53B;
\t\t\t\tINFOPLIST_FILE = {info_file};
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = "Profile-student";
\t\t}};
\t\t{prefix}A0000000000000000001 /* Debug-admin */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = {ent_file};
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tDEVELOPMENT_TEAM = B7BJ5HC53B;
\t\t\t\tINFOPLIST_FILE = {info_file};
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = "Debug-admin";
\t\t}};
\t\t{prefix}A0000000000000000002 /* Release-admin */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = {ent_file};
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tDEVELOPMENT_TEAM = B7BJ5HC53B;
\t\t\t\tINFOPLIST_FILE = {info_file};
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = "Release-admin";
\t\t}};
\t\t{prefix}A0000000000000000003 /* Profile-admin */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = {ent_file};
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tDEVELOPMENT_TEAM = B7BJ5HC53B;
\t\t\t\tINFOPLIST_FILE = {info_file};
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = "Profile-admin";
\t\t}};
\t\t{prefix}B0000000000000000001 /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = {ent_file};
\t\t\t\tCODE_SIGN_IDENTITY = "Apple Development";
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tDEVELOPMENT_TEAM = B7BJ5HC53B;
\t\t\t\tINFOPLIST_FILE = {info_file};
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{prefix}B0000000000000000002 /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = {ent_file};
\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tDEVELOPMENT_TEAM = B7BJ5HC53B;
\t\t\t\tINFOPLIST_FILE = {info_file};
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{prefix}B0000000000000000003 /* Profile */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = {ent_file};
\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";
\t\t\t\tCODE_SIGN_STYLE = Manual;
\t\t\t\tDEVELOPMENT_TEAM = B7BJ5HC53B;
\t\t\t\tINFOPLIST_FILE = {info_file};
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Profile;
\t\t}};
"""

configs_to_add = make_config_blocks(
    "SCX", "ShieldConfigurationExtension", "ai.socialstudying.app.ShieldConfigurationExtension",
    "ShieldConfigurationExtension/ShieldConfigurationExtension.entitlements", "ShieldConfigurationExtension/Info.plist"
) + make_config_blocks(
    "SAX", "ShieldActionExtension", "ai.socialstudying.app.ShieldActionExtension",
    "ShieldActionExtension/ShieldActionExtension.entitlements", "ShieldActionExtension/Info.plist"
)

content = content.replace(
    "/* End XCBuildConfiguration section */",
    configs_to_add + "/* End XCBuildConfiguration section */"
)

def make_config_list(prefix, name):
    return f"""\
\t\t{prefix}70000000000000000001 /* Build configuration list for PBXNativeTarget "{name}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{prefix}90000000000000000001 /* Debug-student */,
\t\t\t\t{prefix}90000000000000000002 /* Release-student */,
\t\t\t\t{prefix}90000000000000000003 /* Profile-student */,
\t\t\t\t{prefix}A0000000000000000001 /* Debug-admin */,
\t\t\t\t{prefix}A0000000000000000002 /* Release-admin */,
\t\t\t\t{prefix}A0000000000000000003 /* Profile-admin */,
\t\t\t\t{prefix}B0000000000000000001 /* Debug */,
\t\t\t\t{prefix}B0000000000000000002 /* Release */,
\t\t\t\t{prefix}B0000000000000000003 /* Profile */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""

config_lists_to_add = make_config_list("SCX", "ShieldConfigurationExtension") + make_config_list("SAX", "ShieldActionExtension")

content = content.replace(
    "/* End XCConfigurationList section */",
    config_lists_to_add + "/* End XCConfigurationList section */"
)

with open(pbx_path, "w", encoding="utf-8") as f:
    f.write(content)

print("SUCCESS: Successfully integrated ShieldConfigurationExtension and ShieldActionExtension into project.pbxproj!")
