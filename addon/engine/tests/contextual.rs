//! `FIXTURE_TECNICA` catalog, project-authored internal conformance specification.
use local_nlu::contextual::{
    contract::{Area, AreaGroup, Catalog, ContextRequest, Entity},
    interpret, register_catalog, slots,
};
use serde_json::json;
use std::collections::BTreeMap;

fn entity(
    id: &str,
    domain: &str,
    name: &str,
    area: &str,
    class: Option<&str>,
    actions: &[&str],
) -> Entity {
    Entity {
        registry_id: id.into(),
        entity_id: format!("{domain}.{id}"),
        domain: domain.into(),
        name: name.into(),
        aliases: vec![],
        device_id: Some(format!("device_{id}")),
        device_name: None,
        area_id: Some(area.into()),
        device_class: class.map(str::to_owned),
        actions: actions.iter().map(|action| (*action).into()).collect(),
        attributes: BTreeMap::new(),
        preferred: false,
    }
}

fn catalog() -> Catalog {
    Catalog {
        version: 4,
        generation: "a".repeat(64),
        groups: vec![],
        areas: vec![
            Area {
                area_id: "quarto".into(),
                names: vec!["Quarto".into()],
            },
            Area {
                area_id: "sala".into(),
                names: vec!["Sala".into()],
            },
            Area {
                area_id: "escritorio".into(),
                names: vec!["Escritório de Jaime".into()],
            },
        ],
        entities: vec![
            entity(
                "ar_quarto",
                "climate",
                "Ar-condicionado",
                "quarto",
                None,
                &["turn_on", "turn_off", "temperature", "query"],
            ),
            entity(
                "ar_sala",
                "climate",
                "Ar-condicionado",
                "sala",
                None,
                &["turn_on", "turn_off", "temperature", "query"],
            ),
            entity(
                "ar_escritorio",
                "climate",
                "Ar-condicionado",
                "escritorio",
                None,
                &["turn_on", "turn_off", "temperature", "query"],
            ),
            entity(
                "fan",
                "fan",
                "Ventilador",
                "quarto",
                None,
                &["turn_on", "turn_off", "percentage", "query"],
            ),
            entity(
                "light",
                "light",
                "Luz",
                "quarto",
                None,
                &["turn_on", "turn_off", "brightness", "color", "query"],
            ),
            entity(
                "sensor",
                "sensor",
                "Termômetro",
                "quarto",
                Some("temperature"),
                &["query"],
            ),
            entity(
                "timer",
                "timer",
                "Timer",
                "quarto",
                None,
                &[
                    "timer_start",
                    "timer_pause",
                    "timer_resume",
                    "timer_cancel",
                    "query",
                ],
            ),
            entity(
                "lock",
                "lock",
                "Porta",
                "quarto",
                None,
                &["lock", "unlock", "query"],
            ),
            entity(
                "calendar",
                "calendar",
                "Calendário",
                "quarto",
                None,
                &["calendar", "query"],
            ),
        ],
    }
}

fn request(text: &str) -> ContextRequest {
    ContextRequest {
        version: 4,
        generation: "a".repeat(64),
        text: text.into(),
        origin_area: Some("quarto".into()),
        ..ContextRequest::default()
    }
}

#[test]
fn all_twenty_frozen_user_examples() {
    let mut catalog = catalog();
    catalog.generation = "d".repeat(64);
    catalog.areas.extend([
        Area {
            area_id: "corredor".into(),
            names: vec!["Corredor".into()],
        },
        Area {
            area_id: "cozinha".into(),
            names: vec!["Cozinha".into()],
        },
    ]);
    catalog.entities.extend([
        entity(
            "hall_light",
            "light",
            "Luz",
            "corredor",
            None,
            &["turn_on", "turn_off", "query"],
        ),
        entity(
            "living_light",
            "light",
            "Luz",
            "sala",
            None,
            &["turn_on", "turn_off", "query"],
        ),
        entity("person", "person", "Bruna", "sala", None, &["query"]),
        entity(
            "presence",
            "binary_sensor",
            "Presença",
            "cozinha",
            Some("occupancy"),
            &["query"],
        ),
        entity(
            "tv",
            "media_player",
            "TV",
            "sala",
            Some("tv"),
            &["remote_key", "channel", "query"],
        ),
        entity(
            "scene",
            "scene",
            "Cinema",
            "sala",
            None,
            &["activate", "query"],
        ),
    ]);
    assert_eq!(register_catalog(catalog).status, "catalog_ready");
    let spec: serde_json::Value = serde_json::from_str(include_str!(
        "../../../data/contextual/conformance-spec.json"
    ))
    .unwrap();
    for case in spec["cases"].as_array().unwrap() {
        let text = case[0].as_str().unwrap();
        let expected = case[1].as_str().unwrap();
        let mut input = request(text);
        input.generation = "d".repeat(64);
        let response = interpret(&input);
        if expected == "cancel" {
            assert_eq!(response.status, "cancel", "{text}: {response:?}");
        } else {
            assert_eq!(response.status, "plan", "{text}: {response:?}");
            if expected == "compound" {
                assert_eq!(response.operations.len(), 2, "{text}");
            } else {
                assert_eq!(response.operations[0].action, expected, "{text}");
            }
        }
    }
}

