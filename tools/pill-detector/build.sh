#!/bin/sh
# Builds the pill detector's trainer for this Mac (Create ML). The tool lands in
# build/pill-detector (git-ignored). Then, from the project folder:
#   build/pill-bench train-data build/detector/train …     training pictures (see pill-bench)
#   build/pill-detector build/detector/train build/detector/PillDetector.mlmodel 3000
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
mkdir -p "$root/build"
xcrun swiftc -O -parse-as-library -swift-version 6 -target arm64-apple-macos14.0 \
    "$here"/*.swift -o "$root/build/pill-detector"
echo "Built $root/build/pill-detector"
