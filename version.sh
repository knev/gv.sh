#!/bin/bash
FILE=./src/se/mitm/base/Version.java

VERSION=`git describe --tags --long`

printf "package se.mitm.base;\n\n" > $FILE
printf "public class Version {\n" >> $FILE
printf "\tpublic static final String commit= \"$VERSION\";\n" >> $FILE
printf "}" >> $FILE

echo 'version '$VERSION' >> '$FILE
echo
git log --oneline --decorate
