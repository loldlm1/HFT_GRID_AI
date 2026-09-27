# Shared MQL5 Dataset Validation

This local tool validates schema 1 of `MQL5_MODEL_FEATURES` for
`PIVOT_MACRO_V1/V2` and `CANDLE_PATTERN_ATR_V2/V3`. Each exact engine/producer/
outcome tuple selects its own admission and expiry requirements. The
[producer contract](../../docs/architecture/model-feature-dataset.md) defines
the features, fields, provenance and engine policies; the
[project index](../../docs/README.md) owns implementation and native acceptance.

The tool uses stdlib Decimal, SQLite and IANA zoneinfo. It installs no database
service and has no Django dependency. A temporary disk index bounds Python
memory while validating every row, clock, relationship, seal and source hash.
The index is removed when the context closes; source exports are read-only.
Temporary lookup indexes include outcomes by attempt, preventing Candle re-entry
checks from rescanning all historical outcomes. Validation rules remain exact.

```bash
.venv/bin/python -m tools.model_dataset.schema_contract --write-mql-header services/model_features/schema.mqh
.venv/bin/python -m tools.model_dataset.schema_contract --check-mql-header services/model_features/schema.mqh
.venv/bin/python -m tools.model_dataset.schema_contract --write-json .codex-artifacts/model-feature-framework/s6/consumer-contract.json
.venv/bin/python -m tools.model_dataset.reader "$MODEL_RUN_PATH" --report "$MODEL_REPORT_PATH"
rtk test .venv/bin/python -m unittest discover -s tools/model_dataset/tests -t . -p 'test_*.py'
```

The generated header is used by both EAs. Change the typed descriptor first,
regenerate/check the header and JSON contract, then recompile affected producers.
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
The third descriptor in tests is synthetic and is not a trading engine. Follow
the [integration checklist](../../docs/research/model-feature-producer-handoff.md#adding-an-engine)
and retain independent acceptance for each engine's broker behavior.

Registration also declares per-callback work, resource caps, cleanup/retries and
cache invalidation under the [runtime performance contract](../../docs/architecture/market-data-broker-executor.md#performance-contract).
Reuse generated table-qualified field IDs and clock offsets; schema generation
keeps indexed access checked. Validate exact ordered bytes and broker facts
before accepting a measured speed change. Shared changes cover both engines,
including export failure/seal behavior and growing-history resource evidence.

The [producer handoff](../../docs/research/model-feature-producer-handoff.md) maps
legacy fields and versions and locates accepted native receipts. Its ignored
`s6/` bundle contains the machine-readable contract, valid synthetic examples,
intentional refusal examples, source/EX5/run pins and checksums. No private native
dataset is a tracked fixture. A failed example remains failed; never repair a
source in place to make validation pass.

The completed older handoff remains historical. The
[entry-quality/lifecycle supplement](../../docs/research/entry-quality-lifecycle-backend-handoff.md)
delivers the 2.10 profiles and backend daily offset/limit requirements. Its private
`.codex-artifacts/entry-quality-lifecycle/s5/` bundle contains the current JSON
descriptor, seven valid/four refusal examples, final native receipts and SHA-256
pins. Profiles declare fixed coefficients, conditional required trial proof and
supported durations; generic nullable columns alone do not establish admission.
Generate a matching descriptor without changing MQL source:

```bash
.venv/bin/python -m tools.model_dataset.schema_contract --write-json .codex-artifacts/entry-quality-lifecycle/s5/consumer-contract.json
```

Do not transfer `ModelRun`'s temporary SQLite implementation into backend runtime.
The backend retains its own typed bounded PostgreSQL intake and full READY checks.

Historical Pivot V14 and Candle 1/2/3 sources continue to use their existing local
readers. This package cannot read those older datasets under new semantics.
Django intake and chart/full-history/broker-feed acceptance remain separate.
