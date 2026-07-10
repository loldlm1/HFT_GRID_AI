# Broker-First Strategy Tester Verification Matrix

**Status**: Human-in-the-loop validation checklist
**Created**: 2026-07-09
**Scope**: Broker-first execution, target-currency risk cap, EA-managed partial TP, and schema v6 deterministic statistics.

This project does not use custom MQL5 tests or CI for this scope. Use MetaEditor
compile as the agentic gate and this matrix for human Strategy Tester/chart
validation.

## Shared Setup

- Build: latest `HFT_Grid_AI.ex5` compiled from `HFT_Grid_AI.mq5`.
- Enable only the deterministic strategy under test where possible.
- Use visual mode for lifecycle/partial TP cases.
- For export scenarios, set `Enable_Signal_Feature_Export = true` and a unique
  `Signal_Feature_Run_Id`.
- Keep `ML_Inference_Mode = ML_INFERENCE_DISABLED` unless specifically testing
  the approved Strategy Tester-only filter.
- Prefer `Enable_Logs = false` and `Enable_File_Logs = false` for long runs;
  enable them only for short diagnostic passes.

## Matrix

| Scenario | Setup | Expected observation | Inspect |
| --- | --- | --- | --- |
| High-spread admission block | Set `Max_Spread` below observed spread. | Candidate is captured, broker send is denied, active lifecycle/reconciliation still runs. | `signal_admissions.tsv` has `candidate` and `admission_blocked`; no matching broker outcome row. |
| Normal broker admission | Use realistic spread and margin. | Candidate passes local broker eligibility and sends one broker order. | Admissions include `admission_allowed`, `broker_send`, and `broker_entry`; feature row appears after broker entry. |
| Target-currency 1:1 risk | Use `Lot_Type = EXECUTION_LOT_TARGET_CURRENCY`, target `50`, `TP_Percent = 100`. | Expected SL loss is capped near 50 account-currency units and expected TP profit is congruent when broker volume constraints allow it. | Admission risk fields: `risk_target_amount`, `expected_sl_loss`, `expected_tp_profit`, `normalized_lot`. |
| Min-volume infeasible target | Use a target below the symbol minimum-volume risk. | Broker admission is blocked instead of rounding up into excess risk. | `admission_blocked` reason and risk-plan fields; no broker send. |
| Partial TP 1R/2R/3R | Set `Partial_TP_Mode = PARTIAL_TP_R_MULTIPLES`. | EA closes real broker partial volumes at 1R, 2R, and final 3R where reached. | Outcome broker partial fields show confirmed levels/volumes; chart/history shows actual partial closes. |
| SL after partial | Enable partial TP and pick a run where price hits a partial level then reverses to SL. | Realized outcome reflects broker partial close plus remaining-volume SL close. | Broker history, `broker_close_source`, partial fields, final `net_profit`. |
| Forced close without exposure | Trigger protection/session force-close while signals are pending or admission-blocked. | Pending/no-ticket signals are canceled, not counted as wins or losses. | Admissions include `lifecycle_cancel`; no `signal_outcomes.tsv` row for no-exposure signals. |
| Forced close with exposure | Trigger force-close with a real broker position open. | EA closes scoped broker position and records confirmed close facts. | Broker history, `broker_close`, `broker_close_confirmed=true`, final outcome row. |
| Insufficient margin/precheck denial | Use high lot/risk settings or low tester deposit. | Order precheck/admission blocks before send or broker send fails with retcode; no invented outcome. | Admission reason/retcode, `MarketStatusRegisterBrokerFailure` logs if enabled, no broker outcome unless a real close exists. |
| Path-label review | Run with schema v6 export enabled. | Path ratios remain trajectory labels, not realized TP2/TP3 outcomes. | `path_label_source`, `path_status`, and partial TP fields in `signal_outcomes.tsv`. |

## Modeling Notes

- Exits are EA-managed, not server-side SL/TP. Tester modeling quality and tick
  sequence affect close timing, especially partial TP and SL-after-partial
  cases.
- Slippage, gaps, commission, swap, and broker execution conditions may make
  realized P/L differ from expected risk-plan telemetry.
- A scenario passes statistically only when broker-confirmed outcomes are
  separated from candidate/admission/path-derived rows.
