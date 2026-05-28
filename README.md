# unit_test_bash

A small, drop-in Bash unit-testing harness. `unitt` parses options and defines
the helpers; the actual test cases live in one or more `unit_test/test_*.sh`
files, which `unitt` discovers and sources automatically.

## Quick start

```
./unitt                          # run all tests, stop at the first failure
./unitt -v                       # verbose: show every test's output, pass or fail
./unitt -c                       # continue past failures instead of stopping
./unitt -l                       # list discovered test units and exit (--list-units)
./unitt -u core                  # run only the 'core' unit (--units core)
./unitt -u 0800-0835             # run every unit with an id in [0800, 0835] (a range)
./unitt -x 0316                  # run everything except unit 0316 (--exclude)
./unitt -t 60                    # fail (and, with -c, skip past) any test that runs > 60s
UNITT_TIMEOUT=60 ./unitt -c      # same per-test timeout via the environment
./unitt -u 99,core --step 42     # run units 99 then core; step from line 42
./unitt --step core,42           # interactive step-through, from test_core.sh line 42 onward
./unitt -h                       # help
```

`-c` and `-v` are mutually exclusive in spirit (the explicit check is currently
commented out in `unitt`).

## Layout

```
unitt                       # entry point: option parsing + helpers, discovers and sources units
unit_test/test_core.sh        # one test unit (any file matching test_*.sh is picked up)
unit_test/test_99-extra.sh    # optionally numbered to control run order
unit_test/test_42_05-foo.sh   # numbered + preamble tag — sources preamble_05.sh first
unit_test/preamble_05.sh      # shared setup for any test_*_05-*.sh unit
```

To grow the suite, drop another file under `unit_test/` whose basename starts
with `test_`. It is sourced automatically — no `source` line to add.

### Run order and unit identifiers

Each discovered file gets a **unit identifier** (and, for numbered files, an
extra **name alias**) taken from the part of its basename after `test_`:

| File                  | Number | Name        | Addressable as       |
|-----------------------|--------|-------------|----------------------|
| `test_core.sh`        | —      | `core`      | `core`               |
| `test_99-discovery.sh`| `99`   | `discovery` | `99` *or* `discovery`|
| `test_01-foo.sh`      | `01`   | `foo`       | `01` *or* `foo`      |

If the part after `test_` starts with digits followed by `-` (or just digits),
the file is **numbered** and the leading number becomes its primary identifier;
the rest after the dash becomes a name alias. Either form may be used wherever
an `ID` is expected (e.g. `--step 99,...` and `--step discovery,...` both
target `test_99-discovery.sh`). Unnumbered files have a single identifier
equal to the full stripped basename.

Files using the preamble form `test_<ID>_<TAG>-<NAME>.sh` (see below) are also
numbered: the leading `<ID>` is the primary identifier, `<NAME>` is the name
alias.

Run order is: numbered units first, sorted by `(id, preamble tag)` — the unit
id drives ordering so a preamble doesn't shuffle a unit's position; ties on id
(only possible across the preamble form vs. the bare form) fall back to tag,
with no-preamble forms sorting first. Unnumbered units run last in alphabetical
order. Duplicate identifiers (across either column) are an error at startup.
Use `./unitt -l` (or `--list-units`) to print the full table.

Numeric ids and preamble tags must be **≤ 18 digits** — the sort key uses
`$((10#...))` (bash 64-bit signed arithmetic) and silently overflows past
that. unitt rejects out-of-range or non-numeric components at startup with a
named error rather than discovering a unit whose sort position is garbage.
In practice this isn't a constraint — typical ids are 1–5 digits.

### Preambles

Insert a `_<TAG>` suffix after the unit id to have unitt source
`unit_test/preamble_<TAG>.sh` before sourcing the unit. The tag is one or more
digits between the unit id and the optional `-NAME`:

| File                       | Preamble file                | Unit id | Name        |
|----------------------------|------------------------------|---------|-------------|
| `test_42_05-foo.sh`        | `unit_test/preamble_05.sh`   | `42`    | `foo`       |
| `test_345_2-bar.sh`        | `unit_test/preamble_2.sh`    | `345`   | `bar`       |
| `test_77_00-baz.sh`        | *(none — all-zero tag)*      | `77`    | `baz`       |
| `test_99-discovery.sh`     | *(none — bare form)*         | `99`    | `discovery` |

Notes:

- An **all-zero tag** (`0`, `00`, `000`, …) is the explicit "no preamble" form.
  The check is numeric, so the number of zeros doesn't matter.
- The preamble filename must match the tag exactly as written. `test_…_2.sh`
  looks for `preamble_2.sh`; `test_…_02.sh` looks for `preamble_02.sh`. They
  are different files.
- If the named preamble doesn't exist, unitt exits with
  `ERROR: preamble [unit_test/preamble_<TAG>.sh] not found for unit [<id>]`.
- The preamble is re-sourced for **each** unit that uses it — it's a plain
  `source` in the per-unit loop, not deduped. Anything it defines lives in the
  same shell scope as the unit and the rest of the suite.

### Disabling a unit

