use serde_json::{Value, json};

#[derive(Clone, Copy, Debug)]
pub enum FieldValue {
    Identifier,
    OptionalIdentifier,
    DeviceIdentifier,
    OptionalDeviceIdentifier,
    Text,
    Place,
    Places,
    Policy,
    Decision,
    Action,
}

#[derive(Clone, Copy, Debug)]
pub struct CommandShape {
    pub name: &'static str,
    pub fields: &'static [(&'static str, FieldValue)],
}

const SAMPLE_IDENTIFIER: &str = "00000000-0000-0000-0000-0000000000a1";
const SAMPLE_DEVICE_IDENTIFIER: &str = "device-sample";
const SAMPLE_TEXT: &str = "sample";
const MISTYPED_NUMBER: i64 = 7;

pub const AGENT_LOGIN_SHAPES: [CommandShape; 7] = [
    CommandShape {
        name: "agent_login_status",
        fields: &[],
    },
    CommandShape {
        name: "start_agent_login",
        fields: &[("place", FieldValue::Place)],
    },
    CommandShape {
        name: "read_agent_login",
        fields: &[],
    },
    CommandShape {
        name: "type_agent_login",
        fields: &[("keys", FieldValue::Text)],
    },
    CommandShape {
        name: "stop_agent_login",
        fields: &[],
    },
    CommandShape {
        name: "save_agent_api_key",
        fields: &[("api_key", FieldValue::Text)],
    },
    CommandShape {
        name: "forget_agent_credential",
        fields: &[],
    },
];

pub const AGENT_PLACE_SHAPES: [CommandShape; 1] = [CommandShape {
    name: "choose_agent_offers",
    fields: &[("offers", FieldValue::Places)],
}];

pub const APPROVAL_SHAPES: [CommandShape; 3] = [
    CommandShape {
        name: "list_approvals",
        fields: &[],
    },
    CommandShape {
        name: "create_approval",
        fields: &[
            ("run_id", FieldValue::OptionalIdentifier),
            ("action", FieldValue::Action),
        ],
    },
    CommandShape {
        name: "decide_approval",
        fields: &[
            ("approval_id", FieldValue::Identifier),
            ("decision", FieldValue::Decision),
        ],
    },
];

pub const DELETION_SHAPES: [CommandShape; 4] = [
    CommandShape {
        name: "delete_project",
        fields: &[("project_id", FieldValue::Identifier)],
    },
    CommandShape {
        name: "delete_workflow",
        fields: &[("workflow_id", FieldValue::Identifier)],
    },
    CommandShape {
        name: "delete_task",
        fields: &[("task_id", FieldValue::Identifier)],
    },
    CommandShape {
        name: "delete_workspace",
        fields: &[("workspace_id", FieldValue::Identifier)],
    },
];

pub const DEVICE_SHAPES: [CommandShape; 8] = [
    CommandShape {
        name: "list_devices",
        fields: &[],
    },
    CommandShape {
        name: "revoke_device",
        fields: &[("device_id", FieldValue::DeviceIdentifier)],
    },
    CommandShape {
        name: "list_workspaces",
        fields: &[],
    },
    CommandShape {
        name: "create_workspace",
        fields: &[("name", FieldValue::Text)],
    },
    CommandShape {
        name: "change_workspace_approval_policy",
        fields: &[
            ("workspace_id", FieldValue::Identifier),
            ("approval_policy", FieldValue::Policy),
        ],
    },
    CommandShape {
        name: "add_device_to_workspace",
        fields: &[
            ("workspace_id", FieldValue::Identifier),
            ("device_id", FieldValue::DeviceIdentifier),
        ],
    },
    CommandShape {
        name: "remove_device_from_workspace",
        fields: &[
            ("workspace_id", FieldValue::Identifier),
            ("device_id", FieldValue::DeviceIdentifier),
        ],
    },
    CommandShape {
        name: "list_audit",
        fields: &[],
    },
];

pub const FILE_SHAPES: [CommandShape; 3] = [
    CommandShape {
        name: "list_repository_branches",
        fields: &[
            ("project_id", FieldValue::Identifier),
            ("repository_address", FieldValue::Text),
            ("preferred_runner_id", FieldValue::OptionalDeviceIdentifier),
        ],
    },
    CommandShape {
        name: "list_repository_files",
        fields: &[
            ("project_id", FieldValue::Identifier),
            ("repository_address", FieldValue::Text),
            ("runner_id", FieldValue::DeviceIdentifier),
            ("branch", FieldValue::Text),
            ("folder", FieldValue::Text),
        ],
    },
    CommandShape {
        name: "read_repository_file",
        fields: &[
            ("project_id", FieldValue::Identifier),
            ("repository_address", FieldValue::Text),
            ("runner_id", FieldValue::DeviceIdentifier),
            ("branch", FieldValue::Text),
            ("path", FieldValue::Text),
        ],
    },
];

impl FieldValue {
    pub fn is_optional(self) -> bool {
        matches!(
            self,
            Self::OptionalIdentifier | Self::OptionalDeviceIdentifier
        )
    }

    pub fn build_sample(self) -> Value {
        match self {
            Self::Identifier | Self::OptionalIdentifier => {
                json!(SAMPLE_IDENTIFIER)
            }
            Self::DeviceIdentifier | Self::OptionalDeviceIdentifier => {
                json!(SAMPLE_DEVICE_IDENTIFIER)
            }
            Self::Text => json!(SAMPLE_TEXT),
            Self::Place => json!("local_process"),
            Self::Places => json!(["local_process"]),
            Self::Policy => json!("ask_before_risky_actions"),
            Self::Decision => json!("approved"),
            Self::Action => json!({ "kind": "deploy", "target": "staging" }),
        }
    }

    pub fn build_mistyped(self) -> Value {
        match self {
            Self::Identifier | Self::OptionalIdentifier => json!(SAMPLE_TEXT),
            Self::Places => json!("local_process"),
            Self::Action => json!({ "kind": SAMPLE_TEXT }),
            _ => json!(MISTYPED_NUMBER),
        }
    }
}

impl CommandShape {
    pub fn build_command(self) -> Value {
        let mut command = json!({ "command": self.name });
        for (field, value) in self.fields {
            command[*field] = value.build_sample();
        }
        command
    }

    pub fn build_command_with_absent_options(self) -> Value {
        let mut command = self.build_command();
        for (field, value) in self.fields {
            if value.is_optional() {
                command[*field] = Value::Null;
            }
        }
        command
    }

    pub fn list_required_fields(self) -> Vec<&'static str> {
        let mut required = Vec::new();
        for (field, value) in self.fields {
            if !value.is_optional() {
                required.push(*field);
            }
        }
        required
    }
}
