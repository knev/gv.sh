#!/bin/bash
FILE=./src/se/mitm/base/Version.java

GIT_TAG=`git describe --tags --long`
DATE=`date +%m%d+%H%M`
VERSION=$GIT_TAG"-"$DATE


printf "package se.mitm.base;\n\n" > $FILE
printf "public class Version {\n" >> $FILE
printf "\tpublic static final String commit= \"$VERSION\";\n" >> $FILE
printf "}" >> $FILE

echo 'version '$VERSION' >> '$FILE
echo
NR=`echo $VERSION | sed 's/^v[0-9]*.[0-9]*-\([0-9]*\)-.*/\1/g'`
git log --oneline --decorate --max-count $((NR +1))
