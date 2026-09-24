"""Analysis clocks verified through IANA, independently of the MQL calendar."""

from datetime import datetime, timezone
from zoneinfo import ZoneInfo


def analysis_clock(raw_msc: int, session: str) -> tuple[int, int]:
    if type(raw_msc) is not int or not 0 < raw_msc < 2**63:
        raise ValueError("Invalid broker milliseconds")
    if session == "FIXED_TIME_SESSIONS":
        return raw_msc, 0
    if session != "EXNESS_SESSION":
        raise ValueError("Unknown broker session")
    try:
        instant = datetime.fromtimestamp(raw_msc // 1000, timezone.utc)
    except (ValueError, OverflowError, OSError) as exc:
        raise ValueError("Clock outside supported calendar") from exc
    if not 2007 <= instant.year <= 2099:
        raise ValueError("Clock outside 2007..2099")
    offset = 0 if instant.astimezone(ZoneInfo("America/New_York")).dst() else -60
    return raw_msc + offset * 60000, offset
