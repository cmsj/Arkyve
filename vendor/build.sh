#!/bin/bash

set -eu

if [ $(basename ${PWD}) != "vendor" ]; then
  echo "ERROR: You're not in the vendor directory."
  exit 1
fi

export MAKE="make -j12"
export MACOSX_DEPLOYMENT_TARGET="14.0"
export SDK="macosx"

export CC=$(xcrun --find --sdk ${SDK} clang)
export CXX=$(xcrun --find --sdk ${SDK} clang++)
export CPP=$(xcrun --find --sdk ${SDK} cpp)
export AR=$(xcrun --find --sdk ${SDK} ar)

rm -rf include/* lib/*
mkdir -p include
mkdir -p lib/Debug
mkdir -p lib/Release

function repo_enter() {
  pushd "$1"
  git reset --hard
  git clean -xdf
}

function repo_exit() {
  git reset --hard
  git clean -xdf
  popd
}

function set_release() {
    if [ "$1" == "Debug" ]; then
        export CONFIGURATION="Debug"
        export CONFIGURE_FLAGS="--enable-debug"
        export OPT_FLAGS="-O0 -g -DDEBUG"
    else
        export CONFIGURATION="Release"
        export CONFIGURE_FLAGS=""
        export OPT_FLAGS="-O3"
    fi
}

function set_arch() {
    if [ "$1" == "arm" ]; then
        export ARCH_FLAGS="-arch arm64"
        export HOST_FLAGS="${ARCH_FLAGS} -isysroot $(xcrun --sdk ${SDK} --show-sdk-path)"
        export PLATFORM="arm"
        export CHOST="arm-apple-darwin"
        export CFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
        export CXXFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
        export LD_FLAGS="${HOST_FLAGS}"
    elif [ "$1" == "x86_64" ]; then
        export ARCH_FLAGS="-arch x86_64"
        export HOST_FLAGS="${ARCH_FLAGS} -isysroot $(xcrun --sdk ${SDK} --show-sdk-path)"
        export PLATFORM="x86_64"
        export CHOST="x86_64-apple-darwin"
        export CFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
        export CXXFLAGS="${CFLAGS}"
        export LD_FLAGS="${HOST_FLAGS}"
    else
        echo "ERROR: Unknown arch: $1"
        exit 1
    fi
}

function fatten_lib() {
    lipo lib/${CONFIGURATION}/lib${1}-arm.a lib/${CONFIGURATION}/lib${1}-x86_64.a -create -output lib/${CONFIGURATION}/lib${1}.a
    rm -f lib/${CONFIGURATION}/lib${1}-*.a
}

# libzstd
function buildZSTD() {
    repo_enter src/zstd

    cmake -B build-cmake-debug -S build/cmake -G Ninja -DCMAKE_OSX_ARCHITECTURES="x86_64;x86_64h;arm64" -DCMAKE_BUILD_TYPE="Debug"
    cmake -B build-cmake-release -S build/cmake -G Ninja -DCMAKE_OSX_ARCHITECTURES="x86_64;x86_64h;arm64" -DCMAKE_BUILD_TYPE="Release"

    pushd build-cmake-debug
    ninja
    cp lib/libzstd.a ../../../lib/Debug/
    popd

    pushd build-cmake-release
    ninja
    cp lib/libzstd.a ../../../lib/Release/
    popd

    # Copy headers
    cp lib/*.h ../../include/

    repo_exit
}

# liblzma
function buildLZMA() {
    repo_enter src/xz
    set_release $1

    for arch in arm x86_64 ; do
        set_arch "${arch}"

        ./autogen.sh
        ./configure ${CONFIGURE_FLAGS} --disable-xz --disable-xzdec --disable-lzma-links --disable-lzmainfo --disable-doc --prefix="${PWD}/build/" --enable-static --disable-shared --host="${CHOST}"
        pushd src/liblzma
        make clean
        ${MAKE}

        cp .libs/liblzma.a "../../../../lib/${CONFIGURATION}/liblzma-${PLATFORM}.a"
        make clean
        popd
    done

    # Copy headers
    cp src/liblzma/api/lzma.h ../../include/
    cp -r src/liblzma/api/lzma ../../include/

    repo_exit
    fatten_lib lzma
}

function buildLZ4() {
    repo_enter src/lz4/lib
    set_release $1

    for arch in arm x86_64 ; do
        set_arch "${arch}"

        rm -f *.o

        ${CC} ${CFLAGS} -o lz4.o lz4.c
        ${CC} ${CFLAGS} -o lz4file.o lz4file.c
        ${CC} ${CFLAGS} -o lz4frame.o lz4frame.c
        ${CC} ${CFLAGS} -o lz4hc.o lz4hc.c
        ${CC} ${CFLAGS} -o xxhash.o xxhash.c

        ${AR} r liblz4-${PLATFORM}.a *.o
        cp liblz4-${PLATFORM}.a ../../../lib/${CONFIGURATION}/liblz4-${PLATFORM}.a
    done

    # Copy headers
    cp *.h ../../../include/

    repo_exit
    fatten_lib lz4
}

# libb2
function buildB2() {
    repo_enter src/libb2
    set_release $1

    for arch in arm x86_64; do
        set_arch "${arch}"

        ./autogen.sh
        ./configure ${CONFIGURE_FLAGS} --prefix="${PWD}/build/" --enable-static --disable-shared --host="${CHOST}"
        make clean
        ${MAKE}
        make install

        cp build/lib/libb2.a "../../lib/${CONFIGURATION}/libb2-${PLATFORM}.a"
        make clean
    done

    # Copy headers
    cp build/include/* ../../include/

    repo_exit
    fatten_lib b2
}

function buildARCHIVE() {
    repo_enter src/libarchive
    set_release $1

    mkdir output

    for arch in arm x86_64; do
        set_arch "${arch}"

        /bin/sh build/autogen.sh
        ./configure ${CONFIGURE_FLAGS} --prefix="${PWD}/output/" --enable-static --disable-shared --host="${CHOST}" --disable-shared --disable-bsdtar --disable-bsdcat --disable-bsdcpio --disable-bsdunzip
        make clean
        ${MAKE}
        make install

        cp output/lib/libarchive.a "../../lib/${CONFIGURATION}/libarchive-${PLATFORM}.a"
        make clean
    done

    # Copy headers
    cp output/include/* ../../include/

    repo_exit
    fatten_lib archive
}

# Call our builder functions

buildZSTD # Builds both Debug and Release

buildLZMA Debug
buildLZMA Release

buildLZ4 Debug
buildLZ4 Release

buildB2 Debug
buildB2 Release

buildARCHIVE Debug
buildARCHIVE Release
