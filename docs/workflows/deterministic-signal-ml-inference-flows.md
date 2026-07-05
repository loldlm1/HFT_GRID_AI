# Deterministic Signal ML Inference Flows

**Status**: Active workflow reference
**Created**: 2026-07-05

This document replaces the completed Phase 1-6 plans as the compact human and
agentic reference for deterministic signal ML use. Historical sprint plans and
acceptance evidence are archived under:

- `docs/plans/archive/deterministic-signal-ml-2026-07-05/`
- `docs/research/archive/deterministic-signal-ml-2026-07-05/`

`ML_INFERENCE_FILTER` is approved for Strategy Tester validation only. Live use
requires a future explicit plan, human approval, monitoring rules, and rollback
criteria.

## Use The Model For Backtesting Or Future Live Approval

```mermaid
flowchart TD
    A[Run Strategy Tester without ML<br/>to generate signal data] --> B[Export historical signal features<br/>and closed outcomes]
    B --> C[Train model in Python]
    C --> D[Validate model on chronological<br/>out-of-sample data]
    D --> E{Model approved?}

    E -- No --> F[Adjust dataset, features,<br/>strategy config, or threshold]
    F --> C

    E -- Yes --> G[Export frozen MT5 artifact<br/>xgb_test_1_export_v1]
    G --> H[Copy artifact to MT5 Common Files]
    H --> I[Run Strategy Tester in SHADOW]
    I --> J[Compare MQL5 scores<br/>against Python scorer]

    J --> K{Parity PASS?}
    K -- No --> L[Fix export or MQL5 inference]
    L --> G

    K -- Yes --> M[Run Strategy Tester in FILTER]
    M --> N[Summarize allow and block decisions]
    N --> O[Compare FILTER predictions<br/>against Python scorer]
    O --> P{Runtime validation PASS?}

    P -- No --> F
    P -- Yes --> Q[Model ready for controlled<br/>backtesting inference]

    Q --> R{Future live approval?}
    R -- No --> S[Keep FILTER limited<br/>to Strategy Tester]
    R -- Yes --> T[Create live rollout plan<br/>with limits, monitoring, and rollback]
    T --> U[Enable live only after<br/>explicit human approval]
```

## How The Model Learns And Why The Process Is Robust

```mermaid
flowchart TD
    A[EA detects deterministic signals] --> B[EA records stable features<br/>for broker-entered signals]
    B --> C[EA records terminal outcomes<br/>TP, SL, profit_r, net_profit]
    C --> D[Python joins features and outcomes]
    D --> E[Dataset validator checks files,<br/>headers, joins, duplicates, and signs]

    E --> F[Chronological split]
    F --> G[Train on earlier market history]
    F --> H[Validate on later unseen history]

    G --> I[XGBoost learns signal patterns<br/>from deterministic features]
    H --> J[Metrics test whether patterns<br/>generalize forward in time]

    J --> K{Metrics and threshold acceptable?}
    K -- No --> L[Reject or retrain model]
    L --> G

    K -- Yes --> M[Freeze model as export artifact]
    M --> N[Export tree and feature contract<br/>to MT5-readable TSV files]
    N --> O[MQL5 loads same frozen artifact]
    O --> P[SHADOW compares MQL5 scores<br/>against Python scores]
    P --> Q{Parity PASS?}

    Q -- No --> R[Reject runtime inference<br/>until scorer parity is fixed]
    Q -- Yes --> S[FILTER may block entries<br/>in Strategy Tester only]

    S --> T[Existing broker and risk gates<br/>still run before broker send]
    T --> U[Runtime summary checks scored rows,<br/>ALLOW/BLOCK counts, and invalid features]
    U --> V[PASS only when parity, counters,<br/>and Strategy Tester behavior agree]
```

## Current Accepted Runtime Evidence

- Export ID: `xgb_test_1_export_v1`
- Strategy Tester run ID: `shadow_test_run_1`
- Runtime mode: `ML_INFERENCE_FILTER`
- Prediction rows: `4846`
- Scored rows: `4846`
- Admission `ALLOW`: `301`
- Admission `BLOCK`: `4545`
- Invalid feature rows: `0`
- Unavailable rows: `0`
- Python/MQL5 decision agreement: `1`
- Result: Phase 6 Strategy Tester `FILTER` validation `PASS`
