"""Strict passive add-on response contract."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Literal


class ProtocolError(Exception):
    """The add-on returned data outside the closed MLP contract."""


Action = Literal[
    "get_state",
    "set_fan_percentage",
    "turn_off",
    "turn_on",
]


@dataclass(frozen=True)
class PlanOperation:
    action: Action
    targets: tuple[str, ...]
    percentage: int | None = None


@dataclass(frozen=True)
class Outcome:
    status: Literal["ambiguous", "invalid_request", "no_match", "plan"]
    operations: tuple[PlanOperation, ...] = ()


@dataclass(frozen=True)
class ResolveOutcome:
    status: Literal["resolved", "ambiguous", "no_match"]
    registry_id: str | None = None
    evidence: str | None = None
    candidates: tuple[str, ...] = ()


EVIDENCE = frozenset(
    (
        "external_entity_id",
        "explicit_registry_alias",
        "display_name_with_constraint",
    )
)


def parse_v2_response(value: Any) -> ResolveOutcome:
    """Parse one exact version-two resolution response (candidates only)."""

    if type(value) is not dict or value.get("outcome") not in (
        "resolved",
        "ambiguous",
        "no_match",
    ):
        raise ProtocolError("response")
    outcome = value["outcome"]
    if outcome == "no_match":
        if set(value) != {"outcome"}:
            raise ProtocolError("response")
        return ResolveOutcome(status="no_match")
    if outcome == "resolved":
        if set(value) != {"outcome", "registry_id", "evidence"}:
            raise ProtocolError("response")
        registry_id = value["registry_id"]
        evidence = value["evidence"]
        if not _valid_identifier(registry_id) or evidence not in EVIDENCE:
            raise ProtocolError("resolved")
        return ResolveOutcome(
            status="resolved",
            registry_id=registry_id,
            evidence=evidence,
        )
    if set(value) != {"outcome", "candidates"}:
        raise ProtocolError("response")
    candidates = value["candidates"]
    if (
        type(candidates) is not list
        or not 2 <= len(candidates) <= 1_024
        or any(not _valid_identifier(candidate) for candidate in candidates)
        or tuple(candidates) != tuple(sorted(set(candidates)))
    ):
        raise ProtocolError("candidates")
    return ResolveOutcome(
        status="ambiguous",
        candidates=tuple(candidates),
    )


def parse_response(value: Any) -> Outcome:
    """Parse one exact version-one response."""

    if type(value) is not dict or type(value.get("status")) is not str:
        raise ProtocolError("response")
    status = value["status"]
    if status in ("ambiguous", "invalid_request", "no_match"):
        if set(value) != {"status", "version"} or value.get("version") != 1:
            raise ProtocolError("response")
        return Outcome(status=status)
    if status != "plan" or set(value) != {
        "operations",
        "status",
        "version",
    }:
        raise ProtocolError("response")
    if value.get("version") != 1 or type(value.get("operations")) is not list:
        raise ProtocolError("response")
    raw_operations = value["operations"]
    if not 1 <= len(raw_operations) <= 4:
        raise ProtocolError("operations")

    operations = tuple(_parse_operation(operation) for operation in raw_operations)
    if any(operation.action == "get_state" for operation in operations):
        if len(operations) != 1:
            raise ProtocolError("query_chain")
    affected: set[str] = set()
    for operation in operations:
        if operation.action == "get_state":
            continue
        for target in operation.targets:
            if target in affected:
                raise ProtocolError("contradiction")
            affected.add(target)
    return Outcome(status="plan", operations=operations)


def _parse_operation(value: Any) -> PlanOperation:
    if type(value) is not dict or type(value.get("action")) is not str:
        raise ProtocolError("operation")
    action = value["action"]
    if action not in (
        "get_state",
        "set_fan_percentage",
        "turn_off",
        "turn_on",
    ):
        raise ProtocolError("action")
    expected_keys = {"action", "targets"}
    percentage = None
    if action == "set_fan_percentage":
        expected_keys.add("percentage")
        percentage = value.get("percentage")
        if type(percentage) is not int or not 0 <= percentage <= 100:
            raise ProtocolError("percentage")
    if set(value) != expected_keys:
        raise ProtocolError("operation")
    raw_targets = value.get("targets")
    if type(raw_targets) is not list or not 1 <= len(raw_targets) <= 32:
        raise ProtocolError("targets")
    targets = tuple(raw_targets)
    if (
        any(not _valid_identifier(target) for target in targets)
        or targets != tuple(sorted(set(targets)))
    ):
        raise ProtocolError("targets")
    return PlanOperation(
        action=action,
        percentage=percentage,
        targets=targets,
    )


def _valid_identifier(value: Any) -> bool:
    return (
        type(value) is str
        and 1 <= len(value) <= 128
        and all(
            character.isascii()
            and (character.isalnum() or character in "_-")
            for character in value
        )
    )


@dataclass(frozen=True)
class PlanV2Operation:
    action: Action
    targets: tuple[str, ...]
    percentage: int | None = None


@dataclass(frozen=True)
class PlanV2:
    status: Literal["ambiguous", "no_match", "plan"]
    operations: tuple[PlanV2Operation, ...] = ()


def parse_v2_plan(value: Any) -> PlanV2:
    """Parse one exact version-two interpretation response."""

    if type(value) is not dict or value.get("version") != 2:
        raise ProtocolError("response")
    status = value.get("status")
    if status in ("ambiguous", "no_match"):
        if set(value) != {"status", "version"}:
            raise ProtocolError("response")
        return PlanV2(status=status)
    if status != "plan" or set(value) != {
        "operations",
        "status",
        "version",
    }:
        raise ProtocolError("response")
    raw_operations = value["operations"]
    if not 1 <= len(raw_operations) <= 4:
        raise ProtocolError("operations")
    operations = tuple(_parse_v2_operation(operation) for operation in raw_operations)
    affected: set[str] = set()
    for operation in operations:
        for target in operation.targets:
            if target in affected:
                raise ProtocolError("contradiction")
            affected.add(target)
    return PlanV2(status="plan", operations=operations)


def _parse_v2_operation(value: Any) -> PlanV2Operation:
    if type(value) is not dict or type(value.get("action")) is not str:
        raise ProtocolError("operation")
    action = value["action"]
    if action not in (
        "get_state",
        "set_fan_percentage",
        "turn_off",
        "turn_on",
    ):
        raise ProtocolError("action")
    expected_keys = {"action", "targets"}
    percentage = None
    if action == "set_fan_percentage":
        expected_keys.add("percentage")
        percentage = value.get("percentage")
        if type(percentage) is not int or not 0 <= percentage <= 100:
            raise ProtocolError("percentage")
    if set(value) != expected_keys:
        raise ProtocolError("operation")
    raw_targets = value.get("targets")
    if type(raw_targets) is not list or not 1 <= len(raw_targets) <= 32:
        raise ProtocolError("targets")
    targets = tuple(raw_targets)
    if (
        any(not _valid_identifier(target) for target in targets)
        or targets != tuple(sorted(set(targets)))
    ):
        raise ProtocolError("targets")
    return PlanV2Operation(
        action=action,
        percentage=percentage,
        targets=targets,
    )
