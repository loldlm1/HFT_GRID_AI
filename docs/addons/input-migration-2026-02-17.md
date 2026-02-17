# Input Migration Note (2026-02-17)

Breaking input rename applied:

- `Grid_Base_Strategy_Type` -> `Base_Strategy_Type`
- `Grid_Points_Range_Setup` -> `Points_Range_Setup`

## Impact
- Existing `.set` files using old names will not map automatically.
- Tests, scripts, and docs that reference old names must be updated.

## `.set` example mapping
Old:
```text
Grid_Base_Strategy_Type=1
Grid_Points_Range_Setup=100.0
```

New:
```text
Base_Strategy_Type=1
Points_Range_Setup=100.0
```

## Recommended migration flow
1. Load old preset.
2. Re-apply values to new input names.
3. Save a new preset file version.
4. Re-run compile/runtime gates.
