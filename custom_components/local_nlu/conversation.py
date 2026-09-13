"""Home Assistant conversation entity for Local NLU."""

from __future__ import annotations

from typing import Any, Literal

try:
    from typing import override
except ImportError:

    def override(function: Any) -> Any:
        return function

from homeassistant.components import conversation
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers import intent
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback

from .runtime import RuntimeResult


async def async_setup_entry(
    _: HomeAssistant,
    config_entry: ConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    async_add_entities((LocalNluConversationEntity(config_entry),))


class LocalNluConversationEntity(
    conversation.ConversationEntity,
    conversation.AbstractConversationAgent,
):
    """Process one PT-BR utterance without retaining it."""

    _attr_has_entity_name = True
    _attr_name = "Local NLU"
    _attr_supported_features = conversation.ConversationEntityFeature.CONTROL

    def __init__(self, config_entry: ConfigEntry) -> None:
        super().__init__()
        self._runtime = config_entry.runtime_data
        self._attr_unique_id = f"{config_entry.entry_id}-conversation"

    @property
    @override
    def supported_languages(self) -> list[str] | Literal["*"]:
        return ["pt-BR"]

    @override
    async def async_process(
        self, user_input: conversation.ConversationInput
    ) -> conversation.ConversationResult:
        result = await self._runtime.async_process(user_input)
        response = intent.IntentResponse(language=user_input.language)
        speech, error_code, query = _render(result)
        if error_code is None:
            response.async_set_speech(speech)
            if query:
                response.response_type = intent.IntentResponseType.QUERY_ANSWER
        else:
            response.async_set_error(error_code, speech)
        return conversation.ConversationResult(
            response=response,
            conversation_id=user_input.conversation_id,
            continue_conversation=False,
        )


def _render(
    result: RuntimeResult,
) -> tuple[str, intent.IntentResponseErrorCode | None, bool]:
    if result.code == "success":
        if result.operation_count == 1:
            return ("Pronto.", None, False)
        return (
            f"Pronto, executei {result.operation_count} comandos.",
            None,
            False,
        )
    if result.code == "query_success":
        values = "; ".join(_render_state(state) for state in result.states)
        return (f"{values}.", None, True)
    if result.code == "ambiguous":
        return (
            "Encontrei mais de um alvo. Diga o nome ou a área com mais detalhes.",
            intent.IntentResponseErrorCode.NO_VALID_TARGETS,
            False,
        )
    if result.code in ("no_match", "invalid_request"):
        return (
            "Não entendi esse comando.",
            intent.IntentResponseErrorCode.NO_INTENT_MATCH,
            False,
        )
    if result.code == "denied":
        return (
            "Você não tem permissão para fazer isso.",
            intent.IntentResponseErrorCode.UNKNOWN,
            False,
        )
    if result.code == "stale":
        return (
            "O alvo mudou ou está indisponível. Tente novamente.",
            intent.IntentResponseErrorCode.NO_VALID_TARGETS,
            False,
        )
    return (
        "O Local NLU não conseguiu concluir o comando.",
        intent.IntentResponseErrorCode.UNKNOWN,
        False,
    )


def _render_state(state: Any) -> str:
    value = {"off": "desligado", "on": "ligado"}.get(state.state, state.state)
    suffix = f" {state.unit}" if state.unit is not None else ""
    return f"{state.label}: {value}{suffix}"
