use orchestration_core::protected_files::{
    DEFAULT_PROTECTED_PATTERNS, ProtectedFiles, validate_protected_files,
    validate_protected_pattern,
};
use proptest::prelude::*;
use proptest::sample::Index;
use serde::Deserialize;

const SHARED_DEFAULT_PATTERNS: &str =
    include_str!("../fixtures/default_protected_patterns.json");

#[derive(Debug, Deserialize)]
struct SharedDefaultPatterns {
    default_protected_patterns: Vec<String>,
}

fn read_shared_defaults() -> Result<Vec<String>, serde_json::Error> {
    let table: SharedDefaultPatterns =
        serde_json::from_str(SHARED_DEFAULT_PATTERNS)?;
    Ok(table.default_protected_patterns)
}

#[test]
fn test_protected_files_default_property_matches_the_shared_list()
-> Result<(), serde_json::Error> {
    let shared = read_shared_defaults()?;

    assert_eq!(ProtectedFiles::default().patterns, shared);
    assert_eq!(DEFAULT_PROTECTED_PATTERNS.to_vec(), shared);
    Ok(())
}

#[test]
fn test_protected_files_default_property_shared_list_is_valid()
-> Result<(), serde_json::Error> {
    let protected = ProtectedFiles {
        patterns: read_shared_defaults()?,
    };

    assert_eq!(validate_protected_files(&protected), Ok(()));
    Ok(())
}

proptest! {
    #[test]
    fn test_protected_files_default_property_every_shared_pattern_is_valid(
        picked in any::<Index>(),
    ) {
        let shared = read_shared_defaults()?;
        let pattern = picked.get(&shared);

        prop_assert_eq!(validate_protected_pattern(pattern), Ok(()));
    }
}
