#!/bin/sh
# Builds pill-bench for this Mac from this folder and the app's own pill-finding files
# (compiled as they are, not copied), so the bench measures exactly what the app does.
# The tool lands in build/pill-bench (git-ignored). Then, from the project folder:
#   build/pill-bench synth <folder>          made-up photos to try it on
#   build/pill-bench run <photos folder>     results.csv, report.html, a picture per photo
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
app="$root/MyPharmacist"
mkdir -p "$root/build"

# The app's build settings that change how Swift reads its files.
xcrun swiftc -O -parse-as-library -swift-version 6 \
    -default-isolation MainActor \
    -enable-upcoming-feature NonisolatedNonsendingByDefault \
    -enable-upcoming-feature InferIsolatedConformances \
    -enable-upcoming-feature MemberImportVisibility \
    -target arm64-apple-macos14.0 \
    -module-name PillBench \
    "$here"/*.swift \
    "$app/PillVision/PillFinder.swift" \
    "$app/PillVision/PillFinder+Vision.swift" \
    "$app/PillVision/SubjectMask.swift" \
    "$app/PillVision/PillDetector.swift" \
    "$app"/Core/Identification/*.swift \
    "$app/Core/Capture/BitmapContext.swift" \
    "$app/Core/Capture/CameraFraming.swift" \
    "$app/Core/Capture/CapturedPhoto.swift" \
    "$app/Core/Capture/PhotoSize.swift" \
    "$app/Core/Verification/CheckLimits.swift" \
    "$app/Core/Log.swift" \
    -o "$root/build/pill-bench"
echo "Built $root/build/pill-bench"
