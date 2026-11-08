use std::fs;
use std::path::Path;

use proptest::prelude::*;

use crate::git_desk::{
    GIT_CASES, GIT_FOLDER_NAME, check_chosen_folder, folder_files_strategy,
    folder_name_strategy, guard_committed, guard_unborn, list_committed_files,
    read_git_problem, read_repository_state, read_started_flag, write_files,
};
use crate::support::git_origin::run_git;
use crate::support::test_device::{describe, fail};

const BROKEN_GIT_FILE_TEXT: &str = "not a git link\n";
const GIT_PROBLEM_START: &str = "could not start git in the folder";
const GIT_OWN_WORD: &str = "gitfile";
const OPTION_LIKE_NAMES: [&str; 4] = ["-c", "--all", "--message", "-q"];
const IDENTITY_NAME_PATTERN: &str = "[A-Z][a-z]{1,8} [A-Z][a-z]{1,8}";
const IDENTITY_EMAIL_PATTERN: &str = "[a-z]{1,8}@[a-z]{1,8}\\.test";
const MOST_REPEATS: usize = 3;

fn break_git_link(folder: &Path) -> Result<(), String> {
    fs::write(folder.join(GIT_FOLDER_NAME), BROKEN_GIT_FILE_TEXT)
        .map_err(describe)
}

fn read_git_link(folder: &Path) -> Result<String, String> {
    fs::read_to_string(folder.join(GIT_FOLDER_NAME)).map_err(describe)
}

fn read_author(folder: &Path) -> Result<String, String> {
    run_git(folder, &["log", "-1", "--format=%an <%ae>"])
}

