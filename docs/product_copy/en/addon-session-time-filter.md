# Product Copy - Session Time Filter

## Product

- Name: `Session Time Filter`
- Type: `Foundation control`
- SKU: `addon_session_time_filter`

## Short Copy Block

`Control when the EA may evaluate or execute strategy logic by defining Asia, London, and New York session windows.`

## Medium Copy Block

`The Session Time Filter is preserved as strategy-neutral foundation behavior. It helps users avoid unwanted market hours by allowing or restricting execution during configured session windows.`

`For non-traders: this works like business hours for the EA. It defines when the system is allowed to operate before any future strategy proceeds to execution.`

## Inputs Explained

- `Session_Asia_Filter_Mode`: Asia session behavior.
- `Session_Asia_Filter_Time_Range`: Asia session range in `HH:MM-HH:MM`.
- `Session_London_Filter_Mode`: London session behavior.
- `Session_London_Filter_Time_Range`: London session range.
- `Session_NewYork_Filter_Mode`: New York session behavior.
- `Session_NewYork_Filter_Time_Range`: New York session range.
- `Session_Time_Dst_Mode`: DST handling mode.
- `Session_Time_Dst_Manual_Offset_Minutes`: manual DST offset when selected.

## Foundation Rule

Session rules are evaluated before local simulated execution and before real broker sends.
