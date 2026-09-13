//! Deterministic, passive PT-BR interpretation for the Local NLU MLP.

mod model;
mod normalize;
mod parser;
pub mod server;

pub use model::{
    Action, Area, Catalog, CatalogEntity, InterpretRequest, InterpretResponse, Operation,
};
pub use parser::interpret;
