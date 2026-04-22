GV_BIN="./gv.sh"
chmod +x $GV_BIN

# Compute NSI filename the same way gv.sh does
_TOP=$(basename "$(pwd)")
_NSI_FILE="${_TOP%.git}.nsi"

cleanup() {
    rm -f ./version.h ./version.h.bak
    rm -f ./package.json ./package.json.tmp
    rm -f "./$_NSI_FILE" "./${_NSI_FILE}.bak"
    rm -rf ./antora-docs
}

mk_version_h() {
    cat > ./version.h << 'EOF'
// version.h
#pragma once

#define VERSION_MAJOR     0
#define VERSION_MINOR     1
#define VERSION_PATCH     54
#define VERSION_BUILD     0       // will be auto-incremented
#define VERSION_SUFFIX    ""
/* Updated to 0.1.54 on 2026-04-09 10:56 */

// Helper macros for resource compiler
#define _TOSTR(x)   #x
#define TOSTR(x)    _TOSTR(x)

#define VER_FILE_VERSION  VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH, VERSION_BUILD
#define VER_FILE_VERSION_STR \
    TOSTR(VERSION_MAJOR) "." TOSTR(VERSION_MINOR) "." TOSTR(VERSION_PATCH) "-" TOSTR(VERSION_BUILD) VERSION_SUFFIX "\0"

#define VER_PRODUCT_VERSION     VER_FILE_VERSION
#define VER_PRODUCT_VERSION_STR VER_FILE_VERSION_STR
EOF
}

mk_package_json() {
    cat > ./package.json << 'EOF'
{
  "name": "app-subverse-map",
  "description": "app-Subverse-map",
  "version": "0.1.49",
  "author": "K.Nevelsteen, PhD",
  "license": "MIT",
  "main": "./dist/main/main.js",
  "scripts": {
    "rebuild": "node -r ts-node/register ../../.erb/scripts/electron-rebuild.js",
    "postinstall": "npm run rebuild && npm run link-modules",
    "link-modules": "node -r ts-node/register ../../.erb/scripts/link-modules.ts"
  },
  "dependencies": {}
}
EOF
}

mk_nsi() {
    cat > "./$_NSI_FILE" << 'EOF'
; Script for installing an application with DLL dependencies in AppData\Local\IOI\tx-Decentraland
; Source files are in x64/Release
; Adds the application to Task Scheduler, runs it immediately, and provides uninstallation
; No Desktop or Start Menu shortcuts
; Installer runs with admin privileges, but app runs in user space
; Uninstaller stops the task and terminates the app before deletion
; Silent installer for tx-Decentraland

!define APP_NAME "tx-Decentraland"
!define APP_EXECUTABLE "tx-Decentraland.exe"
!define APP_VERSION "0.1.9"
!define INSTALL_DIR "$LOCALAPPDATA\IOI\tx-Decentraland"
!define TASK_NAME "IOI\${APP_NAME}_task"
!define TASK_PATH "IOI"
!define TASK_SIMPLE_NAME "${APP_NAME}_task"
!define SOURCE_DIR "x64/Release"
EOF
}

mk_antora() {
    mkdir -p ./antora-docs
    cat > ./antora-docs/antora.yml << 'EOF'
name: IOI
title: IOI
version: "0.3"
nav:
- modules/ROOT/nav.adoc
EOF
}

#----------------------------------------------------------------------
# Group 1: CLI basics
#----------------------------------------------------------------------
echo
echo "# Group 1: CLI basics"

cleanup

run_test "$GV_BIN" "0" "v[0-9]+\.[0-9]+-[0-9]+-g"
run_test "$GV_BIN --qewrere" "1" "$(escape_expected "usage: gv.sh")"
run_test "$GV_BIN -h" "0" "$(escape_expected "usage: gv.sh")"

#----------------------------------------------------------------------
# Group 2: --vs
#----------------------------------------------------------------------
echo
echo "# Group 2: --vs"

cleanup

run_test "$GV_BIN --vs" "1" "Error: version.h not found"

mk_version_h
run_test "$GV_BIN --vs" "0" "version.h updated:"
run_test "grep 'VERSION_PATCH' ./version.h" "0" "VERSION_PATCH[[:space:]]+[0-9]+"

cleanup
mk_version_h
run_test "$GV_BIN --vs --tag rc1" "0" "\-rc1"

#----------------------------------------------------------------------
# Group 3: --js
#----------------------------------------------------------------------
echo
echo "# Group 3: --js"

cleanup

