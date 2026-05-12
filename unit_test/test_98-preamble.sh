#! /bin/echo Please-source

echo "#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "# unit_test: 98-preamble.sh -- exercises preamble support (test_XX_YYY-NAME.sh)"

echo
echo "# --help mentions the preamble naming convention"

run_test "./unitt -h" "0" "$(escape_expected "test_XX_YYY-NAME.sh")"
run_test "./unitt -h" "0" "$(escape_expected "preamble_XX.sh")"
run_test "./unitt -h" "0" "all-zero XX means no"

# Tests below stage scratch preamble / unit files in unit_test/ with unique
# numeric ids so they don't collide with the rest of the suite. The parent
# unitt has already done discovery, so these new files only affect the child
# ./unitt subprocesses spawned by run_test.
pre_files=()
register_pre_file() { pre_files+=("$1"); }
cleanup_pre_files() {
    local f
    for f in "${pre_files[@]}"; do
        rm -f "$f"
    done
}
# test_core.sh (sourced later) installs its own EXIT trap that would
# override ours, so we also do an inline cleanup at end-of-file. The trap
# covers the case where a run_test below fails with continue_mode off and
# unitt exits before reaching the inline call.
trap 'cleanup_pre_files' EXIT

# A preamble that sets a variable, plus a unit that proves the variable was
# visible when the unit was sourced.
register_pre_file "unit_test/preamble_77.sh"
cat > unit_test/preamble_77.sh <<'EOF'
PREAMBLE_77_TOKEN="hello-from-preamble"
EOF

register_pre_file "unit_test/test_77_777-pre_smoke.sh"
cat > unit_test/test_77_777-pre_smoke.sh <<'EOF'
echo "# token=[$PREAMBLE_77_TOKEN]"
run_test "echo \"\$PREAMBLE_77_TOKEN\"" "0" "^hello-from-preamble$"
EOF

echo
echo "# preamble is sourced before its unit"

# Addressable by id (777) and by name (pre_smoke); preamble runs either way.
run_test "./unitt -u 777" "0" "$(escape_expected "token=[hello-from-preamble]")"
run_test "./unitt -u pre_smoke" "0" "$(escape_expected "token=[hello-from-preamble]")"

# --list-units shows the unit's id/name pair; the preamble tag is not part
# of the addressable identifier.
run_test "./unitt -l" "0" "unit:.777.-.pre_smoke."
run_test "./unitt -u 777 -l" "0" "unit:.777.-.pre_smoke."
run_test "./unitt -u 777 -l" "0" "unit:.core." "true"

echo
echo "# tag 00 means no preamble is sourced"

# An explicit-00 unit must not pick up preamble state from any other tag.
# The unit echoes a marker line containing the observed token state so the
# parent can grep for it (the captured PASS line alone doesn't expose the
# command's actual stdout in non-verbose mode).
register_pre_file "unit_test/test_00_779-pre_zero.sh"
cat > unit_test/test_00_779-pre_zero.sh <<'EOF'
echo "# pre_zero token=[${PREAMBLE_77_TOKEN:-unset}]"
run_test "true" "0" ".*"
EOF
run_test "./unitt -u 779" "0" "$(escape_expected "pre_zero token=[unset]")"
run_test "./unitt -u pre_zero" "0" "$(escape_expected "pre_zero token=[unset]")"

# A single-digit "0" tag is also no preamble — the check is numeric so 0,
# 00, 000, etc. all behave identically. Without this, "0" would try to
# source preamble_0.sh.
register_pre_file "unit_test/test_0_771-zero_tag.sh"
cat > unit_test/test_0_771-zero_tag.sh <<'EOF'
echo "# zero_tag token=[${PREAMBLE_77_TOKEN:-unset}]"
run_test "true" "0" ".*"
EOF
run_test "./unitt -u 771" "0" "$(escape_expected "zero_tag token=[unset]")"

echo
echo "# missing preamble file is a hard error"

# preamble_88.sh is deliberately not created; sourcing must abort with the
# documented diagnostic before the unit's run_test fires.
register_pre_file "unit_test/test_88_888-pre_missing.sh"
cat > unit_test/test_88_888-pre_missing.sh <<'EOF'
run_test "true" "0" "should-never-run"
EOF
run_test "./unitt -u 888" "1" \
    "$(escape_expected "ERROR: preamble [unit_test/preamble_88.sh] not found for unit [888]")"
run_test "./unitt -u 888" "1" "should-never-run" "true"

echo
echo "# leading-zero preamble tag (08) is parsed as base-10"

# Regression guard: 10#... in the discovery sort key prevents bash from
# treating "08" as octal (which would error since 8 isn't an octal digit).
register_pre_file "unit_test/preamble_08.sh"
cat > unit_test/preamble_08.sh <<'EOF'
PREAMBLE_08_OK="yes"
EOF
register_pre_file "unit_test/test_08_809-leading_zero.sh"
cat > unit_test/test_08_809-leading_zero.sh <<'EOF'
run_test "echo \"\$PREAMBLE_08_OK\"" "0" "^yes$"
EOF
run_test "./unitt -u 809" "0" "PASS: .echo .\\\$PREAMBLE_08_OK.."

echo
echo "# id / preamble-tag length and shape are validated at discovery"

# The sort key uses bash $((10#...)) which is signed 64-bit. 18 digits is
# the largest length that always fits; the guard rejects 19+ digits and
# any non-numeric id in the preamble form before discovery returns.

# 18-digit id: still works.
register_pre_file "unit_test/preamble_01.sh"
cat > unit_test/preamble_01.sh <<'EOF'
:
EOF
register_pre_file "unit_test/test_01_123456789012345678-edge18.sh"
cat > unit_test/test_01_123456789012345678-edge18.sh <<'EOF'
run_test "true" "0" ".*"
EOF
run_test "./unitt -u edge18 -l" "0" "unit:.123456789012345678.-.edge18."

# 19-digit id: rejected.
register_pre_file "unit_test/test_01_1234567890123456789-over19.sh"
cat > unit_test/test_01_1234567890123456789-over19.sh <<'EOF'
run_test "true" "0" "should-never-run"
EOF
run_test "./unitt -l" "1" "$(escape_expected "exceeds 18 digits")"

# 19-digit preamble tag: same guard fires for the tag.
register_pre_file "unit_test/test_1234567890123456789_42-bigtag.sh"
cat > unit_test/test_1234567890123456789_42-bigtag.sh <<'EOF'
run_test "true" "0" "should-never-run"
EOF
run_test "./unitt -l" "1" "$(escape_expected "exceeds 18 digits")"
# Remove the over-length files before the next test so its error message
# is the one that wins.
rm -f unit_test/test_01_1234567890123456789-over19.sh \
      unit_test/test_1234567890123456789_42-bigtag.sh

# Non-numeric id in the preamble form: rejected (regex would allow letters
# but the arithmetic sort key wouldn't).
register_pre_file "unit_test/test_01_abc-letters.sh"
cat > unit_test/test_01_abc-letters.sh <<'EOF'
run_test "true" "0" "should-never-run"
EOF
run_test "./unitt -l" "1" "$(escape_expected "must be all-digit")"

# Inline cleanup — see the trap comment above for why we do both.
cleanup_pre_files
