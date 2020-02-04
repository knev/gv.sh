#!/bin/bash
FILE=./src/se/mitm/version/Version.java

git describe --tags > /dev/null || exit

GIT_TAG=`git describe --tags --long`
DATE=`date +%m%d+%H%M`
VERSION=$GIT_TAG"-"$DATE

printf "package se.mitm.version;

public class Version {
	public static final String commit= \"$VERSION\";

	public static void main(String[] arraystringArgs) {
		System.out.println(\"MiTM-of-minecraft: \" + commit);
	}
}" > $FILE

echo 'version '$VERSION' >> '$FILE

DOWN=./obfuscate/out/mitm-downstream
mkdir -p $DOWN
cp -v $FILE $DOWN/.

UP=./obfuscate/out/mitm-upstream
mkdir -p $UP
cp -v $FILE $UP/.

echo
NR=`echo $VERSION | sed 's/^v[0-9]*.[0-9]*-\([0-9]*\)-.*/\1/g'`
git log --oneline --decorate --max-count $((NR +1))
