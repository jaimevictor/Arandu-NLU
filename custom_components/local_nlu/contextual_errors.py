"""Typed, privacy-safe outcomes shared by runtime and the HA speech boundary."""

MESSAGES = {
    "missing_user": "Este dispositivo de voz ainda não está associado a um usuário.",
    "inactive_or_missing_configured_user": "O usuário associado a este dispositivo de voz está indisponível. Confira a configuração do ARANDU NLU.",
    "identity_origin_unavailable": "O dispositivo de voz associado está indisponível. Confira a configuração do ARANDU NLU.",
    "identity_changed": "A identidade da conversa mudou. Faça o pedido novamente.",
    "unknown_area": "Não encontrei um cômodo com esse nome.",
    "ambiguous_area": "Há mais de um cômodo com esse nome. Em qual cômodo?",
    "no_accessible_sensor": "Não encontrei um sensor acessível para essa medição nesse cômodo ou aparelho.",
    "sensor_unavailable": "O sensor dessa medição está indisponível no momento.",
    "ambiguous_source": "Qual sensor você quer consultar?",
    "invalid_measurement": "O sensor não forneceu uma medição válida.",
    "measurement_stale": "Não há uma observação recente dessa medição.",
    "incompatible_units": "As unidades dos sensores são incompatíveis com essa medição.",
    "no_compatible_capability": "Não encontrei dispositivos acessíveis com essa capacidade.",
    "permission_denied": "Você não tem permissão para fazer isso.",
    "invalid_request": "O pedido contém dados inválidos ou excede os limites permitidos.",
    "unsupported_intent": "Essa operação ainda não é suportada.",
    "no_match": "Não entendi esse pedido. Diga a ação e o cômodo ou aparelho.",
    "backend_unavailable": "Não consegui acessar o serviço local do ARANDU NLU.",
    "stale": "Os dispositivos ou o contexto mudaram. Faça o pedido novamente.",
    "target_limit": "Esse conjunto excede o limite de 32 dispositivos. Nenhum foi acionado; peça um conjunto menor.",
    "bulk_target_unavailable": "Há um dispositivo indisponível nesse conjunto. Nenhum foi acionado.",
    "dialogue_changed": "O contexto, as permissões ou os dispositivos mudaram. Faça o pedido novamente.",
    "dialogue_expired": "A pergunta anterior expirou. Faça o pedido novamente.",
    "no_location_provider": "Não há uma fonte de localização acessível configurada para esse aparelho.",
    "location_stale": "Não há uma observação recente da localização desse aparelho.",
    "location_unknown_area": "A fonte de localização não identificou um cômodo cadastrado.",
    "location_ambiguous": "Há mais de uma localização possível para esse aparelho.",
    "device_not_identified": "Não identifiquei esse aparelho no catálogo acessível.",
}


def speech(code: str, reason: str | None) -> str | None:
    aliases = {"entity_unavailable": "sensor_unavailable", "entity_permission": "permission_denied", "not_exposed": "permission_denied"}
    return MESSAGES.get(aliases.get(reason, reason), MESSAGES.get(code))
