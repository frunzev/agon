use orchestration_node::identity_store::{
    IdentityStoreError, KeychainIdentityStore,
};
use proptest::prelude::*;

use crate::store_contract::{
    fill_every_secret, full_snapshot_strategy, read_snapshot,
};
use crate::store_desk::{
    TEST_SERVICE_NAME, open_keychain_desk, service_name_strategy,
};

const PLATFORM_CASE_COUNT: u32 = 8;
const MOCK_STORE_VENDOR: &str = "Mock store";
#[cfg(target_os = "macos")]
const MACOS_KEYCHAIN_VENDOR: &str = "macOS Keychain Store";
#[cfg(target_os = "macos")]
const MACOS_LOGIN_KEYCHAIN_DOMAIN: &str = "domain: User";

type OpenedStore = Result<KeychainIdentityStore, IdentityStoreError>;

fn is_keychain_refusal(opened: &OpenedStore) -> bool {
    matches!(opened, Err(IdentityStoreError::Keychain(message))
        if !message.is_empty())
}

fn describe_open_problem(opened: OpenedStore) -> Option<String> {
    opened.err().map(|problem| problem.to_string())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PLATFORM_CASE_COUNT))]

    #[test]
    fn test_keychain_identity_store_open_platform_property_keeps_service(
        service_name in service_name_strategy(),
    ) {
        let opened = KeychainIdentityStore::open_platform(&service_name);

        if let Ok(store) = opened {
            let description = format!("{store:?}");
            let quoted_service_name = format!("{service_name:?}");
            prop_assert!(description.contains(&quoted_service_name));
        }
    }

    #[test]
    fn test_keychain_identity_store_open_platform_property_any_name_alike(
        first_service in service_name_strategy(),
        second_service in service_name_strategy(),
    ) {
        let first_open =
            KeychainIdentityStore::open_platform(&first_service);
        let second_open =
            KeychainIdentityStore::open_platform(&second_service);

        prop_assert_eq!(
            describe_open_problem(first_open),
            describe_open_problem(second_open),
        );
    }

    #[test]
    fn test_keychain_identity_store_open_platform_property_others_untouched(
        service_name in service_name_strategy(),
        secrets in full_snapshot_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        fill_every_secret(&desk.store, &secrets)?;

        let _opened = KeychainIdentityStore::open_platform(&service_name);

        prop_assert_eq!(read_snapshot(&desk.store)?, secrets);
    }

    #[test]
    fn test_open_platform_store_property_opens_or_names_the_problem(
        service_name in service_name_strategy(),
    ) {
        let opened = KeychainIdentityStore::open_platform(&service_name);

        prop_assert!(opened.is_ok() || is_keychain_refusal(&opened));
    }

    #[test]
    fn test_open_platform_store_property_repeated_opens_agree(
        service_name in service_name_strategy(),
    ) {
        let first_open = KeychainIdentityStore::open_platform(&service_name);
        let second_open = KeychainIdentityStore::open_platform(&service_name);

        prop_assert_eq!(
            describe_open_problem(first_open),
            describe_open_problem(second_open),
        );
    }

    #[test]
    fn test_open_platform_store_property_supported_systems_open(
        service_name in service_name_strategy(),
    ) {
        let opened = KeychainIdentityStore::open_platform(&service_name);

        if cfg!(any(target_os = "macos", target_os = "ios")) {
            prop_assert!(opened.is_ok(), "{:?}", opened);
        } else {
            prop_assert!(opened.is_ok() || is_keychain_refusal(&opened));
        }
    }

    #[test]
    fn test_build_platform_store_property_uses_the_platform_vendor(
        service_name in service_name_strategy(),
    ) {
        let opened = KeychainIdentityStore::open_platform(&service_name);

        if let Ok(store) = opened {
            let description = format!("{store:?}");
            prop_assert!(!description.contains(MOCK_STORE_VENDOR));
            #[cfg(target_os = "macos")]
            prop_assert!(description.contains(MACOS_KEYCHAIN_VENDOR));
        }
    }

    #[test]
    fn test_build_platform_store_property_macos_uses_the_login_keychain(
        service_name in service_name_strategy(),
    ) {
        let opened = KeychainIdentityStore::open_platform(&service_name);

        #[cfg(target_os = "macos")]
        {
            let description = format!("{opened:?}");
            prop_assert!(description.contains(MACOS_LOGIN_KEYCHAIN_DOMAIN));
        }
        #[cfg(not(target_os = "macos"))]
        prop_assert!(opened.is_ok() || is_keychain_refusal(&opened));
    }

    #[test]
    fn test_build_platform_store_property_never_installs_a_default_store(
        service_name in service_name_strategy(),
    ) {
        let _opened = KeychainIdentityStore::open_platform(&service_name);

        prop_assert!(keyring_core::get_default_store().is_none());
    }
}
