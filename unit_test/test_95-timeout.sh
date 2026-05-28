#! /bin/echo Please-source

echo "#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "# unit_test: 95-timeout.sh -- per-test timeout (UNITT_TIMEOUT / --timeout / preamble / per-test arg)"

# Scratch single-file core suites drive child ./unitt runs via UNIT_TEST_CORE,
# so the children exercise the timeout against a known tiny suite instead of
# recursing into this one. mktemp -d keeps them out of unit_test/ (no discovery
# pollution). test_core.sh (sourced later) installs an EXIT trap that clobbers
# ours, so we also clean up inline at end-of-file.
to_dir=$(mktemp -d "${TMPDIR:-/tmp}/unitt_to.XXXXXX")
# Preamble-scoped timeout can't use UNIT_TEST_CORE (that path bypasses
# preambles), so a couple of units are staged in unit_test/ and cleaned up the
# way test_98-preamble.sh does its scratch files.
ut_files=()
register_ut_file() { ut_files+=("$1"); }
cleanup_to() { rm -rf "$to_dir"; local f; for f in "${ut_files[@]}"; do rm -f "$f"; done; }
trap 'cleanup_to' EXIT

# A test that wedges for 3s — comfortably longer than the 1s timeouts below, so
# a working timeout kills it at ~1s while a broken one lets it run to completion.
printf 'run_test "sleep 3" "0" ".*"\n' > "$to_dir/hang_ok.sh"

echo
echo "# a hung test is killed and reported failed; the suite finishes (no hang) and exits 1"

run_test "UNIT_TEST_CORE='$to_dir/hang_ok.sh' UNITT_TIMEOUT=1 ./unitt -c" \
    "1" "$(escape_expected 'SUMMARY: 0 passed, 1 failed')"

echo
echo "# a timeout fails the test even when it expected a non-zero exit (a hang is never a pass)"

# Expected status 1 + the catch-all .* regex would otherwise satisfy the normal
# pass logic; only a timeout-specific short-circuit keeps this a failure.
printf 'run_test "sleep 3" "1" ".*"\n' > "$to_dir/hang_nz.sh"
run_test "UNIT_TEST_CORE='$to_dir/hang_nz.sh' UNITT_TIMEOUT=1 ./unitt -c" \
    "1" "$(escape_expected 'SUMMARY: 0 passed, 1 failed')"

echo
echo "# the failure names the timeout, and shows whatever the command printed before the kill"

run_test "UNIT_TEST_CORE='$to_dir/hang_ok.sh' UNITT_TIMEOUT=1 ./unitt -c" "1" "TIMEOUT 1s"

# The marker is computed at run time ($((...))) and the command is single-quoted
# so $cmd stays literal ("$((21+21))_HANG_MARK") — the value "42_HANG_MARK" can
# only appear in the command's real output, proving partial output is shown
# rather than the echoed command string.
cat > "$to_dir/partial.sh" <<'EOF'
run_test 'echo $((21+21))_HANG_MARK; sleep 3' "0" "^never$"
EOF
run_test "UNIT_TEST_CORE='$to_dir/partial.sh' UNITT_TIMEOUT=1 ./unitt -c" "1" "42_HANG_MARK"

echo
echo "# without -c, a timeout aborts the run like any other failure"

printf 'run_test "sleep 3" "0" ".*"\nrun_test "echo SECOND_RAN" "0" ".*"\n' > "$to_dir/mix.sh"
run_test "UNIT_TEST_CORE='$to_dir/mix.sh' UNITT_TIMEOUT=1 ./unitt" "1" "To be continued"
# The run aborted at the timeout, so the second test never executed.
run_test "UNIT_TEST_CORE='$to_dir/mix.sh' UNITT_TIMEOUT=1 ./unitt" "1" "SECOND_RAN" "true"

echo
echo "# a per-test 5th arg sets the timeout for one run_test call, overriding the global"

# Tighter than the (absent) global: the 5th arg alone kills the hang.
printf 'run_test "sleep 3" "0" ".*" false 1\n' > "$to_dir/per_down.sh"
run_test "UNIT_TEST_CORE='$to_dir/per_down.sh' ./unitt -c" \
    "1" "$(escape_expected 'SUMMARY: 0 passed, 1 failed')"

# Looser than a tight global: the 5th arg grants a slow-but-fine test more time.
printf 'run_test "sleep 2" "0" ".*" false 5\n' > "$to_dir/per_up.sh"
run_test "UNIT_TEST_CORE='$to_dir/per_up.sh' UNITT_TIMEOUT=1 ./unitt -c" \
    "0" "$(escape_expected 'SUMMARY: 1 passed, 0 failed')"

echo
echo "# --timeout / -t flag sets the timeout and overrides the env var"

