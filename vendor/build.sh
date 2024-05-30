#!/bin/bash

set -eu

export MAKE="make -j12"
export MACOSX_DEPLOYMENT_TARGET="14.0"
export SDK="macosx"

rm -rf include/* lib/*
mkdir -p include
mkdir -p lib/Debug
mkdir -p lib/Release

# libzstd
function buildZSTD() {
    pushd src/zstd
    rm -rf build-cmake-{debug,release}

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
    popd
}

# liblzma
function buildLZMA() {

    export CC=$(xcrun --find --sdk ${SDK} clang)
    export CXX=$(xcrun --find --sdk ${SDK} clang++)
    export CPP=$(xcrun --find --sdk ${SDK} cpp)

    if [ "$1" == "Debug" ]; then
        export CONFIGURATION="Debug"
        export CONFIGURE_FLAGS="--enable-debug"
        export OPT_FLAGS="-O0 -g -DDEBUG"
    else 
        export CONFIGURATION="Release"
        export CONFIGURE_FLAGS=""
        export OPT_FLAGS="-O3"
    fi

    pushd src/xz

    # Build ARM first
    export ARCH_FLAGS="-arch arm64"
    export HOST_FLAGS="${ARCH_FLAGS} -isysroot $(xcrun --sdk ${SDK} --show-sdk-path)"
    export PLATFORM="arm"
    export CHOST="arm-apple-darwin"
    export CFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
    export CXXFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
    export LD_FLAGS="${HOST_FLAGS}"

    ./autogen.sh
    ./configure ${CONFIGURE_FLAGS} --disable-xz --disable-xzdec --disable-lzma-links --disable-lzmainfo --disable-doc --prefix="${PWD}/build/" --enable-static --disable-shared --host="${CHOST}"
    pushd src/liblzma
    make clean
    ${MAKE}

    cp .libs/liblzma.a "../../../../lib/${CONFIGURATION}/liblzma-${PLATFORM}.a"
    make clean
    popd

    # Now build x86_64
    export ARCH_FLAGS="-arch x86_64"
    export HOST_FLAGS="${ARCH_FLAGS} -isysroot $(xcrun --sdk ${SDK} --show-sdk-path)"
    export PLATFORM="x86_64"
    export CHOST="x86_64-apple-darwin"
    export CFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
    export CXXFLAGS="${CFLAGS}"
    export LD_FLAGS="${HOST_FLAGS}"

    ./autogen.sh
    ./configure ${CONFIGURE_FLAGS} --disable-xz --disable-xzdec --disable-lzma-links --disable-lzmainfo --disable-doc --prefix="${PWD}/build/" --enable-static --disable-shared --host="${CHOST}"
    pushd src/liblzma
    make clean
    ${MAKE}

    cp .libs/liblzma.a "../../../../lib/${CONFIGURATION}/liblzma-${PLATFORM}.a"
    make clean
    popd

    # Copy headers
    cp src/liblzma/api/lzma.h ../../include/
    cp -r src/liblzma/api/lzma ../../include/

    popd

    lipo lib/${CONFIGURATION}/liblzma-arm.a lib/${CONFIGURATION}/liblzma-x86_64.a -create -output lib/${CONFIGURATION}/liblzma.a
    rm -f lib/${CONFIGURATION}/liblzma-*.a
}

function buildLZ4() {
    pushd src/lz4/lib

    export CC=$(xcrun --find --sdk ${SDK} clang)
    export AR=$(xcrun --find --sdk ${SDK} ar)

    if [ "$1" == "Debug" ]; then
        export CONFIGURATION="Debug"
        export OPT_FLAGS="-O0 -g -DDEBUG"
    else
        export CONFIGURATION="Release"
        export OPT_FLAGS="-O3"
    fi

    # Build ARM first
    export ARCH_FLAGS="-arch arm64"
    export HOST_FLAGS="${ARCH_FLAGS} -isysroot $(xcrun --sdk ${SDK} --show-sdk-path)"
    export PLATFORM="arm"
    export CHOST="arm-apple-darwin"
    export CFLAGS="-c -fPIC ${HOST_FLAGS} ${OPT_FLAGS}"
    export LD_FLAGS="${HOST_FLAGS}"

    rm -f *.o

    ${CC} ${CFLAGS} -o lz4.o lz4.c
    ${CC} ${CFLAGS} -o lz4file.o lz4file.c
    ${CC} ${CFLAGS} -o lz4frame.o lz4frame.c
    ${CC} ${CFLAGS} -o lz4hc.o lz4hc.c
    ${CC} ${CFLAGS} -o xxhash.o xxhash.c

    ${AR} r liblz4-${PLATFORM}.a *.o
    cp liblz4-${PLATFORM}.a ../../../lib/${CONFIGURATION}/liblz4-${PLATFORM}.a

    # Now build x86_64
    export ARCH_FLAGS="-arch x86_64"
    export HOST_FLAGS="${ARCH_FLAGS} -isysroot $(xcrun --sdk ${SDK} --show-sdk-path)"
    export PLATFORM="x86_64"
    export CHOST="x86_64-apple-darwin"
    export CFLAGS="-c -fPIC ${HOST_FLAGS} ${OPT_FLAGS}"
    export LD_FLAGS="${HOST_FLAGS}"

    rm -f *.o

    ${CC} ${CFLAGS} -o lz4.o lz4.c
    ${CC} ${CFLAGS} -o lz4file.o lz4file.c
    ${CC} ${CFLAGS} -o lz4frame.o lz4frame.c
    ${CC} ${CFLAGS} -o lz4hc.o lz4hc.c
    ${CC} ${CFLAGS} -o xxhash.o xxhash.c

    ${AR} r liblz4-${PLATFORM}.a *.o
    cp liblz4-${PLATFORM}.a ../../../lib/${CONFIGURATION}/liblz4-${PLATFORM}.a

    # Copy headers
    cp *.h ../../../include/

    popd

    lipo lib/${CONFIGURATION}/liblz4-arm.a lib/${CONFIGURATION}/liblz4-x86_64.a -create -output lib/${CONFIGURATION}/liblz4.a
    rm -f lib/${CONFIGURATION}/liblz4-*.a
}

# libb2
function buildB2() {

    export CC=$(xcrun --find --sdk ${SDK} clang)
    export CXX=$(xcrun --find --sdk ${SDK} clang++)
    export CPP=$(xcrun --find --sdk ${SDK} cpp)

    if [ "$1" == "Debug" ]; then
        export CONFIGURATION="Debug"
        export CONFIGURE_FLAGS="--enable-debug"
        export OPT_FLAGS="-O0 -g -DDEBUG"
    else 
        export CONFIGURATION="Release"
        export CONFIGURE_FLAGS=""
        export OPT_FLAGS="-O3"
    fi

    pushd src/libb2

    # Build ARM first
    export ARCH_FLAGS="-arch arm64"
    export HOST_FLAGS="${ARCH_FLAGS} -isysroot $(xcrun --sdk ${SDK} --show-sdk-path)"
    export PLATFORM="arm"
    export CHOST="arm-apple-darwin"
    export CFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
    export CXXFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
    export LD_FLAGS="${HOST_FLAGS}"

    ./autogen.sh
    ./configure ${CONFIGURE_FLAGS} --prefix="${PWD}/build/" --enable-static --disable-shared --host="${CHOST}"
    make clean
    ${MAKE}
    make install

    cp build/lib/libb2.a "../../lib/${CONFIGURATION}/libb2-${PLATFORM}.a"
    make clean

    # Now build x86_64
    export ARCH_FLAGS="-arch x86_64"
    export HOST_FLAGS="${ARCH_FLAGS} -isysroot $(xcrun --sdk ${SDK} --show-sdk-path)"
    export PLATFORM="x86_64"
    export CHOST="x86_64-apple-darwin"
    export CFLAGS="${HOST_FLAGS} ${OPT_FLAGS}"
    export CXXFLAGS="${CFLAGS}"
    export LD_FLAGS="${HOST_FLAGS}"

    ./autogen.sh
    ./configure ${CONFIGURE_FLAGS} --prefix="${PWD}/build/" --enable-static --disable-shared --host="${CHOST}"
    make clean
    ${MAKE}
    make install

    cp build/lib/libb2.a "../../lib/${CONFIGURATION}/libb2-${PLATFORM}.a"
    make clean

    # Copy headers
    cp build/include/* ../../include/

    popd

    lipo lib/${CONFIGURATION}/libb2-arm.a lib/${CONFIGURATION}/libb2-x86_64.a -create -output lib/${CONFIGURATION}/libb2.a
    rm -f lib/${CONFIGURATION}/libb2-*.a
}

# Call our builder functions

buildZSTD

buildLZMA Debug
buildLZMA Release

buildLZ4 Debug
buildLZ4 Release

buildB2 Debug
buildB2 Release

