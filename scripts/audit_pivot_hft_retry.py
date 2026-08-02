#!/usr/bin/env python3
"""Validate Pivot HFT retry, fill, recovery, and supersession audit logs."""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


SUPPORTED_SCHEMAS = {2, 3}
AUTHORITATIVE_SCHEMA = 3
SUMMARY_VERSION = 1
DEFAULT_MAX_VIOLATIONS = 20
COMMENT_PATTERN = re.compile(
    r"^PH2_([BS])_([RS][1-3])_R([0-9]+)(?:_T.*)?$"
)
LABEL_PATTERN = re.compile(r"^[A-Z0-9_]+$")
RECONCILIATION_FAILURE_LABELS = {
    "FILL_RECOVERY_CHECKPOINT_FAILED",
    "PROTECTION_CLOSE_FAILED",
    "RECOVERY_QUARANTINE_STATE_FAILED",
    "RECOVERY_STORAGE_FAILURE",
    "VIRTUAL_FILL_UNRESOLVED",
    "VIRTUAL_LIFECYCLE_ABORTED",
}
SUMMARY_COUNTERS = (
    "events_counted",
    "initial_broker_fills",
    "virtual_retry_fills",
    "broker_retry_fills",
    "broker_fills_total",
    "normal_managed_fills",
    "emergency_managed_fills",
    "position_finalizations",
    "candidates_latched",
    "candidates_replaced",
    "candidates_discarded",
    "candidates_promoted",
    "retries_suppressed",
    "recovery_restores",
    "recovery_quarantines",
    "emergency_closes",
    "emergency_reconciled",
    "reconciliation_failures",
)


@dataclass(frozen=True)
class AuditEvent:
    line_no: int
    label: str
    fields: dict[str, str]


@dataclass(frozen=True)
class Violation:
    line_no: int
    label: str
    message: str


@dataclass
class RunReport:
    schema: int = 0
    event_count: int = 0
    counts: Counter[str] = field(default_factory=Counter)
    violations: list[Violation] = field(default_factory=list)


@dataclass
class AuditReport:
    run_reports: list[RunReport]
    parse_violations: list[Violation]

    @property
    def violations(self) -> list[Violation]:
        combined = list(self.parse_violations)
        for run_index, report in enumerate(self.run_reports, 1):
            combined.extend(
                Violation(
                    violation.line_no,
                    violation.label,
                    f"run#{run_index}: {violation.message}",
                )
                for violation in report.violations
            )
        return combined


def add_violation(
    violations: list[Violation],
    event: AuditEvent | None,
    message: str,
) -> None:
    if event is None:
        violations.append(Violation(0, "AUDIT", message))
        return
    violations.append(Violation(event.line_no, event.label, message))


def parse_int(
    event: AuditEvent,
    key: str,
    violations: list[Violation],
    *,
    required: bool = True,
    minimum: int | None = None,
) -> int | None:
    value = event.fields.get(key)
    if value is None:
        if required:
            add_violation(violations, event, f"missing integer field {key}")
        return None
    try:
        parsed = int(value)
    except ValueError:
        add_violation(violations, event, f"invalid integer field {key}")
        return None
    if minimum is not None and parsed < minimum:
        add_violation(violations, event, f"integer field {key} is below minimum")
        return None
    return parsed


def parse_lines(
    lines: Iterable[str],
) -> tuple[dict[str, list[AuditEvent]], list[Violation]]:
    runs: dict[str, list[AuditEvent]] = {}
    violations: list[Violation] = []
    for line_no, raw_line in enumerate(lines, 1):
        line = raw_line.rstrip("\r\n")
        if not line:
            continue
        parts = line.split(" | ", 2)
        if len(parts) != 3:
            violations.append(
                Violation(line_no, "PARSE", "malformed audit row")
            )
            continue
        _, label, payload = parts
        if not LABEL_PATTERN.fullmatch(label):
            violations.append(
                Violation(line_no, "PARSE", "invalid event label")
            )
            continue

        fields: dict[str, str] = {}
        duplicates: set[str] = set()
        malformed_token = False
        for token in payload.split("|"):
            if "=" not in token:
                malformed_token = True
                continue
            key, value = token.split("=", 1)
            if not key:
                malformed_token = True
                continue
            if key in fields:
                duplicates.add(key)
                continue
            fields[key] = value

        event = AuditEvent(line_no, label, fields)
        if malformed_token:
            add_violation(violations, event, "malformed payload token")
        if duplicates:
            add_violation(violations, event, "duplicate payload key")
        run_id = fields.get("run")
        if not run_id:
            add_violation(violations, event, "missing run id")
            continue
        runs.setdefault(run_id, []).append(event)
    return runs, violations


def expected_source(threshold: int, retry_number: int) -> str:
    if retry_number <= 0 or threshold <= 1:
        return "BROKER"
    if retry_number < threshold:
        return "VIRTUAL"
    return "BROKER"


def execution_identity(
    event: AuditEvent,
    violations: list[Violation],
) -> tuple[str, str] | None:
    source = event.fields.get("execution_source")
    execution_id = event.fields.get("execution_id")
    if source not in {"BROKER", "VIRTUAL"} or not execution_id:
        add_violation(violations, event, "missing execution identity")
        return None
    return source, execution_id


def candidate_identity(
    event: AuditEvent,
    violations: list[Violation],
    *,
    previous: bool = False,
) -> tuple[str, str, str, str, str] | None:
    if previous:
        keys = (
            "previous_owner_sequence",
            "previous_owner_execution_id",
            "previous_level",
            "previous_activation_bar",
            "previous_admission_bar",
        )
    else:
        keys = (
            "owner_sequence",
            "owner_execution_id",
            "candidate_level",
            "candidate_activation_bar",
            "candidate_admission_bar",
        )
    values = tuple(event.fields.get(key, "") for key in keys)
    if any(not value for value in values):
        add_violation(violations, event, "missing candidate identity")
        return None
    return values


