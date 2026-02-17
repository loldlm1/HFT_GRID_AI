# Input Migration Note (2026-02-17)

Breaking input rename applied:

- `Grid_Base_Strategy_Type` -> `Base_Strategy_Type`
- `Grid_Points_Range_Setup` -> `Points_Range_Setup`

## Impact
- Existing `.set` files using old names will not map automatically.
- Tests or scripts that reference old names must be updated.

## Recommended migration
1. Load old preset.
2. Re-save preset after setting the new input names.
3. Re-run compile/runtime test gates.
