"""Causal feature registry and independent feature calculations for validation."""

from decimal import Decimal, ROUND_HALF_UP
from types import MappingProxyType

from .schema_contract import TABLE_BY_NAME

SERIES = ("stochastic_k", "stochastic_d", "percent_b", "percent_b_sma_5", "atr_13", "atr_13_sma_5")
FEATURES = MappingProxyType({f.name: f for f in TABLE_BY_NAME["feature_snapshots.tsv"].fields
                             if f.classification == "CAUSAL_FEATURE"})


def percent_b(high: Decimal, low: Decimal, close: Decimal, lower: Decimal, upper: Decimal) -> Decimal | None:
    if upper <= lower:
        return None
    return 100 * ((high + low + 2 * close) / 4 - lower) / (upper - lower)


def sma(values: list[Decimal | None], period: int = 5) -> tuple[Decimal | None, ...]:
    if period <= 0:
        raise ValueError("Period must be positive")
    return tuple(None if any(v is None for v in values[i:i + period]) else
                 sum(values[i:i + period], Decimal(0)) / period
                 for i in range(max(0, len(values) - period + 1)))


def structure_class(kind: int, price: Decimal, previous: Decimal | None, tick: Decimal) -> str:
    if kind not in (-1, 1) or tick <= 0 or not price.is_finite():
        raise ValueError("Invalid structure comparison")
    if previous is None:
        return "HIGH" if kind == 1 else "LOW"
    current_tick, prior_tick = ((v / tick).quantize(Decimal(1), rounding=ROUND_HALF_UP) for v in (price, previous))
    if current_tick == prior_tick:
        return "EQ"
    return ("HH" if current_tick > prior_tick else "LH") if kind == 1 else ("HL" if current_tick > prior_tick else "LL")


def pivot_zone(bid: Decimal, prices: tuple[Decimal, ...]) -> tuple[str, Decimal | None, Decimal | None]:
    from .schema_contract import LEVELS

    if len(prices) != 7 or not all(a < b for a, b in zip(prices, prices[1:])):
        raise ValueError("Invalid pivot ladder")
    if bid < prices[0]:
        return "BELOW_S3", None, prices[0]
    for i, price in enumerate(prices):
        if bid == price:
            return "AT_" + LEVELS[i], price, price
        if i < 6 and bid < prices[i + 1]:
            return LEVELS[i] + "_TO_" + LEVELS[i + 1], price, prices[i + 1]
    return "ABOVE_R3", prices[-1], None
