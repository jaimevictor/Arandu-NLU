use std::collections::BTreeSet;

use crate::{
    Action, Catalog, InterpretRequest, InterpretResponse, Operation,
    model::{MAX_OPERATIONS, MAX_TARGET_CLAUSES, MAX_TARGETS_PER_OPERATION, validate_request},
    normalize::{normalize, strip_article, strip_preposition},
};

const EFFECT_STARTERS: &[&str] = &[
    "acenda", "acende", "ajuste", "apaga", "apague", "coloque", "defina", "desliga", "desligue",
    "liga", "ligue",
];

enum Resolution {
    Ambiguous,
    Match(Vec<String>),
    NoMatch,
}

#[derive(Clone, Copy)]
enum DomainHint {
    Fan,
    Light,
    Sensor,
    Switch,
}

impl DomainHint {
    fn matches(self, domain: &str) -> bool {
        match self {
            Self::Fan => domain == "fan",
            Self::Light => domain == "light",
            Self::Sensor => matches!(domain, "binary_sensor" | "sensor"),
            Self::Switch => domain == "switch",
        }
    }
}

#[must_use]
pub fn interpret(request: &InterpretRequest) -> InterpretResponse {
    let mut request = request.clone();
    if !validate_request(&mut request) {
        return InterpretResponse::invalid_request();
    }

    let text = normalize(&request.text);
    if text.is_empty() {
        return InterpretResponse::invalid_request();
    }

    if looks_like_query(&text) {
        if has_effect_boundary(&text) {
            return InterpretResponse::no_match();
        }
        let Some(target) = query_target(&text) else {
            return InterpretResponse::no_match();
        };
        return match resolve_target(target, Action::GetState, &request.catalog) {
            Resolution::Ambiguous => InterpretResponse::ambiguous(),
            Resolution::NoMatch => InterpretResponse::no_match(),
            Resolution::Match(targets) => InterpretResponse::plan(vec![Operation {
                action: Action::GetState,
                percentage: None,
                targets,
            }]),
        };
    }

    let Some(segments) = effect_segments(&text) else {
        return InterpretResponse::no_match();
    };
    let mut operations = Vec::with_capacity(segments.len());
    for segment in segments {
        let Some((action, percentage, target)) = effect_parts(segment) else {
            return InterpretResponse::no_match();
        };
        match resolve_target(target, action, &request.catalog) {
            Resolution::Ambiguous => return InterpretResponse::ambiguous(),
            Resolution::NoMatch => return InterpretResponse::no_match(),
            Resolution::Match(targets) => operations.push(Operation {
                action,
                percentage,
                targets,
            }),
        }
    }

    if operations.is_empty() || operations.len() > MAX_OPERATIONS {
        return InterpretResponse::no_match();
    }
    let mut affected = BTreeSet::new();
    for operation in &operations {
        if !operation.action.is_effect()
            || operation
                .targets
                .iter()
                .any(|target| !affected.insert(target))
        {
            return InterpretResponse::no_match();
        }
    }
    InterpretResponse::plan(operations)
}

fn looks_like_query(text: &str) -> bool {
    ["como ", "qual ", "quanto "]
        .iter()
        .any(|prefix| text.starts_with(prefix))
}

fn query_target(text: &str) -> Option<&str> {
    const PREFIXES: &[&str] = &[
        "qual e o estado das ",
        "qual e o estado dos ",
        "qual e o estado da ",
        "qual e o estado de ",
        "qual e o estado do ",
        "qual o estado das ",
        "qual o estado dos ",
        "qual o estado da ",
        "qual o estado de ",
        "qual o estado do ",
        "quanto esta a ",
        "quanto esta o ",
        "quanto esta ",
        "como esta a ",
        "como esta o ",
        "como esta ",
        "qual e a ",
        "qual e o ",
        "qual a ",
        "qual o ",
    ];
    PREFIXES
        .iter()
        .find_map(|prefix| text.strip_prefix(prefix))
        .filter(|target| !target.is_empty())
}

fn effect_segments(text: &str) -> Option<Vec<&str>> {
    if !starts_effect(text) {
        return None;
    }
    let mut result = Vec::new();
    let mut segment_start = 0_usize;
    for (delimiter, _) in text.match_indices(" e ") {
        let next_start = delimiter + 3;
        if starts_effect(&text[next_start..]) {
            let segment = text[segment_start..delimiter].trim();
            if segment.is_empty() {
                return None;
            }
            result.push(segment);
            segment_start = next_start;
        }
    }
    let final_segment = text[segment_start..].trim();
    if final_segment.is_empty() {
        return None;
    }
    result.push(final_segment);
    (result.len() <= MAX_OPERATIONS).then_some(result)
}

fn has_effect_boundary(text: &str) -> bool {
    text.match_indices(" e ")
        .any(|(delimiter, _)| starts_effect(&text[delimiter + 3..]))
}

