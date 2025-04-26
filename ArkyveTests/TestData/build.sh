#!/bin/bash

set -eu

if [ "$(basename ${PWD})" != "TestData" ]; then
    echo "ERROR: You need to be in the TestData directory to run this"
    exit 1
fi

NAME="helloworld"
SRC="helloworld"
ARCHIVES="${PWD}/archives"

brew bundle install

rm -rfv "${ARCHIVES}/"
mkdir -p "${ARCHIVES}"

tar czf "${ARCHIVES}/${NAME}.tar.gz" "${SRC}"
tar cjf "${ARCHIVES}/${NAME}.tar.bz2" "${SRC}"
zip -r "${ARCHIVES}/${NAME}.zip" "${SRC}"
7z a "${ARCHIVES}/${NAME}.7z" "${SRC}"
find "${SRC}" -print -depth | cpio -ov > "${ARCHIVES}/${NAME}.cpio"
mkisofs -o "${ARCHIVES}/${NAME}.iso" "${SRC}"
find "${SRC}" -type f -print0 | xargs -0 ar rc "${ARCHIVES}/${NAME}.a"
lha a "${ARCHIVES}/${NAME}.lha" "${SRC}"
xar -c -f "${ARCHIVES}/${NAME}.xar" "${SRC}"
rar a "${ARCHIVES}/${NAME}.rar" "${SRC}"

