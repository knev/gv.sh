#!/bin/bash

# https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself
# PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# Use a Windows-compatible way to get the script's directory
# PWD=$(cd "$(dirname "$0")" && pwd)

usage() {
	echo "usage: $(basename $0) [--js|--java|--vs] [--agv [--fix]] [--tag TAG] [-h | --help]"
	echo
	echo "Examples:"
	echo "    gv --js --tag api // package.json=  \"version\": \"0.0.21-api.5\" "
	echo
}

error_exit() {
	echo "FAIL!"
	exit 1
}

FILE=./src/se/mitm/version/Version.java

PRINT=1
JAVASCRIPT=0
JAVA=0
VS=0
APPLE_GENERIC_VER=0
FIX=0
COLLECT=0
OBF_OUT=./obfuscate/out
OUT=$OBF_OUT
HELP=0
while [ "$1" != "" ]; do
	case $1 in
		--tag )					shift
								TAG=$1
								;;
		--print )				PRINT=1
								;;
		--js)					JAVASCRIPT=1
								;;
		--java)					JAVA=1
								;;
		--vs)					VS=1
								;;
		--agv)					APPLE_GENERIC_VER=1
								;;
		--fix)					FIX=1
								;;
		--collect )				COLLECT=1
								;;
		--out )					shift
								OUT=$1
								;;
		-h | --help )			(( !$APPLE_GENERIC_VER )) && { usage && exit 0; }
								HELP=1
								;;
		* )						usage
								exit 1
	esac
	shift
done

#--------------------------------------------------------------------------------------------------------------------------------

collect()
{
	FILE_VERSION=$(cat "$FILE" | grep -m1 commit | sed 's/.*commit=[ ]*\"\([^"]*\)\";/\1/' | sed 's/\(v[0-9]*.[0-9]*-[0-9]*\)-.*$/\1/')
	mkdir -p "$OUT/$FILE_VERSION" || error_exit
	echo "OUT='$OUT/$FILE_VERSION'"

	for SIDE in "down" "up"
	do
		MiM_VERSION=$(java -classpath "./obfuscate/out/mim-${SIDE}stream/mim-${SIDE}stream.jar" se.mitm.version.Version | sed 's/Man in the Middle of Minecraft (MiM): \(v[0-9]*.[0-9]*-[0-9]*\)-.*$/\1/')
		
		[ "$MiM_VERSION" != "$FILE_VERSION" ] && { echo "Build version does not match Version file."; error_exit; }

		cp -v "$OBF_OUT/mim-${SIDE}stream/mim-${SIDE}stream.jar" "$OUT/$FILE_VERSION/." || error_exit

		BASENAME=$(basename "$FILE")
		cp -v "$FILE" "$OUT/${BASENAME%.*}-mim-${SIDE}stream.${BASENAME##*.}" || exit 1
	done

	cp -v ./res/patches/forge-broken-packets-no-lwjgl.patch "$OUT/$FILE_VERSION/."

	exit 0
}

#--------------------------------------------------------------------------------------------------------------------------------

GIT_TAG=$(git describe --tags --long --match "v[0-9]*.[0-9]*")
# [ -n "$TAG" ] && EXTRA_GIT_TAG=$(git tag --sort=-version:refname --list "$TAG.[0-9]*.[0-9]*" | head -n 1)
[ -n "$TAG" ] && EXTRA_GIT_TAG=$(git tag --sort=-version:refname --list "$TAG.[0-9]*" "$TAG.[0-9]*.[0-9]*" | head -n 1)

MAJOR_NR=$(echo "$GIT_TAG" | sed 's/^v\([0-9]*\).[0-9]*-[0-9]*-.*/\1/g')
MINOR_NR=$(echo "$GIT_TAG" | sed 's/^v[0-9]*.\([0-9]*\)-[0-9]*-.*/\1/g')
PATCH_NR=$(echo "$GIT_TAG" | sed 's/^v[0-9]*.[0-9]*-\([0-9]*\)-.*/\1/g')
PLUS1=$((PATCH_NR + 1))
NEWVER="$MAJOR_NR.$MINOR_NR.$PLUS1"