def validate_comment_agreement(
    event: AuditEvent,
    violations: list[Violation],
) -> None:
    comment = event.fields.get("comment", "")
    if not comment.startswith("PH2_"):
        return
    match = COMMENT_PATTERN.fullmatch(comment)
    if not match:
        add_violation(violations, event, "malformed PH2 broker comment")
        return
    retry_number = parse_int(event, "retry_number", violations, minimum=0)
    if retry_number is None:
        return
    direction_token, level, comment_retry = match.groups()
    expected_direction = {
        "BULLISH": "B",
        "BEARISH": "S",
    }.get(event.fields.get("dir", ""))
    if expected_direction and direction_token != expected_direction:
        add_violation(violations, event, "broker comment direction mismatch")
    if event.fields.get("level") and level != event.fields["level"]:
        add_violation(violations, event, "broker comment level mismatch")
    if int(comment_retry) != retry_number:
        add_violation(violations, event, "broker comment retry mismatch")


def validate_routing(
    events: list[AuditEvent],
    threshold: int,
    violations: list[Violation],
) -> None:
    for event in events:
        if event.label not in {
            "BROKER_FILL_ACCOUNTED",
            "FILL_REGISTERED",
            "ORDER_SEND_RESULT",
            "VIRTUAL_FILL_REGISTERED",
        }:
            if (
                event.label == "RECOVERY_COMMENT_HINT"
                and event.fields.get("format") == "PH2"
                and event.fields.get("corroboration") != "MATCH"
            ):
                add_violation(
                    violations,
                    event,
                    "preserved broker comment disagrees with checkpoint",
                )
            continue

        retry_number = parse_int(
            event, "retry_number", violations, minimum=0
        )
        if retry_number is None:
            continue
        actual_source = (
            "VIRTUAL"
            if event.label == "VIRTUAL_FILL_REGISTERED"
            else "BROKER"
        )
        declared_source = event.fields.get("execution_source")
        if declared_source and declared_source != actual_source:
            add_violation(
                violations, event, "event execution source mismatch"
            )
        if expected_source(threshold, retry_number) != actual_source:
            add_violation(
                violations, event, "retry routed to the wrong source"
            )
        if threshold == 0 and retry_number > 0:
            add_violation(
                violations, event, "same-level retry exists at threshold 0"
            )
        if event.label == "ORDER_SEND_RESULT":
            validate_comment_agreement(event, violations)


