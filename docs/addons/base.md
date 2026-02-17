# Base EA (No Addons Required)

## Included input groups
- `EA_License_Key`
- `Account Settings EA`
- `Protection Risk Management`
- `Strategy Context`
- `Risk Managment Settings`

## Base-allowed strategy controls
These controls are available without the Grid addon:
- `Base_Strategy_Type`
- `Points_Range_Setup`

## License requirements
- `EA_License_Key` must decrypt correctly.
- The embedded expiry timestamp must be greater than current server time.
- If key validation fails, EA startup fails.

## Runtime behavior
- Live/Demo: entitlement check is refreshed daily.
- Strategy Tester: key/expiry is validated locally; addon entitlements are not fetched online.
