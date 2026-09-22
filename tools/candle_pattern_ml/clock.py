"""Versioned export-clock expectations, independently checked with IANA New York."""

from datetime import datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

CLOCK_POLICIES = {
    "FIXED_TIME_SESSIONS": {
        "broker_time_basis": "BROKER_NATIVE",
        "analysis_clock_policy": "BROKER_FIXED_V1",
        "analysis_calendar": "NONE",
        "analysis_calendar_coverage": "NOT_APPLICABLE",
    },
    "EXNESS_SESSION": {
        "broker_time_basis": "UTC_SHIFT_0",
        "analysis_clock_policy": "EXNESS_NEW_YORK_V1",
        "analysis_calendar": "US_NEW_YORK",
        "analysis_calendar_coverage": "US_2007_RULES_2007_2099",
    },
}
CLOCK_MANIFEST_KEYS = {"broker_session", *CLOCK_POLICIES["EXNESS_SESSION"]}
CLOCK_SUMMARY_KEYS = {"last_analysis_time_msc", "last_analysis_offset_minutes"}


def analysis_clock(broker_msc: int, session: str) -> tuple[int, int]:
    if type(broker_msc) is not int or not 0 < broker_msc < 2**63:
        raise ValueError("Invalid broker milliseconds")
    if session == "FIXED_TIME_SESSIONS":
        return broker_msc, 0
    if session != "EXNESS_SESSION":
        raise ValueError("Unknown broker session")
    try:
        instant = datetime.fromtimestamp(broker_msc // 1000, timezone.utc)
    except (ValueError, OverflowError, OSError) as exc:
        raise ValueError("Clock outside supported calendar coverage") from exc
    if not 2007 <= instant.year <= 2099:
        raise ValueError("Clock outside supported calendar coverage")
    try:
        new_york = ZoneInfo("America/New_York")
    except ZoneInfoNotFoundError as exc:
        raise ValueError("New York timezone database unavailable") from exc
    offset = 0 if instant.astimezone(new_york).dst() else -60
    return broker_msc + offset * 60000, offset