def validate_fill_lifecycles(
    events: list[AuditEvent],
    schema: int,
    violations: list[Violation],
) -> None:
    fills: Counter[tuple[str, str]] = Counter()
    finalizations: Counter[tuple[str, str]] = Counter()
    allowed_recovered: set[tuple[str, str]] = set()
    allowed_emergency: set[tuple[str, str]] = set()
    latest_checkpoint_status: dict[str, str] = {}

    for event in events:
        if event.label in {"FILL_REGISTERED", "VIRTUAL_FILL_REGISTERED"}:
            identity = execution_identity(event, violations)
            if identity:
                fills[identity] += 1
        elif event.label == "POSITION_FINALIZED":
            identity = execution_identity(event, violations)
            if identity:
                finalizations[identity] += 1
        elif event.label == "RECOVERY_POSITION_RESTORED":
            ticket = event.fields.get("ticket", "")
            if ticket and ticket != "0":
                allowed_recovered.add(("BROKER", ticket))
        elif event.label == "EMERGENCY_LIFECYCLE_REGISTERED":
            identity = execution_identity(event, violations)
            if identity:
                allowed_emergency.add(identity)
        elif event.label == "RECOVERY_POSITION_QUARANTINED":
            ticket = event.fields.get("ticket", "")
            if ticket and ticket != "0":
                allowed_emergency.add(("BROKER", ticket))
        elif event.label == "RECOVERY_CHECKPOINT":
            ticket = event.fields.get("ticket", "")
            status = event.fields.get("status", "")
            if ticket and ticket != "0" and status:
                latest_checkpoint_status[ticket] = status

    for identity, count in fills.items():
        if count != 1:
            add_violation(violations, None, "duplicate fill lifecycle identity")
        checkpointed_open = (
            identity[0] == "BROKER"
            and latest_checkpoint_status.get(identity[1], "").endswith(
                ("_ACTIVE", "_CLOSE_WAIT")
            )
        )
        if finalizations[identity] != 1 and not checkpointed_open:
            add_violation(violations, None, "fill has no unique finalization")
    for identity, count in finalizations.items():
        if count != 1:
            add_violation(
                violations, None, "duplicate position finalization identity"
            )
        if (
            identity not in fills
            and identity not in allowed_recovered
            and identity not in allowed_emergency
        ):
            add_violation(violations, None, "orphan position finalization")

    if schema < AUTHORITATIVE_SCHEMA:
        return

    accounted: Counter[str] = Counter()
    normal: Counter[str] = Counter()
    registration_failed: Counter[str] = Counter()
    checkpoint_failed: Counter[str] = Counter()
    emergency_attached: Counter[str] = Counter()
    emergency_unattached: Counter[str] = Counter()
    emergency_reconciled_deals: Counter[str] = Counter()
    emergency_reconciled_tickets: Counter[str] = Counter()
    recovery_quarantine_tickets: Counter[str] = Counter()
    terminal_tickets: Counter[str] = Counter()

    for event in events:
        deal = event.fields.get("deal", "")
        ticket = event.fields.get("ticket", "")
        if event.label == "BROKER_FILL_ACCOUNTED" and deal:
            accounted[deal] += 1
        elif event.label == "FILL_REGISTERED" and deal:
            normal[deal] += 1
        elif event.label == "FILL_REGISTRATION_FAILED" and deal:
            registration_failed[deal] += 1
        elif event.label == "FILL_RECOVERY_CHECKPOINT_FAILED" and deal:
            checkpoint_failed[deal] += 1
        elif event.label == "EMERGENCY_LIFECYCLE_REGISTERED" and deal:
            emergency_attached[deal] += 1
        elif event.label == "EMERGENCY_QUARANTINE_ACTIVE" and deal:
            emergency_unattached[deal] += 1
        elif event.label == "EMERGENCY_EXPOSURE_RECONCILED":
            if deal:
                emergency_reconciled_deals[deal] += 1
            if ticket and ticket != "0":
                emergency_reconciled_tickets[ticket] += 1
        if event.label == "RECOVERY_POSITION_QUARANTINED" and ticket:
            recovery_quarantine_tickets[ticket] += 1
        if (
            event.label == "POSITION_FINALIZED"
            and event.fields.get("close_trigger")
            in {"REGISTRATION_FAILURE", "RECOVERY_FAILURE"}
            and ticket
        ):
            terminal_tickets[ticket] += 1

    for deal, count in accounted.items():
        if count != 1:
            add_violation(violations, None, "duplicate broker fill accounting")
        classifications = (
            normal[deal]
            + registration_failed[deal]
            + checkpoint_failed[deal]
        )
        if classifications != 1:
            add_violation(
                violations,
                None,
                "broker fill is not uniquely normal- or emergency-managed",
            )
    for deal in set(normal) | set(registration_failed) | set(checkpoint_failed):
        if accounted[deal] != 1:
            add_violation(
                violations, None, "managed broker fill lacks accounting"
            )

    for event in events:
        if event.label == "FILL_REGISTRATION_FAILED":
            deal = event.fields.get("deal", "")
            ticket = event.fields.get("ticket", "")
            owners = emergency_attached[deal] + emergency_unattached[deal]
            if not deal or owners != 1:
                add_violation(
                    violations, event, "registration failure lacks emergency owner"
                )
            if not deal or emergency_reconciled_deals[deal] != 1:
                add_violation(
                    violations, event, "emergency fill did not reconcile closed"
                )
            if (
                deal
                and emergency_attached[deal] == 1
                and (not ticket or terminal_tickets[ticket] != 1)
            ):
                add_violation(
                    violations,
                    event,
                    "attached emergency fill lacks one finalization",
                )
        elif event.label == "FILL_RECOVERY_CHECKPOINT_FAILED":
            deal = event.fields.get("deal", "")
            ticket = event.fields.get("ticket", "")
            if not ticket or recovery_quarantine_tickets[ticket] != 1:
                add_violation(
                    violations,
                    event,
                    "checkpoint failure lacks recovery quarantine",
                )
            if not ticket or terminal_tickets[ticket] != 1:
                add_violation(
                    violations,
                    event,
                    "checkpoint failure did not reconcile closed",
                )
            reconciled = (
                (ticket and emergency_reconciled_tickets[ticket] == 1)
                or (deal and emergency_reconciled_deals[deal] == 1)
            )
            if not reconciled:
                add_violation(
                    violations,
                    event,
                    "checkpoint failure left emergency quarantine active",
                )
        elif event.label == "RECOVERY_POSITION_QUARANTINED":
            ticket = event.fields.get("ticket", "")
            mode = event.fields.get("quarantine_mode", "")
            if not ticket or ticket == "0":
                add_violation(violations, event, "recovery quarantine lacks ticket")
                continue
            if mode not in {"SINGLE", "MULTIPLE"}:
                add_violation(violations, event, "invalid recovery quarantine mode")
            if terminal_tickets[ticket] != 1:
                add_violation(
                    violations,
                    event,
                    "recovery quarantine lacks one finalization",
                )
            if (
                mode == "SINGLE"
                and emergency_reconciled_tickets[ticket] != 1
            ):
                add_violation(
                    violations,
                    event,
                    "single recovery quarantine did not reconcile closed",
                )
        elif event.label == "RECOVERY_QUARANTINE_STATE_FAILED":
            if event.fields.get("quarantine_mode") != "SINGLE":
                add_violation(
                    violations,
                    event,
                    "multiple recovery quarantine state could not be audited",
                )
                continue
            deal = event.fields.get("deal", "")
            ticket = event.fields.get("ticket", "")
            reconciled = (
                (ticket and emergency_reconciled_tickets[ticket] == 1)
                or (deal and emergency_reconciled_deals[deal] == 1)
            )
            if not reconciled:
                add_violation(
                    violations,
                    event,
                    "failed recovery state did not reconcile closed",
                )


