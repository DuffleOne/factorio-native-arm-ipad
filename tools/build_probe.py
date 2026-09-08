#!/usr/bin/env python3
"""Build the local ARM64 iPadOS port from an owned macOS Factorio installation."""
import argparse
import json
import plistlib
import subprocess
import shutil
import hashlib
from pathlib import Path
from audit import ROOT, DEFAULT_APP, mobile_path, sdk_path, audit as generate_audit
from config import DEFAULT_BUNDLE_ID, SUPPORTED_SHA256, validate_source
from macho import MachO
from entrypoint import inject_entry


def build_shim(app, uikit=False, sdk='iphonesimulator'):
    audit = json.loads((ROOT/'reports/audit-iphoneos.json').read_text())
    directory = ROOT/'build'/('generated-'+sdk)
    directory.mkdir(parents=True, exist_ok=True)
    missing = {s['name'] for lib in audit['libraries'] for s in lib['missing']}
    # nan is provided by libSystem on iOS; macOS happens to bind it to CoreServices.
    missing.discard('_nan')
    missing.discard('_clGetPlatformIDs')
    missing.discard('_SteamAPI_RestartAppIfNecessary')
    missing.discard('_SteamAPI_Init')
    classes = sorted({s.split('$_')[1] for s in missing if s.startswith('_OBJC_')})
    classes = [c for c in classes if c not in ('NSColorSpace','NSBitmapImageRep')]
    lines = ['#import <Foundation/Foundation.h>', '#include <stdio.h>', '#include <stdlib.h>', '#include <execinfo.h>',
             '__attribute__((noreturn)) static void unavailable(const char *s) {',
             'fprintf(stderr, "FACTORIO_PROBE_UNIMPLEMENTED: %s\\n", s); void *bt[32]; int n=backtrace(bt,32); backtrace_symbols_fd(bt,n,2); fflush(stderr); abort(); }']
    for cls in classes:
        lines += [f'@interface {cls}: NSObject @end', f'@implementation {cls}',
                  '- (void)doesNotRecognizeSelector:(SEL)s { unavailable(sel_getName(s)); }',
                  '+ (void)doesNotRecognizeSelector:(SEL)s { unavailable(sel_getName(s)); }', '@end']
    for i, symbol in enumerate(sorted(missing)):
        if symbol.startswith('_OBJC_'):
            continue
        if symbol == '_NSApp':
            lines.append('id NSApp = nil;')
        elif symbol == '_NSAppKitVersionNumber':
            lines.append('double NSAppKitVersionNumber = 0;')
        elif symbol.startswith('_k') or (symbol.startswith('_NS') and symbol != '_NSRectFill'):
            lines.append(f'NSString * const {symbol[1:]} = @"{symbol[1:]}";')
        else:
            lines += [f'void probe_trap_{i}(void) __asm__("{symbol}");',
                      f'void probe_trap_{i}(void) {{ unavailable("{symbol}"); }}']
    source = directory/'ProbeShim.m'
    source.write_text('\n'.join(lines)+'\n')
    frameworks = app/'Frameworks'
    frameworks.mkdir(exist_ok=True)
    library = frameworks/'ProbeShim.dylib'
    target_triple='arm64-apple-ios26.0'+('-simulator' if sdk=='iphonesimulator' else '')
    sdk_root=str(sdk_path(sdk))
    command = ['xcrun','--sdk',sdk,'clang','-target',target_triple,
               '-Werror=property-attribute-mismatch','-Werror=objc-property-synthesis',
               '-isysroot',sdk_root,'-dynamiclib','-fobjc-arc',str(source),str(ROOT/'probe/PlatformFallbacks.m'),
               str(ROOT/'probe/BitmapCompat.m'),'-framework','ImageIO',
               '-o',str(library),'-install_name','@executable_path/Frameworks/ProbeShim.dylib',
               '-Wl,-reexport-lSystem','-Wl,-reexport-lobjc','-Wl,-reexport-lresolv']
    if uikit:
        main_offset = next(s['address'] for s in audit['entrypoints'] if s['name']=='_main') - 0x100000000
        command += [str(ROOT/'probe/UIKitEntry.m'),str(ROOT/'probe/MetalCompat.m'),
                    str(ROOT/'probe/TouchControls.m'),'-I'+str(ROOT/'build/vendor/SDL-release-2.30.9/include'),
                    f'-DORIGINAL_MAIN_OFFSET={main_offset}','-framework','UIKit']
        sdl = frameworks/'libSDL2.dylib'
        sdl_build='sdl-simulator' if sdk=='iphonesimulator' else 'sdl-iphoneos'
        shutil.copyfile(ROOT/'build'/sdl_build/'libSDL2-2.0.0.dylib',sdl)
        subprocess.run(['install_name_tool','-id','@executable_path/Frameworks/libSDL2.dylib',str(sdl)],check=True)
        rename_objc_classes(sdl, {'SDL_RumbleMotor':'FPI_RumbleMotor','SDL_RumbleContext':'FPI_RumbleContext',
                                'SDL_VideoData':'FPI_VideoData','SDL_WindowData':'FPI_WindowData'})
        subprocess.run(['codesign','--force','--sign','-',str(sdl)],check=True,capture_output=True)
        command += ['-Wl,-reexport_library,'+str(sdl)]
    for lib in audit['libraries']:
        if '.framework/' in lib['mobile'] and lib['sdk_has_exports']:
            command += ['-Wl,-reexport_framework,'+Path(lib['mobile']).name]
    subprocess.run(command, check=True)
    rename_objc_classes(library, {'NSColor':'FPColor'})
    subprocess.run(['codesign','--force','--sign','-',str(library)], check=True)
    # Preserve each original ordinal with a distinct reexporting facade. Modern
    # dyld rejects duplicate LC_LOAD_DYLIB names even when their ordinals differ.
    empty = directory/'Facade.c'
    empty.write_text('/* Reexports only. */\n')
    replacements = {}
    for i, lib in enumerate(audit['libraries']):
        if '.framework/' not in lib['original'] and 'libsteam_api' not in lib['original']:
            continue
        name = f'P{i:02}.dylib'
        target = frameworks/name
        install = '@executable_path/Frameworks/'+name
        subprocess.run(['xcrun','--sdk',sdk,'clang',
                        '-target',target_triple,'-isysroot',sdk_root,
                        '-dynamiclib',str(empty),'-o',str(target),'-install_name',install,
                        '-Wl,-reexport_library,'+str(library),'-L'+str(frameworks)], check=True)
        subprocess.run(['codesign','--force','--sign','-',str(target)],check=True, capture_output=True)
        replacements[lib['original']] = install
    return replacements

