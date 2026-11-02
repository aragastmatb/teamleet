#!/bin/zsh
# tools/build_apk.sh: a signed Android APK of the last commit, in build/android/team1337.apk.
# Builds from a clean checkout of HEAD, so uncommitted edits don't get in. The version code is the
# commit count: every build installs over the one before.
# Needs JDK 17 and the Android SDK set in Godot's editor settings, and the release key in
# ~/.android-keys (team1337-release.txt says where it is and its password). Keep the key: an APK
# signed with another one won't install over the old.
set -e
ROOT=${0:A:h:h}
GODOT=~/Applications/Godot.app/Contents/MacOS/Godot
KEYS=~/.android-keys/team1337-release.txt
WT=$(mktemp -d)/team1337
cd $ROOT
git worktree add -q --detach $WT HEAD
trap "git -C $ROOT worktree remove --force $WT" EXIT
CODE=$(git rev-list --count HEAD)
sed -i '' "s/^version\/code=.*/version\/code=$CODE/; s/^version\/name=.*/version\/name=\"1.0.$CODE\"/" $WT/export_presets.cfg
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$(grep '^keystore=' $KEYS | cut -d= -f2-)
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=$(grep '^alias=' $KEYS | cut -d= -f2-)
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$(grep '^password=' $KEYS | cut -d= -f2-)
$GODOT --headless --path $WT --import > /dev/null 2>&1 || true
mkdir -p $WT/build/android
$GODOT --headless --path $WT --export-release Android build/android/team1337.apk 2>&1 | grep -iE "error|fail" || true
mkdir -p $ROOT/build/android
mv $WT/build/android/team1337.apk $ROOT/build/android/team1337.apk
echo "build/android/team1337.apk, version 1.0.$CODE"