run_test "UNIT_TEST_CORE='$to_dir/hang_ok.sh' ./unitt --timeout 1 -c" \
    "1" "$(escape_expected 'SUMMARY: 0 passed, 1 failed')"
run_test "UNIT_TEST_CORE='$to_dir/hang_ok.sh' ./unitt -t 1 -c" \
    "1" "$(escape_expected 'SUMMARY: 0 passed, 1 failed')"
# env says 99s (would let sleep 3 finish); the flag's 1s wins and kills it.
run_test "UNIT_TEST_CORE='$to_dir/hang_ok.sh' UNITT_TIMEOUT=99 ./unitt --timeout 1 -c" \
    "1" "$(escape_expected 'SUMMARY: 0 passed, 1 failed')"
run_test "./unitt -h" "0" "$(escape_expected '--timeout SECS')"

echo
echo "# a preamble can scope a timeout to its unit, and it must not leak to later units"

# preamble_71 sets unitt_timeout=1; unit 7100 uses it (sleep 3 -> killed). Unit
# 7101 has no preamble, so the baseline (no timeout) must be back in force and
# its sleep 2 must survive. Run both: 7100 fails, 7101 passes.
register_ut_file "unit_test/preamble_71.sh"
cat > "unit_test/preamble_71.sh" <<'EOF'
unitt_timeout=1
EOF
register_ut_file "unit_test/test_7100_71-to_pre.sh"
cat > "unit_test/test_7100_71-to_pre.sh" <<'EOF'
run_test "sleep 3" "0" ".*"
EOF
register_ut_file "unit_test/test_7101-to_bare.sh"
cat > "unit_test/test_7101-to_bare.sh" <<'EOF'
run_test "sleep 2" "0" ".*"
EOF
run_test "./unitt -u 7100,7101 -c" "1" "$(escape_expected 'SUMMARY: 1 passed, 1 failed')"

echo
echo "# a non-integer timeout (env, flag, or per-test arg) is a startup error, exit 2"

run_test "UNITT_TIMEOUT=abc ./unitt -l" "2" "UNITT_TIMEOUT: expected a non-negative integer"
run_test "UNITT_TIMEOUT=abc ./unitt -l >/dev/null 2>&1; echo rc=\$?" "0" "^rc=2$"
run_test "./unitt --timeout abc -l" "2" "$(escape_expected 'timeout: expected a non-negative integer')"
printf 'run_test "true" "0" ".*" false abc\n' > "$to_dir/bad_arg.sh"
run_test "UNIT_TEST_CORE='$to_dir/bad_arg.sh' ./unitt -c" \
    "2" "$(escape_expected 'run_test: timeout must be a non-negative integer')"

echo
echo "# a timeout of 0 disables the timeout (a slow-but-fine test is not killed)"

printf 'run_test "sleep 1" "0" ".*"\n' > "$to_dir/sleep1.sh"
run_test "UNIT_TEST_CORE='$to_dir/sleep1.sh' UNITT_TIMEOUT=0 ./unitt" \
    "0" "$(escape_expected 'SUMMARY: 1 passed, 0 failed')"

echo
echo "# killing a wedged command also kills the children it spawned (no orphan leak)"

# A compound command: the subshell backgrounds nothing, but `sleep` is a CHILD
# of the eval subshell (not exec'd into it). Killing only the subshell PID would
# reparent and leak the sleep; the watchdog must take down the whole tree. The
# 91234 sentinel is unique so pgrep can't match anything else.
cat > "$to_dir/leak.sh" <<'EOF'
run_test "echo x; sleep 91234" "0" ".*"
EOF
run_test "UNIT_TEST_CORE='$to_dir/leak.sh' UNITT_TIMEOUT=1 ./unitt -c >/dev/null 2>&1; sleep 1; if pgrep -f 'sleep 91234' >/dev/null 2>&1; then echo LEAKED; pkill -f 'sleep 91234'; else echo CLEAN; fi" \
    "0" "^CLEAN$"

echo
echo "# if the timeout path can't create its temp dir, that's a hard error (no silent degrade)"

# Point TMPDIR at a non-existent dir so run_capture's mktemp -d fails. Only the
# timeout path uses a temp dir, so this needs UNITT_TIMEOUT > 0.
printf 'run_test "true" "0" ".*"\n' > "$to_dir/triv.sh"
run_test "TMPDIR=/no/such/unitt/dir UNITT_TIMEOUT=1 UNIT_TEST_CORE='$to_dir/triv.sh' ./unitt -c" \
    "2" "run_capture: failed to create temp dir"

# Inline cleanup — see the trap comment above for why we do both.
pkill -f 'sleep 91234' 2>/dev/null
cleanup_to