def validate_candidates(
    events: list[AuditEvent],
    schema: int,
    violations: list[Violation],
) -> None:
    if schema < AUTHORITATIVE_SCHEMA:
        return
    identity_type = tuple[str, str, str, str, str]
    latched: Counter[identity_type] = Counter()
    restored: Counter[identity_type] = Counter()
    terminal: Counter[identity_type] = Counter()
    promoted: Counter[identity_type] = Counter()
    replacement_events: Counter[identity_type] = Counter()
    replacement_latches: Counter[identity_type] = Counter()
    armed: Counter[tuple[str, str, str, str]] = Counter()
    persisted_candidate = False

    for event in events:
        if event.label == "CAMPAIGN_ARMED":
            arm = (
                event.fields.get("sequence", ""),
                event.fields.get("retry_number", ""),
                event.fields.get("execution_source", ""),
                event.fields.get("attempt", ""),
            )
            if all(arm):
                armed[arm] += 1
            continue
        if event.label in {
            "CANDIDATE_LATCHED",
            "CANDIDATE_REPLACED",
            "CANDIDATE_PROMOTED",
            "CANDIDATE_DISCARDED",
        } or (
            event.label == "RECOVERY_POSITION_RESTORED"
            and event.fields.get("candidate_restored") == "1"
        ):
            version = parse_int(
                event,
                "candidate_transition_version",
                violations,
                minimum=1,
            )
            if version is not None and version != 1:
                add_violation(
                    violations, event, "unsupported candidate transition version"
                )
        if event.label == "CANDIDATE_LATCHED":
            identity = candidate_identity(event, violations)
            if identity:
                latched[identity] += 1
                latch_kind = event.fields.get("latch_kind", "")
                if latch_kind == "REPLACEMENT":
                    replacement_latches[identity] += 1
                elif latch_kind != "INITIAL":
                    add_violation(violations, event, "invalid candidate latch kind")
        elif event.label in {"CANDIDATE_PROMOTED", "CANDIDATE_DISCARDED"}:
            identity = candidate_identity(event, violations)
            if identity:
                terminal[identity] += 1
                terminal_reason = event.fields.get("terminal_reason", "")
                if not terminal_reason:
                    add_violation(violations, event, "candidate terminal lacks reason")
                if event.label == "CANDIDATE_PROMOTED":
                    promoted[identity] += 1
                    promoted_sequence = event.fields.get("promoted_sequence", "")
                    if not promoted_sequence:
                        add_violation(
                            violations, event, "promoted candidate lacks sequence"
                        )
                    elif armed[(promoted_sequence, "0", "BROKER", "1")] != 1:
                        add_violation(
                            violations,
                            event,
                            "promoted candidate is not one broker initial",
                        )
                elif event.fields.get("promoted_sequence", ""):
                    add_violation(
                        violations, event, "discarded candidate has promotion"
                    )
        elif event.label == "CANDIDATE_REPLACED":
            previous_identity = candidate_identity(
                event, violations, previous=True
            )
            if previous_identity:
                terminal[previous_identity] += 1
            replacement_identity = candidate_identity(event, violations)
            if replacement_identity:
                replacement_events[replacement_identity] += 1
        elif (
            event.label == "RECOVERY_POSITION_RESTORED"
            and event.fields.get("candidate_restored") == "1"
        ):
            identity = candidate_identity(event, violations)
            if identity:
                restored[identity] += 1
        elif (
            event.label == "RECOVERY_CHECKPOINT"
        ):
            persisted_candidate = event.fields.get("candidate_valid") == "1"

    for identity in set(replacement_events) | set(replacement_latches):
        if (
            replacement_events[identity] != 1
            or replacement_latches[identity] != 1
        ):
            add_violation(
                violations,
                None,
                "replacement candidate lacks one replacement latch",
            )

    identities = set(latched) | set(restored) | set(terminal)
    unterminated: list[identity_type] = []
    for identity in identities:
        admissions = latched[identity] + restored[identity]
        if admissions != 1:
            add_violation(
                violations, None, "candidate lacks one authoritative admission"
            )
        if terminal[identity] == 0:
            unterminated.append(identity)
        elif terminal[identity] != 1:
            add_violation(
                violations, None, "candidate has duplicate terminal transitions"
            )
        if promoted[identity] > 1:
            add_violation(
                violations, None, "candidate has duplicate promotion transitions"
            )
    if unterminated and (len(unterminated) != 1 or not persisted_candidate):
        add_violation(
            violations, None, "candidate is neither terminal nor checkpointed"
        )


def validate_supersession(
    events: list[AuditEvent],
    schema: int,
    violations: list[Violation],
) -> None:
    if schema < AUTHORITATIVE_SCHEMA:
        return
    fill_pairs: Counter[tuple[str, str]] = Counter()
    armed: Counter[tuple[str, str, str, str]] = Counter()
    for event in events:
        if event.label in {
            "BROKER_FILL_ACCOUNTED",
            "VIRTUAL_FILL_REGISTERED",
        }:
            sequence = event.fields.get("sequence", "")
            retry = event.fields.get("retry_number", "")
            if sequence and retry:
                fill_pairs[(sequence, retry)] += 1
        elif event.label == "CAMPAIGN_ARMED":
            sequence = event.fields.get("sequence", "")
            retry = event.fields.get("retry_number", "")
            source = event.fields.get("execution_source", "")
            attempt = event.fields.get("attempt", "")
            if sequence and retry and source and attempt:
                armed[(sequence, retry, source, attempt)] += 1

    for event in events:
        if event.label == "RETRY_SUPERSEDED":
            old_sequence = event.fields.get("sequence", "")
            old_retry_key = "suppressed_retry_number"
            old_attempt_key = "suppressed_attempt"
            new_sequence = event.fields.get("promoted_sequence", "")
            new_retry_key = "promoted_retry_number"
            new_attempt_key = "promoted_attempt"
            new_source_key = "promoted_execution_source"
        elif event.label == "RETRY_CAMPAIGN_SUPERSEDED":
            old_sequence = event.fields.get("previous_sequence", "")
            old_retry_key = "previous_retry_number"
            old_attempt_key = "previous_attempt"
            new_sequence = event.fields.get("sequence", "")
            new_retry_key = "retry_number"
            new_attempt_key = "attempt"
            new_source_key = "execution_source"
        else:
            continue
        transition_version = parse_int(
            event, "transition_version", violations, minimum=1
        )
        if transition_version is not None and transition_version != 1:
            add_violation(
                violations, event, "unsupported supersession transition version"
            )
        old_retry_value = parse_int(
            event, old_retry_key, violations, minimum=1
        )
        parse_int(event, old_attempt_key, violations, minimum=1)
        new_retry_value = parse_int(
            event, new_retry_key, violations, minimum=0
        )
        new_attempt_value = parse_int(
            event, new_attempt_key, violations, minimum=1
        )
        new_source = event.fields.get(new_source_key, "")
        if not event.fields.get("transition_reason", ""):
            add_violation(violations, event, "supersession lacks reason")
        if not old_sequence or old_retry_value is None or not new_sequence:
            add_violation(violations, event, "incomplete supersession identity")
            continue
        old_retry = str(old_retry_value)
        if fill_pairs[(old_sequence, old_retry)] != 0:
            add_violation(
                violations, event, "suppressed retry has a fill"
            )
        if (
            new_retry_value != 0
            or new_attempt_value != 1
            or new_source != "BROKER"
        ):
            add_violation(
                violations, event, "promoted transition is not broker initial"
            )
        if armed[(new_sequence, "0", "BROKER", "1")] != 1:
            add_violation(
                violations,
                event,
                "promoted campaign is not one broker initial",
            )


