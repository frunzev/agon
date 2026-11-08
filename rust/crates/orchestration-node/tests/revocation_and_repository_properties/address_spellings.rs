use orchestration_core::repository_address::parse_repository_address;
use proptest::prelude::*;

use crate::address_strategies::{host, path_part};

const PADDING_CHOICES: [&str; 4] = ["", " ", "\t", "\n"];
const SUFFIX_CHOICES: [&str; 5] = ["", ".git", "/", ".git/", "//"];
const UNPARSEABLE_PATTERNS: [&str; 4] = [
    "[a-z]{1,10}",
    "[a-z]{1,8}\\.[a-z]{2,4}/[a-z]{1,8}",
    "(ftp|ssh|http)://[a-z]{1,8}\\.[a-z]{2,4}/[a-z]{1,8}/[a-z]{1,8}",
    "git@[a-z]{1,8}\\.[a-z]{2,4}/[a-z]{1,8}/[a-z]{1,8}",
];

#[derive(Clone, Copy, Debug)]
pub enum AddressForm {
    Bare,
    Https,
    GitAt,
}

const ADDRESS_FORMS: [AddressForm; 3] =
    [AddressForm::Bare, AddressForm::Https, AddressForm::GitAt];

fn shout_letters(host_text: &str, shouted_letters: &[bool]) -> String {
    let mut shouted_host = String::new();
    for (letter, is_shouted) in host_text.chars().zip(shouted_letters) {
        if *is_shouted {
            shouted_host.push(letter.to_ascii_uppercase());
        } else {
            shouted_host.push(letter);
        }
    }
    shouted_host
}

fn host_length(canonical_address: &str) -> usize {
    let host_text = canonical_address.split('/').next().unwrap_or_default();
    host_text.len()
}

prop_compose! {
    pub fn spelling_of(canonical_address: String)(
        form in prop::sample::select(ADDRESS_FORMS.to_vec()),
        shouted_letters in prop::collection::vec(
            any::<bool>(),
            host_length(&canonical_address),
        ),
        suffix in prop::sample::select(SUFFIX_CHOICES.to_vec()),
        leading in prop::sample::select(PADDING_CHOICES.to_vec()),
        trailing in prop::sample::select(PADDING_CHOICES.to_vec()),
    ) -> String {
        let (host_text, path) =
            canonical_address.split_once('/').unwrap_or_default();
        let shouted_host = shout_letters(host_text, &shouted_letters);
        let spelled = match form {
            AddressForm::Bare => format!("{shouted_host}/{path}"),
            AddressForm::Https => format!("https://{shouted_host}/{path}"),
            AddressForm::GitAt => format!("git@{shouted_host}:{path}"),
        };
        format!("{leading}{spelled}{suffix}{trailing}")
    }
}

fn join_address_parts(address_parts: (String, String, String)) -> String {
    let (host_text, owner, name) = address_parts;
    format!("{host_text}/{owner}/{name}")
}

fn is_canonical(address: &str) -> bool {
    let parsed = parse_repository_address(address);
    parsed.as_deref() == Ok(address)
}

fn is_unparseable(address: &str) -> bool {
    parse_repository_address(address).is_err()
}

pub fn foreign_address_strategy() -> impl Strategy<Value = String> {
    (host(), path_part(), path_part())
        .prop_map(join_address_parts)
        .prop_filter("a canonical address", |address| is_canonical(address))
}

pub fn unparseable_address_strategy() -> impl Strategy<Value = String> {
    prop::sample::select(UNPARSEABLE_PATTERNS.to_vec())
        .prop_flat_map(|pattern| pattern)
        .prop_filter("an unparseable address", |address| {
            is_unparseable(address)
        })
}

fn pair_with_spelling(
    canonical_address: String,
) -> (Just<String>, BoxedStrategy<String>) {
    let spelling = spelling_of(canonical_address.clone()).boxed();
    (Just(canonical_address), spelling)
}

pub fn foreign_spelling_strategy() -> impl Strategy<Value = (String, String)> {
    foreign_address_strategy().prop_flat_map(pair_with_spelling)
}
