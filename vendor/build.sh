#!/bin/bash

set -eu

if [ $(basename ${PWD}) != "vendor" ]; then
  echo "ERROR: You're not in the vendor directory."
  exit 1
fi

export VENDOR_DIR="${PWD}"
export MAKE="make -j12"
export MACOSX_DEPLOYMENT_TARGET="14.0"
export SDK="macosx"

export CC=$(xcrun --find --sdk ${SDK} clang)
export CXX=$(xcrun --find --sdk ${SDK} clang++)
export CPP=$(xcrun --find --sdk ${SDK} cpp)
export AR=$(xcrun --find --sdk ${SDK} ar)

rm -rf include lib logs
mkdir -p include
mkdir -p lib/Debug
mkdir -p lib/Release
mkdir -p logs

brew bundle install

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
        export LDFLAGS="${HOST_FLAGS}"
    elif [ "$1" == "x86_64" ]; then
        export ARCH_FLAGS="-arch x86_64"
        export HOST_FLAGS="${ARCH_FLAGS} -isysroot $(xcrun --sdk ${SDK} --show-sdk-path)"
        export PLATFORM="x86_64"
        export CHOST="x86_64-apple-darwin"
        export CFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
        export CXXFLAGS="${CFLAGS}"
        export LDFLAGS="${HOST_FLAGS}"
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

    rm -rf build-cmake-debug build-cmake-release

    cmake -B build-cmake-debug -S build/cmake -G Ninja -DCMAKE_OSX_ARCHITECTURES="x86_64;x86_64h;arm64" -DCMAKE_BUILD_TYPE="Debug" -DCMAKE_OSX_SYSROOT=macosx
    cmake -B build-cmake-release -S build/cmake -G Ninja -DCMAKE_OSX_ARCHITECTURES="x86_64;x86_64h;arm64" -DCMAKE_BUILD_TYPE="Release" -DCMAKE_OSX_SYSROOT=macosx

    pushd build-cmake-debug
    ninja
    cp lib/libzstd.a "${VENDOR_DIR}/lib/Debug/"
    popd

    pushd build-cmake-release
    ninja
    cp -v lib/libzstd.a "${VENDOR_DIR}/lib/Release/"
    popd

    # Copy headers
    cp -v lib/*.h "${VENDOR_DIR}/include/"

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

        cp -v .libs/liblzma.a "${VENDOR_DIR}/lib/${CONFIGURATION}/liblzma-${PLATFORM}.a"
        make clean
        popd
    done

    # Copy headers
    cp -v src/liblzma/api/lzma.h "${VENDOR_DIR}/include/"
    cp -v -r src/liblzma/api/lzma "${VENDOR_DIR}/include/"

    repo_exit
    fatten_lib lzma
}

function buildLZ4() {
    repo_enter src/lz4/lib
    set_release $1

    for arch in arm x86_64 ; do
        set_arch "${arch}"

        rm -f *.o

        ${CC} ${CFLAGS} -c -o lz4.o lz4.c
        ${CC} ${CFLAGS} -c -o lz4file.o lz4file.c
        ${CC} ${CFLAGS} -c -o lz4frame.o lz4frame.c
        ${CC} ${CFLAGS} -c -o lz4hc.o lz4hc.c
        ${CC} ${CFLAGS} -c -o xxhash.o xxhash.c

        ${AR} rcs liblz4-${PLATFORM}.a *.o
        cp liblz4-${PLATFORM}.a "${VENDOR_DIR}/lib/${CONFIGURATION}/liblz4-${PLATFORM}.a"
    done

    # Copy headers
    cp -v *.h "${VENDOR_DIR}/include/"

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

        cp -v build/lib/libb2.a "${VENDOR_DIR}/lib/${CONFIGURATION}/libb2-${PLATFORM}.a"
        make clean
    done

    # Copy headers
    cp -v build/include/* "${VENDOR_DIR}/include/"

    repo_exit
    fatten_lib b2
}

function buildARCHIVE() {
    repo_enter src/libarchive
    set_release $1

    mkdir output

    for arch in arm x86_64; do
        set_arch "${arch}"

        export CFLAGS="-I${VENDOR_DIR}/include/ ${CFLAGS}"
        export LDFLAGS="-L${VENDOR_DIR}/lib/ ${LDFLAGS}"

        /bin/sh build/autogen.sh
        ./configure ${CONFIGURE_FLAGS} --prefix="${PWD}/output/" --enable-static --disable-shared --host="${CHOST}" --disable-shared --disable-bsdtar --disable-bsdcat --disable-bsdcpio --disable-bsdunzip
        make clean

        ${MAKE}
        make install

        cp -v output/lib/libarchive.a "${VENDOR_DIR}/lib/${CONFIGURATION}/libarchive-${PLATFORM}.a"
        make clean
    done

    # Copy headers
    cp -v output/include/* "${VENDOR_DIR}/include/"

    repo_exit
    fatten_lib archive
}

# Call our builder functions

echo "Building libzstd..."
# Builds both Debug and Release
buildZSTD >logs/zstd.log 2>&1

echo "Building liblzma..."
buildLZMA Debug >logs/lzma-debug.log 2>&1
buildLZMA Release >logs/lzma-release.log 2>&1

echo "Building liblz4..."
buildLZ4 Debug >logs/lz4-debug.log 2>&1
buildLZ4 Release >logs/lz4-release.log 2>&1

echo "Building libb2..."
buildB2 Debug >logs/b2-debug.log 2>&1
buildB2 Release >logs/b2-release.log 2>&1

echo "Building libarchive..."
buildARCHIVE Debug >logs/libarchive-debug.log 2>&1
buildARCHIVE Release >logs/libarchive-release.log 2>&1

echo "Library results:"
find lib -type f -exec lipo -info {} \;

echo "Include results:"
find include -type f

echo "Build complete"
