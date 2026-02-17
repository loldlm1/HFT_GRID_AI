# Addon Guide: Time Filter Session Manager

## SKU
- `addon_session_time_filter`

## What this addon unlocks
- Time-window gating for Asia, London, and New York sessions.
- Per-session behavior control (`ALLOW_RUN` or `FORCE_CLOSE`).

## Inputs in this group
- `Session_Asia_Filter_Mode`
- `Session_Asia_Filter_Time_Range`
- `Session_London_Filter_Mode`
- `Session_London_Filter_Time_Range`
- `Session_NewYork_Filter_Mode`
- `Session_NewYork_Filter_Time_Range`

## Entitlement trigger rule
Addon is required when any session mode is not `SESSION_FILTER_OFF`.

## Time format
- Use `HH:MM-HH:MM` in 24h format.
- Example: `07:00-12:00`.

## Recommended setups
### Setup A: London + New York focus (balanced)
- `Session_Asia_Filter_Mode = SESSION_FILTER_OFF`
- `Session_London_Filter_Mode = SESSION_FILTER_ALLOW_RUN`
- `Session_London_Filter_Time_Range = 07:00-12:00`
- `Session_NewYork_Filter_Mode = SESSION_FILTER_ALLOW_RUN`
- `Session_NewYork_Filter_Time_Range = 12:00-20:00`

### Setup B: Day-end flattening (defensive)
- `Session_Asia_Filter_Mode = SESSION_FILTER_OFF`
- `Session_London_Filter_Mode = SESSION_FILTER_ALLOW_RUN`
- `Session_London_Filter_Time_Range = 07:00-12:00`
- `Session_NewYork_Filter_Mode = SESSION_FILTER_FORCE_CLOSE`
- `Session_NewYork_Filter_Time_Range = 12:00-20:00`

## If addon is missing
- EA startup is blocked.
- Chart comment shows missing addon key.
