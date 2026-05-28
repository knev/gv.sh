#! /bin/echo Please-source

echo "#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "# unit_test: 96-exit_codes.sh -- machine-readable SUMMARY line and the 0/1/2 exit-code contract"

# Scratch core files drive child ./unitt runs via UNIT_TEST_CORE, so the
# children run a known tiny suite (one "core" unit) instead of recursing into
# this one. The exact exit code is asserted with a `; echo rc=$?` tail because
# run_test's status check is loose (any non-zero matches any non-zero) and the
# whole point here is to tell 1 apart from 2.
ec_dir=$(mktemp -d)
# test_core.sh (sourced after this unit) installs its own EXIT trap that
# clobbers ours, so we also clean up inline at end-of-file. The trap covers a
# mid-file failure with -c off, where unitt exits before the inline cleanup.
trap "rm -rf '$ec_dir'" EXIT

printf 'run_test "true" "0" ".*"\nrun_test "true" "0" ".*"\n' > "$ec_dir/all_pass.sh"
# Two passes + one fail (regex can't match) → SUMMARY: 2 passed, 1 failed.
printf 'run_test "true" "0" ".*"\nrun_test "echo hi" "0" "^WONT_MATCH$"\nrun_test "true" "0" ".*"\n' \
    > "$ec_dir/mixed.sh"

echo
echo "# SUMMARY line"

run_test "UNIT_TEST_CORE='$ec_dir/all_pass.sh' ./unitt" \
    "0" "$(escape_expected 'SUMMARY: 2 passed, 0 failed')"
# Counters are independent of -c; the failed test still increments fail_count.
run_test "UNIT_TEST_CORE='$ec_dir/mixed.sh' ./unitt -c" \
    "1" "$(escape_expected 'SUMMARY: 2 passed, 1 failed')"

echo
echo "# exit 0 — all passed"

run_test "UNIT_TEST_CORE='$ec_dir/all_pass.sh' ./unitt >/dev/null 2>&1; echo rc=\$?" \
    "0" "^rc=0$"

echo
echo "# exit 1 — test failure (the key fix: -c no longer hides the failure)"

run_test "UNIT_TEST_CORE='$ec_dir/mixed.sh' ./unitt -c >/dev/null 2>&1; echo rc=\$?" \
    "0" "^rc=1$"
# Without -c the run aborts at the first failure; still exit 1, with the marker.
run_test "UNIT_TEST_CORE='$ec_dir/mixed.sh' ./unitt >/dev/null 2>&1; echo rc=\$?" \
    "0" "^rc=1$"
run_test "UNIT_TEST_CORE='$ec_dir/mixed.sh' ./unitt" "1" "To be continued"

echo
echo "# exit 2 — usage / selection errors (distinct from test failures)"

run_test "./unitt --bogus >/dev/null 2>&1; echo rc=\$?"        "0" "^rc=2$"
run_test "./unitt -z >/dev/null 2>&1; echo rc=\$?"             "0" "^rc=2$"
run_test "./unitt --units >/dev/null 2>&1; echo rc=\$?"        "0" "^rc=2$"
run_test "./unitt -u nope >/dev/null 2>&1; echo rc=\$?"        "0" "^rc=2$"
run_test "./unitt -u 0105-0102 >/dev/null 2>&1; echo rc=\$?"   "0" "^rc=2$"
# --help is not an error: clean exit 0.
run_test "./unitt -h >/dev/null 2>&1; echo rc=\$?"             "0" "^rc=0$"

# Inline cleanup — see the trap comment above for why we do both.
rm -rf "$ec_dir"