#[test]
fn floor_groups_are_explicit_and_categories_remain_distinct() {
    let mut catalog = catalog();
    catalog.generation = "e".repeat(64);
    catalog.groups = vec![AreaGroup {
        group_id: "floor".into(),
        names: vec!["Andar superior".into()],
        area_ids: vec!["quarto".into(), "sala".into()],
    }];
    catalog.entities.push(entity(
        "fan2",
        "fan",
        "Ventilador",
        "sala",
        None,
        &["turn_on", "turn_off", "query"],
    ));
    assert_eq!(register_catalog(catalog).status, "catalog_ready");
    let mut input = request("liga as luzes do andar superior");
    input.generation = "e".repeat(64);
    let plan = interpret(&input);
    assert_eq!(plan.status, "plan", "{plan:?}");
    assert_eq!(plan.operations[0].targets, ["light"]);
    assert_eq!(
        plan.operations[0].parameters.scope.as_deref(),
        Some("floor_group")
    );
    input.text = "liga as ventiladores do andar superior".into();
    let plan = interpret(&input);
    assert_eq!(plan.status, "plan", "{plan:?}");
    assert_eq!(plan.operations[0].targets, ["fan", "fan2"]);
}

#[test]
fn corpus_resolution_regressions() {
    let mut catalog = catalog();
    catalog.generation = "c".repeat(64);
    catalog.entities.extend([
        entity(
            "washer",
            "sensor",
            "Máquina de lavar",
            "sala",
            None,
            &["query"],
        ),
        entity(
            "window",
            "binary_sensor",
            "Janela",
            "sala",
            Some("window"),
            &["query"],
        ),
        entity(
            "plug",
            "switch",
            "Tomada da TV",
            "sala",
            Some("outlet"),
            &["turn_on", "query"],
        ),
        entity(
            "vacuum",
            "vacuum",
            "Robô aspirador",
            "sala",
            None,
            &["vacuum_start", "vacuum_area", "query"],
        ),
        entity(
            "mower",
            "lawn_mower",
            "Cortador de grama",
            "sala",
            None,
            &["mower_start", "query"],
        ),
    ]);
    catalog.entities[1]
        .actions
        .extend(["fan_mode".into(), "swing_mode".into()]);
    assert_eq!(register_catalog(catalog).status, "catalog_ready");
    for (text, action, target) in [
        ("como está a máquina de lavar", "query", "washer"),
        ("a janela da sala está aberta", "query", "window"),
        ("liga a tomada da TV", "turn_on", "plug"),
        ("liga o robô aspirador", "vacuum_start", "vacuum"),
        ("liga o cortador de grama", "mower_start", "mower"),
        (
            "manda o robô aspirador limpar o escritório de Jaime",
            "vacuum_area",
            "vacuum",
        ),
        (
            "coloca o ventilador do ar-condicionado da sala em alta",
            "fan_mode",
            "ar_sala",
        ),
        (
            "deixa a aleta do ar-condicionado da sala para cima",
            "swing_mode",
            "ar_sala",
        ),
    ] {
        let mut input = request(text);
        input.generation = "c".repeat(64);
        input.origin_area = Some("sala".into());
        let result = interpret(&input);
        assert_eq!(result.status, "plan", "{text}: {result:?}");
        assert_eq!(result.operations[0].action, action, "{text}");
        assert_eq!(result.operations[0].targets, [target], "{text}");
    }
}

