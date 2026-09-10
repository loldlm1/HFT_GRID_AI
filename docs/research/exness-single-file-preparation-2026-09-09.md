# Exness Single-File Preparation - 2026-09-09

The maintained `prepare-mt5-file` service completed one reusable MT5 tick TSV
for each requested symbol. The frozen cutoff is **2026-09-08 00:00 UTC
exclusive**; the September 8 UTC day was incomplete when selected and excluded.
Coverage is the full published source history through September 7, not a claim
that the provider supplied every possible historical tick.

| Symbol | First source day (UTC) | Ticks | Bytes | Cached preparation (seconds) |
| --- | --- | ---: | ---: | ---: |
| XAUUSD | 2015-08-10 | 333,083,223 | 15,247,608,724 | 197.680 |
| EURUSD | 2015-08-10 | 168,825,623 | 7,391,160,868 | 82.444 |
| GBPJPY | 2015-08-10 | 204,237,488 | 8,940,893,387 | 119.223 |
| BTCUSD | 2017-09-26 | 312,330,265 | 14,162,571,742 | 174.248 |

Total: 1,018,476,599 ticks and 45,742,234,721 bytes. Timings include source
conversion, required stable sorting, complete final audit and checksum readback
from cached archives on this host; they exclude network downloads and are not
controlled comparative benchmarks. Only six of the 99 source archives required
sorting. Ordered sources use bounded streaming conversion.

## Persistent Files

The visible directory is `/home/admin/Documents/Exness_Tick_Data`, also reachable
from MT5/Wine as `C:\users\admin\Documents\Exness_Tick_Data`. Each symbol has
`<SYMBOL>_ticks.tsv` and `<SYMBOL>_manifest.json`. `README.md` records import
settings, and `SHA256SUMS` records these verified hashes:

```text
bd443ff944f345a236932f5d68c2bd9c61cdfd47131b2740aa1e4e0bd5f7f8f4  XAUUSD_ticks.tsv
4cd8ee86abbc9d4247be29d24049e835456da476181e5cedfa7b054605210c3f  EURUSD_ticks.tsv
2a79a0219d4656e7b1a84b1418beae018b76e4b254542f1f82b6734695abb8d8  GBPJPY_ticks.tsv
cad984be7c2a274207090fd4f061c7d8b1339e10f188efd0dc97bd528bfaa32a  BTCUSD_ticks.tsv
```

The task's duplicate tick files, downloaded archives, extracted CSVs and source
parts were removed. Small inventories, checkpoints, hashes and validation
records remain under ignored task/service paths. No task data intermediates
remain. Existing unrelated archive collections were preserved.

## EURUSD Policy

The user approved `--normalize-eurusd-decimal-artifacts`. Values with more than
12 decimal places may become five-decimal quotes only within an exact `1e-16`
distance. All 168,825,623 source ticks remain. There were 3,349,652 adjusted quote
values across 3,347,662 ticks, with a maximum change of exactly `1e-16`.
For example, `1.1847699999999999` becomes `1.18477`. The manifest records the
policy and per-source counts, maxima and bounded before/after examples.
Other symbols retained strict source quotes; no raw archive was rewritten.

## Validation And Boundaries

- All 91 Exness service tests pass, including 17 new preparation tests.
- Python compileall and C++17 compilation with `-Wall -Wextra -Werror` pass.
- Source CRC/grammar/interval/quote checks and per-source/daily row conservation
  pass. Repeated ticks, equal-time ordering and UTC milliseconds are retained.
- Every complete final TSV passes native-format, row-count, quote and timestamp
  ordering checks plus SHA-256 readback. Three strict outputs also match earlier
  independently prepared files byte for byte; EURUSD has an additional final
  checksum readback after publication.
- September 5 unavailable daily archives for XAUUSD, EURUSD and GBPJPY remain
  explicit in the manifests. No rows were synthesized for unavailable sources.
- No MQL5 source changed. Full-range native import, custom-symbol specifications,
  broker equivalence and Strategy Tester acceptance were not performed here.

The resumable service keeps one accumulating output, verifies committed byte
ranges, atomically publishes the final file and deletes owned temporary inputs
by default. See the [service command](../../tools/exness_tick_history/README.md#one-persistent-mt5-file-per-symbol)
and [workflow](../../tools/exness_tick_history/README.md#operator-validation-queue) for future preparation and
the separate native acceptance path.
