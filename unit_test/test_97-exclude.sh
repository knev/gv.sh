#! /bin/echo Please-source

echo "#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "# unit_test: 97-exclude.sh -- -x exclusion and -u/-x numeric ranges (test_YYY-NAME selection)"

# Stage a clean block of numeric-id units (0600..0604) plus one disabled
# numeric unit (0605) so ranges have a predictable target set. Ids 0600-0605
# are reserved as scratch — a real unit must not claim one or the staging
# below would overwrite (and the cleanup delete) it. The parent unitt already
# finished discovery, so these files only affect the child ./unitt subprocesses
# spawned by run_test below. Selection is asserted via -l (every test
# invocation exits at --list-units before sourcing anything).
ex_files=()
register_ex_file() { ex_files+=("$1"); }
cleanup_ex_files() {
    local f
    for f in "${ex_files[@]}"; do
        rm -f "$f"
    done
}
# test_core.sh (sourced later) installs its own EXIT trap that clobbers ours,
# so we also clean up inline at end-of-file. The trap covers a mid-file
# failure with -c off, where unitt exits before the inline cleanup.
trap 'cleanup_ex_files' EXIT

for n in 0 1 2 3 4; do
    register_ex_file "unit_test/test_060${n}-r${n}.sh"
    cat > "unit_test/test_060${n}-r${n}.sh" <<'EOF'
run_test "true" "0" ".*"
EOF
done

# A disabled numeric unit: leading `_` means discovery never sources it. The
# body errors if sourced, so a regression in the disable rule would surface.
register_ex_file "unit_test/_test_0605-rdis.sh"
cat > "unit_test/_test_0605-rdis.sh" <<'EOF'
echo "ERROR: _test_0605-rdis.sh was sourced — disabled units must never run" >&2
EOF

echo
echo "# -u range expands to every enabled id in [LO,HI]"

run_test "./unitt -u 0600-0603 -l" "0" "unit:.0600.-.r0."
run_test "./unitt -u 0600-0603 -l" "0" "unit:.0603.-.r3."
run_test "./unitt -u 0600-0603 -l" "0" "unit:.0604.-.r4." "true"

echo
echo "# ranges mix with ids and names in one SEL"

# 0600, the 0602-0603 range, and the name alias r4 (=0604); 0601 left out.
run_test "./unitt -u 0600,0602-0603,r4 -l" "0" "unit:.0600.-.r0."
run_test "./unitt -u 0600,0602-0603,r4 -l" "0" "unit:.0602.-.r2."
run_test "./unitt -u 0600,0602-0603,r4 -l" "0" "unit:.0604.-.r4."
run_test "./unitt -u 0600,0602-0603,r4 -l" "0" "unit:.0601.-.r1." "true"

echo
echo "# plain id list is unchanged by the range support"

run_test "./unitt -u 0600,0603 -l" "0" "unit:.0600.-.r0."
run_test "./unitt -u 0600,0603 -l" "0" "unit:.0603.-.r3."
run_test "./unitt -u 0600,0603 -l" "0" "unit:.0601.-.r1." "true"
run_test "./unitt -u 0600,0603 -l" "0" "unit:.0602.-.r2." "true"

echo
echo "# -x removes units on top of a -u selection"

run_test "./unitt -u 0600-0603 -x 0602 -l" "0" "unit:.0600.-.r0."
run_test "./unitt -u 0600-0603 -x 0602 -l" "0" "unit:.0603.-.r3."
run_test "./unitt -u 0600-0603 -x 0602 -l" "0" "unit:.0602.-.r2." "true"

echo
echo "# -x accepts ranges too"

run_test "./unitt -u 0600-0603 -x 0601-0602 -l" "0" "unit:.0600.-.r0."
run_test "./unitt -u 0600-0603 -x 0601-0602 -l" "0" "unit:.0603.-.r3."
run_test "./unitt -u 0600-0603 -x 0601-0602 -l" "0" "unit:.0601.-.r1." "true"
run_test "./unitt -u 0600-0603 -x 0601-0602 -l" "0" "unit:.0602.-.r2." "true"

echo
echo "# -x without -u excludes from all enabled units"

# The scratch block is dropped; the always-present non-numeric 'core' stays.
run_test "./unitt -x 0600-0604 -l" "0" "unit:.core."
run_test "./unitt -x 0600-0604 -l" "0" "unit:.0600.-.r0." "true"
run_test "./unitt -x 0600-0604 -l" "0" "unit:.0604.-.r4." "true"

echo
echo "# numeric ranges never match non-numeric ids"

# A range that spans the whole numeric space removes every numbered unit but
# leaves 'core' (its id is the non-numeric string 'core').
run_test "./unitt -x 0001-9999 -l" "0" "unit:.core."
run_test "./unitt -x 0001-9999 -l" "0" "unit:.0600.-.r0." "true"

echo
echo "# a range silently skips disabled units; naming one explicitly is an error"

# 0600-0605 spans the disabled 0605, which is skipped (no error, exit 0).
run_test "./unitt -u 0600-0605 -l" "0" "unit:.0600.-.r0."
run_test "./unitt -u 0600-0605 -l" "0" "unit:.0604.-.r4."
run_test "./unitt -u 0600-0605 -l" "0" "unit:.0605.-.rdis." "true"
# Naming the disabled unit directly is rejected.
run_test "./unitt -u 0605" "1" "units: test unit .0605. is disabled"
# A range whose only candidate is disabled matches nothing — distinct from the
# empty-numeric-space case below (9990-9991), this one had a unit but skipped it.
run_test "./unitt -u 0605-0605" "1" "units: range .0605-0605. matched no enabled units"

echo
echo "# selection / range error cases"

run_test "./unitt -u 0601-0600"       "1" "units: inverted range .0601-0600."
run_test "./unitt -u 9990-9991"       "1" "units: range .9990-9991. matched no enabled units"
run_test "./unitt -u 0600 -x 0600"    "1" "units: selection is empty after exclusions"
run_test "./unitt -x nope"            "1" "exclude: unknown test unit .nope."
run_test "./unitt --exclude"          "1" "exclude: missing value"
run_test "./unitt -x '0600,,'"        "1" "exclude: empty entry"
run_test "./unitt -x 0601-0600"       "1" "exclude: inverted range .0601-0600."

echo
echo "# -h documents -x"

run_test "./unitt -h" "0" "$(escape_expected "-x, --exclude SEL")"

# Inline cleanup — see the trap comment above for why we do both.
cleanup_ex_files
