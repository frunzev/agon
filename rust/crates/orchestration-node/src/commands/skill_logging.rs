use orchestration_core::identifiers::SkillId;

pub(super) fn log_left_out_skill(skill_id: SkillId) {
    eprintln!(
        "skill {} is left out of the list: its sealed text cannot be \
         opened with any workspace key",
        skill_id.0
    );
}
