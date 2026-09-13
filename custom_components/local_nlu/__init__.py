"""Local NLU Home Assistant companion integration."""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from homeassistant.config_entries import ConfigEntry
    from homeassistant.core import HomeAssistant


async def async_setup(_: HomeAssistant, __: dict[str, Any]) -> bool:
    return True


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    from homeassistant.helpers.aiohttp_client import async_get_clientsession

    from .client import ClientError, LocalNluClient, normalize_endpoint
    from .const import CONF_ENDPOINT, PLATFORMS
    from .runtime import LocalNluRuntime

    try:
        endpoint = normalize_endpoint(entry.data[CONF_ENDPOINT])
    except (KeyError, ClientError):
        return False
    client = LocalNluClient(async_get_clientsession(hass), endpoint)
    entry.runtime_data = LocalNluRuntime(hass, client)
    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    return True


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    from .const import PLATFORMS

    unloaded = await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
    if unloaded:
        try:
            del entry.runtime_data
        except AttributeError:
            pass
    return unloaded
