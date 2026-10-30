"""Generate the checked-in Xcode project without third-party dependencies."""
from pathlib import Path
import hashlib
root=Path(__file__).parent
objects={}
def ident(name):return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def put(name,content):objects[ident(name)]=content;return ident(name)
files=sorted((root/'Sources').glob('*.swift'))
refs=[];builds=[]
for f in files:
 ref=put('file'+f.name,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f.name}; sourceTree = "<group>";')
 refs.append(ref)
 builds.append(put('build'+f.name,f'isa = PBXBuildFile; fileRef = {ref};'))
sourcegroup=put('sources','isa = PBXGroup; children = ('+','.join(refs)+',); path = Sources; sourceTree = "<group>";')
product=put('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = FrameCut.app; sourceTree = BUILT_PRODUCTS_DIR;')
products=put('products',f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
main=put('main',f'isa = PBXGroup; children = ({sourcegroup},{products},); sourceTree = "<group>";')
phase=put('phase','isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ('+','.join(builds)+',); runOnlyForDeploymentPostprocessing = 0;')
frameworks=put('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
resources=put('resources','isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
projectconfs=[];targetconfs=[]
for mode in ['Debug','Release']:
 debug=mode=='Debug'
 projectconfs.append(put('project'+mode, 'isa = XCBuildConfiguration; name = '+mode+'; buildSettings = { CLANG_ENABLE_MODULES = YES; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; SWIFT_OPTIMIZATION_LEVEL = "'+('-Onone' if debug else '-O')+'"; '+('SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; ' if debug else '')+'};'))
 targetconfs.append(put('target'+mode, 'isa = XCBuildConfiguration; name = '+mode+'; buildSettings = { PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = app.framecut.editor; CODE_SIGN_STYLE = Automatic; TARGETED_DEVICE_FAMILY = "1,2"; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_CFBundleDisplayName = FrameCut; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription = "Salvar os vídeos exportados na sua biblioteca."; };'))
def configlist(name,ids): return put(name,'isa = XCConfigurationList; buildConfigurations = ('+','.join(ids)+',); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
pc=configlist('pc',projectconfs);tc=configlist('tc',targetconfs)
target=put('target',f'isa = PBXNativeTarget; buildConfigurationList = {tc}; buildPhases = ({phase},{frameworks},{resources},); buildRules = (); dependencies = (); name = FrameCut; productName = FrameCut; productReference = {product}; productType = "com.apple.product-type.application";')
project=put('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1600; }}; buildConfigurationList = {pc}; compatibilityVersion = "Xcode 14.0"; developmentRegion = pt; hasScannedForEncodings = 0; knownRegions = (pt,en,Base,); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
output=root/'FrameCut.xcodeproj';output.mkdir(exist_ok=True)
(output/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+ '\n'.join(k+' = { '+v+' };' for k,v in objects.items())+'\n}; rootObject = '+project+'; }\n')
schemes=output/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
(schemes/'FrameCut.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="FrameCut.app" BlueprintName="FrameCut" ReferencedContainer="container:FrameCut.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="FrameCut.app" BlueprintName="FrameCut" ReferencedContainer="container:FrameCut.xcodeproj"/></BuildableProductRunnable></LaunchAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated',output)
