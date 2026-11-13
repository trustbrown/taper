"""Generate a minimal standard Xcode project; no third-party project generator needed."""
from pathlib import Path
import hashlib
base=Path(__file__).parent
sources=sorted((base/'Taper').rglob('*.swift'))
assets=base/'Taper/Resources/Assets.xcassets'
plist=base/'Taper/Resources/Info.plist'
def ID(s): return hashlib.sha1(s.encode()).hexdigest().upper()[:24]
def E(s): return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
objects=[]
def add(key,typ,fields): objects.append(f'\t\t{ID(key)} /* {key.split("/")[-1]} */ = {{isa = {typ}; {fields.rstrip() if fields.rstrip().endswith(";") else fields.rstrip() + ";"}}};')
def r(key): return ID(key)+' /* '+key.split('/')[-1]+' */'
for file in sources+[assets,plist]:
    rel=file.relative_to(base).as_posix()
    ftype='folder.assetcatalog' if file==assets else 'text.plist.xml' if file==plist else 'sourcecode.swift'
    add('ref:'+rel,'PBXFileReference',f'lastKnownFileType = {ftype}; path = {E(file.name)}; sourceTree = "<group>"')
    if file.suffix=='.swift' or file==assets:
        add('build:'+rel,'PBXBuildFile',f'fileRef = {r("ref:"+rel)}')
folders=[base/'Taper']+sorted(x for x in (base/'Taper').rglob('*') if x.is_dir() and x!=assets and assets not in x.parents)
for folder in folders:
    rel=folder.relative_to(base).as_posix()
    direct_dirs=[x for x in folders if x.parent==folder]
    direct_files=[x for x in sources+[assets,plist] if x.parent==folder]
    children=[r('group:'+x.relative_to(base).as_posix()) for x in direct_dirs]+[r('ref:'+x.relative_to(base).as_posix()) for x in direct_files]
    add('group:'+rel,'PBXGroup',f'children = ({", ".join(children)}); path = {E(folder.name)}; sourceTree = "<group>"')
add('group:root','PBXGroup',f'children = ({r("group:Taper")}, {r("ref:products")}); sourceTree = "<group>"')
add('ref:products','PBXFileReference','explicitFileType = wrapper.application; includeInIndex = 0; path = Taper.app; sourceTree = BUILT_PRODUCTS_DIR')
add('phase:sources','PBXSourcesBuildPhase','buildActionMask = 2147483647; files = ('+', '.join(r('build:'+x.relative_to(base).as_posix()) for x in sources)+'); runOnlyForDeploymentPostprocessing = 0')
add('phase:resources','PBXResourcesBuildPhase',f'buildActionMask = 2147483647; files = ({r("build:"+assets.relative_to(base).as_posix())}); runOnlyForDeploymentPostprocessing = 0')
add('config:proj:Debug','XCBuildConfiguration','name = Debug; buildSettings = { SWIFT_VERSION = 5.0; IPHONEOS_DEPLOYMENT_TARGET = 26.0; }')
add('config:proj:Release','XCBuildConfiguration','name = Release; buildSettings = { SWIFT_VERSION = 5.0; IPHONEOS_DEPLOYMENT_TARGET = 26.0; }')
for mode in ['Debug','Release']:
    fields=f'''name = {mode}; buildSettings = {{
    ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
    CODE_SIGN_STYLE = Automatic;
    GENERATE_INFOPLIST_FILE = NO;
    INFOPLIST_FILE = Taper/Resources/Info.plist;
    IPHONEOS_DEPLOYMENT_TARGET = 26.0;
    PRODUCT_BUNDLE_IDENTIFIER = org.tapercommunity.Taper;
    PRODUCT_NAME = "$(TARGET_NAME)";
    SDKROOT = iphoneos;
    SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
    SWIFT_VERSION = 5.0;
    TARGETED_DEVICE_FAMILY = 1;
    SUPPORTS_MACCATALYST = NO;
    ENABLE_PREVIEWS = YES;
    }}'''
    add('config:app:'+mode,'XCBuildConfiguration',fields)
for name,kind in [('proj','proj'),('app','app')]:
    add('configs:'+name,'XCConfigurationList',f'buildConfigurations = ({r("config:"+kind+":Debug")}, {r("config:"+kind+":Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release')
add('target:app','PBXNativeTarget',f'buildConfigurationList = {r("configs:app")}; buildPhases = ({r("phase:sources")}, {r("phase:resources")}); buildRules = (); dependencies = (); name = Taper; productName = Taper; productReference = {r("ref:products")}; productType = "com.apple.product-type.application"')
add('project','PBXProject',f'''attributes = {{ LastUpgradeCheck = 2600; TargetAttributes = {{ {ID('target:app')} = {{ CreatedOnToolsVersion = 26.0; }}; }}; }};
    buildConfigurationList = {r('configs:proj')}; compatibilityVersion = "Xcode 16.0";
    developmentRegion = en; hasScannedForEncodings = 0;
    knownRegions = (en, Base); mainGroup = {r('group:root')};
    productRefGroup = {r('group:root')}; projectDirPath = ""; projectRoot = "";
    targets = ({r('target:app')})''')
header='// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 60;\n\tobjects = {\n'
footer=f'\n\t}};\n\trootObject = {r("project")};\n}}\n'
proj=base/'Taper.xcodeproj';proj.mkdir(exist_ok=True)
(proj/'project.pbxproj').write_text(header+'\n'.join(objects)+footer)
print('Created',proj,'with',len(sources),'Swift files')