#[test]
fn required_semantic_context_and_parameters() {
    assert_eq!(register_catalog(catalog()).status, "catalog_ready");
    for (text, action, target) in [
        ("Liga o ar.", "turn_on", "ar_quarto"),
        (
            "Liga o ar do escritório do Jaime",
            "turn_on",
            "ar_escritorio",
        ),
        ("Qual é a temperatura aqui?", "query", "sensor"),
        (
            "Coloca o ar em vinte e três graus",
            "temperature",
            "ar_quarto",
        ),
        ("Coloca o ar em 22,5 graus", "temperature", "ar_quarto"),
        ("Deixa a luz mais fraca", "brightness", "light"),
        ("Aumenta um pouco o ventilador", "percentage", "fan"),
        ("Coloca a iluminação azul", "color", "light"),
        ("Coloca um timer de dez minutos", "timer_start", "timer"),
        (
            "O que eu tenho no calendário amanhã?",
            "calendar",
            "calendar",
        ),
        ("Destranca a porta", "unlock", "lock"),
        ("Pode ligar o ventilador?", "turn_on", "fan"),
    ] {
        let result = interpret(&request(text));
        assert_eq!(result.status, "plan", "{text}: {result:?}");
        assert_eq!(result.operations[0].action, action, "{text}");
        assert_eq!(result.operations[0].targets, vec![target], "{text}");
    }
    assert_eq!(
        interpret(&request("Coloca o ar em 22,5 graus")).operations[0]
            .parameters
            .value,
        Some(json!(22.5))
    );
    assert_eq!(
        interpret(&request("Coloca um timer de dez minutos")).operations[0]
            .parameters
            .value,
        Some(json!(600.0))
    );
}

#[test]
fn ambiguity_negation_and_unknown_explicit_area_fail_closed() {
    let _ = register_catalog(catalog());
    let mut no_origin = request("Liga o ar");
    no_origin.origin_area = None;
    assert_eq!(interpret(&no_origin).status, "clarification");
    for text in [
        "Não liga o ventilador",
        "Não quero o ventilador ligado",
        "Nunca destranca a porta",
    ] {
        let result = interpret(&request(text));
        assert_eq!(result.status, "cancel");
        assert!(result.operations.is_empty());
    }
    let result = interpret(&request("Liga o ar do quarto inexistente"));
    assert!(result.operations.is_empty());
    let mut duplicates = catalog();
    duplicates.generation = "b".repeat(64);
    duplicates.entities.push(entity(
        "second",
        "climate",
        "Ar-condicionado",
        "quarto",
        None,
        &["turn_on"],
    ));
    let _ = register_catalog(duplicates);
    let mut input = request("Liga o ar");
    input.generation = "b".repeat(64);
    assert_eq!(interpret(&input).status, "clarification");
}

#[test]
fn compound_relative_and_context() {
    let _ = register_catalog(catalog());
    let result = interpret(&request("Liga o ar e apaga a luz"));
    assert_eq!(result.status, "plan", "{result:?}");
    assert_eq!(result.operations.len(), 2);
    let contradictory = interpret(&request("Liga o ar e desliga o ar"));
    assert!(contradictory.operations.is_empty());
    let mut continuation = request("Esfria mais dois graus");
    continuation.last_targets = vec!["ar_quarto".into()];
    let result = interpret(&continuation);
    assert_eq!(result.status, "plan", "{result:?}");
    assert_eq!(result.operations[0].targets, vec!["ar_quarto"]);
}

#[test]
fn numbers_duration_and_limits() {
    assert_eq!(slots::number("vinte e tres"), Some(23.0));
    assert_eq!(slots::number("um dois"), None);
    assert_eq!(slots::duration("uma hora e dez minutos"), Some(4200.0));
    assert_eq!(slots::duration("dez minutos banana"), None);
    assert_eq!(slots::duration("uma hora e"), None);
    assert_eq!(slots::original_slot("!!!", ""), None);
    assert_eq!(
        slots::original_slot("Adiciona Reunião às sete", "reuniao"),
        Some("Reunião".into())
    );
    assert_eq!(slots::number("NaN"), None);
    let mut request = request("liga o ar");
    request.text = "a".repeat(2049);
    assert_eq!(interpret(&request).status, "invalid_request");
}