def raw_summary_counts(events: list[AuditEvent]) -> Counter[str]:
    counts: Counter[str] = Counter()
    counts["events_counted"] = sum(
        event.label not in {"RUN_SUMMARY", "RUN_END"} for event in events
    )
    for event in events:
        retry_text = event.fields.get("retry_number", "")
        try:
            retry_number = int(retry_text)
        except ValueError:
            retry_number = -1
        if event.label == "BROKER_FILL_ACCOUNTED":
            counts["broker_fills_total"] += 1
            if retry_number == 0:
                counts["initial_broker_fills"] += 1
            elif retry_number > 0:
                counts["broker_retry_fills"] += 1
        elif event.label == "VIRTUAL_FILL_REGISTERED" and retry_number > 0:
            counts["virtual_retry_fills"] += 1
        elif event.label == "FILL_REGISTERED":
            counts["normal_managed_fills"] += 1
        elif event.label in {
            "FILL_REGISTRATION_FAILED",
            "FILL_RECOVERY_CHECKPOINT_FAILED",
        }:
            counts["emergency_managed_fills"] += 1
        elif event.label == "POSITION_FINALIZED":
            counts["position_finalizations"] += 1
        elif event.label == "CANDIDATE_LATCHED":
            counts["candidates_latched"] += 1
        elif event.label == "CANDIDATE_REPLACED":
            counts["candidates_replaced"] += 1
        elif event.label == "CANDIDATE_DISCARDED":
            counts["candidates_discarded"] += 1
        elif event.label == "CANDIDATE_PROMOTED":
            counts["candidates_promoted"] += 1
        elif event.label in {
            "RETRY_SUPERSEDED",
            "RETRY_CAMPAIGN_SUPERSEDED",
        }:
            counts["retries_suppressed"] += 1
        elif event.label == "RECOVERY_POSITION_RESTORED":
            counts["recovery_restores"] += 1
        elif event.label == "RECOVERY_POSITION_QUARANTINED":
            counts["recovery_quarantines"] += 1
        elif event.label == "EMERGENCY_CLOSE_SENT":
            counts["emergency_closes"] += 1
        elif event.label == "EMERGENCY_EXPOSURE_RECONCILED":
            counts["emergency_reconciled"] += 1
        if event.label in RECONCILIATION_FAILURE_LABELS:
            counts["reconciliation_failures"] += 1
    return counts


def validate_summary(
    events: list[AuditEvent],
    schema: int,
    violations: list[Violation],
) -> None:
    summaries = [event for event in events if event.label == "RUN_SUMMARY"]
    endings = [event for event in events if event.label == "RUN_END"]
    if schema < AUTHORITATIVE_SCHEMA:
        return
    if len(summaries) != 1:
        add_violation(violations, None, "schema 3 requires one run summary")
        return
    summary = summaries[0]
    if len(endings) != 1:
        add_violation(violations, None, "schema 3 requires one run end")
    elif summary.line_no >= endings[0].line_no:
        add_violation(violations, summary, "run summary is not before run end")
    version = parse_int(summary, "summary_version", violations, minimum=1)
    if version != SUMMARY_VERSION:
        add_violation(violations, summary, "unsupported summary version")
    expected = raw_summary_counts(events)
    for key in SUMMARY_COUNTERS:
        actual = parse_int(summary, key, violations, minimum=0)
        if actual is not None and actual != expected[key]:
            add_violation(violations, summary, f"summary counter mismatch: {key}")
    write_failures = parse_int(
        summary, "audit_write_failures", violations, minimum=0
    )
    if write_failures not in {None, 0}:
        add_violation(violations, summary, "audit writer reported failures")


def validate_run(events: list[AuditEvent]) -> RunReport:
    report = RunReport(event_count=len(events))
    report.counts.update(event.label for event in events)
    starts = [event for event in events if event.label == "RUN_START"]
    if len(starts) != 1:
        add_violation(report.violations, None, "run lacks one RUN_START")
        return report
    schema = parse_int(
        starts[0], "schema_version", report.violations, minimum=1
    )
    if schema is None:
        return report
    report.schema = schema
    if schema not in SUPPORTED_SCHEMAS:
        add_violation(report.violations, starts[0], "unsupported audit schema")
        return report

    configs = [event for event in events if event.label == "CONFIG"]
    if len(configs) != 1:
        add_violation(report.violations, None, "run lacks one CONFIG event")
        return report
    threshold = parse_int(
        configs[0], "start_real_retry", report.violations, minimum=0
    )
    if threshold is None:
        return report

    validate_routing(events, threshold, report.violations)
    validate_fill_lifecycles(events, schema, report.violations)
    validate_candidates(events, schema, report.violations)
    validate_supersession(events, schema, report.violations)
    validate_summary(events, schema, report.violations)
    return report