fn starts_effect(text: &str) -> bool {
    EFFECT_STARTERS.iter().any(|starter| {
        text == *starter
            || text
                .strip_prefix(starter)
                .is_some_and(|rest| rest.starts_with(' '))
    })
}

fn effect_parts(segment: &str) -> Option<(Action, Option<u8>, &str)> {
    if let Some(target) = strip_starter(segment, &["acenda", "acende", "liga", "ligue"]) {
        return Some((Action::TurnOn, None, target));
    }
    if let Some(target) = strip_starter(segment, &["apaga", "apague", "desliga", "desligue"]) {
        return Some((Action::TurnOff, None, target));
    }
    let target_and_percentage = strip_starter(segment, &["ajuste", "coloque", "defina"])?;
    let (target, percentage) = percentage_parts(target_and_percentage)?;
    Some((Action::SetFanPercentage, Some(percentage), target))
}

fn strip_starter<'a>(value: &'a str, starters: &[&str]) -> Option<&'a str> {
    starters.iter().find_map(|starter| {
        value
            .strip_prefix(starter)
            .and_then(|rest| rest.strip_prefix(' '))
            .filter(|rest| !rest.is_empty())
    })
}

fn percentage_parts(value: &str) -> Option<(&str, u8)> {
    let (target, raw_percentage) = [" em ", " para "]
        .iter()
        .filter_map(|marker| {
            value
                .rfind(marker)
                .map(|index| (&value[..index], &value[index + marker.len()..]))
        })
        .max_by_key(|(target, _)| target.len())?;
    let digits = raw_percentage.strip_suffix(" por cento")?;
    if digits.is_empty() || !digits.bytes().all(|byte| byte.is_ascii_digit()) {
        return None;
    }
    let percentage: u8 = digits.parse().ok()?;
    if percentage > 100 {
        return None;
    }
    let target = target
        .strip_prefix("a velocidade do ")
        .or_else(|| target.strip_prefix("a velocidade da "))
        .unwrap_or(target);
    (!target.is_empty()).then_some((target, percentage))
}

fn resolve_target(target: &str, action: Action, catalog: &Catalog) -> Resolution {
    let target = strip_article(target);
    if let Some((domain, areas)) = area_expression(target) {
        match resolve_areas(domain, &areas, action, catalog) {
            Resolution::NoMatch => {}
            result => return result,
        }
    }
    resolve_entity_chain(target, action, catalog)
}

fn area_expression(target: &str) -> Option<(DomainHint, Vec<&str>)> {
    let (noun, rest) = target.split_once(' ')?;
    let domain = match noun {
        "luz" | "luzes" | "lampada" | "lampadas" | "iluminacao" => DomainHint::Light,
        "interruptor" | "interruptores" | "tomada" | "tomadas" => DomainHint::Switch,
        "ventilador" | "ventiladores" => DomainHint::Fan,
        "sensores" => DomainHint::Sensor,
        _ => return None,
    };
    let clauses: Vec<_> = rest.split(" e ").collect();
    if clauses.is_empty() || clauses.len() > MAX_TARGET_CLAUSES {
        return None;
    }
    let mut areas = Vec::with_capacity(clauses.len());
    for clause in clauses {
        let area = strip_preposition(clause)?;
        if area.is_empty() {
            return None;
        }
        areas.push(area);
    }
    Some((domain, areas))
}

fn resolve_areas(
    domain: DomainHint,
    area_names: &[&str],
    action: Action,
    catalog: &Catalog,
) -> Resolution {
    let mut area_ids = Vec::with_capacity(area_names.len());
    for area_name in area_names {
        let matches: BTreeSet<_> = catalog
            .areas
            .iter()
            .filter(|area| area.names.iter().any(|name| normalize(name) == *area_name))
            .map(|area| area.area_id.as_str())
            .collect();
        if matches.len() > 1 {
            return Resolution::Ambiguous;
        }
        let Some(area_id) = matches.first() else {
            return Resolution::NoMatch;
        };
        area_ids.push(*area_id);
    }

    let mut targets = BTreeSet::new();
    for area_id in area_ids {
        let matches: Vec<_> = catalog
            .entities
            .iter()
            .filter(|entity| {
                entity.area_id.as_deref() == Some(area_id)
                    && domain.matches(&entity.domain)
                    && entity.supports(action)
            })
            .map(|entity| entity.registry_id.clone())
            .collect();
        if matches.is_empty() {
            return Resolution::NoMatch;
        }
        targets.extend(matches);
    }
    if targets.is_empty() || targets.len() > MAX_TARGETS_PER_OPERATION {
        return Resolution::NoMatch;
    }
    Resolution::Match(targets.into_iter().collect())
}

