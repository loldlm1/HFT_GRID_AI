# Session Time Filter Guide

## Purpose

The session time filter is preserved as strategy-neutral foundation behavior. It controls when the EA may evaluate or act on strategy execution, independent of the removed legacy strategy add-ons.

## Inputs

- `Session_Asia_Filter_Mode`
- `Session_Asia_Filter_Time_Range`
- `Session_London_Filter_Mode`
- `Session_London_Filter_Time_Range`
- `Session_NewYork_Filter_Mode`
- `Session_NewYork_Filter_Time_Range`
- `Session_Time_Dst_Mode`
- `Session_Time_Dst_Manual_Offset_Minutes`

## Behavior

- `SESSION_FILTER_OFF` disables a session slot.
- `SESSION_FILTER_ALLOW_RUN` allows execution during the configured session window.
- `SESSION_FILTER_FORCE_CLOSE` is reserved for defensive session handling where supported by the execution lifecycle.
- Time ranges use `HH:MM-HH:MM` in 24-hour format.
- DST handling is controlled by the session DST inputs.

## Foundation Rule

Session gating must be applied before local simulated execution and before real broker order sends. It must not be bypassed by future strategies unless a later phase explicitly changes the risk model.

## Validation

This doc is maintained as active product guidance. Runtime implementation changes are validated by the phase-level MT5 compile gate, not by custom MQL5 tests.
