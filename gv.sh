#!/bin/bash

# https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself
# PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

error_exit() {
	echo "FAIL!"
	exit 1
}

FILE=./src/se/mitm/version/Version.java

PRINT=1
JAVASCRIPT=0
APPLE_GENERIC_VER=0
JAVA=0
COLLECT=0
OBF_OUT=./obfuscate/out
OUT=$OBF_OUT
while [ "$1" != "" ]; do
	case $1 in
		--print )				PRINT=1
								;;
		--js)					JAVASCRIPT=1
								;;
		--java)					JAVA=1
								;;
		--agv)					APPLE_GENERIC_VER=1
								;;
		--collect )				COLLECT=1
								;;
		--out )					shift
								OUT=$1
								;;
		* )						exit 1
	esac
	shift
done

#--------------------------------------------------------------------------------------------------------------------------------

collect()
{
	FILE_VERSION=`cat $FILE | grep -m1 commit | sed 's/.*commit=[ ]*\"\([^"]*\)\";/\1/' | sed 's/\(v[0-9]*.[0-9]*-[0-9]*\)-.*$/\1/'`
	mkdir -p $OUT/$FILE_VERSION || error_exit
	echo "OUT='$OUT/$FILE_VERSION'"

	for SIDE in "down" "up"
	do
		MiM_VERSION=`java -classpath ./obfuscate/out/mim-$SIDE'stream'/mim-$SIDE'stream.jar' se.mitm.version.Version | sed 's/Man in the Middle of Minecraft (MiM): \(v[0-9]*.[0-9]*-[0-9]*\)-.*$/\1/'`
		
		[ $MiM_VERSION != $FILE_VERSION ] && { echo "Build version does not match Version file."; error_exit; }

		cp -v $OBF_OUT/mim-$SIDE'stream'/mim-$SIDE'stream'.jar $OUT/$FILE_VERSION/. || error_exit

		BASENAME=${FILE##*/}
		cp -v $FILE $OUT/${BASENAME%.*}-mim-$SIDE'stream'.${BASENAME##*.} || exit 1
	done

	cp -v ./res/patches/forge-broken-packets-no-lwjgl.patch $OUT/$FILE_VERSION/.

	exit 0
}


#--------------------------------------------------------------------------------------------------------------------------------

GIT_TAG=`git describe --tags --long`
MAJOR_NR=`echo $GIT_TAG | sed 's/^v\([0-9]*\).[0-9]*-[0-9]*-.*/\1/g'`
MINOR_NR=`echo $GIT_TAG | sed 's/^v[0-9]*.\([0-9]*\)-[0-9]*-.*/\1/g'`
PATCH_NR=`echo $GIT_TAG | sed 's/^v[0-9]*.[0-9]*-\([0-9]*\)-.*/\1/g'`
PLUS1=$((PATCH_NR +1))
NEWVER=$MAJOR_NR'.'$MINOR_NR'.'$PLUS1

if [[ $JAVASCRIPT == 1 ]]; then
	FILE='package.json'

	# https://superuser.com/questions/112834/how-to-match-whitespace-in-sed/637913#637913
	# https://stackoverflow.com/questions/7573368/in-place-edits-with-sed-on-os-x/7573438#7573438
	sed -i '' 's/^\([[:space:]]*"version"[[:space:]]*:[[:space:]]*"\)[0-9]*.[0-9]*.[0-9]*\("[[:space:]]*,[[:space:]]*\)$/\1'$NEWVER'\2/' ${FILE}
fi

if [[ $PRINT == 1 ]]; then
	echo $GIT_TAG
	if [[ $JAVASCRIPT == 1 ]]; then
		echo -e $FILE'='`cat ${FILE} | grep -m1 version`'\n'
	elif [[ $JAVA == 1 ]]; then
		echo $FILE'= version '`cat $FILE | grep -m1 commit | sed 's/.*commit=[ ]*\"\([^"]*\)\";/\1/' `
	fi
fi

if [[ $APPLE_GENERIC_VER == 1 ]]; then
	#AGV=`agvtool what-version | grep "Found CFBundleShortVersionString" | sed 's/.*CFBundleShortVersionString of \"\([^"]*\)\".*/\1/' `
	#AGV=`agvtool what-version | tail -n 2 | sed 's/[ ]*\(v[0-9]*.[0-9]*-[0-9]*-[[:alnum:]]*\).*$/\1/'`
	#echo '['$AGV']'

	# In order for AGV to work ...
	# Targets | Build Settings | Versioning 
	#  - "Current Project Version" = set it to 0
	#  - (optional?) "Versioning System" = Apple Generic
	# Add an Info.plist 
	#  - add "Bundle identifier" = $(PRODUCT_BUNDLE_IDENTIFIER) and add it in Settings ...
	#  - add "Bundle version"
	#  - add "Bundle version string (short)"
	# this script will give the ERROR: Cannot find "$(SRCROOT)/Info.plist"
	#  - edit the .xcodeproj/project.pbxproj file and remove [ $(SRCROOT)/ ], leaving just [ Info.plist ]

	# https://developer.apple.com/library/archive/qa/qa1827/_index.html
	agvtool new-marketing-version $NEWVER		# set the short version
	agvtool next-version -all					# update the build number, -all is required to update the Info.plist
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