def analyze_lines(
    lines: Iterable[str],
    requested_run: str | None = None,
) -> AuditReport:
    runs, parse_violations = parse_lines(lines)
    if requested_run is not None:
        if requested_run not in runs:
            parse_violations.append(
                Violation(0, "AUDIT", "requested run id was not found")
            )
            selected: list[list[AuditEvent]] = []
        else:
            selected = [runs[requested_run]]
    else:
        selected = list(runs.values())
    if not selected:
        parse_violations.append(Violation(0, "AUDIT", "no audit runs found"))
    return AuditReport(
        run_reports=[validate_run(events) for events in selected],
        parse_violations=parse_violations,
    )


def report_counts(report: AuditReport) -> Counter[str]:
    counts: Counter[str] = Counter()
    for run_report in report.run_reports:
        counts["runs"] += 1
        counts[f"schema_{run_report.schema}"] += 1
        counts["events"] += run_report.event_count
        for key in (
            "BROKER_FILL_ACCOUNTED",
            "FILL_REGISTERED",
            "VIRTUAL_FILL_REGISTERED",
            "POSITION_FINALIZED",
            "CANDIDATE_LATCHED",
            "CANDIDATE_PROMOTED",
            "CANDIDATE_DISCARDED",
            "RETRY_SUPERSEDED",
            "RETRY_CAMPAIGN_SUPERSEDED",
            "RECOVERY_POSITION_RESTORED",
            "RECOVERY_POSITION_QUARANTINED",
        ):
            counts[key] += run_report.counts[key]
        if run_report.counts["BROKER_FILL_ACCOUNTED"]:
            counts["broker_fills_display"] += run_report.counts[
                "BROKER_FILL_ACCOUNTED"
            ]
        else:
            counts["broker_fills_display"] += run_report.counts[
                "FILL_REGISTERED"
            ]
    return counts


def print_report(report: AuditReport, max_violations: int) -> int:
    counts = report_counts(report)
    violations = report.violations
    status = "PASS" if not violations else "FAIL"
    print(
        f"{status} audit runs={counts['runs']} events={counts['events']} "
        f"schema2={counts['schema_2']} schema3={counts['schema_3']}"
    )
    print(
        "counts "
        f"broker_fills={counts['broker_fills_display']} "
        f"virtual_fills={counts['VIRTUAL_FILL_REGISTERED']} "
        f"finalizations={counts['POSITION_FINALIZED']} "
        f"candidate_latched={counts['CANDIDATE_LATCHED']} "
        f"candidate_terminal="
        f"{counts['CANDIDATE_PROMOTED'] + counts['CANDIDATE_DISCARDED']} "
        f"retries_suppressed="
        f"{counts['RETRY_SUPERSEDED'] + counts['RETRY_CAMPAIGN_SUPERSEDED']} "
        f"recovery_restores={counts['RECOVERY_POSITION_RESTORED']} "
        f"recovery_quarantines={counts['RECOVERY_POSITION_QUARANTINED']}"
    )
    if violations:
        print(f"violations={len(violations)} showing={min(len(violations), max_violations)}")
        for violation in violations[:max_violations]:
            location = f"line {violation.line_no}" if violation.line_no else "aggregate"
            print(f"- {location} {violation.label}: {violation.message}")
        return 1
    print("violations=0")
    return 0


def synthetic_line(label: str, payload: str, run: str = "self") -> str:
    return (
        f"2026.01.01 00:00:00 | {label} | "
        f"run={run}|symbol=SYNTH|magic=1|{payload}\n"
    )


