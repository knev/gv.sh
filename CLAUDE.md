# CLAUDE.md

## Workflow

- **This project always uses TDD.** No production code without a failing test
  first: write the test, watch it fail for the right reason, write the minimal
  code to pass, then refactor. This applies to features, bug fixes, and
  behavior changes alike.
- Tests live in `unit_test/test_*.sh` as `run_test` calls and are discovered and
  run by `./unitt`. The harness tests itself this way — new `unitt` behavior is
  driven by a new test unit (see `test_96-exit_codes.sh`, `test_97-exclude.sh`).

## Running the suite

```
./unitt        # stop at first failure
./unitt -c     # run all, report a SUMMARY tally
```

See `README.md` for the full option/feature reference.
