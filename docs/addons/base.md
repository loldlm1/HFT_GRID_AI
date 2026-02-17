# Base EA Guide (No Addons Required)

## Included input groups
- `EA_License_Key`
- `Account Settings EA`
- `Protection Risk Management`
- `Strategy Context`
- `Risk Managment Settings`

## Base controls that stay unlocked
- `Base_Strategy_Type`
- `Points_Range_Setup`
- `Lot_Type`
- `Lot_Strategy_Size`
- `Lot_Multiplier`
- `Signal_Lot_Strategy`
- `TP_Percent`
- `Daily_Signal_Limit`
- `Daily_Signal_Limit_Mode`

## Recommended baseline setup
Use this as a safe starting profile before enabling paid addons.

- `Max_Spread = 200`
- `Min_Range_Points = 200`
- `Protection_Risk_Mode = ENABLED_GRID_PROTECTION`
- `Protection_Risk_Drawdown_Type = PROTECTION_RISK_ACCOUNT_SIZE_PERCENT`
- `Protection_Risk_Drawdown_Value = 10`
- `Strategy_Timeframe = PERIOD_M1`
- `Stoch_Structure_Period_Type = 5`
- `Structure_Trigger_Entry = LEVELS_AS_LIMITS`
- `Structure_Touch_Policy = ALLOW_RETEST`
- `Strategy_Direction_Mode = BOTH_DIRECTION`
- `Signal_Concurrency_Mode = SINGLE_RUNNING_SIGNAL`
- `Base_Strategy_Type = POINTS_RANGE`
- `Points_Range_Setup = 100`
- `Lot_Type = GRID_LOT_SIZE`
- `Lot_Strategy_Size = 0.01`
- `Lot_Multiplier = 2.0`
- `Signal_Lot_Strategy = RISK_STRATEGY_OFF`
- `TP_Percent = 100`

## License requirements
- `EA_License_Key` must decrypt successfully.
- Embedded key expiry timestamp must be in the future.
- If key validation fails, `OnInit` fails and EA does not start.

## Runtime behavior
- Live and Demo: license state is refreshed every 24h.
- On refresh failure, EA removes itself.
- Strategy Tester: key and expiry checks apply, addon entitlement checks are bypassed.