fn expected_problem_start(folder: &Path) -> String {
    format!("{GIT_PROBLEM_START} {}: ", folder.display())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_describe_git_problem_property_names_the_chosen_folder(
        name in folder_name_strategy(),
    ) {
        let guarded = guard_committed(&name)?;
        break_git_link(&guarded.chosen).map_err(fail)?;

        let problem = read_git_problem(&guarded.chosen);

        let expected_start = expected_problem_start(&guarded.chosen);
        prop_assert!(problem.starts_with(&expected_start), "{}", problem);
    }

    #[test]
    fn test_describe_git_problem_property_keeps_a_trimmed_problem(
        name in folder_name_strategy(),
    ) {
        let guarded = guard_committed(&name)?;
        break_git_link(&guarded.chosen).map_err(fail)?;

        let problem = read_git_problem(&guarded.chosen);

        let expected_start = expected_problem_start(&guarded.chosen);
        let git_words =
            problem.strip_prefix(&expected_start).unwrap_or_default();
        prop_assert!(!git_words.is_empty(), "{}", problem);
        prop_assert_eq!(git_words.trim(), git_words);
    }

    #[test]
    fn test_describe_git_problem_property_is_the_same_each_time(
        name in folder_name_strategy(),
        repeat_count in 2..=MOST_REPEATS,
    ) {
        let guarded = guard_committed(&name)?;
        break_git_link(&guarded.chosen).map_err(fail)?;
        let first = check_chosen_folder(&guarded.chosen);

        for _ in 1..repeat_count {
            let again = check_chosen_folder(&guarded.chosen);
            prop_assert_eq!(again, first.clone());
        }
        prop_assert!(first.is_err());
    }

    #[test]
    fn test_run_git_property_a_failure_changes_nothing(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_unborn(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;
        break_git_link(&guarded.chosen).map_err(fail)?;
        let guard_before = read_repository_state(&guarded.guard);

        let checked = check_chosen_folder(&guarded.chosen);

        prop_assert!(checked.is_err());
        prop_assert_eq!(
            read_git_link(&guarded.chosen).map_err(fail)?,
            BROKEN_GIT_FILE_TEXT
        );
        prop_assert_eq!(read_repository_state(&guarded.guard), guard_before);
    }

    #[test]
    fn test_run_git_property_passes_option_like_names_as_text(
        name in prop::sample::select(OPTION_LIKE_NAMES.to_vec()),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_committed(name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;

        let checked = check_chosen_folder(&guarded.chosen).map_err(fail)?;

        let subject = run_git(&guarded.chosen, &["log", "-1", "--format=%s"])
            .map_err(fail)?;
        prop_assert_eq!(read_started_flag(&checked), Some(true));
        prop_assert_eq!(subject, format!("Start {name}"));
    }

    #[test]
    fn test_run_git_property_a_repaired_folder_starts_cleanly(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_committed(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;
        break_git_link(&guarded.chosen).map_err(fail)?;
        let refused = check_chosen_folder(&guarded.chosen);
        fs::remove_file(guarded.chosen.join(GIT_FOLDER_NAME)).map_err(fail)?;

        let checked = check_chosen_folder(&guarded.chosen).map_err(fail)?;

        prop_assert!(refused.is_err());
        prop_assert_eq!(read_started_flag(&checked), Some(true));
        let committed = list_committed_files(&guarded.chosen).map_err(fail)?;
        let expected: Vec<String> = files.keys().cloned().collect();
        prop_assert_eq!(committed, expected);
    }

    #[test]
    fn test_start_git_property_works_inside_the_chosen_folder(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_committed(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;
        let guard_before = read_repository_state(&guarded.guard);

        check_chosen_folder(&guarded.chosen).map_err(fail)?;

        let prefix =
            run_git(&guarded.chosen, &["rev-parse", "--show-prefix"])
                .map_err(fail)?;
        prop_assert_eq!(prefix, "");
        prop_assert_eq!(read_repository_state(&guarded.guard), guard_before);
    }

    #[test]
    fn test_start_git_property_reports_the_words_git_wrote(
        name in folder_name_strategy(),
    ) {
        let guarded = guard_committed(&name)?;
        break_git_link(&guarded.chosen).map_err(fail)?;

        let problem = read_git_problem(&guarded.chosen);

        prop_assert!(problem.contains(GIT_OWN_WORD), "{}", problem);
    }

    #[test]
    fn test_start_git_property_the_repository_top_is_the_chosen_folder(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_unborn(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;

        check_chosen_folder(&guarded.chosen).map_err(fail)?;

        let top_level =
            run_git(&guarded.chosen, &["rev-parse", "--show-toplevel"])
                .map_err(fail)?;
        let top_name = Path::new(&top_level)
            .file_name()
            .map(|folder_name| folder_name.to_string_lossy().into_owned());
        prop_assert_eq!(top_name, Some(name));
    }

    #[test]
    fn test_list_missing_identity_settings_property_keeps_a_set_identity(
        name in folder_name_strategy(),
        author_name in IDENTITY_NAME_PATTERN,
        author_email in IDENTITY_EMAIL_PATTERN,
    ) {
        let guarded = guard_committed(&name)?;
        let folder = &guarded.chosen;
        run_git(folder, &["init", "--quiet"]).map_err(fail)?;
        run_git(folder, &["config", "user.name", &author_name]).map_err(fail)?;
        run_git(folder, &["config", "user.email", &author_email])
            .map_err(fail)?;

        check_chosen_folder(folder).map_err(fail)?;

        let author = read_author(folder).map_err(fail)?;
        prop_assert_eq!(author, format!("{author_name} <{author_email}>"));
    }

    #[test]
    fn test_list_missing_identity_settings_property_saves_no_fallback(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_committed(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;

        check_chosen_folder(&guarded.chosen).map_err(fail)?;

        let folder = &guarded.chosen;
        let saved_name =
            run_git(folder, &["config", "--local", "--get", "user.name"]);
        let saved_email =
            run_git(folder, &["config", "--local", "--get", "user.email"]);
        prop_assert!(saved_name.is_err(), "{:?}", saved_name);
        prop_assert!(saved_email.is_err(), "{:?}", saved_email);
    }

    #[test]
    fn test_list_missing_identity_settings_property_always_names_an_author(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_committed(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;

        check_chosen_folder(&guarded.chosen).map_err(fail)?;

        let folder = &guarded.chosen;
        let author_name =
            run_git(folder, &["log", "-1", "--format=%an"]).map_err(fail)?;
        let author_email =
            run_git(folder, &["log", "-1", "--format=%ae"]).map_err(fail)?;
        prop_assert!(!author_name.trim().is_empty());
        prop_assert!(author_email.contains('@'), "{}", author_email);
    }
}
