use super::{
    contract::{ACTIONS, Catalog, Command, ContextRequest, Response},
    grammar, slots,
};
use crate::model::valid_identifier;
use std::collections::{BTreeMap, BTreeSet};

pub(super) struct Index {
    catalog: Catalog,
    names: BTreeMap<String, Vec<(usize, u16, &'static str)>>,
    areas: BTreeMap<String, BTreeSet<String>>,
    actions: BTreeMap<String, Vec<usize>>,
    ids: BTreeMap<String, usize>,
    groups: BTreeMap<String, Vec<(String, BTreeSet<String>)>>,
}
type Resolved = (Vec<String>, Vec<String>, Option<String>);

fn clean(value: &str) -> String {
    slots::normalize(value)
        .split_whitespace()
        .filter(|word| {
            !matches!(
                *word,
                "a" | "o"
                    | "as"
                    | "os"
                    | "um"
                    | "uma"
                    | "de"
                    | "do"
                    | "da"
                    | "dos"
                    | "das"
                    | "no"
                    | "na"
            )
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn type_names(domain: &str, class: Option<&str>) -> Vec<&'static str> {
    match domain {
        "climate" => vec!["ar", "ar condicionado", "split", "termostato"],
        "fan" => vec!["ventilador", "ventiladores"],
        "light" => vec!["luz", "luzes", "iluminacao", "lampada", "lampadas"],
        "cover" => match class {
            Some("gate") => vec!["portao", "portoes"],
            Some("garage") => vec!["garagem", "portao"],
            Some("curtain") => vec!["cortina", "cortinas"],
            Some("blind" | "shade") => vec!["persiana", "persianas"],
            _ => vec!["cortina", "persiana"],
        },
        "media_player" => match class {
            Some("tv") => vec!["tv", "televisao", "televisor"],
            Some("speaker") => vec!["alto falante", "caixa de som", "musica"],
            _ => vec!["reprodutor"],
        },
        "lock" => vec!["fechadura", "porta"],
        "switch" => match class {
            Some("outlet") => vec!["tomada"],
            _ => vec!["interruptor"],
        },
        "humidifier" => {
            if class == Some("dehumidifier") {
                vec!["desumidificador"]
            } else {
                vec!["umidificador"]
            }
        }
        "vacuum" => vec!["robo aspirador", "aspirador", "robo"],
        "lawn_mower" => vec!["cortador de grama", "cortador"],
        "timer" => vec!["timer", "temporizador"],
        "calendar" => vec!["calendario", "agenda"],
        "alarm_control_panel" => vec!["alarme", "seguranca"],
        "weather" => vec!["tempo", "clima"],
        "sun" => vec!["sol"],
        "camera" => vec!["camera"],
        "remote" => vec!["controle remoto", "controle"],
        "binary_sensor" => match class {
            Some("door") => vec!["porta", "portas"],
            Some("window") => vec!["janela", "janelas"],
            Some("occupancy" | "presence" | "motion") => vec!["presenca", "movimento"],
            Some("moisture") => vec!["vazamento"],
            _ => Vec::new(),
        },
        "sensor" => match class {
            Some("temperature") => vec!["temperatura"],
            Some("humidity") => vec!["umidade"],
            Some("power") => vec!["consumo", "potencia"],
            Some("battery") => vec!["bateria"],
            _ => Vec::new(),
        },
        _ => Vec::new(),
    }
}

impl Index {
    #[allow(clippy::too_many_lines)] // One bounded catalog validation/compilation pass.
    pub fn new(mut catalog: Catalog) -> Option<Self> {
        if catalog.version != 4
            || catalog.generation.len() != 64
            || !catalog.generation.bytes().all(|ch| ch.is_ascii_hexdigit())
            || catalog.entities.len() > 8_192
            || catalog.areas.len() > 256
            || catalog.groups.len() > 256
        {
            return None;
        }
        catalog
            .entities
            .sort_by(|a, b| a.registry_id.cmp(&b.registry_id));
        let mut names: BTreeMap<String, Vec<(usize, u16, &'static str)>> = BTreeMap::new();
        let mut areas: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
        let mut actions: BTreeMap<String, Vec<usize>> = BTreeMap::new();
        let mut ids = BTreeMap::new();
        let mut entity_ids = BTreeSet::new();
        let mut area_ids = BTreeSet::new();
        let mut total_names = 0;
        for area in &catalog.areas {
            if !valid_identifier(&area.area_id)
                || !area_ids.insert(area.area_id.clone())
                || area.names.is_empty()
                || area.names.len() > 8
            {
                return None;
            }
            for name in &area.names {
                if !valid_name(name) {
                    return None;
                }
                total_names += name.len();
                areas
                    .entry(clean(name))
                    .or_default()
                    .insert(area.area_id.clone());
            }
        }
        for (i, entity) in catalog.entities.iter().enumerate() {
            if !valid_identifier(&entity.registry_id)
                || ids.insert(entity.registry_id.clone(), i).is_some()
                || entity.entity_id.len() > 255
                || entity
                    .entity_id
                    .split_once('.')
                    .is_none_or(|(domain, id)| domain != entity.domain || !valid_identifier(id))
                || !entity_ids.insert(entity.entity_id.clone())
                || !valid_name(&entity.name)
                || entity.aliases.len() > 8
                || entity.actions.len() > ACTIONS.len()
                || entity
                    .actions
                    .iter()
                    .any(|action| !ACTIONS.contains(&action.as_str()))
                || entity
                    .area_id
                    .as_ref()
                    .is_some_and(|area| !area_ids.contains(area))
                || serde_json::to_vec(&entity.attributes).ok()?.len() > 4_096
            {
                return None;
            }
            let mut add = |name: &str, rank: u16, evidence: &'static str| {
                total_names += name.len();
                names
                    .entry(clean(name))
                    .or_default()
                    .push((i, rank, evidence));
            };
            add(&entity.entity_id, 100, "explicit_entity_id");
            for alias in &entity.aliases {
                if !valid_name(alias) {
                    return None;
                }
                add(alias, 90, "user_alias");
            }
            add(&entity.name, 80, "friendly_name");
            if matches!(entity.domain.as_str(), "script" | "scene") {
                let name = clean(&entity.name);
                for prefix in ["modo ", "cena ", "rotina "] {
                    if let Some(short) = name.strip_prefix(prefix) {
                        add(short, 70, "semantic_name_prefix");
                    }
                }
            }
            if let Some(name) = &entity.device_name {
                if !valid_name(name) {
                    return None;
                }
                add(name, 70, "device_name");
            }
            let synonyms = if entity.domain == "climate"
                && !clean(&entity.name).contains("ar condicionado")
                && !clean(&entity.name).contains("split")
                && !entity
                    .attributes
                    .get("hvac_modes")
                    .and_then(serde_json::Value::as_array)
                    .is_some_and(|modes| modes.iter().any(|mode| mode.as_str() == Some("cool")))
            {
                vec!["termostato"]
            } else {
                type_names(&entity.domain, entity.device_class.as_deref())
            };
            for synonym in synonyms {
                add(synonym, 60, "semantic_type");
            }
            // A climatizador alias is admitted only with entity-specific evidence.
            if clean(&entity.name).contains("climatizador") {
                add("climatizador", 60, "semantic_type");
            }
            for action in &entity.actions {
                actions.entry(action.clone()).or_default().push(i);
            }
        }
        let mut groups: BTreeMap<String, Vec<(String, BTreeSet<String>)>> = BTreeMap::new();
        let mut group_ids = BTreeSet::new();
        for group in &catalog.groups {
            if !valid_identifier(&group.group_id)
                || !group_ids.insert(&group.group_id)
                || group.names.is_empty()
                || group.names.len() > 8
                || group.area_ids.is_empty()
                || group.area_ids.len() > 256
                || group.area_ids.iter().any(|id| !area_ids.contains(id))
            {
                return None;
            }
            for name in &group.names {
                if !valid_name(name) {
                    return None;
                }
                groups.entry(clean(name)).or_default().push((
                    group.group_id.clone(),
                    group.area_ids.iter().cloned().collect(),
                ));
            }
        }
        if total_names > 2_097_152 {
            return None;
        }
        Some(Self {
            catalog,
            names,
            areas,
            actions,
            ids,
            groups,
        })
    }

    pub fn domain_hint(&self, text: &str) -> Option<String> {
        let text = clean(text);
        let words: Vec<&str> = text.split_whitespace().collect();
        let mut best = 0;
        let mut domains = BTreeSet::new();
        for start in 0..words.len() {
            for end in start + 1..=words.len().min(start + 12) {
                if let Some(rows) = self.names.get(&words[start..end].join(" ")) {
                    for (i, rank, _) in rows {
                        if *rank > best {
                            best = *rank;
                            domains.clear();
                        }
                        if *rank == best {
                            domains.insert(self.catalog.entities[*i].domain.clone());
                        }
                    }
                }
            }
        }
        if domains.len() == 1 {
            domains.into_iter().next()
        } else {
            grammar::semantic_domain(&text).map(str::to_owned)
        }
    }

    #[allow(clippy::too_many_lines, clippy::result_large_err)] // Cold failure includes a typed clarification command.
    pub fn resolve(
        &self,
        command: &Command,
        request: &ContextRequest,
    ) -> Result<Resolved, Response> {
        if matches!(
            command.action.as_str(),
            "local_time" | "local_date" | "binding" | "camera_view"
        ) {
            return Ok((Vec::new(), vec!["typed_intent".into()], None));
        }
        let mut mention = command.mention.as_deref().map(clean).unwrap_or_default();
        let explicit_area = command.area.as_deref().map(clean);
        let mut area = None;
        let mut explicit = false;
        let mut group_id = None;
        let mut group_areas = None;
        if let Some(name) = explicit_area {
            if command.parameters.scope.as_deref() == Some("floor_group")
                && let Some(groups) = self.groups.get(&name)
            {
                if !command.plural || groups.len() != 1 {
                    return Err(Response::failure(
                        "clarification",
                        &command.intent,
                        "ambiguous_group",
                    ));
                }
                group_id = Some(groups[0].0.clone());
                group_areas = Some(groups[0].1.clone());
                explicit = true;
            } else if let Some(id) = self.area(&name) {
                area = Some(id);
                explicit = true;
            } else {
                let full = format!("{mention} {name}");
                if self
                    .names
                    .get(&full)
                    .is_some_and(|rows| rows.iter().any(|(_, rank, _)| *rank >= 70))
                {
                    mention = full;
                } else {
                    return Err(Response::failure(
                        "clarification",
                        &command.intent,
                        "unknown_area",
                    ));
                }
            }
        }
        // Longest exact area suffix wins; never infer a person's room from person state.
        if area.is_none() && group_areas.is_none() && !mention.is_empty() {
            let registered_whole = self
                .names
                .get(&mention)
                .is_some_and(|rows| rows.iter().any(|(_, rank, _)| *rank >= 70));
            let mut matches: Vec<_> = self
                .areas
                .keys()
                .filter(|name| mention == **name || mention.ends_with(&format!(" {name}")))
                .collect();
            matches.sort_by_key(|name| std::cmp::Reverse(name.len()));
            if let Some(name) = matches.first() {
                area = Some(self.area(name).ok_or_else(|| {
                    Response::failure("clarification", &command.intent, "ambiguous_area")
                })?);
                if !registered_whole {
                    mention = mention[..mention.len() - name.len()].trim().to_owned();
                }
                explicit = true;
            }
        }
        let here = command.origin
            || mention
                .split_whitespace()
                .any(|word| matches!(word, "aqui" | "daqui"))
            || mention.contains("nesse comodo")
            || mention.contains("neste comodo")
            || mention.contains("perto mim")
            || mention.contains("onde eu estou");
        if here && area.is_none() {
            area = Some(request.origin_area.clone().ok_or_else(|| {
                Response::failure("clarification", &command.intent, "missing_origin_area")
            })?);
        }
        for phrase in [
            "daqui",
            "aqui",
            "nesse comodo",
            "neste comodo",
            "perto mim",
            "onde eu estou",
            "nessa sala",
            "nesse quarto",
        ] {
            format!(" {mention} ")
                .replace(&format!(" {phrase} "), " ")
                .trim()
                .clone_into(&mut mention);
        }
        if matches!(mention.as_str(), "tudo" | "todos" | "todas") {
            mention.clear();
        }
        let context_target = matches!(
            mention.as_str(),
            "isso" | "esse aparelho" | "essa" | "ele" | "ela" | "mais dois graus" | "dois graus"
        );
        let mut ranked: BTreeMap<usize, (u16, &'static str)> = BTreeMap::new();
        if context_target {
            for target in &request.last_targets {
                if let Some(i) = self.ids.get(target) {
                    ranked.insert(*i, (75, "recent_entity"));
                }
            }
            if ranked.is_empty() {
                return Err(Response::failure(
                    "clarification",
                    &command.intent,
                    "missing_context_target",
                ));
            }
        } else if !mention.is_empty() {
            if let Some(rows) = self.names.get(&mention) {
                for (i, rank, evidence) in rows {
                    if ranked.get(i).is_none_or(|(previous, _)| previous < rank) {
                        ranked.insert(*i, (*rank, *evidence));
                    }
                }
            }
            if ranked.is_empty() {
                // Measurement entities belonging to a named device may match its device name.
                return Err(Response::failure(
                    "clarification",
                    &command.intent,
                    "unknown_target_or_area",
                ));
            }
        } else {
            for i in self.actions.get(&command.action).into_iter().flatten() {
                ranked.insert(*i, (50, "capability_category"));
            }
        }
        ranked.retain(|i, _| {
            let entity = &self.catalog.entities[*i];
            entity.actions.contains(&command.action)
                && (command.domains.is_empty() || command.domains.contains(&entity.domain))
                && area.as_ref().is_none_or(|area| {
                    command.parameters.metric.as_deref() == Some("location")
                        || entity.area_id.as_ref() == Some(area)
                })
                && group_areas.as_ref().is_none_or(|areas| {
                    entity.area_id.as_ref().is_some_and(|id| areas.contains(id))
                })
                && class_compatible(command, entity)
        });
        if ranked.is_empty() {
            return Err(Response::failure(
                "unavailable",
                &command.intent,
                "no_compatible_capability",
            ));
        }
        // Environmental sensors outrank measured climate fallback. Setpoints never qualify.
        if command.parameters.metric.as_deref() == Some("temperature")
            && ranked
                .keys()
                .any(|i| self.catalog.entities[*i].domain == "sensor")
        {
            ranked.retain(|i, _| self.catalog.entities[*i].domain == "sensor");
        }
        let max_rank = ranked.values().map(|(rank, _)| *rank).max().unwrap_or(0);
        ranked.retain(|_, (rank, _)| *rank == max_rank);
        if !explicit
            && area.is_none()
            && (command.action != "query" || !command.plural)
            && (max_rank <= 60
                || (max_rank <= 80
                    && self
                        .names
                        .get(&mention)
                        .is_some_and(|rows| rows.iter().any(|(_, rank, _)| *rank == 60))))
            && let Some(origin) = &request.origin_area
        {
            let local: Vec<_> = ranked
                .keys()
                .filter(|i| self.catalog.entities[**i].area_id.as_ref() == Some(origin))
                .copied()
                .collect();
            if !local.is_empty() {
                ranked.retain(|i, _| local.contains(i));
                area = Some(origin.clone());
            }
        }
        if !command.plural && ranked.len() > 1 {
            let preferred: Vec<_> = ranked
                .keys()
                .filter(|i| self.catalog.entities[**i].preferred)
                .copied()
                .collect();
            if preferred.len() == 1 {
                ranked.retain(|i, _| preferred.contains(i));
            }
        }
        if ranked.len() > 32 {
            return Err(Response::failure(
                "unavailable",
                &command.intent,
                "target_limit",
            ));
        }
        if !command.plural && ranked.len() > 1 {
            let mut response =
                Response::failure("clarification", &command.intent, "ambiguous_target");
            response.candidates = ranked
                .keys()
                .map(|i| self.catalog.entities[*i].registry_id.clone())
                .collect();
            return Err(response);
        }
        let mut targets: Vec<_> = ranked
            .keys()
            .map(|i| self.catalog.entities[*i].registry_id.clone())
            .collect();
        targets.sort();
        let evidence: BTreeSet<_> = ranked
            .values()
            .map(|(_, kind)| (*kind).to_owned())
            .collect();
        Ok((targets, evidence.into_iter().collect(), area.or(group_id)))
    }

    fn area(&self, name: &str) -> Option<String> {
        let matches = self.areas.get(name)?;
        (matches.len() == 1)
            .then(|| matches.iter().next().cloned())
            .flatten()
    }

    pub fn cleaning_area(&self, name: &str) -> Option<String> {
        self.catalog
            .areas
            .iter()
            .find(|area| area.area_id == name)
            .map(|area| area.area_id.clone())
            .or_else(|| self.area(&clean(name)))
    }

    pub fn is_group(&self, id: &str) -> bool {
        self.catalog.groups.iter().any(|group| group.group_id == id)
    }
}

fn valid_name(value: &str) -> bool {
    !value.trim().is_empty() && value.len() <= 128 && !value.chars().any(char::is_control)
}

fn class_compatible(command: &Command, entity: &super::contract::Entity) -> bool {
    if let Some(class) = command.device_class.as_deref() {
        if class == "temperature" && entity.domain == "climate" {
            return entity
                .attributes
                .get("ambient_temperature")
                .and_then(serde_json::Value::as_bool)
                == Some(true);
        }
        if class == "occupancy" {
            return matches!(
                entity.device_class.as_deref(),
                Some("occupancy" | "presence" | "motion")
            );
        }
        return entity.device_class.as_deref() == Some(class);
    }
    match command.parameters.metric.as_deref() {
        Some("opening") => matches!(
            entity.device_class.as_deref(),
            Some("door" | "window" | "opening" | "gate" | "garage")
        ),
        Some("tank_level") => {
            entity
                .attributes
                .get("semantic_category")
                .and_then(serde_json::Value::as_str)
                == Some("tank_level")
        }
        Some("people_count") => {
            entity
                .attributes
                .get("semantic_category")
                .and_then(serde_json::Value::as_str)
                == Some("people_count")
        }
        Some("remaining_time") => {
            entity
                .attributes
                .get("semantic_category")
                .and_then(serde_json::Value::as_str)
                == Some("remaining_time")
        }
        _ => true,
    }
}
