#!/bin/bash

# https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself
# PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

FILE=./src/se/mitm/version/Version.java
DIR="$( dirname $FILE )" 
mkdir -p $DIR
git describe --tags > /dev/null || exit

GIT_TAG=`git describe --tags --long`
DATE=`date +%m%d+%H%M`
VERSION=$GIT_TAG"-"$DATE

printf "package se.mitm.version;

public class Version {
	public static final String commit= \"$VERSION\";

	public static void main(String[] arraystringArgs) {
		System.out.println(\"Man in the Middle of Minecraft (MiM): \" + commit);
	}
}" > $FILE

echo 'version '$VERSION' >> '$FILE

DOWN=./obfuscate/out/mim-downstream
mkdir -p $DOWN
cp -v $FILE $DOWN/. || exit 1

UP=./obfuscate/out/mim-upstream
mkdir -p $UP
cp -v $FILE $UP/. || exit 1

echo
NR=`echo $VERSION | sed 's/^v[0-9]*.[0-9]*-\([0-9]*\)-.*/\1/g'`
git log --oneline --decorate --max-count $((NR +1))