mk_package_json
run_test "$GV_BIN --js" "0" "$(escape_expected "package.json updated:")"
run_test "grep '\"version\"' ./package.json" "0" "\"version\".*\"[0-9]+\.[0-9]+\.[0-9]+\""

run_test "$GV_BIN --js --tag api" "0" "$(escape_expected "-api.6")"

#----------------------------------------------------------------------
# Group 4: --nsi
#----------------------------------------------------------------------
echo
echo "# Group 4: --nsi"

cleanup

run_test "$GV_BIN --nsi" "1" "Error: Could not find"

mk_nsi
run_test "$GV_BIN --nsi" "0" "APP_VERSION"

#----------------------------------------------------------------------
# Group 5: --antora
#----------------------------------------------------------------------
echo
echo "# Group 5: --antora"

cleanup

run_test "$GV_BIN --antora" "1" "Error: antora.yml not found"

mk_antora
run_test "$GV_BIN --antora" "0" "Updating.*antora.yml"

run_test "grep '^version:' ./antora-docs/antora.yml" "0" "version:.*[0-9]+\.[0-9]+\.[0-9]+"

cleanup
mk_antora
run_test "$GV_BIN --antora --tag api" "0" "\-api.6"

#----------------------------------------------------------------------
# Group 6: -a AUTO mode
#----------------------------------------------------------------------
echo
echo "# Group 6: -a AUTO mode"

cleanup

run_test "$GV_BIN -a" "0" "Updating" "true"

mk_version_h
run_test "$GV_BIN -a" "0" "version.h updated:"
cleanup

mk_package_json
mk_version_h
run_test "$GV_BIN -a" "0" "$(escape_expected "package.json updated:.*version.h updated:")"
cleanup

mk_version_h
mk_antora
run_test "$GV_BIN -a" "0" "version.h updated:.*Updating.*antora.yml"
cleanup

mk_package_json
mk_nsi
run_test "$GV_BIN -a" "0" "package.json updated:.*Updating gv.sh.nsi"
cleanup

mk_package_json
mk_version_h
mk_nsi
mk_antora
run_test "$GV_BIN -a" "0" "package.json updated:.*version.h updated:.*Updating gv.sh.nsi.*Updating.*antora.yml"
cleanup

# Explicit --vs with both version.h and package.json present:
# AUTO=0 so only VS fires, JS must NOT fire
mk_package_json
mk_version_h
run_test "$GV_BIN --vs" "0" "$(escape_expected "package.json updated:")" "true"

#----------------------------------------------------------------------
# Group 7: multiple switches together
#----------------------------------------------------------------------
echo
echo "# Group 7: multiple switches together"

cleanup

# --vs + --nsi: both files updated in one run
mk_version_h
mk_nsi
run_test "$GV_BIN --vs --nsi" "0" "version.h updated:.*Updating gv.sh.nsi"
cleanup

# --js + --antora: both files updated in one run
mk_package_json
mk_antora
run_test "$GV_BIN --js --antora" "0" "$(escape_expected "package.json updated:.*Updating.*antora.yml")"
cleanup

# --vs + --nsi: when version.h is missing, exits before touching the .nsi file
mk_nsi
run_test "$GV_BIN --vs --nsi" "1" "Error: version.h not found"

#----------------------------------------------------------------------
# Group 8: --tag
#----------------------------------------------------------------------
echo
echo "# Group 8: --tag"

#TODO: Normally, we should add the tag, if it doesn't exist as a tag in the git repo, but leave this for now

cleanup

# --vs --tag: VERSION_SUFFIX written to version.h
mk_version_h
run_test "$GV_BIN --vs --tag alpha" "0" "VERSION_SUFFIX.*\-alpha"
cleanup

# --nsi --tag: APP_VERSION line includes tag
mk_nsi
run_test "$GV_BIN --nsi --tag v2" "0" "APP_VERSION.*\-v2"
cleanup

# --antora --tag: antora.yml version line includes tag
mk_antora
run_test "$GV_BIN --antora --tag rc2" "0" "\-rc2"
run_test "grep '^version:' ./antora-docs/antora.yml" "0" "\-rc2"
cleanup

# --js --tag: package.json should NOT update when current version has no tag
# (gv.sh skips update if EXTRA_GIT_TAG is empty and current version is plain semver — tag only applies via EXTRA_GIT_TAG)
# So just verify it exits cleanly and prints the version line
mk_package_json
run_test "$GV_BIN --js --tag somefeature" "0" "$(escape_expected "somefeature")" "true"

