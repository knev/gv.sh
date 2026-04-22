# gv.sh

A git-tag-driven version bumper. Reads `git describe` on the current repo, computes the next patch version, and writes it into one or more project files (`package.json`, `version.h`, NSIS `.nsi`, Antora `antora.yml`).

## Install

```sh
make install
```

Installs `gv.sh` into your `PATH` as `gv` (see `Makefile`).

## How the version is computed

```
GIT_TAG = git describe --tags --long --match "v[0-9]*.[0-9]*"
        → e.g.  v0.1-54-gabc1234
MAJOR.MINOR.PATCH = 0.1.54
NEWVER            = 0.1.55           # PATCH + 1
```

If `--tag TAG` is passed, `gv` additionally looks up the most recent tag matching `TAG.[0-9]*` / `TAG.[0-9]*.[0-9]*` and appends it as a suffix where the target format supports it.

## Usage

```
gv [-a] [--js [PATH]]... [--vs [PATH]]... [--nsi [PATH]]... [--antora [PATH]]... [--agv [--fix]] [--tag TAG] [-h | --help]
```

### Target switches

Each target switch can be repeated, with or without a PATH. Without a PATH, the switch targets the default file for that type; with a PATH, it targets that specific file. Repeating the same switch operates on multiple files in one run.

| Switch      | Default path                  | What it updates                                                                    |
|-------------|-------------------------------|------------------------------------------------------------------------------------|
| `--js`      | `./package.json`              | The top-level `"version"` field.                                                   |
| `--vs`      | `./version.h`                 | `VERSION_MAJOR`, `VERSION_MINOR`, `VERSION_PATCH`, `VERSION_BUILD`, `VERSION_SUFFIX` defines, plus a trailing `/* Updated to … */` comment. |
| `--nsi`     | `<repo-dir>.nsi`              | The `!define APP_VERSION "…"` line. Default filename is derived from the current directory (`.git` suffix stripped). |
| `--antora`  | `./antora-docs/antora.yml`    | The top-level `version:` field.                                                    |

### Repeating a switch

```sh
# Update the local package.json AND a sub-package
gv --js --js packages/entropy-cpp/package.json

# Plus antora in the same invocation
gv --js --js packages/entropy-cpp/package.json --antora

# Two distinct version.h files
gv --vs src/include/version.h --vs vendor/lib/version.h

# Two .nsi files, no default
gv --nsi installer/a.nsi --nsi installer/b.nsi
```

Supported form: `--js PATH --js PATH --js PATH`.
Not supported: `--js PATH PATH PATH` (subsequent bare paths are parsed as unknown args).

### Other switches

| Switch           | Effect                                                                                             |
|------------------|----------------------------------------------------------------------------------------------------|
| `-a`             | Auto mode. For each target whose switch was NOT given, if its default file exists, update it.      |
| `--tag TAG`      | Suffix handling. `--vs`/`--nsi`/`--antora` append `-TAG` to the written version. `--js` uses `TAG.N.M` git tags to form e.g. `0.0.21-api.5`. |
| `--agv`          | Apple Generic Versioning: runs `agvtool new-marketing-version` and `agvtool next-version -all`.    |
| `--agv --fix`    | Rewrite `INFOPLIST_FILE = "$(SRCROOT)/…"` to `INFOPLIST_FILE = "…"` in the `.xcodeproj/project.pbxproj`. |
| `--agv -h`       | Print setup notes for AGV instead of running it.                                                   |
| `--print`        | Print the computed git tag (on by default).                                                        |
| `-h`, `--help`   | Print usage.                                                                                       |

### AUTO-mode interaction with repeated switches

`-a` only fills in defaults for switches that weren't specified at all. If you pass `--js` (even once, with or without a PATH), `-a` will not additionally inject the default `./package.json` on your behalf — pass it explicitly as another `--js` if you want both.

## Examples

```sh
# Bump package.json
gv --js

# Bump package.json with a pre-release suffix pulled from git tags
gv --js --tag api
#   → "version": "0.0.21-api.5"

# Bump a version.h sitting elsewhere
gv --js release/build/package.json

# Bump both version.h and the .nsi installer in one shot
gv --vs --nsi

# Bump two package.json files and the antora docs
gv --js --js packages/entropy-cpp/package.json --antora

# Auto mode: whatever default files are present, update them
gv -a
```

## Testing

```sh
./test.sh          # run all tests, stop on first failure
./test.sh -c       # continue on failure
./test.sh -v       # verbose
```

Tests live in `unit_test/test_gv.sh` and cover each switch individually, combined switches, custom PATH arguments, AUTO mode, `--tag` interaction, and repeated switches.

