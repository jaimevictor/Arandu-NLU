"""Versioned descriptor cache; state values are always read again in the executor."""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import time
from typing import Any
from types import SimpleNamespace

from homeassistant.helpers import area_registry, device_registry, entity_registry

from .capabilities import DOMAINS, capabilities, finite
from .catalog import CatalogError, _bounded_names, _effective_area_id, _entity_names

ATTRIBUTES = frozenset("supported_features device_class state_class unit_of_measurement min max step min_temp max_temp target_temp_step min_humidity max_humidity min_color_temp_kelvin max_color_temp_kelvin supported_color_modes hvac_modes fan_modes swing_modes preset_modes available_modes operation_list options effect_list source_list semantic_category".split())


@dataclass(frozen=True)
class Snapshot:
    payload: dict
    by_id: dict[str, dict]


def exposed(hass: Any, entry: Any, entity_id: str) -> bool:
    from homeassistant.components.homeassistant import exposed_entities
    return (entry is None or (getattr(entry, "disabled_by", None) is None and getattr(entry, "hidden_by", None) is None)) and exposed_entities.async_should_expose(hass, "conversation", entity_id) is True


def build(hass: Any, user: Any, options: dict) -> Snapshot:
    registry = entity_registry.async_get(hass)
    areas = area_registry.async_get(hass)
    devices = device_registry.async_get(hass)
    candidates = dict(registry.entities)
    # YAML scenes/scripts/helpers may legitimately have no entity-registry entry.
    if hasattr(hass.states, "async_all"):
        for state in hass.states.async_all():
            if state.entity_id.split(".", 1)[0] in DOMAINS:
                candidates.setdefault(state.entity_id, None)
    rows = []
    for entity_id, entry in sorted(candidates.items()):
        domain = entity_id.split(".", 1)[0]
        if domain not in DOMAINS or not exposed(hass, entry, entity_id):
            continue
        state = hass.states.get(entity_id)
        available = state is not None and state.state not in ("unknown", "unavailable")
        if state is None:
            state = SimpleNamespace(state="unavailable", attributes={})
        if not user.is_admin and user.permissions.check_entity(entity_id, "read") is not True:
            continue
        actions = capabilities(hass, entity_id, state, options.get("device_mappings")) if available else ["query"]
        if not user.is_admin and user.permissions.check_entity(entity_id, "control") is not True:
            from .capabilities import READ_ACTIONS
            actions = [action for action in actions if action in READ_ACTIONS]
        if not actions:
            continue
        area_id = _effective_area_id(entry, devices) if entry is not None else None
        device_id = getattr(entry, "device_id", None)
        device = devices.async_get(device_id) if device_id else None
        device_name = getattr(device, "name_by_user", None) or getattr(device, "name", None)
        names = _entity_names(entry, state) if entry is not None else _bounded_names((state.attributes.get("friendly_name"), entity_id))
        if not names:
            continue
        name = state.attributes.get("friendly_name")
        if name not in names:
            name = names[0]
        attrs = {key: sorted(value) if isinstance(value, set) else list(value) if isinstance(value, tuple) else value for key, value in state.attributes.items() if key in ATTRIBUTES and _bounded_attribute(value)}
        attrs["ambient_temperature"] = finite(state.attributes.get("current_temperature"))
        attrs["available"] = available
        overrides = options.get("entity_preferences", {}).get(entity_id, {})
        if type(overrides) is dict and overrides.get("semantic_category") in ("tank_level", "people_count", "remaining_time"):
            attrs["semantic_category"] = overrides["semantic_category"]
        rows.append({
            "registry_id": entry.id if entry is not None else "state_" + hashlib.sha256(entity_id.encode()).hexdigest()[:32],
            "entity_id": entity_id, "domain": domain, "area_id": area_id,
            "device_id": device_id, "name": name,
            "device_name": device_name if type(device_name) is str and device_name in _bounded_names((device_name,)) else None,
            "aliases": _bounded_names(tuple(getattr(entry, "aliases", ()) or ())),
            "device_class": state.attributes.get("device_class"),
            "actions": actions, "attributes": attrs,
            "preferred": type(overrides) is dict and overrides.get("preferred") is True,
        })
    # A valid cleaning destination need not contain an exposed entity.
    used = set(areas.areas)
    area_rows = [{"area_id": aid, "names": _bounded_names((areas.areas[aid].name, *sorted(areas.areas[aid].aliases)))} for aid in sorted(used) if aid in areas.areas]
    groups = []
    try:
        from homeassistant.helpers import floor_registry
    except ImportError:
        floor_registry = None
    if floor_registry is not None:
        for fid, floor in sorted(floor_registry.async_get(hass).floors.items()):
            members = sorted(aid for aid in used if aid in areas.areas and getattr(areas.areas[aid], "floor_id", None) == fid)
            if members:
                groups.append({"group_id": fid, "names": _bounded_names((floor.name, *sorted(getattr(floor, "aliases", ())))), "area_ids": members})
    if len(rows) > 8192 or len(area_rows) > 256 or any(not area["names"] for area in area_rows):
        raise CatalogError("contextual_limits")
    if len(groups) > 256 or any(not group["names"] for group in groups):
        raise CatalogError("contextual_groups")
    payload = {"version": 4, "entities": sorted(rows, key=lambda row: row["registry_id"]), "areas": area_rows, "groups": groups}
    canonical = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()
    if len(canonical) > 2_097_000:
        raise CatalogError("contextual_bytes")
    payload["generation"] = hashlib.sha256(canonical).hexdigest()
    return Snapshot(payload, {row["registry_id"]: row for row in rows})