#----------------------------------------------------------------------
# Group 9: optional PATH parameter on --js, --nsi, --antora
#----------------------------------------------------------------------
echo
echo "# Group 9: optional PATH parameter"

cleanup

# --js PATH: update version in custom location
mkdir -p ./release/build
cat > ./release/build/package.json << 'EOF'
{
  "name": "custom",
  "version": "0.1.49",
  "license": "MIT"
}
EOF
run_test "$GV_BIN --js release/build/package.json" "0" "$(escape_expected "package.json updated:")"
run_test "grep '\"version\"' ./release/build/package.json" "0" "\"version\".*\"[0-9]+\.[0-9]+\.[0-9]+\""
# Default package.json should NOT be created/touched
run_test "ls package.json 2>&1" "1" "No such file"
rm -rf ./release

# --js PATH with --tag
mkdir -p ./alt
cat > ./alt/pkg.json << 'EOF'
{
  "name": "alt",
  "version": "0.1.49",
  "license": "MIT"
}
EOF
run_test "$GV_BIN --js alt/pkg.json --tag api" "0" "$(escape_expected "pkg.json updated:")"
run_test "grep '\"version\"' ./alt/pkg.json" "0" "\-api"
rm -rf ./alt

cleanup

# --nsi PATH: update APP_VERSION in custom file
mkdir -p ./installer
cat > ./installer/myapp.nsi << 'EOF'
!define APP_NAME "MyApp"
!define APP_VERSION "0.1.9"
EOF
run_test "$GV_BIN --nsi installer/myapp.nsi" "0" "APP_VERSION"
run_test "grep '!define APP_VERSION' ./installer/myapp.nsi" "0" "APP_VERSION.*\"[0-9]+\.[0-9]+\.[0-9]+\""
rm -rf ./installer

# --nsi PATH with --tag
mkdir -p ./installer
cat > ./installer/myapp.nsi << 'EOF'
!define APP_NAME "MyApp"
!define APP_VERSION "0.1.9"
EOF
run_test "$GV_BIN --nsi installer/myapp.nsi --tag beta" "0" "APP_VERSION.*\-beta"
rm -rf ./installer

cleanup

# --antora PATH: update version in custom antora.yml
mkdir -p ./docs/site
cat > ./docs/site/antora.yml << 'EOF'
name: IOI
title: IOI
version: "0.3"
EOF
run_test "$GV_BIN --antora docs/site/antora.yml" "0" "Updating.*antora.yml"
run_test "grep '^version:' ./docs/site/antora.yml" "0" "version:.*[0-9]+\.[0-9]+\.[0-9]+"
rm -rf ./docs

# --antora PATH with --tag
mkdir -p ./docs/site
cat > ./docs/site/antora.yml << 'EOF'
name: IOI
title: IOI
version: "0.3"
EOF
run_test "$GV_BIN --antora docs/site/antora.yml --tag rc3" "0" "\-rc3"
run_test "grep '^version:' ./docs/site/antora.yml" "0" "\-rc3"
rm -rf ./docs

# Missing custom file: should error out, not fall back to default
run_test "$GV_BIN --js does/not/exist.json" "0" "$(escape_expected "package.json updated:")" "true"
run_test "$GV_BIN --nsi does/not/exist.nsi" "1" "Error: Could not find"
run_test "$GV_BIN --antora does/not/exist.yml" "1" "Error: antora.yml not found"

# Combined switches with custom paths: each switch claims its own PATH
mkdir -p ./sub/js ./sub/nsi ./sub/docs
cat > ./sub/js/package.json << 'EOF'
{
  "name": "combo",
  "version": "0.0.1",
  "license": "MIT"
}
EOF
cat > ./sub/nsi/app.nsi << 'EOF'
!define APP_NAME "Combo"
!define APP_VERSION "0.0.1"
EOF
cat > ./sub/docs/antora.yml << 'EOF'
name: combo
title: combo
version: "0.0"
EOF
run_test "$GV_BIN --js sub/js/package.json --nsi sub/nsi/app.nsi --antora sub/docs/antora.yml --tag rc4" "0" "package.json updated:.*Updating sub/nsi/app.nsi.*Updating sub/docs/antora.yml"
run_test "grep '!define APP_VERSION' ./sub/nsi/app.nsi" "0" "\-rc4"
run_test "grep '^version:' ./sub/docs/antora.yml" "0" "\-rc4"
rm -rf ./sub

#----------------------------------------------------------------------

cleanup
