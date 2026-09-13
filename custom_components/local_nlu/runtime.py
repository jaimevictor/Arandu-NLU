"""Authorize and execute passive plans inside Home Assistant."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Literal

from homeassistant.auth.permissions.const import POLICY_CONTROL, POLICY_READ
from homeassistant.const import STATE_UNAVAILABLE, STATE_UNKNOWN
from homeassistant.helpers import device_registry, entity_registry

from .catalog import CatalogError, CatalogSnapshot, build_catalog
from .client import ClientError, LocalNluClient
from .const import (
    FAN_FEATURE_SET_SPEED,
    FAN_FEATURE_TURN_OFF,
    FAN_FEATURE_TURN_ON,
    MAX_QUERY_RESPONSE_BYTES,
    MAX_STATE_BYTES,
    MAX_UNIT_BYTES,
    SUPPORTED_DOMAINS,
)
from .protocol import Outcome, PlanOperation, ProtocolError, parse_response


ResultCode = Literal[
    "ambiguous",
    "denied",
    "execution_failed",
    "invalid_request",
    "no_match",
    "query_success",
    "stale",
    "success",
    "unavailable",
]


@dataclass(frozen=True)
class StateResult:
    label: str
    state: str
    unit: str | None


@dataclass(frozen=True)
class RuntimeResult:
    code: ResultCode
    operation_count: int = 0
    states: tuple[StateResult, ...] = ()


@dataclass(frozen=True)
class _PreparedTarget:
    area_id: str | None
    domain: str
    entity_id: str
    label: str
    registry_id: str


@dataclass(frozen=True)
class _PreparedOperation:
    action: str
    percentage: int | None
    targets: tuple[_PreparedTarget, ...]


class _PreflightError(Exception):
    def __init__(self, code: ResultCode) -> None:
        super().__init__(code)
        self.code = code


class LocalNluRuntime:
    """Create a request snapshot, validate the returned plan, and execute it."""

    def __init__(self, hass: Any, client: LocalNluClient) -> None:
        self._hass = hass
        self._client = client

    async def async_process(self, user_input: Any) -> RuntimeResult:
        try:
            initial = build_catalog(self._hass)
            raw = await self._client.async_interpret(
                {
                    "catalog": initial.payload,
                    "text": user_input.text,
                    "version": 1,
                }
            )
            outcome = parse_response(raw)
        except (CatalogError, ClientError, ProtocolError):
            return RuntimeResult(code="unavailable")
        except Exception:
            return RuntimeResult(code="unavailable")
        if outcome.status != "plan":
            return RuntimeResult(code=outcome.status)

        user_id = getattr(user_input.context, "user_id", None)
        if type(user_id) is not str:
            return RuntimeResult(code="denied")
        try:
            user = await self._hass.auth.async_get_user(user_id)
        except Exception:
            return RuntimeResult(code="denied")
        if user is None or user.is_active is not True:
            return RuntimeResult(code="denied")

        try:
            current = build_catalog(self._hass)
            if current.payload != initial.payload:
                return RuntimeResult(code="stale")
            prepared = self._preflight(outcome, user, current)
        except CatalogError:
            return RuntimeResult(code="stale")
        except _PreflightError as error:
            return RuntimeResult(code=error.code)
        except Exception:
            return RuntimeResult(code="unavailable")

        if prepared[0].action == "get_state":
            try:
                states = self._query(prepared[0], user)
            except _PreflightError as error:
                return RuntimeResult(code=error.code)
            except Exception:
                return RuntimeResult(code="unavailable")
            return RuntimeResult(
                code="query_success",
                operation_count=1,
                states=states,
            )

        completed = 0
        try:
            for operation in prepared:
                await self._async_execute(
                    operation,
                    user_id,
                    user_input.context,
                )
                completed += 1
        except _PreflightError as error:
            return RuntimeResult(code=error.code, operation_count=completed)
        except Exception:
            return RuntimeResult(code="execution_failed", operation_count=completed)
        return RuntimeResult(code="success", operation_count=completed)

    def _preflight(
        self,
        outcome: Outcome,
        user: Any,
        snapshot: CatalogSnapshot,
    ) -> tuple[_PreparedOperation, ...]:
        registry = entity_registry.async_get(self._hass)
        by_id = {entry.id: entry for entry in registry.entities.values()}
        devices = device_registry.async_get(self._hass)
        allowed = {
            row["registry_id"]: row
            for row in snapshot.payload["entities"]
        }
        prepared: list[_PreparedOperation] = []
        affected: set[str] = set()
        for operation in outcome.operations:
            targets = tuple(
                self._prepare_target(
                    operation,
                    registry_id,
                    by_id,
                    allowed,
                    devices,
                    user,
                )
                for registry_id in operation.targets
            )
            if operation.action != "get_state":
                for target in targets:
                    if target.registry_id in affected:
                        raise _PreflightError("invalid_request")
                    affected.add(target.registry_id)
            prepared.append(
                _PreparedOperation(
                    action=operation.action,
                    percentage=operation.percentage,
                    targets=targets,
                )
            )
        return tuple(prepared)

    def _prepare_target(
        self,
        operation: PlanOperation,
        registry_id: str,
        by_id: dict[str, Any],
        allowed: dict[str, dict[str, Any]],
        devices: Any,
        user: Any,
    ) -> _PreparedTarget:
        entry = by_id.get(registry_id)
        admitted = allowed.get(registry_id)
        if (
            entry is None
            or admitted is None
            or admitted["entity_id"] != entry.entity_id
            or operation.action not in admitted["actions"]
        ):
            raise _PreflightError("stale")
        state = self._live_state(entry, operation.action, user)
        area_id = _effective_area_id(entry, devices)
        label = admitted["names"][0]
        return _PreparedTarget(
            area_id=area_id,
            domain=entry.entity_id.split(".", 1)[0],
            entity_id=entry.entity_id,
            label=label,
            registry_id=registry_id,
        )

    def _live_state(self, entry: Any, action: str, user: Any) -> Any:
        from homeassistant.components.homeassistant import exposed_entities

        if entry.disabled_by is not None:
            raise _PreflightError("stale")
        domain = entry.entity_id.split(".", 1)[0]
        if domain not in SUPPORTED_DOMAINS or not _action_supports_domain(
            action, domain
        ):
            raise _PreflightError("stale")
        if (
            exposed_entities.async_should_expose(
                self._hass, "conversation", entry.entity_id
            )
            is not True
        ):
            raise _PreflightError("stale")
        state = self._hass.states.get(entry.entity_id)
        if state is None or state.state in (STATE_UNAVAILABLE, STATE_UNKNOWN):
            raise _PreflightError("stale")
        policy = POLICY_READ if action == "get_state" else POLICY_CONTROL
        if user.is_admin is not True and (
            user.permissions.check_entity(entry.entity_id, policy) is not True
        ):
            raise _PreflightError("denied")
        if action in ("turn_off", "turn_on"):
            required_feature = (
                FAN_FEATURE_TURN_OFF
                if action == "turn_off"
                else FAN_FEATURE_TURN_ON
            )
            supported = state.attributes.get("supported_features", 0)
            if (
                self._hass.services.has_service(domain, action) is not True
                or (
                    domain == "fan"
                    and (
                        type(supported) is not int
                        or not supported & required_feature
                    )
                )
            ):
                raise _PreflightError("stale")
        elif action == "set_fan_percentage":
            supported = state.attributes.get("supported_features", 0)
            if (
                domain != "fan"
                or self._hass.services.has_service("fan", "set_percentage")
                is not True
                or type(supported) is not int
                or not supported & FAN_FEATURE_SET_SPEED
            ):
                raise _PreflightError("stale")
        return state

    def _revalidate(self, operation: _PreparedOperation, user: Any) -> None:
        registry = entity_registry.async_get(self._hass)
        devices = device_registry.async_get(self._hass)
        by_id = {entry.id: entry for entry in registry.entities.values()}
        for target in operation.targets:
            entry = by_id.get(target.registry_id)
            if (
                entry is None
                or entry.entity_id != target.entity_id
                or _effective_area_id(entry, devices) != target.area_id
            ):
                raise _PreflightError("stale")
            self._live_state(entry, operation.action, user)

    async def _async_execute(
        self,
        operation: _PreparedOperation,
        user_id: str,
        context: Any,
    ) -> None:
        by_domain: dict[str, list[str]] = {}
        for target in operation.targets:
            by_domain.setdefault(target.domain, []).append(target.entity_id)
        service = (
            "set_percentage"
            if operation.action == "set_fan_percentage"
            else operation.action
        )
        data = (
            {"percentage": operation.percentage}
            if operation.action == "set_fan_percentage"
            else {}
        )
        for domain in sorted(by_domain):
            try:
                user = await self._hass.auth.async_get_user(user_id)
            except Exception as error:
                raise _PreflightError("denied") from error
            if user is None or user.is_active is not True:
                raise _PreflightError("denied")
            batch = _PreparedOperation(
                action=operation.action,
                percentage=operation.percentage,
                targets=tuple(
                    target
                    for target in operation.targets
                    if target.domain == domain
                ),
            )
            self._revalidate(batch, user)
            await self._hass.services.async_call(
                domain,
                service,
                data,
                blocking=True,
                context=context,
                target={"entity_id": sorted(by_domain[domain])},
            )

    def _query(
        self,
        operation: _PreparedOperation,
        user: Any,
    ) -> tuple[StateResult, ...]:
        self._revalidate(operation, user)
        results: list[StateResult] = []
        response_bytes = 0
        for target in sorted(operation.targets, key=lambda item: item.entity_id):
            state = self._hass.states.get(target.entity_id)
            if (
                state is None
                or type(state.state) is not str
                or len(state.state.encode("utf-8")) > MAX_STATE_BYTES
            ):
                raise _PreflightError("stale")
            unit = state.attributes.get("unit_of_measurement")
            if (
                type(unit) is not str
                or not unit
                or len(unit.encode("utf-8")) > MAX_UNIT_BYTES
            ):
                unit = None
            result = StateResult(
                label=target.label,
                state=state.state,
                unit=unit,
            )
            response_bytes += (
                len(result.label.encode("utf-8"))
                + len(result.state.encode("utf-8"))
                + (
                    len(result.unit.encode("utf-8"))
                    if result.unit is not None
                    else 0
                )
                + 64
            )
            if response_bytes > MAX_QUERY_RESPONSE_BYTES:
                raise _PreflightError("stale")
            results.append(result)
        return tuple(results)


def _effective_area_id(entry: Any, devices: Any) -> str | None:
    if type(entry.area_id) is str:
        return entry.area_id
    if type(entry.device_id) is not str:
        return None
    device = devices.async_get(entry.device_id)
    return device.area_id if device is not None and type(device.area_id) is str else None


def _action_supports_domain(action: str, domain: str) -> bool:
    if action == "get_state":
        return domain in SUPPORTED_DOMAINS
    if action == "set_fan_percentage":
        return domain == "fan"
    return action in ("turn_off", "turn_on") and domain in (
        "fan",
        "light",
        "switch",
    )