def _bounded_attribute(value: Any) -> bool:
    if type(value) in (int, float):
        return finite(value)
    if type(value) is str:
        return len(value.encode()) <= 128
    if isinstance(value, (list, tuple, set)):
        return len(value) <= 64 and all(type(item) is str and len(item.encode()) <= 128 for item in value)
    return type(value) is bool


class CatalogCache:
    """Invalidate on descriptor changes, not each word or numeric sensor update."""
    def __init__(self, hass: Any) -> None:
        self.hass = hass
        self.cache: dict[str, tuple[float, str, Snapshot]] = {}
        self.listeners = []
        if hasattr(hass, "bus"):
            for event in ("entity_registry_updated", "device_registry_updated", "area_registry_updated", "floor_registry_updated", "service_registered", "service_removed", "exposed_entities_updated"):
                self.listeners.append(hass.bus.async_listen(event, self.invalidate))
            self.listeners.append(hass.bus.async_listen("state_changed", self.state_changed))

    def invalidate(self, _: Any = None) -> None:
        self.cache.clear()

    def state_changed(self, event: Any) -> None:
        before, after = event.data.get("old_state"), event.data.get("new_state")
        if before is None or after is None or (before.state in ("unknown", "unavailable")) != (after.state in ("unknown", "unavailable")) or any(before.attributes.get(key) != after.attributes.get(key) for key in ATTRIBUTES):
            self.invalidate()

    def get(self, user_id: str, user: Any, options: dict) -> Snapshot:
        fingerprint = json.dumps(options, ensure_ascii=False, sort_keys=True, allow_nan=False)
        if len(fingerprint.encode()) > 65536:
            raise CatalogError("options_bytes")
        entry = self.cache.get(user_id)
        if entry is not None and entry[1] == fingerprint and time.monotonic() - entry[0] <= 5:
            return entry[2]
        snapshot = build(self.hass, user, options)
        if len(self.cache) >= 16 and user_id not in self.cache:
            self.cache.pop(next(iter(self.cache)))
        self.cache[user_id] = (time.monotonic(), fingerprint, snapshot)
        return snapshot

    def close(self) -> None:
        for unsubscribe in self.listeners:
            unsubscribe()
        self.listeners.clear()
        self.cache.clear()


def origin_area(hass: Any, user_input: Any, options: dict) -> str | None:
    devices = device_registry.async_get(hass)
    registry = entity_registry.async_get(hass)
    device_id = getattr(user_input, "device_id", None)
    satellite_id = getattr(user_input, "satellite_id", None)
    if type(satellite_id) is str:
        entry = registry.entities.get(satellite_id)
        if entry is not None:
            if getattr(entry, "disabled_by", None) is not None:
                return None
            area = _effective_area_id(entry, devices)
            if area:
                return area
    if type(device_id) is str:
        device = devices.async_get(device_id)
        if device is not None and type(device.area_id) is str:
            return device.area_id
    preferred = options.get("default_area")
    if type(preferred) is str and preferred in area_registry.async_get(hass).areas:
        return preferred
    return None
