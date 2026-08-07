# V11 Dataset Column Type Registry Acceptance

The accepted raw run
`2026.01.05_00_00_00_XAUUSD_pivot_v11` now completes the official toolchain
without a type override:

- validate: 7,178 origins, 186,036 trials, 185,788 outcomes; 119.08s and
  1,935,292 KB peak RSS;
- build: `v11_type_registry_xauusd_20260105_20260731`; 181.15s and
  1,935,524 KB peak RSS;
- audit: `v11_type_registry_xauusd_20260105_20260731_audit`; 7,032 strict
  pairs, 7,032 matches, zero mismatches; 2.36s and 158,948 KB peak RSS;
- training: `v11_type_registry_xauusd_20260105_20260731_model`; 178,701 rows;
  746.65s and 2,024,896 KB peak RSS; `OFFLINE_RESEARCH_ONLY`.

All official table counts match the prior diagnostic build, all 13 Parquet
tables are semantically identical, and the four ablation metrics are exact.
`block_source` is `VARCHAR` across all 28,466 execution checks, including 7,054
`broker_close` rows. The query hash remains
`e913a0dd82c9f4db7a5c2091f438ad574e43a97cb0b73046b537753854487858`;
all eight raw TSV hashes also remain unchanged.

The accepted run starts after the user's intentional fresh binary regeneration:
`HFT_Grid_AI.ex5` is 236,798 bytes, modified
`2026-08-07 17:12:13.571463230 -0400`, SHA-256
`169685833d0f10e0504352b2b9333778aef29e4aabdd2d5d5e05d0daffdccb33`.
The prior agent compile log remains the separate clean compile evidence; this
Python-only plan did not invoke MetaEditor.

No runtime optimization is warranted from this evidence. Routine dataset builds
need not run a separate `--validate-only` command because build validates
internally, and Strategy Tester evidence runs should disable file logging when
debug telemetry is not required. No MQL5 compile was needed for this
Python-only correction.