fn resolve_entity_chain(target: &str, action: Action, catalog: &Catalog) -> Resolution {
    match resolve_entity_clause(target, action, catalog) {
        Resolution::Match(targets) => return Resolution::Match(targets),
        Resolution::Ambiguous => return Resolution::Ambiguous,
        Resolution::NoMatch => {}
    }

    let clauses: Vec<_> = target.split(" e ").collect();
    if clauses.len() < 2 || clauses.len() > MAX_TARGET_CLAUSES {
        return Resolution::NoMatch;
    }
    let mut targets = BTreeSet::new();
    for clause in clauses {
        match resolve_entity_clause(strip_article(clause), action, catalog) {
            Resolution::Ambiguous => return Resolution::Ambiguous,
            Resolution::NoMatch => return Resolution::NoMatch,
            Resolution::Match(matches) => {
                targets.extend(matches);
            }
        }
    }
    if targets.len() > MAX_TARGETS_PER_OPERATION {
        Resolution::NoMatch
    } else {
        Resolution::Match(targets.into_iter().collect())
    }
}

fn resolve_entity_clause(clause: &str, action: Action, catalog: &Catalog) -> Resolution {
    let matches: BTreeSet<_> = catalog
        .entities
        .iter()
        .filter(|entity| {
            entity.supports(action)
                && entity
                    .names
                    .iter()
                    .any(|name| strip_article(&normalize(name)) == clause)
        })
        .map(|entity| entity.registry_id.clone())
        .collect();
    match matches.len() {
        0 => Resolution::NoMatch,
        1 => Resolution::Match(matches.into_iter().collect()),
        _ => Resolution::Ambiguous,
    }
}

#[cfg(test)]
mod tests {
    use crate::{
        Action, Catalog, CatalogEntity, InterpretRequest, InterpretResponse, Operation, interpret,
    };

    use super::{Resolution, effect_segments, percentage_parts, resolve_target};

    #[test]
    fn splits_only_action_conjunctions() {
        assert_eq!(
            effect_segments("apague a luz da sala e do quarto e ligue a cafeteira"),
            Some(vec![
                "apague a luz da sala e do quarto",
                "ligue a cafeteira"
            ])
        );
    }

    #[test]
    fn percentage_is_strictly_bounded() {
        assert_eq!(
            percentage_parts("o ventilador em 100 por cento"),
            Some(("o ventilador", 100))
        );
        assert_eq!(percentage_parts("o ventilador em 101 por cento"), None);
    }

    #[test]
    fn entity_resolution_is_ambiguous_on_duplicate_alias() {
        let catalog = Catalog {
            areas: vec![],
            entities: vec![entity("one", "light.one"), entity("two", "light.two")],
            version: 1,
        };
        assert!(matches!(
            resolve_target("abajur", Action::TurnOn, &catalog),
            Resolution::Ambiguous
        ));
    }

    #[test]
    fn capitalized_alias_articles_match_single_chain_and_query() {
        let single = catalog(vec![entity_with(
            "one",
            "light.one",
            "O Abajur",
            vec![Action::TurnOn],
        )]);
        assert_eq!(
            interpret(&InterpretRequest {
                catalog: single,
                text: "Acenda o abajur.".to_owned(),
                version: 1,
            }),
            plan(Action::TurnOn, vec!["one"])
        );

        let chain = catalog(vec![
            entity_with(
                "one",
                "light.one",
                "O Abajur da Sala",
                vec![Action::TurnOff],
            ),
            entity_with(
                "two",
                "light.two",
                "O Abajur do Quarto",
                vec![Action::TurnOff],
            ),
        ]);
        assert_eq!(
            interpret(&InterpretRequest {
                catalog: chain,
                text: "Apague o abajur da sala e o abajur do quarto.".to_owned(),
                version: 1,
            }),
            plan(Action::TurnOff, vec!["one", "two"])
        );

        let query = catalog(vec![entity_with(
            "one",
            "light.one",
            "A Luz Principal da Sala",
            vec![Action::GetState],
        )]);
        assert_eq!(
            interpret(&InterpretRequest {
                catalog: query,
                text: "Qual é o estado da luz principal da sala?".to_owned(),
                version: 1,
            }),
            plan(Action::GetState, vec!["one"])
        );
    }

    fn entity(registry_id: &str, entity_id: &str) -> CatalogEntity {
        entity_with(registry_id, entity_id, "abajur", vec![Action::TurnOn])
    }

    fn entity_with(
        registry_id: &str,
        entity_id: &str,
        name: &str,
        actions: Vec<Action>,
    ) -> CatalogEntity {
        CatalogEntity {
            actions,
            area_id: None,
            domain: "light".to_owned(),
            entity_id: entity_id.to_owned(),
            names: vec![name.to_owned()],
            registry_id: registry_id.to_owned(),
        }
    }

    fn catalog(entities: Vec<CatalogEntity>) -> Catalog {
        Catalog {
            areas: vec![],
            entities,
            version: 1,
        }
    }

    fn plan(action: Action, targets: Vec<&str>) -> InterpretResponse {
        InterpretResponse::Plan {
            operations: vec![Operation {
                action,
                percentage: None,
                targets: targets.into_iter().map(str::to_owned).collect(),
            }],
            version: 1,
        }
    }
}
