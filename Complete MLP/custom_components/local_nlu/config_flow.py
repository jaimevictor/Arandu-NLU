"""Configuration flow for the local passive add-on endpoint."""

from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant import config_entries
from homeassistant.helpers.aiohttp_client import async_get_clientsession

from .client import ClientError, LocalNluClient, normalize_endpoint
from .const import CONF_ENDPOINT, DEFAULT_ENDPOINT, DOMAIN


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
                    title="Local NLU",
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
