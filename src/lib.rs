//! Simply Light — the one `impl Hooks` at the crate root.
//!
//! The mod is a **content carry**: the 160 light blocks live in `data/` and `assets/` inside
//! this same `.hmod` (160 block declarations from vanilla templates, 2048 states, 234 recipes,
//! 12 tags). Nothing is registered from Rust.
//!
//! [`runtime`] is the port's pure census model, carried byte-identical from the retired
//! bundle's `runtime.rs`. It is a `#[cfg(test)]` module: `cargo test` re-derives the families,
//! ids, template state spaces, light levels and drop rules from upstream's registration order,
//! so the carried declarations are checked without the game. Keep game access out of it.

pub mod runtime;

/// The mod instance the generated `hooks()` boxes once for the session.
///
/// Simply Light answers no game moment: the retired bundle's plan held one `[[module]]` (the
/// test-only census) and **zero** `[[injection]]`s. Upstream's code behaviours — the redstone
/// toggle of the two lamp blocks, the lamp post's three-block column, the edge-light editor,
/// the shift tooltips — are all recorded gaps at this pin (see `notes.md`, "Gaps after the
/// migration"), so an empty `Hooks` impl is the honest shape and `build`/`check` accept it.
#[derive(Default)]
struct Mod;

#[mod_api::horizon_mod]
impl mod_api::Hooks for Mod {}
