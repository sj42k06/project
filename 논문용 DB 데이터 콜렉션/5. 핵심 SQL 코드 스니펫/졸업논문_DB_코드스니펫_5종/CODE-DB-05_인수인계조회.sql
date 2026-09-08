-- 코드 스니펫 5
-- 기능: 보고서, 모니터링 세션 및 인수인계 상태 통합 조회
-- 출처: 졸업작품 최종 데이터베이스 SQL 837~847행

SELECT
    r.report_id, r.report_title, ms.shift_type, ms.start_time, ms.end_time,
    r.total_risk_events, r.resolved_count, r.unresolved_count,
    r.major_risk_case, r.major_accident_type, r.max_risk_percent, r.avg_risk_percent,
    r.approval_status, hl.handover_status,
    hl.signature_check, hl.sms_sent
FROM reports r
JOIN monitoring_sessions ms ON r.session_id = ms.session_id
JOIN handover_logs hl ON r.report_id = hl.report_id
ORDER BY r.created_at DESC
LIMIT 20;
