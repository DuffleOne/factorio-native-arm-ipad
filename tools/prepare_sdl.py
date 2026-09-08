#!/usr/bin/env python3
"""Fetch pinned upstream SDL and compile a separate ARM64 iOS platform library."""
import argparse
import hashlib
import subprocess
import tarfile
import urllib.request
from pathlib import Path
from config import ROOT, CMAKE

SHA256='682a055004081e37d81a7d4ce546c3ee3ef2e0e6a675ed2651e430ccd14eb407'
URL='https://github.com/libsdl-org/SDL/archive/refs/tags/release-2.30.9.tar.gz'

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--sdk',choices=['iphoneos','iphonesimulator'],default='iphonesimulator')
    args=parser.parse_args()
    (ROOT/'reports').mkdir(exist_ok=True)
    vendor=ROOT/'build/vendor'
    vendor.mkdir(parents=True,exist_ok=True)
    archive=vendor/'SDL-2.30.9.tar.gz'
    if not archive.exists(): urllib.request.urlretrieve(URL,archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=SHA256:
        raise ValueError('SDL archive checksum mismatch')
    source=vendor/'SDL-release-2.30.9'
    if not source.exists():
        with tarfile.open(archive) as tar: tar.extractall(vendor,filter='data')
    # Keep the upstream code intact; add only our small input adapter to its
    # existing target, which can then call SDL's private event/state functions.
    with tarfile.open(archive) as tar:
        upstream=tar.extractfile('SDL-release-2.30.9/CMakeLists.txt').read().decode()
    cmake=upstream+'\n# Local iPad input adapter\n'+f'target_sources(SDL2 PRIVATE "{ROOT}/probe/SDLInputBridge.c")\n'+f'target_include_directories(SDL2 PRIVATE "{source}/src")\n'
    cmake_file=source/'CMakeLists.txt'
    if cmake_file.read_text()!=cmake: cmake_file.write_text(cmake)
    build=ROOT/'build'/('sdl-simulator' if args.sdk=='iphonesimulator' else 'sdl-iphoneos')
    with (ROOT/f'reports/sdl-configure-{args.sdk}.log').open('w') as log:
        subprocess.run([CMAKE,'-S',str(source),'-B',str(build),'-DCMAKE_SYSTEM_NAME=iOS',
            '-DCMAKE_OSX_SYSROOT='+args.sdk,'-DCMAKE_OSX_ARCHITECTURES=arm64',
            '-DCMAKE_OSX_DEPLOYMENT_TARGET=26.0','-DSDL_SHARED=ON','-DSDL_STATIC=OFF',
            '-DSDL_TEST=OFF','-DSDL_TESTS=OFF','-DSDL_INSTALL=OFF','-DCMAKE_BUILD_TYPE=Release'],
            check=True,stdout=log,stderr=subprocess.STDOUT)
    with (ROOT/f'reports/sdl-build-{args.sdk}.log').open('w') as log:
        subprocess.run([CMAKE,'--build',str(build),'-j','8'],check=True,stdout=log,stderr=subprocess.STDOUT)
    print(build/'libSDL2-2.0.0.dylib')

if __name__=='__main__': main()
