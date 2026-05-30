#! /bin/echo Please-source

echo "#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "# unit_test: 94-lock.sh -- single-instance mkdir lock: acquire / release / refuse / reclaim / nesting"

# Every assertion below spawns a CHILD ./unitt as a *fresh top-level* run by
# stripping the inherited UNITT_LOCK_HELD marker (env -u) and pointing TMPDIR at
# a throwaway dir, so the child's lock lives at $lk and never collides with the
# parent's real lock. Without `env -u` the child would inherit the parent's
# exported UNITT_LOCK_HELD and bypass locking outright — that bypass is the
# nesting case, tested explicitly at the end with the marker left in place.
#
# The acquire/release branches are deterministic on purpose: rather than race two
# real runs (slow, flaky — the loser's timing is unobservable), each test plants
# a known lock state at $lk and asserts the single startup branch it drives.
lk_root=$(mktemp -d)
lk="$lk_root/unitt.lock"
# test_core.sh (sourced later) installs its own EXIT trap that clobbers ours, so
# we also clean up inline at end-of-file; the trap covers a mid-file failure with
# -c off, where unitt exits before the inline cleanup.
trap 'rm -rf "$lk_root"' EXIT

# A pid that can never be live: macOS caps pids well below this, so kill -0
# always fails with ESRCH. Using a reaped real pid instead would be flaky — the
# OS could recycle it for one of the many short-lived procs this harness spawns
# between planting it and the child's kill -0, flipping "stale" to "live".
dead_pid=99999999

echo
echo "# the owning run records its own pid in the lock, then releases on exit"

# A core unit that reads the lock pidfile from inside the running child: the
# child's $$ IS the lock owner, so the file must hold exactly that pid. The
# marker line is grepped by the parent (the captured PASS line doesn't expose
# the command's own stdout in non-verbose mode). Reused below to prove that a
# reclaim doesn't just proceed but actually re-takes ownership.
cat > "$lk_root/owned.sh" <<'EOF'
if [ "$(cat "$TMPDIR/unitt.lock/pid" 2>/dev/null)" = "$$" ]; then
    echo "# lock-acquire: OWNED-BY-SELF"
else
    echo "# lock-acquire: pidfile=[$(cat "$TMPDIR/unitt.lock/pid" 2>/dev/null)] self=[$$]"
fi
run_test "true" "0" ".*"
EOF
run_test "env -u UNITT_LOCK_HELD TMPDIR='$lk_root' UNIT_TEST_CORE='$lk_root/owned.sh' ./unitt" \
    "0" "lock-acquire: OWNED-BY-SELF"

# On normal exit the owner removes its lock dir, leaving the tree clean for the
# next run. (That the lock was *acquired* in the first place is proven by the
# OWNED-BY-SELF test above; this only checks the EXIT-time teardown.)
run_test "env -u UNITT_LOCK_HELD TMPDIR='$lk_root' ./unitt -l >/dev/null 2>&1; test ! -e '$lk' && echo RELEASED" \
    "0" "^RELEASED$"

echo
echo "# a live foreign lock makes an unrelated top-level run refuse (exit 1, not 2)"

mkdir -p "$lk"; echo "$$" > "$lk/pid"            # $$ = this (parent) run — definitely alive
run_test "env -u UNITT_LOCK_HELD TMPDIR='$lk_root' ./unitt -l" "1" \
    "$(escape_expected "another run is active (pid")"
run_test "env -u UNITT_LOCK_HELD TMPDIR='$lk_root' ./unitt -l" "1" \
    "$(escape_expected "(if that pid is dead, rm -rf")"
# Refusal is exit 1 — distinct from the 2 reserved for usage/selection errors
# (see test_96-exit_codes.sh for that contract).
run_test "env -u UNITT_LOCK_HELD TMPDIR='$lk_root' ./unitt -l >/dev/null 2>&1; echo rc=\$?" \
    "0" "^rc=1$"
# The loser of the race must NOT delete the lock it never owned: its EXIT reap is
# gated on the pidfile matching its own pid, which it doesn't.
run_test "cat '$lk/pid'" "0" "^$$\$"
rm -rf "$lk"

echo
echo "# a stale lock (dead or empty owner) is reclaimed and re-taken by the run"

# owned.sh asserts the lock pidfile holds the child's OWN pid, so a pass proves
# the child tore the stale dir down and re-acquired — not merely that it didn't
# refuse. (A regression that read the stale pidfile but never rewrote it would
# leave the dead/empty owner in place and fail this.)
# Dead owner pid: reclaimed.
mkdir -p "$lk"; echo "$dead_pid" > "$lk/pid"
run_test "env -u UNITT_LOCK_HELD TMPDIR='$lk_root' UNIT_TEST_CORE='$lk_root/owned.sh' ./unitt" \
    "0" "lock-acquire: OWNED-BY-SELF"
rm -rf "$lk"
# A lock dir with no pidfile at all is likewise treated as stale and reclaimed.
mkdir -p "$lk"                                    # no pid file written
run_test "env -u UNITT_LOCK_HELD TMPDIR='$lk_root' UNIT_TEST_CORE='$lk_root/owned.sh' ./unitt" \
    "0" "lock-acquire: OWNED-BY-SELF"
rm -rf "$lk"

echo
echo "# a nested run (UNITT_LOCK_HELD inherited) rides the parent's lock"

# unitt only tests UNITT_LOCK_HELD for non-emptiness; the value is never read,
# so any non-empty marker selects the nesting path.
# Even with a LIVE foreign lock present, a nested child neither refuses nor
# touches it — it proceeds straight to the run.
mkdir -p "$lk"; echo "$$" > "$lk/pid"
run_test "UNITT_LOCK_HELD=1 TMPDIR='$lk_root' ./unitt -l" "0" "unit:.core."
# ...and the pre-existing lock is left exactly as it was (no acquire, no release).
run_test "cat '$lk/pid'" "0" "^$$\$"
rm -rf "$lk"
# With no pre-existing lock, a nested run creates none ($_unitt_lockdir stays
# unset, so startup never mkdir's and the reap never rm's).
run_test "UNITT_LOCK_HELD=1 TMPDIR='$lk_root' ./unitt -l >/dev/null 2>&1; test ! -e '$lk' && echo NO-LOCK-CREATED" \
    "0" "^NO-LOCK-CREATED$"

# Inline cleanup — see the trap comment above for why we do both.
rm -rf "$lk_root"
