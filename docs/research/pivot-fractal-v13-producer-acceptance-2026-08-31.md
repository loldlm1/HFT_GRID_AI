# Pivot Fractal V13 Producer Acceptance

## Decision

**PENDING**. Sprints 1-7 freeze the V13 contract and documentation, but the
producer is not accepted for downstream Django cutover until Sprint 8 records a
clean final MetaEditor compile and human Strategy Tester/chart evidence.

This draft does not authorize live rollout, runtime model loading, online
learning, execution filtering, or downstream V12 deletion.

## Provenance Before Final Compile

- Branch: `bot/pivot_points_fractal`
- Sprint 7 rollback point: `a684db53fe9988425005933c57f4e9bd32b9eb5c`
- Pre-compile producer/tooling pin: `a684db53fe9988425005933c57f4e9bd32b9eb5c`
- Final accepted commit: pending
- Schema/feature/root: `13`, `schema_v13_hft_deep_pivot_features`,
  `Common\Files\PivotFractalV13\runs\<run_id>\`
- Validator SHA-256:
  `774c737ddce861cefe960c382acd865a9f4fbf7488edd734b5b58f24fda2ea1d`
- Builder SHA-256:
  `f3de2ca4cabc80fa2144544f1efcc7f09fdf8ce85b2552fc8f655396194b9c32`
- Canonical 566-column registry SHA-256:
  `986c4868fb70b08e18296e8679a5ad2aeebe59849571ef2b7ee58fcab8cde3c1`
- Sorted twelve-TSV fixture bundle SHA-256:
  `ea36e31a685b80e0562a04400758bcf1b2dae3be596a3afa45a0f809be9b70f5`

The current workspace `HFT_Grid_AI.ex5` is the historical pre-V13 artifact:
`245,208` bytes, modified `2026-08-13 19:41:28 -0400`, SHA-256
`553af41908b3061978bba8b5643110b92765953ef3429654ce1d03aa0db2ab84`.
It is a baseline only and must be replaced by the Sprint 8 compile; it is not
V13 acceptance evidence.

## Completed Evidence

- Sprint 1: strict V13 files, headers, types, identities, duration/censoring,
  atomic capacity, and V12 rejection committed at `8b2069b`.
- Sprint 2: structural/midpoint H1 lanes, no retries, and V13 magic isolation
  committed at `f05678b`.
- Sprint 3: causal configurable M10 window/lifecycle committed at `84bfb36`.
- Sprint 4: one configured-Micro snapshot, parent links, and deep `1R/2R/3R`
  outcomes committed at `af08a2f`.
- Sprint 5: strict twelve-file V13 exporter committed at `1597448`.
- Sprint 6: typed native-grain builder/audit/training committed at `a684db5`.
- Python `compileall`: PASS.
- Contract suite: `35` tests, PASS.
- Fixture validate/build/audit: PASS, `AUDIT_COMPLETE`.
- H1/deep loader selection: `8`/`5` rows; expected support rejection below
  `500` rows proves the fixture cannot imply deployment support.

## Sprint 8 Acceptance Matrix

| Gate | Required evidence | Status |
| --- | --- | --- |
| MetaEditor preflight | `get_workspace_info`, allowed roots, compiler build, `can_compile_file` | PENDING |
| Compile | `compile_file`, `0 errors, 0 warnings` | PENDING |
| Binary | regenerated `.ex5` timestamp, size, and SHA-256 | PENDING |
| H1 lanes | structural/midpoint touch/no-touch and `1R/2R/3R/5R` exits | PENDING |
| Deep events | shared same-direction M10 identity and one configured-Micro snapshot | PENDING |
| Parent timing | exact uncapped lifecycle seconds and M10 parent age | PENDING |
| Censoring | parent-exit/run-end/capacity states are not losses | PENDING |
| Broker safety | one structural H1 `1R` path, immutable SL/TP, no deep order | PENDING |
| Export parity | matched export-off/on broker event stream | PENDING |
| Operations | DST/session, state caps, performance, cleanup, chart behavior | PENDING |
| V13 run | twelve files, natural seal, strict validate/build/audit | PENDING |

## Human Tester Record

Record the operator-selected symbol, chart period, real-tick interval, terminal
build, deposit/leverage, execution delay, session mode, all four public input
groups, export-on/off elapsed time, memory/state peaks, file counts/sizes, and
bounded scenario observations. Do not commit account IDs, credentials, raw TSV
contents, or full journals.

## Final Decision Rule

Acceptance requires every Sprint 8 matrix row to pass, one sprint-specific
commit named `chore: accept pivot v13 producer compile and tester gate`, and an
updated handoff with the final source/binary/run hashes. Until then, the Django
cutover gate remains closed and no live rollout is authorized.
