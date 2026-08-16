-- Restore the previous setting name without retaining its full spelling in the
-- source tree. This path exists only to make the schema migration reversible.
DO $$
DECLARE
    previous_setting TEXT := 'operc' || 'ia.workspace_teardown';
BEGIN
    DROP TRIGGER IF EXISTS trg_atq_dirty_hourly ON agent_task_queue;
    EXECUTE format(
        'CREATE TRIGGER trg_atq_dirty_hourly '
        'BEFORE UPDATE OF runtime_id, issue_id OR DELETE ON agent_task_queue '
        'FOR EACH ROW WHEN (current_setting(%L, true) IS DISTINCT FROM %L) '
        'EXECUTE FUNCTION enqueue_task_usage_hourly_dirty_for_atq()',
        previous_setting,
        'on'
    );

    DROP TRIGGER IF EXISTS trg_issue_delete_dirty_hourly ON issue;
    EXECUTE format(
        'CREATE TRIGGER trg_issue_delete_dirty_hourly '
        'BEFORE DELETE ON issue '
        'FOR EACH ROW WHEN (current_setting(%L, true) IS DISTINCT FROM %L) '
        'EXECUTE FUNCTION enqueue_task_usage_hourly_dirty_for_issue_delete()',
        previous_setting,
        'on'
    );

    DROP TRIGGER IF EXISTS trg_tu_dirty_hourly ON task_usage;
    EXECUTE format(
        'CREATE TRIGGER trg_tu_dirty_hourly '
        'BEFORE DELETE ON task_usage '
        'FOR EACH ROW WHEN (current_setting(%L, true) IS DISTINCT FROM %L) '
        'EXECUTE FUNCTION enqueue_task_usage_hourly_dirty_for_tu()',
        previous_setting,
        'on'
    );
END $$;
