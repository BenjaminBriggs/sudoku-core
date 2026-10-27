#!/bin/bash
# Downloads the HoDoKu release the tests are checked against, with its regression test library,
# and verifies both checksums.
# Usage: scripts/hodoku/fetch.sh [folder]   (default: the current folder)
# Then: SUDOKU_HODOKU_JAR=<folder>/HoDoKu.jar SUDOKU_HODOKU_REGLIB=<folder>/reglib-1.3.txt
set -euo pipefail

VERSION="2.6.0"
FOLDER="${1:-.}"
mkdir -p "$FOLDER"

fetch() {
    local url="$1" name="$2" sha256="$3"
    curl --fail --location --silent --show-error --output "$FOLDER/$name" "$url"
    echo "${sha256}  ${FOLDER}/${name}" | shasum -a 256 --check --status || {
        echo "${name}'s checksum doesn't match HoDoKu2 ${VERSION}" >&2
        rm -f "$FOLDER/$name"
        exit 1
    }
    echo "Saved ${FOLDER}/${name}"
}

fetch "https://github.com/wyzelli/HoDoKu/releases/download/${VERSION}/HoDoKu.jar" HoDoKu.jar \
    4a5f1d62330052f412493055e51327cbd16eff7d1c6a9a3a208bd470fea8f4ff
fetch "https://raw.githubusercontent.com/wyzelli/HoDoKu/${VERSION}/reglib-1.3.txt" reglib-1.3.txt \
    d37272f245ca6cfc5f3d4037998c80a1fd2ce996682dd7c2b3cc5aefa3ff7173
