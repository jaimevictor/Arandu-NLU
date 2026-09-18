"""Configuration flow for the local passive add-on endpoint."""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

import voluptuous as vol

from homeassistant import config_entries
from homeassistant.helpers.aiohttp_client import async_get_clientsession

if TYPE_CHECKING:
    from homeassistant.config_entries import ConfigEntry

from .client import ClientError, LocalNluClient, normalize_endpoint
from .const import (
    CONF_ENDPOINT,
    CONF_SHADOW_ENABLED,
    CONF_V2_ENABLED,
    DEFAULT_ENDPOINT,
    DOMAIN,
)


class LocalNluConfigFlow(config_entries.ConfigFlow, domain=DOMAIN):
    """Configure exactly one local add-on endpoint."""

    VERSION = 1

    async def async_step_user(
        self, user_input: dict[str, Any] | None = None
    ) -> config_entries.ConfigFlowResult:
        if self._async_current_entries():
            return self.async_abort(reason="single_instance_allowed")
        errors: dict[str, str] = {}
        if user_input is not None:
            try:
                endpoint = normalize_endpoint(user_input[CONF_ENDPOINT])
                client = LocalNluClient(
                    async_get_clientsession(self.hass), endpoint
                )
                await client.async_health()
            except (KeyError, ClientError):
                errors["base"] = "cannot_connect"
            else:
                await self.async_set_unique_id(DOMAIN)
                self._abort_if_unique_id_configured()
                return self.async_create_entry(
                    title="ARANDU NLU",
                    data={CONF_ENDPOINT: endpoint},
                )
        return self.async_show_form(
            step_id="user",
            data_schema=vol.Schema(
                {
                    vol.Required(
                        CONF_ENDPOINT,
                        default=DEFAULT_ENDPOINT,
                    ): str
                }
            ),
            errors=errors,
        )


class LocalNluOptionsFlow(config_entries.OptionsFlow):
    """Toggle v2 interpretation and residential shadow (both default off)."""

    async def async_step_init(
        self, user_input: dict[str, Any] | None = None
    ) -> config_entries.ConfigFlowResult:
        if user_input is not None:
            return self.async_create_entry(data=user_input)
        options = self.config_entry.options
        return self.async_show_form(
            step_id="init",
            data_schema=vol.Schema(
                {
                    vol.Optional(
                        CONF_V2_ENABLED,
                        default=bool(options.get(CONF_V2_ENABLED, False)),
                    ): bool,
                    vol.Optional(
                        CONF_SHADOW_ENABLED,
                        default=bool(options.get(CONF_SHADOW_ENABLED, False)),
                    ): bool,
                }
            ),
        )


async def async_get_options_flow(
    config_entry: ConfigEntry,
) -> LocalNluOptionsFlow:
    return LocalNluOptionsFlow(config_entry)