if (( $JAVASCRIPT )); then
	FILE='package.json'

	# https://superuser.com/questions/112834/how-to-match-whitespace-in-sed/637913#637913
	# https://stackoverflow.com/questions/7573368/in-place-edits-with-sed-on-os-x/7573438#7573438
	# Use sed without -i '' (not supported in Git Bash) and redirect to a temp file

    # Extract current version from package.json
    CURRENT_VERSION=$(grep -m1 '"version"' "$FILE" | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

    if [ -n "$EXTRA_GIT_TAG" ]; then
        # If EXTRA_GIT_TAG is not empty, update to NEWVER-EXTRA_GIT_TAG
        NEW_VERSION="$NEWVER-$EXTRA_GIT_TAG"
        sed 's/^\([[:space:]]*"version"[[:space:]]*:[[:space:]]*"\)[0-9]*.[0-9]*.[0-9]*\(-[^"]*\)\?\("[[:space:]]*,[[:space:]]*\)$/\1'"$NEW_VERSION"'\3/' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
    else
        # If EXTRA_GIT_TAG is empty, check for extra tag in current version
        if [[ "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            # No extra tag in current version, update to NEWVER
            sed 's/^\([[:space:]]*"version"[[:space:]]*:[[:space:]]*"\)[0-9]*.[0-9]*.[0-9]*\("[[:space:]]*,[[:space:]]*\)$/\1'"$NEWVER"'\2/' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
        fi
        # If current version has an extra tag, do nothing
    fi
fi

if (( $PRINT )); then
	echo "$GIT_TAG"
	[ -n "$TAG" ] && echo "-$EXTRA_GIT_TAG"
	if (( $JAVASCRIPT )); then
		echo -e "$FILE=$(grep -m1 version "$FILE")\n"
	elif (( $JAVA )); then
		echo "$FILE= version $(grep -m1 commit "$FILE" | sed 's/.*commit=[ ]*\"\([^"]*\)\";/\1/')"
	fi
fi

if (( $APPLE_GENERIC_VER )); then

	if (( $HELP )); then
		echo
		echo "In order for AGV to work ... "
		echo "Targets | Build Settings | Versioning "
		echo " - \"Current Project Version\" = set it to 0 "
		echo " - (optional?) \"Versioning System\" = Apple Generic "
		echo "Add an Info.plist "
		echo " - add \"Bundle identifier\" "
		echo " - add \"Bundle version\" "
		echo " - add \"Bundle version string (short)\" "
		echo "this script will give the ERROR: Cannot find \"\$(SRCROOT)/Info.plist\" "
		echo " - edit the <PROJECT_NAME>.xcodeproj/project.pbxproj file and remove [ \$(SRCROOT)/ ], leaving just [ Info.plist ] "
		echo

		exit 0
	fi

	if (( $FIX )); then
		PRJ_NAME=$(basename "$(find . -type d -name "*.xcodeproj")" .xcodeproj)
		echo
		echo "$PRJ_NAME.xcodeproj/project.pbxproj:"
		echo "<<<<<<<"
		grep "INFOPLIST_FILE" "$PRJ_NAME.xcodeproj/project.pbxproj" | sed -E 's/^[[:space:]]*/  /'
		echo "======="
		sed 's/\([[:space:]]*\)INFOPLIST_FILE[[:space:]]*=[[:space:]]*"\$(SRCROOT)\//\1INFOPLIST_FILE = "/' "$PRJ_NAME.xcodeproj/project.pbxproj" > "$PRJ_NAME.xcodeproj/project.pbxproj.tmp" && mv "$PRJ_NAME.xcodeproj/project.pbxproj.tmp" "$PRJ_NAME.xcodeproj/project.pbxproj"
		grep "INFOPLIST_FILE" "$PRJ_NAME.xcodeproj/project.pbxproj" | sed -E 's/^[[:space:]]*/  /'
		echo ">>>>>>>"
	else
		#TODO
		# agvtool is macOS-specific and won't work on Windows/Git Bash
		echo "Warning: agvtool is not available on Windows. Skipping Apple Generic Versioning commands."

		#AGV=`agvtool what-version | grep "Found CFBundleShortVersionString" | sed 's/.*CFBundleShortVersionString of \"\([^"]*\)\".*/\1/' `
		#AGV=`agvtool what-version | tail -n 2 | sed 's/[ ]*\(v[0-9]*.[0-9]*-[0-9]*-[[:alnum:]]*\).*$/\1/'`
		#echo '['$AGV']'

		# https://developer.apple.com/library/archive/qa/qa1827/_index.html
		agvtool new-marketing-version $NEWVER		# set the short version
		agvtool next-version -all					# update the build number, -all is required to update the Info.plist
	fi
	
fi

#─────────────────────────────────────────────────────────────
# --vs : Update version.h for Visual Studio C++ project
#─────────────────────────────────────────────────────────────

if (( $VS )); then
    VERSION_H="./version.h"          # ← Change this path if needed!

    if [ ! -f "$VERSION_H" ]; then
        echo "Error: version.h not found at $VERSION_H"
        exit 1
    fi

	echo
    echo "Updating version.h → $NEWVER${EXTRA_GIT_TAG:+"-$EXTRA_GIT_TAG"}"

    # Backup first (good practice)
    cp "$VERSION_H" "$VERSION_H.bak" || exit 1

    # Update MAJOR / MINOR / PATCH
    sed -i.bak \
        -e "s/^#define[[:space:]]\+VERSION_MAJOR[[:space:]]\+[0-9]\+/#define VERSION_MAJOR     $MAJOR_NR/" \
        -e "s/^#define[[:space:]]\+VERSION_MINOR[[:space:]]\+[0-9]\+/#define VERSION_MINOR     $MINOR_NR/" \
        -e "s/^#define[[:space:]]\+VERSION_PATCH[[:space:]]\+[0-9]\+/#define VERSION_PATCH     $PLUS1/" \
        "$VERSION_H"

    # Decide what to do with VERSION_BUILD
    # Option 1: Always reset to 0 on version bump (most common for semver style)
    # Option 2: Increment current build number (like CI build counter)
    # Option 3: Use git commit count or date-based

    # Recommended: reset to 0 + optional suffix in comment or string
    sed -i.bak \
        -e 's/^#define[[:space:]]\+VERSION_BUILD[[:space:]]\+[0-9]\+/#define VERSION_BUILD     0/' \
        "$VERSION_H"

    # Optional: add a comment with the full tag / date
    DATE=$(date +"%Y-%m-%d %H:%M")
    sed -i.bak \
        -e "/#define[[:space:]]\+VERSION_BUILD/a\\
/* Updated to $NEWVER${EXTRA_GIT_TAG:+"-$EXTRA_GIT_TAG"} on $DATE */" \
        "$VERSION_H"

    # Clean up backup files created by sed -i.bak (macOS & some Linux)
    rm -f "${VERSION_H}.bak"

    echo "version.h updated:"
    grep -E 'VERSION_(MAJOR|MINOR|PATCH|BUILD)' "$VERSION_H"
fi

# if [[ $COLLECT == 1 ]]; then
# 	collect || error_exit
# fi

# DIR="$( dirname $FILE )" 
# mkdir -p $DIR
# git describe --tags > /dev/null || exit

# DATE=`date +%m%d+%H%M`
# VERSION=$GIT_TAG"-"$DATE

# printf "package se.mitm.version;

# public class Version {
# 	public static final String commit= \"$VERSION\";

# 	public static void main(String[] arraystringArgs) {
# 		System.out.println(\"Man in the Middle of Minecraft (MiM): \" + commit);
# 	}
# }" > $FILE

# echo 'version '$VERSION' >> '$FILE

# echo
# NR=`echo $VERSION | sed 's/^v[0-9]*.[0-9]*-\([0-9]*\)-.*/\1/g'`
# git log --oneline --decorate --max-count $((NR +1))

