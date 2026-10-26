#!/usr/bin/env python3
"""Generate the dependency-free Xcode project deterministically (Python stdlib)."""
import hashlib
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def oid(key):
    return hashlib.sha1(key.encode()).hexdigest()[:24].upper()


def project():
    sources = sorted([*ROOT.glob("App/*.swift"), *ROOT.glob("Sources/MileageCore/*.swift")])
    resources = [ROOT / "App/Assets.xcassets", ROOT / "App/PrivacyInfo.xcprivacy"]
    refs = []
    builds = []
    source_builds = []
    resource_builds = []
    file_ids = []
    for path in sources + resources + [ROOT / "App/Info.plist"]:
        rel = path.relative_to(ROOT).as_posix()
        file_id = oid(rel)
        file_ids.append(file_id)
        file_type = "sourcecode.swift" if path.suffix == ".swift" else (
            "folder.assetcatalog" if path.suffix == ".xcassets" else "text.plist.xml")
        refs.append(f'{file_id} = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = "{rel}"; sourceTree = SOURCE_ROOT; }};')
        if path.name != "Info.plist":
            build_id = oid("build:" + rel)
            builds.append(f'{build_id} = {{isa = PBXBuildFile; fileRef = {file_id}; }};')
            (source_builds if path.suffix == ".swift" else resource_builds).append(build_id)
    project_id, target_id, product_id = oid("project"), oid("target"), oid("product")
    root_group, product_group = oid("root-group"), oid("product-group")
    source_phase, resource_phase, framework_phase = oid("sources"), oid("resources"), oid("frameworks")
    project_configs, target_configs = oid("project-configs"), oid("target-configs")
    config_objects = []
    for owner in ["project", "target"]:
        for name in ["Debug", "Release"]:
            if owner == "project":
                settings = '''ALWAYS_SEARCH_USER_PATHS = NO;
                CLANG_ENABLE_MODULES = YES;
                CLANG_ENABLE_OBJC_ARC = YES;
                IPHONEOS_DEPLOYMENT_TARGET = 17.0;
                SDKROOT = iphoneos;
                SWIFT_VERSION = 5.0;'''
                if name == "Debug":
                    settings += '''DEBUG_INFORMATION_FORMAT = dwarf;
                    SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
                    SWIFT_OPTIMIZATION_LEVEL = "-Onone";
                    GCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)");'''
                else:
                    settings += '''DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
                    SWIFT_COMPILATION_MODE = wholemodule;
                    SWIFT_OPTIMIZATION_LEVEL = "-O";'''
            else:
                settings = '''ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
                CODE_SIGN_STYLE = Automatic;
                CURRENT_PROJECT_VERSION = 1;
                DEVELOPMENT_TEAM = "";
                ENABLE_PREVIEWS = YES;
                GENERATE_INFOPLIST_FILE = NO;
                INFOPLIST_FILE = App/Info.plist;
                LD_RUNPATH_SEARCH_PATHS = ("$(inherited)", "@executable_path/Frameworks");
                MARKETING_VERSION = 0.1.0;
                PRODUCT_BUNDLE_IDENTIFIER = com.stealthorange.mileage;
                PRODUCT_NAME = "$(TARGET_NAME)";
                SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
                SUPPORTS_MACCATALYST = NO;
                SWIFT_EMIT_LOC_STRINGS = YES;
                TARGETED_DEVICE_FAMILY = 1;'''
            config_objects.append(f'{oid(owner + name)} = {{isa = XCBuildConfiguration; buildSettings = {{{settings}}}; name = {name}; }};')
    return '''// !$*UTF8*$!
{
archiveVersion = 1;
classes = {};
objectVersion = 56;
objects = {
''' + "\n".join(builds + refs + config_objects) + f'''
{product_id} = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Mileage.app; sourceTree = BUILT_PRODUCTS_DIR; }};
{root_group} = {{isa = PBXGroup; children = ({','.join(file_ids + [product_group])}); sourceTree = "<group>"; }};
{product_group} = {{isa = PBXGroup; children = ({product_id}); name = Products; sourceTree = "<group>"; }};
{source_phase} = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({','.join(source_builds)}); runOnlyForDeploymentPostprocessing = 0; }};
{resource_phase} = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({','.join(resource_builds)}); runOnlyForDeploymentPostprocessing = 0; }};
{framework_phase} = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};
{target_id} = {{isa = PBXNativeTarget; buildConfigurationList = {target_configs}; buildPhases = ({source_phase},{framework_phase},{resource_phase}); buildRules = (); dependencies = (); name = Mileage; productName = Mileage; productReference = {product_id}; productType = "com.apple.product-type.application"; }};
{project_id} = {{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; TargetAttributes = {{{target_id} = {{CreatedOnToolsVersion = 16.0; ProvisioningStyle = Automatic; SystemCapabilities = {{com.apple.BackgroundModes = {{enabled = 1; }}; }}; }}; }}; }}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base); mainGroup = {root_group}; productRefGroup = {product_group}; projectDirPath = ""; projectRoot = ""; targets = ({target_id}); }};
{project_configs} = {{isa = XCConfigurationList; buildConfigurations = ({oid('projectDebug')},{oid('projectRelease')}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};
{target_configs} = {{isa = XCConfigurationList; buildConfigurations = ({oid('targetDebug')},{oid('targetRelease')}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};
}};
rootObject = {project_id};
}}
'''


if __name__ == "__main__":
    destination = ROOT / "Mileage.xcodeproj/project.pbxproj"
    contents = project()
    if "--check" in sys.argv:
        if not destination.exists() or destination.read_text() != contents:
            raise SystemExit("Xcode project is stale. Run python3 scripts/generate_project.py")
        print("Xcode source membership is current.")
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(contents)
        print("Generated Mileage.xcodeproj")
