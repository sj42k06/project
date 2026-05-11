USE safety_system;

-- =========================================
-- 1. NORMAL / RISK 비율 통계
-- =========================================

SELECT 
    detection_status AS 상태,
    COUNT(*) AS 개수
FROM risk_logs
GROUP BY detection_status;

-- =========================================
-- 2. 사고 유형별 발생 통계
-- =========================================

SELECT
    sr.case_name AS 사고유형,
    COUNT(*) AS 발생횟수
FROM risk_logs rl
JOIN safety_rules sr
ON rl.rule_id = sr.rule_id
WHERE rl.detection_status = 'RISK'
GROUP BY sr.case_name
ORDER BY 발생횟수 DESC;

-- =========================================
-- 3. 조치 상태 통계
-- =========================================

SELECT
    action_status AS 조치상태,
    COUNT(*) AS 개수
FROM risk_logs
WHERE detection_status = 'RISK'
GROUP BY action_status;

-- =========================================
-- 4. 관리자별 분석 기록 통계
-- =========================================

SELECT
    u.name AS 관리자,
    COUNT(*) AS 분석기록수
FROM risk_logs rl
JOIN users u
ON rl.detected_by = u.user_id
GROUP BY u.name
ORDER BY 분석기록수 DESC;

-- =========================================
-- 5. 날짜별 위험 감지 통계
-- =========================================

SELECT
    DATE(detected_at) AS 날짜,
    COUNT(*) AS 위험건수
FROM risk_logs
WHERE detection_status = 'RISK'
GROUP BY DATE(detected_at)
ORDER BY 날짜;

-- =========================================
-- 6. 월별 위험 감지 통계
-- =========================================

SELECT
    DATE_FORMAT(detected_at, '%Y-%m') AS 월,
    COUNT(*) AS 위험건수
FROM risk_logs
WHERE detection_status = 'RISK'
GROUP BY DATE_FORMAT(detected_at, '%Y-%m')
ORDER BY 월;

-- =========================================
-- 7. 인수인계 상태 통계
-- =========================================

SELECT
    handover_status AS 인수인계상태,
    COUNT(*) AS 개수
FROM handover_logs
GROUP BY handover_status;

-- =========================================
-- 8. 최근 미조치 위험 기록 조회
-- =========================================

SELECT
    rl.risk_id,
    sr.case_name,
    u.name AS 관리자,
    rl.action_note,
    rl.detected_at
FROM risk_logs rl
JOIN safety_rules sr
ON rl.rule_id = sr.rule_id
JOIN users u
ON rl.detected_by = u.user_id
WHERE rl.action_status = '미조치'
ORDER BY rl.detected_at DESC
LIMIT 20;

-- =========================================
-- 9. 최근 인수인계 대기 목록
-- =========================================

SELECT
    hl.handover_id,
    r.report_title,
    u1.name AS 인계자,
    u2.name AS 인수자,
    hl.handover_status,
    hl.handover_date
FROM handover_logs hl
JOIN reports r
ON hl.report_id = r.report_id
JOIN users u1
ON hl.from_user_id = u1.user_id
JOIN users u2
ON hl.to_user_id = u2.user_id
WHERE hl.handover_status = '대기'
ORDER BY hl.handover_date DESC;

-- =========================================
-- 10. 날짜 범위 검색 예시
-- =========================================

SELECT
    sr.case_name,
    COUNT(*) AS 발생횟수
FROM risk_logs rl
JOIN safety_rules sr
ON rl.rule_id = sr.rule_id
WHERE rl.detection_status = 'RISK'
AND rl.detected_at BETWEEN '2025-10-01' AND '2025-10-31'
GROUP BY sr.case_name;