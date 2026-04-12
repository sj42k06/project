USE safety_system_schemas;

-- 기본 정보
SELECT
    r.report_id,
    v.video_path,
    r.summary,
    r.created_at,
    MIN(ri.event_time) AS start_time,
    MAX(ri.event_time) AS end_time,
    COUNT(ri.item_id) AS total_items
FROM reports r
JOIN videos v ON r.video_id = v.video_id
LEFT JOIN report_items ri ON r.report_id = ri.report_id
WHERE r.report_id = 1
GROUP BY
    r.report_id,
    v.video_path,
    r.summary,
    r.created_at;