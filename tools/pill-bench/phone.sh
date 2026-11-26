#!/bin/sh
# The scan photos a debug build of the app keeps (ScanPhotoKeeper), on the iPhone
# connected to this Mac. The phone has to be unlocked to open the app.
#   phone.sh start           opens the app keeping every scan's photo, until it is closed,
#                            sending nothing to the pill checker (every pill comes out unknown)
#   phone.sh pull <folder>   copies the kept photos and their .json into <folder>
#   phone.sh clear           opens the app once, deleting the kept photos
# PHONE=<name or UDID> picks the phone when more than one is connected.
set -eu
app=com.genichihashi.MyPharmacist
phone="${PHONE:-$(xcrun devicectl list devices --json-output - 2>/dev/null | python3 -I -c '
import json, sys
for device in json.load(sys.stdin)["result"]["devices"]:
    hardware, connection = device.get("hardwareProperties", {}), device.get("connectionProperties", {})
    if hardware.get("reality") == "physical" and hardware.get("deviceType") == "iPhone" and connection.get("tunnelState") == "connected":
        print(hardware["udid"])
        break
')}"
if [ -z "$phone" ]; then
    echo "No iPhone connected." >&2
    exit 1
fi

case "${1:-}" in
start)
    xcrun devicectl device process launch --device "$phone" --terminate-existing "$app" -- -keepScanPhotos -noCloud
    ;;
pull)
    folder="${2:?phone.sh pull <folder>}"
    mkdir -p "$folder"
    xcrun devicectl device copy from --device "$phone" --domain-type appDataContainer --domain-identifier "$app" \
        --source Documents/ScanPhotos --destination "$folder"
    echo "$(ls "$folder" | grep -c '\.jpg$') photos in $folder"
    ;;
clear)
    xcrun devicectl device process launch --device "$phone" --terminate-existing "$app" -- -clearScanPhotos
    ;;
*)
    sed -n 2,8p "$0"
    exit 2
    ;;
esac
