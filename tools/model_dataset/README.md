# Shared MQL5 Dataset Validation

This local tool validates schema 1 of `MQL5_MODEL_FEATURES` for
`PIVOT_MACRO_V1` and `CANDLE_PATTERN_ATR_V2`. The
[producer contract](../../docs/architecture/model-feature-dataset.md) defines
the features, fields, provenance and engine policies; the
[project index](../../docs/README.md) owns implementation and native acceptance.

The tool uses stdlib Decimal, SQLite and IANA zoneinfo. It installs no database
service and has no Django dependency. A temporary disk index bounds Python
memory while validating every row, clock, relationship, seal and source hash.
The index is removed when the context closes; source exports are read-only.

```bash
.venv/bin/python -m tools.model_dataset.schema_contract --write-mql-header services/model_features/schema.mqh
.venv/bin/python -m tools.model_dataset.schema_contract --check-mql-header services/model_features/schema.mqh
.venv/bin/python -m tools.model_dataset.schema_contract --write-json .codex-artifacts/model-feature-framework/s6/consumer-contract.json
.venv/bin/python -m tools.model_dataset.reader "$MODEL_RUN_PATH" --report "$MODEL_REPORT_PATH"
rtk test .venv/bin/python -m unittest discover -s tools/model_dataset/tests -t . -p 'test_*.py'
```

During Sprint 2, generate the unused header under the ignored evidence directory.
Sprint 3 wires the header into the real Candle EA before any native compile claim.
Report paths must be outside the sealed run. An invalid/incompatible source exits
nonzero. No report implies neither acceptance nor permission to repair a dataset.
Use fresh run IDs for corrected exports and retain the failed original.

`ModelRun` is a context manager exposing immutable source-token rows, counts and
SHA-256 receipts after validation. `compatibility_signature` distinguishes engine,
feature, timeframe, clock, execution and instrument configurations. No automatic
concatenation, suffix mapping, legacy conversion, model fitting or label balancing
is performed. A VERIFIED instrument mapping still needs its external source/spec
provenance receipt; a symbol string alone is not evidence.

`feature_contract.FEATURES` includes only fields classified CAUSAL_FEATURE.
Confirmed structure and the live forming projection have distinct fields.
PARITY is excluded from targets even when its observed exit reached TP or SL;
unentered/censored results have no completed duration or binary label.

New engines register typed extension tables with an explicit core grain, engine
identity, extension version and outcome policy. They reuse common descriptors
and shared providers. They must supply engine semantic checks and fixtures before
becoming an accepted profile; an unregistered descriptor is rejected on intake.
The third descriptor in tests is synthetic and is not a trading engine.

Historical Pivot V14 and Candle 1/2/3 sources continue to use their existing local
readers. This package cannot read those older datasets under new semantics.
Django intake and chart/full-history/broker-feed acceptance remain separate.