def self_test_lines(schema: int = 3) -> list[str]:
    lines = [
        synthetic_line(
            "RUN_START",
            f"schema_version={schema}|tester=1|tester_visual_mode=0|"
            "chart_tf=PERIOD_M1|writer=shared_append|retry_identity=logical|"
            "broker_comment_schema=PH2|recovery_scope_metadata=status_only",
        ),
        synthetic_line("CONFIG", "start_real_retry=2"),
        synthetic_line(
            "CAMPAIGN_ARMED",
            "sequence=base|retry_number=0|attempt=1|execution_source=BROKER",
        ),
        synthetic_line(
            "ORDER_SEND_RESULT",
            "sequence=base|dir=BULLISH|level=S2|retry_number=0|"
            "execution_source=BROKER|comment=PH2_B_S2_R0_T1",
        ),
        synthetic_line(
            "BROKER_FILL_ACCOUNTED",
            "sequence=base|deal=100|retry_number=0|retry_ordinal=1",
        ),
        synthetic_line(
            "FILL_REGISTERED",
            "sequence=base|execution_source=BROKER|execution_id=200|"
            "ticket=200|position_id=300|deal=100|retry_number=0",
        ),
        synthetic_line(
            "POSITION_FINALIZED",
            "sequence=base|execution_source=BROKER|execution_id=200|"
            "ticket=200|position_id=300|retry_number=0|close_trigger=INITIAL_SL",
        ),
        synthetic_line(
            "VIRTUAL_FILL_REGISTERED",
            "sequence=base|execution_source=VIRTUAL|execution_id=V1|ticket=0|"
            "retry_number=1",
        ),
        synthetic_line(
            "POSITION_FINALIZED",
            "sequence=base|execution_source=VIRTUAL|execution_id=V1|ticket=0|"
            "retry_number=1|close_trigger=INITIAL_SL",
        ),
        synthetic_line(
            "CANDIDATE_LATCHED",
            "latch_kind=INITIAL|candidate_transition_version=1|candidate_level=S2|"
            "candidate_activation_bar=10|candidate_admission_bar=11|"
            "owner_sequence=base|owner_execution_id=V1|terminal_reason=|"
            "promoted_sequence=",
        ),
        synthetic_line(
            "CANDIDATE_REPLACED",
            "transition_reason=strictly_deeper_candidate|"
            "previous_owner_sequence=base|previous_owner_execution_id=V1|"
            "previous_level=S2|previous_activation_bar=10|"
            "previous_admission_bar=11|candidate_transition_version=1|"
            "candidate_level=S3|candidate_activation_bar=12|"
            "candidate_admission_bar=13|owner_sequence=base|"
            "owner_execution_id=V1|terminal_reason=|promoted_sequence=",
        ),
        synthetic_line(
            "CANDIDATE_LATCHED",
            "latch_kind=REPLACEMENT|candidate_transition_version=1|"
            "candidate_level=S3|candidate_activation_bar=12|"
            "candidate_admission_bar=13|owner_sequence=base|"
            "owner_execution_id=V1|terminal_reason=|promoted_sequence=",
        ),
        synthetic_line(
            "CAMPAIGN_ARMED",
            "sequence=deep|retry_number=0|attempt=1|execution_source=BROKER",
        ),
        synthetic_line(
            "RETRY_SUPERSEDED",
            "transition_version=1|transition_reason=deeper_pivot_promoted|"
            "sequence=base|suppressed_retry_number=2|suppressed_attempt=3|"
            "promoted_sequence=deep|promoted_retry_number=0|promoted_attempt=1|"
            "promoted_execution_source=BROKER",
        ),
        synthetic_line(
            "CANDIDATE_PROMOTED",
            "candidate_transition_version=1|candidate_level=S3|"
            "candidate_activation_bar=12|candidate_admission_bar=13|"
            "owner_sequence=base|owner_execution_id=V1|"
            "terminal_reason=promoted_after_non_positive_close|"
            "promoted_sequence=deep",
        ),
        synthetic_line(
            "BROKER_FILL_ACCOUNTED",
            "sequence=deep|deal=101|retry_number=0|retry_ordinal=1",
        ),
        synthetic_line(
            "FILL_REGISTERED",
            "sequence=deep|execution_source=BROKER|execution_id=201|"
            "ticket=201|position_id=301|deal=101|retry_number=0",
        ),
        synthetic_line(
            "POSITION_FINALIZED",
            "sequence=deep|execution_source=BROKER|execution_id=201|"
            "ticket=201|position_id=301|retry_number=0|close_trigger=FIXED_TP",
        ),
    ]
    if schema == 3:
        lines.extend(
            [
                synthetic_line(
                    "RUN_SUMMARY",
                    "summary_version=1|events_counted=18|initial_broker_fills=2|"
                    "virtual_retry_fills=1|broker_retry_fills=0|"
                    "broker_fills_total=2|normal_managed_fills=2|"
                    "emergency_managed_fills=0|position_finalizations=3|"
                    "candidates_latched=2|candidates_replaced=1|"
                    "candidates_discarded=0|candidates_promoted=1|"
                    "retries_suppressed=1|recovery_restores=0|"
                    "recovery_quarantines=0|emergency_closes=0|"
                    "emergency_reconciled=0|reconciliation_failures=0|"
                    "audit_write_failures=0",
                ),
                synthetic_line("RUN_END", "deinit_reason=0"),
            ]
        )
    return lines


def emergency_self_test_lines() -> list[str]:
    lines = self_test_lines()
    lines[5] = synthetic_line(
        "FILL_REGISTRATION_FAILED",
        "sequence=base|retry_number=0|retry_ordinal=1|deal=100|"
        "ticket=200|position_id=300",
    )
    lines[6] = lines[6].replace(
        "close_trigger=INITIAL_SL", "close_trigger=REGISTRATION_FAILURE"
    )
    lines[6:6] = [
        synthetic_line(
            "EMERGENCY_LIFECYCLE_REGISTERED",
            "sequence=base|execution_source=BROKER|execution_id=200|"
            "ticket=200|position_id=300|deal=100",
        ),
        synthetic_line(
            "EMERGENCY_CLOSE_SENT",
            "execution_source=BROKER|execution_id=200|ticket=200|"
            "position_id=300",
        ),
        synthetic_line(
            "EMERGENCY_EXPOSURE_RECONCILED",
            "sequence=base|execution_source=BROKER|execution_id=200|"
            "ticket=200|position_id=300|deal=100",
        ),
    ]
    lines[-2] = synthetic_line(
        "RUN_SUMMARY",
        "summary_version=1|events_counted=21|initial_broker_fills=2|"
        "virtual_retry_fills=1|broker_retry_fills=0|broker_fills_total=2|"
        "normal_managed_fills=1|emergency_managed_fills=1|"
        "position_finalizations=3|candidates_latched=2|"
        "candidates_replaced=1|candidates_discarded=0|"
        "candidates_promoted=1|retries_suppressed=1|recovery_restores=0|"
        "recovery_quarantines=0|emergency_closes=1|emergency_reconciled=1|"
        "reconciliation_failures=0|audit_write_failures=0",
    )
    return lines


