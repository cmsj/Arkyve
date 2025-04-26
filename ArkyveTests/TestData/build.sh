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

rm -rf "${ARCHIVES}/*"
mkdir -p "${ARCHIVES}"

tar czf "${ARCHIVES}/${NAME}.tar.gz" "${SRC}"
tar cjf "${ARCHIVES}/${NAME}.tar.bz2" "${SRC}"
zip -r "${ARCHIVES}/${NAME}.zip" "${SRC}"
7z a "${ARCHIVES}/${NAME}.7z" "${SRC}"
