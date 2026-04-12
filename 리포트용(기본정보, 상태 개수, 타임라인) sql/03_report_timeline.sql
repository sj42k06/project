USE safety_system_schemas;

-- 타임라인
SELECT
    ri.item_id,
    ri.event_time,
    ri.status,
    ri.description,
    f.frame_path
FROM report_items ri
JOIN frames f ON ri.frame_id = f.frame_id
WHERE ri.report_id = 1
ORDER BY ri.event_time ASC;