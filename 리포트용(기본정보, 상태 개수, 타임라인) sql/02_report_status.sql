USE safety_system_schemas;

-- 상태 개수
SELECT
    SUM(CASE WHEN status = '정상' THEN 1 ELSE 0 END) AS normal_count,
    SUM(CASE WHEN status = '주의' THEN 1 ELSE 0 END) AS caution_count,
    SUM(CASE WHEN status = '위험' THEN 1 ELSE 0 END) AS danger_count,
    COUNT(*) AS total_count
FROM report_items
WHERE report_id = 1;