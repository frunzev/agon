use crate::dart_command_shapes::DartField::{
    AgentKind, Availability, DeviceIdentifier, EmptyList, Identifier,
    Schedule, TaskArguments, TaskStart, Text, Workflow,
};
use crate::dart_command_shapes::DartShape;

pub const RUN_SHAPES: [DartShape; 7] = [
    DartShape {
        name: "list_runs",
        fields: &[("task_id", Identifier)],
    },
    DartShape {
        name: "show_run",
        fields: &[("run_id", Identifier)],
    },
    DartShape {
        name: "cancel_run",
        fields: &[("run_id", Identifier)],
    },
    DartShape {
        name: "retry_run",
        fields: &[("run_id", Identifier)],
    },
    DartShape {
        name: "send_chat_message",
        fields: &[
            ("workspace_id", Identifier),
            ("run_id", Identifier),
            ("text", Text),
        ],
    },
    DartShape {
        name: "list_person_steps",
        fields: &[],
    },
    DartShape {
        name: "answer_person_step",
        fields: &[
            ("run_id", Identifier),
            ("step_name", Text),
            ("answer", Text),
        ],
    },
];

pub const RUNNER_SHAPES: [DartShape; 3] = [
    DartShape {
        name: "list_runners",
        fields: &[("workspace_id", Identifier)],
    },
    DartShape {
        name: "pause_runner",
        fields: &[("device_id", DeviceIdentifier)],
    },
    DartShape {
        name: "resume_runner",
        fields: &[("device_id", DeviceIdentifier)],
    },
];

pub const SERVER_BACKUP_SHAPES: [DartShape; 2] = [
    DartShape {
        name: "start_server_backup",
        fields: &[],
    },
    DartShape {
        name: "stop_server_backup",
        fields: &[],
    },
];

pub const TASK_SHAPES: [DartShape; 7] = [
    DartShape {
        name: "list_tasks",
        fields: &[("workspace_id", Identifier)],
    },
    DartShape {
        name: "create_task",
        fields: &[("task", TaskArguments), ("start", TaskStart)],
    },
    DartShape {
        name: "update_task",
        fields: &[("task_id", Identifier), ("task", TaskArguments)],
    },
    DartShape {
        name: "list_jobs",
        fields: &[("workspace_id", Identifier)],
    },
    DartShape {
        name: "create_job",
        fields: &[("task", TaskArguments), ("schedule", Schedule)],
    },
    DartShape {
        name: "update_job",
        fields: &[
            ("task_id", Identifier),
            ("task", TaskArguments),
            ("schedule", Schedule),
        ],
    },
    DartShape {
        name: "start_task",
        fields: &[("task_id", Identifier)],
    },
];

pub const WORKFLOW_SHAPES: [DartShape; 5] = [
    DartShape {
        name: "list_workflows",
        fields: &[("workspace_id", Identifier)],
    },
    DartShape {
        name: "create_workflow",
        fields: &[
            ("workspace_id", Identifier),
            ("name", Text),
            ("availability", Availability),
            ("agents", EmptyList),
            ("connections", EmptyList),
        ],
    },
    DartShape {
        name: "save_workflow",
        fields: &[("workspace_id", Identifier), ("workflow", Workflow)],
    },
    DartShape {
        name: "sign_workflow",
        fields: &[("workflow_id", Identifier)],
    },
    DartShape {
        name: "discard_workflow_change",
        fields: &[("workflow_id", Identifier)],
    },
];

pub const WORKFLOW_AGENT_SHAPES: [DartShape; 3] = [
    DartShape {
        name: "draft_workflow",
        fields: &[("workspace_id", Identifier), ("description", Text)],
    },
    DartShape {
        name: "change_workflow",
        fields: &[
            ("workspace_id", Identifier),
            ("workflow_id", Identifier),
            ("request", Text),
            ("agent", AgentKind),
        ],
    },
    DartShape {
        name: "fill_agent_settings",
        fields: &[
            ("workspace_id", Identifier),
            ("workflow_id", Identifier),
            ("agent_id", Identifier),
        ],
    },
];

pub const WORKFLOW_DRAFT_SHAPES: [DartShape; 1] = [DartShape {
    name: "workflow_draft_status",
    fields: &[
        ("workspace_id", Identifier),
        ("task_id", Identifier),
        ("workflow_id", Identifier),
    ],
}];