Prefix the filename with `_` (e.g. `_test_Entroopy.sh` or
`_test_99-foo.sh`) to mark a unit as **disabled**. Disabled units still appear
in `-l` output marked `(disabled)` so you can see what's been parked, but they
are never sourced and cannot be selected by `--units` or targeted by `--step`.
Rename the file (drop the leading `_`) to re-enable.

### Selecting which units to run

Both `-u` and `-x` take a **SEL** — a comma-separated list whose entries are
unit ids, name aliases, and/or **numeric ranges** `LO-HI`:

| Entry        | Selects                                                          |
|--------------|------------------------------------------------------------------|
| `0316`       | the unit whose id is `0316`                                      |
| `validate`   | the unit whose name alias is `validate`                          |
| `0800-0835`  | every numbered unit whose id is in `[0800, 0835]` (inclusive)    |

Ranges are inclusive and zero-pad-tolerant (`0800-0835` and `800-835` compare
numerically). A range only ever matches **numbered** units — non-numeric ids
like `core` are never swept up by one. Disabled units inside a range are
silently skipped (a range is a bulk selector), but naming a disabled unit
*explicitly* is still an error. The expanded set is de-duplicated.

`-u, --units SEL` filters the suite to the selected units. Order in the run is
always the discovery order, regardless of how you list them:

```
./unitt -u core             # only test_core.sh
./unitt -u 99,core          # both, in discovery order
./unitt -u 0800-0835        # a whole range
./unitt -u 0073,0800-0835,validate   # ids, a range, and a name in one SEL
./unitt -u discovery -l     # confirm the filter took effect
```

`-x, --exclude SEL` removes the selected units. It applies *on top of* `-u`
(subtracted from that selection) or, when `-u` is omitted, to **all** enabled
units — so "run everything except the one flaky test" is just `-x`:

```
./unitt -x 0316             # everything except unit 0316
./unitt -u 0800-0835 -x 0820   # the range minus one id
./unitt -x 0316,0800-0835      # exclude an id and a whole range
```

If `-u`/`-x` together leave nothing to run, unitt exits `2` with
`units: selection is empty after exclusions`. An inverted range (`0835-0800`)
or a range that matches no enabled unit is likewise a `2`.

## Writing a test

Tests are calls to `run_test`:

```bash
run_test "<command>" "<expected_exit>" "<expected_regex>" [not_flag] [timeout]
```

