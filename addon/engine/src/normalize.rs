use unicode_normalization::{UnicodeNormalization, char::is_combining_mark};

pub(crate) fn normalize(input: &str) -> String {
    let mut expanded = String::with_capacity(input.len());
    for character in input
        .nfd()
        .filter(|character| !is_combining_mark(*character))
    {
        if character == '%' {
            expanded.push_str(" por cento ");
        } else if character.is_alphanumeric() {
            for lower in character.to_lowercase() {
                expanded.push(lower);
            }
        } else {
            expanded.push(' ');
        }
    }
    expanded.split_whitespace().collect::<Vec<_>>().join(" ")
}

pub(crate) fn strip_article(value: &str) -> &str {
    for article in ["a ", "as ", "o ", "os ", "uma ", "um "] {
        if let Some(rest) = value.strip_prefix(article) {
            return rest;
        }
    }
    value
}

pub(crate) fn strip_preposition(value: &str) -> Option<&str> {
    for preposition in [
        "das ", "dos ", "nas ", "nos ", "da ", "de ", "do ", "na ", "no ",
    ] {
        if let Some(rest) = value.strip_prefix(preposition) {
            return Some(rest);
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::normalize;

    #[test]
    fn removes_case_diacritics_and_punctuation() {
        assert_eq!(
            normalize("  DESLIGUE o Ventilador em 25%!  "),
            "desligue o ventilador em 25 por cento"
        );
    }
}
