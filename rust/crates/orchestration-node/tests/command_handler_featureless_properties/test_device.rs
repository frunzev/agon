use std::fmt::Display;

use proptest::test_runner::TestCaseError;
use serde_json::Value;

pub fn describe(error: impl Display) -> String {
    error.to_string()
}

pub fn fail(error: impl Display) -> TestCaseError {
    TestCaseError::fail(error.to_string())
}

pub fn read_text(value: &Value, pointer: &str) -> Result<String, String> {
    let found = value.pointer(pointer).and_then(Value::as_str);
    let text = found.ok_or_else(|| format!("{pointer} is missing"))?;
    Ok(text.to_owned())
}
