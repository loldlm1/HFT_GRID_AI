"""Validation helpers for deterministic signal Phase 1 export runs."""

from __future__ import annotations


class Phase1ValidationError(RuntimeError):
    """Raised when a Phase 1 export folder cannot be used as a dataset input."""
