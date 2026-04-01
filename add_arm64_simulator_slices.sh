#!/bin/bash
# Adds arm64 simulator slices to the three xcframeworks in Card.IO
# by retagging the device arm64 object files from iphoneos → iossimulator (platform 7)
# and updating each xcframework's Info.plist.

set -e

BASE="$(cd "$(dirname "$0")/Frameworks" && pwd)"
TMPDIR_BASE=$(mktemp -d)

# ---- library definitions: "<xcframework_name> <device_.a_name> <sim_.a_name>"
LIBS=(
  "libCardIO    libCardIO_device.a    libCardIO_sim.a"
  "libopencv_core    libopencv_core_device.a    libopencv_core_sim.a"
  "libopencv_imgproc    libopencv_imgproc_device.a    libopencv_imgproc_sim.a"
)

for ENTRY in "${LIBS[@]}"; do
  read -r LIB DEVICE_A SIM_A <<< "$ENTRY"

  XCFW="$BASE/$LIB.xcframework"
  DEVICE_DIR="$XCFW/ios-arm64"
  SIM_ARM64_DIR="$XCFW/ios-arm64-simulator"
  WORK="$TMPDIR_BASE/$LIB"

  echo ""
  echo ">>> Processing $LIB"

  mkdir -p "$WORK/objs_original" "$WORK/objs_retagged"

  # 1. Extract all object files from the device arm64 archive
  cd "$WORK/objs_original"
  ar x "$DEVICE_DIR/$DEVICE_A"
  echo "    Extracted $(ls | wc -l | tr -d ' ') object files"

  # 2. Retag each .o: LC_VERSION_MIN_IPHONEOS → LC_BUILD_VERSION(IOSSIMULATOR)
  for OBJ in *.o; do
    vtool -arch arm64 -set-build-version 7 15.0 15.0 -replace \
      -output "$WORK/objs_retagged/$OBJ" \
      "$WORK/objs_original/$OBJ"
  done
  echo "    Retagged all .o files to IOSSIMULATOR"

  # 3. Repack into a new static archive
  cd "$WORK/objs_retagged"
  libtool -static -o "$WORK/$SIM_A" *.o
  echo "    Packed new archive: $SIM_A"

  # 4. Create ios-arm64-simulator slice directory with headers + new .a
  mkdir -p "$SIM_ARM64_DIR"
  cp "$DEVICE_DIR/Headers" "$SIM_ARM64_DIR/Headers"
  cp "$WORK/$SIM_A" "$SIM_ARM64_DIR/$SIM_A"
  echo "    Created $SIM_ARM64_DIR"

  # 5. Update Info.plist — insert the new ios-arm64-simulator entry
  python3 - "$XCFW/Info.plist" "$SIM_A" <<'PYEOF'
import sys, plistlib, pathlib

plist_path = pathlib.Path(sys.argv[1])
sim_a_name = sys.argv[2]

with open(plist_path, "rb") as f:
    data = plistlib.load(f)

# Remove any existing arm64 simulator entry to avoid duplicates
data["AvailableLibraries"] = [
    lib for lib in data["AvailableLibraries"]
    if lib.get("LibraryIdentifier") != "ios-arm64-simulator"
]

data["AvailableLibraries"].append({
    "BinaryPath": sim_a_name,
    "HeadersPath": "Headers",
    "LibraryIdentifier": "ios-arm64-simulator",
    "LibraryPath": sim_a_name,
    "SupportedArchitectures": ["arm64"],
    "SupportedPlatform": "ios",
    "SupportedPlatformVariant": "simulator"
})

with open(plist_path, "wb") as f:
    plistlib.dump(data, f)

print(f"    Updated Info.plist — now {len(data['AvailableLibraries'])} slices:")
for lib in data["AvailableLibraries"]:
    print(f"      {lib['LibraryIdentifier']}  {lib['SupportedArchitectures']}")
PYEOF

done

rm -rf "$TMPDIR_BASE"
echo ""
echo "Done. All three xcframeworks now have ios-arm64-simulator slices."