| Arg               | Meaning                                                                 |
|-------------------|-------------------------------------------------------------------------|
| `command`         | Shell command to run. Evaluated via `eval`, so quoting matters.         |
| `expected_exit`   | `0` for success, anything else for failure. Matched loosely: 0-vs-0 or non-zero-vs-non-zero is a match (the exact non-zero code is not compared). |
| `expected_regex`  | Bash `[[ =~ ]]` regex matched against combined stdout+stderr.           |
| `not_flag`        | Optional. `true` inverts the regex check (output must **not** match).   |
| `timeout`         | Optional. Per-test timeout in seconds, overriding the global for this one call (see [Per-test timeout](#per-test-timeout)). `0` disables it. |

### Escaping regex metacharacters

Because the third argument is a real Bash regex, characters like `[ ] ( ) ? ! |`
must be escaped. Wrap literal patterns in `escape_expected` so you can write
them naturally:

```bash
run_test "$FPATH_BIN wsweep --qewrere" "1" "$(escape_expected "ERROR: invalid command [wsweep]")"
```

Note: this means you cannot use `[]` or `()` as regex grouping inside a pattern
that you also pass through `escape_expected` — the helper escapes those
literally. Use `.*` and friends for wildcards instead.

### Example

From `unit_test/test_core.sh`:

```bash
run_test "$FPATH_BIN wsweep --qewrere" "1" "$(escape_expected "ERROR: invalid command [wsweep]")"
run_test "ls -alR $TEST" "1" "$TEST.?: No such file or directory"
```

The first asserts a non-zero exit and a literal error string. The second uses a
raw regex (`.?` after `$TEST`) and expects a non-zero exit from `ls`.

## Output

On pass (default mode):

```
PASS: [<cmd>][<exit>] "<regex>", line no. [<N>]
```

On fail (or always, in `-v` mode):

```
# FAIL: [<exit>][<cmd>], line no. [<N>]
# Expected EXIT status [YES|no]: [<expected>]
# Expected to contain [YES|no]: "<regex>"
#----
  <captured combined stdout+stderr>
#----
```

`line no.` is the line in the test unit's source file where `run_test` was
called, which is what `--step` keys off of.

Without `-c`, the harness prints `To be continued ...` and stops on the first
failure. With `-c` it runs the whole suite and reports the tally at the end.

### Summary line and exit codes

Every run ends with a machine-readable summary on its own line:

```
SUMMARY: <N> passed, <M> failed
```

The counters are bumped at each pass/fail, independent of marker formatting, so
`grep '^SUMMARY:'` is a reliable way to scrape the result. The process exit code
follows the grep/pytest convention so a script can branch on it without parsing
output:

| Exit | Meaning                                                                       |
|------|-------------------------------------------------------------------------------|
| `0`  | all tests passed                                                              |
| `1`  | the suite ran but a test failed (true with **and** without `-c` — `-c` no longer hides failures from the exit code) |
| `2`  | the suite never ran a test: a usage error, an unknown/disabled unit, a bad range, or an empty selection |

```bash
./unitt -c
case $? in
  0) echo "green" ;;
  1) echo "test failures" ;;
  2) echo "bad invocation" ;;
esac
```

## Per-test timeout

A single wedged command can otherwise hang the whole run indefinitely. Set a
per-test timeout (in **seconds**) and any one `run_test` that runs longer is
killed and recorded as a failure — so with `-c` the suite skips past the hang
and still produces a complete signal. A timeout is an ordinary failure: it
counts toward the `SUMMARY` tally, and (like any failure) it aborts the run
without `-c` or is stepped over with it. The failure block names the limit and
shows whatever the command printed before the kill:

```
# FAIL: [the-wedged-cmd][TIMEOUT 60s], line no. [42]
# Test exceeded the 60s per-test timeout and was killed.
```

The limit can be set at four scopes, each overriding the broader one:

| Scope        | How                                              | Applies to                    |
|--------------|--------------------------------------------------|-------------------------------|
| Global (env) | `UNITT_TIMEOUT=60 ./unitt`                        | every `run_test` in the run   |
| Global (flag)| `./unitt --timeout 60` (or `-t 60`)               | every `run_test`; **wins over the env var** |
| Per-unit     | `unitt_timeout=120` inside a preamble             | the unit(s) using that preamble |
| Per-test     | a 5th arg: `run_test "$cmd" "$st" "$re" false 300`| that one call                 |

```bash
UNITT_TIMEOUT=60 ./unitt -c        # 60s for everything
./unitt -t 60 -c                   # same, via flag (overrides UNITT_TIMEOUT)
```

```bash
# unit_test/preamble_05.sh — scoped to units that use tag _05
unitt_timeout=120
```

```bash
# one known-slow test gets more room; the rest keep the global limit
run_test "slow-thing" "0" ".*" false 300
```

The per-unit hook works because `run_test` reads the live `unitt_timeout`
variable, and the value is reset to the global baseline before each unit — so a
preamble's override stays scoped to its own unit and doesn't leak into the next.

A timeout of `0` disables the timeout (the default). A non-integer value —
whether from `UNITT_TIMEOUT`, `--timeout`, or the 5th arg — is a startup/usage
error and exits `2`.

## Step mode

`--step [ID,]LINENO` pauses before every `run_test` whose caller line is
`>= LINENO` *and* (when `ID` is given) whose unit identifier matches `ID`. The
`ID,` prefix is required when more than one test unit will run after any
`--units` filter; when only one unit will run (either because the suite has
one unit or `--units` narrowed it to one), a bare `LINENO` is accepted.
Examples:

```
./unitt --step core,12           # pause inside test_core.sh from line 12 onward
./unitt --step 99,1              # pause inside test_99-discovery.sh from the first run_test
./unitt -u core --step 12        # bare line OK once -u narrows to one unit
```

At each pause:

```
--- step [<unit>:<file>:<N>] ---
  $ <cmd>
  Expected EXIT status:[<exp>] regex:[<regex>]
[Enter]=run, c=continue without stepping, l=continue to [unit,]line, s=skip, q=quit ?
```

- `Enter` — run this test, then pause at the next one.
- `c` — run this and all remaining tests without pausing.
- `l` — prints the unit table (already-sourced units show `done` in the Status
  column, the active one shows `current`), then prompts for `[unit,]line`.
  Bare `line` keeps stepping in the current unit; `unit,line` jumps stepping
  to a unit that's still ahead in the run order (one-shot version of `c`).
  Empty input cancels and re-displays the main step prompt; targets marked
  `done` are rejected — once a unit has finished sourcing you can't return to it.
- `s` — skip this test (counts as a pass-through, not a failure).
- `q` — quit immediately.

Keystrokes are read from `/dev/tty`, so tests that pipe into stdin still work.

## How `run_test` captures output

The combined stdout+stderr **and** exit status are captured in one shot via a
file-descriptor trick:

```bash
full_output=$( { eval "$cmd" 2>&1; echo $? >&3; } 3>&1 | cat )
exit_status=${full_output##*$'\n'}
output=${full_output%$'\n'*}
```

The exit status is appended after a newline, then split off. This is the only
reliable way in pure Bash to get both at once from a single subshell.

When a [per-test timeout](#per-test-timeout) is in force, `run_capture` takes a
different path: it runs the command in the background, captures its output to a
temp file, and a watchdog `wait`s for it — reaping it the instant it finishes
(so a fast test pays no polling cost) or, once the limit elapses, sending
`SIGTERM` and then `SIGKILL` after a 1s grace. A marker file distinguishes a
real timeout (reported as exit `124`) from a command that merely exited
non-zero. No external `timeout(1)` is used, so the harness stays drop-in on a
stock macOS/BSD or Linux shell.