def rename_objc_classes(path, replacements):
    m = MachO(path)
    section = next(s for s in m.sections if s['name']=='__objc_classname')
    start,end = section['offset'],section['offset']+section['size']
    data = m.data
    for old,new in replacements.items():
        assert len(old)==len(new)
        needle = old.encode()+b'\0'
        at = data.find(needle,start,end)
        if at<0:
            raise ValueError('Missing Objective-C metadata name: '+old)
        data[at:at+len(old)] = new.encode()
    path.write_bytes(data)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', type=Path, default=DEFAULT_APP)
    parser.add_argument('--bundle-id', default=DEFAULT_BUNDLE_ID)
    parser.add_argument('--shim', action='store_true', help='Add fail-fast diagnostic placeholders')
    parser.add_argument('--uikit', action='store_true', help='Use UIKit entry and iOS SDL adapter')
    parser.add_argument('--simulator-metal',action='store_true',help='Diagnostic: try Metal despite simulator GPU-family reporting')
    parser.add_argument('--sdk',choices=['iphoneos','iphonesimulator'],default='iphonesimulator')
    parser.add_argument('--bundle-data',action='store_true',help='Include the local base-game data for standalone launch')
    args = parser.parse_args()
    if args.simulator_metal and args.sdk!='iphonesimulator':
        parser.error('--simulator-metal is forbidden in device builds')
    validate_source(args.app)
    if args.shim or args.uikit:
        generate_audit(args.app, 'iphoneos')
    (ROOT/'reports').mkdir(exist_ok=True)
    app = ROOT/('build/FactorioProbe.app' if args.sdk=='iphonesimulator' else 'build/iphoneos/FactorioProbe.app')
    app.mkdir(parents=True, exist_ok=True)
    binary = args.app/'Contents/MacOS/factorio'
    if hashlib.sha256(binary.read_bytes()).hexdigest()!=SUPPORTED_SHA256:
        raise ValueError('Unrecognized Factorio binary: this patch set is pinned to the audited 2.0.77 build')
    macho = MachO(binary)
    replacements = {lib: mobile_path(lib) for lib in macho.libraries}
    if args.shim or args.uikit:
        replacements.update(build_shim(app,args.uikit,args.sdk))
    macho.retarget(app/'FactorioProbe', 7 if args.sdk=='iphonesimulator' else 2, replacements)
    if args.uikit:
        entry = inject_entry(app/'FactorioProbe',app/'Frameworks/libSDL2.dylib',args.simulator_metal)
        (ROOT/f'reports/entrypoint-patch-{args.sdk}.json').write_text(json.dumps(entry,indent=2)+'\n')
    info = dict(CFBundleExecutable='FactorioProbe', CFBundleIdentifier=args.bundle_id,
                CFBundleName='Factorio Loader Probe', CFBundleDisplayName='Factorio Probe',
                CFBundlePackageType='APPL', CFBundleVersion='1', CFBundleShortVersionString='0.1',
                CFBundleSupportedPlatforms=['iPhoneSimulator' if args.sdk=='iphonesimulator' else 'iPhoneOS'], MinimumOSVersion='26.0',
                UIDeviceFamily=[2], LSRequiresIPhoneOS=True, UILaunchScreen={})
    if args.uikit:
        info['UISupportedInterfaceOrientations'] = ['UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight']
        info['UIApplicationSupportsIndirectInputEvents'] = True
        info['UIStatusBarHidden'] = True
        info['UIViewControllerBasedStatusBarAppearance'] = False
        info['UIRequiresFullScreen'] = True
    (app/'Info.plist').write_bytes(plistlib.dumps(info))
    if args.bundle_data and not (app/'data/base/info.json').exists():
        try:
            subprocess.run(['cp','-cR',str(args.app/'Contents/data'),str(app/'data')],check=True)
        except subprocess.CalledProcessError:
            # Non-APFS volumes do not support clonefile; use an ordinary copy.
            shutil.copytree(args.app/'Contents/data',app/'data',dirs_exist_ok=True)
    subprocess.run(['codesign','--force','--sign','-',str(app)], check=True)
    print(app)

if __name__ == '__main__':
    main()