def recovery_quarantine_self_test_lines() -> list[str]:
    lines = self_test_lines()
    lines[-2:-2] = [
        synthetic_line(
            "RECOVERY_POSITION_QUARANTINED",
            "sequence=recovery|execution_source=BROKER|execution_id=300|"
            "ticket=300|position_id=400|deal=200|status=SAFETY_ONLY|"
            "quarantine_mode=SINGLE|reason=checkpoint_missing",
        ),
        synthetic_line(
            "POSITION_FINALIZED",
            "sequence=recovery|execution_source=BROKER|execution_id=300|"
            "ticket=300|position_id=400|retry_number=0|"
            "close_trigger=RECOVERY_FAILURE",
        ),
        synthetic_line(
            "EMERGENCY_EXPOSURE_RECONCILED",
            "sequence=recovery|execution_source=BROKER|execution_id=300|"
            "ticket=300|position_id=400|deal=200",
        ),
    ]
    lines[-2] = synthetic_line(
        "RUN_SUMMARY",
        "summary_version=1|events_counted=21|initial_broker_fills=2|"
        "virtual_retry_fills=1|broker_retry_fills=0|broker_fills_total=2|"
        "normal_managed_fills=2|emergency_managed_fills=0|"
        "position_finalizations=4|candidates_latched=2|"
        "candidates_replaced=1|candidates_discarded=0|"
        "candidates_promoted=1|retries_suppressed=1|recovery_restores=0|"
        "recovery_quarantines=1|emergency_closes=0|emergency_reconciled=1|"
        "reconciliation_failures=0|audit_write_failures=0",
    )
    return lines


def run_self_test() -> int:
    cases: list[tuple[str, list[str], bool, str | None]] = []
    passing = self_test_lines()
    cases.append(("schema3_pass", passing, True, None))
    cases.append(
        ("emergency_lifecycle_pass", emergency_self_test_lines(), True, None)
    )
    cases.append(
        (
            "recovery_quarantine_pass",
            recovery_quarantine_self_test_lines(),
            True,
            None,
        )
    )

    wrong_route = self_test_lines()
    wrong_route[7] = wrong_route[7].replace("retry_number=1", "retry_number=2")
    cases.append(
        ("routing_failure", wrong_route, False, "retry routed to the wrong source")
    )

    suppressed_fill = self_test_lines()
    suppressed_fill.insert(
        -2,
        synthetic_line(
            "BROKER_FILL_ACCOUNTED",
            "sequence=base|deal=102|retry_number=2|retry_ordinal=3",
        ),
    )
    cases.append(
        (
            "suppressed_fill_failure",
            suppressed_fill,
            False,
            "suppressed retry has a fill",
        )
    )

    duplicate_key = self_test_lines()
    duplicate_key[1] = duplicate_key[1].rstrip("\n") + "|start_real_retry=2\n"
    cases.append(
        ("duplicate_key_failure", duplicate_key, False, "duplicate payload key")
    )

    missing_finalization = self_test_lines()
    del missing_finalization[6]
    cases.append(
        (
            "orphan_lifecycle_failure",
            missing_finalization,
            False,
            "fill has no unique finalization",
        )
    )

    summary_mismatch = self_test_lines()
    summary_mismatch[-2] = summary_mismatch[-2].replace(
        "initial_broker_fills=2", "initial_broker_fills=3"
    )
    cases.append(
        (
            "summary_mismatch_failure",
            summary_mismatch,
            False,
            "summary counter mismatch",
        )
    )

    missing_promoted_arm = [
        line
        for line in self_test_lines()
        if not ("CAMPAIGN_ARMED" in line and "sequence=deep" in line)
    ]
    cases.append(
        (
            "promoted_arm_failure",
            missing_promoted_arm,
            False,
            "promoted candidate is not one broker initial",
        )
    )

    emergency_unreconciled = [
        line
        for line in emergency_self_test_lines()
        if "EMERGENCY_EXPOSURE_RECONCILED" not in line
    ]
    cases.append(
        (
            "emergency_reconcile_failure",
            emergency_unreconciled,
            False,
            "emergency fill did not reconcile closed",
        )
    )

    recovery_unreconciled = [
        line
        for line in recovery_quarantine_self_test_lines()
        if "EMERGENCY_EXPOSURE_RECONCILED" not in line
    ]
    cases.append(
        (
            "recovery_reconcile_failure",
            recovery_unreconciled,
            False,
            "single recovery quarantine did not reconcile closed",
        )
    )

    legacy = self_test_lines(schema=2)
    cases.append(("schema2_legacy_pass", legacy, True, None))

    failures = []
    for name, lines, should_pass, expected_violation in cases:
        violations = analyze_lines(lines).violations
        passed = not violations
        if passed != should_pass:
            failures.append(name)
            continue
        if expected_violation and not any(
            expected_violation in violation.message for violation in violations
        ):
            failures.append(name + "_wrong_violation")
    if failures:
        print("SELF_TEST FAIL cases=" + ",".join(failures))
        return 1
    print(f"SELF_TEST PASS cases={len(cases)}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Validate Pivot HFT audit routing, lifecycle, recovery, and "
            "supersession invariants without printing raw rows."
        )
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--file", type=Path, help="explicit query_debug.txt path")
    group.add_argument("--self-test", action="store_true")
    parser.add_argument("--run-id", help="validate only this exact run id")
    parser.add_argument(
        "--max-violations",
        type=int,
        default=DEFAULT_MAX_VIOLATIONS,
        help="maximum summarized violations to print (default: 20)",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.self_test:
        return run_self_test()
    if args.max_violations < 1 or args.max_violations > 100:
        print("error: --max-violations must be between 1 and 100", file=sys.stderr)
        return 2
    try:
        with args.file.open("r", encoding="utf-8", errors="replace") as handle:
            report = analyze_lines(handle, args.run_id)
    except OSError as exc:
        print(f"error: cannot read audit file ({exc.strerror or 'I/O error'})", file=sys.stderr)
        return 2
    return print_report(report, args.max_violations)


if __name__ == "__main__":
    raise SystemExit(main())
