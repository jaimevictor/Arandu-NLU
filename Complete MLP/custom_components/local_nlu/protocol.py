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
