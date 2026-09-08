-- 코드 스니펫 2
-- 기능: 모니터링 세션별 위험 이벤트와 조치 결과를 집계하여 보고서 생성
-- 출처: 졸업작품 최종 데이터베이스 SQL 664~726행
-- 주의: 원본 저장 프로시저 내부에서 발췌한 논문 설명용 구문이며 단독 실행용 파일이 아님

-- 7) 세션별 보고서 생성
INSERT INTO reports
(session_id, report_title, report_date, created_by, total_analyzed_frames, total_normal_frames,
 total_risk_events, resolved_count, unresolved_count, major_risk_case, major_accident_type,
 max_risk_percent, avg_risk_percent,
 report_content, next_shift_note, approval_status, approved_by, approved_at, created_at)
SELECT
    ms.session_id,
    CONCAT(DATE_FORMAT(ms.session_date, '%Y-%m-%d'), ' ', ms.shift_type, ' 안전 인수인계 보고서') AS report_title,
    ms.session_date AS report_date,
    ms.manager_id AS created_by,
    ms.analyzed_frames AS total_analyzed_frames,
    ms.normal_frames AS total_normal_frames,
    ms.risk_event_count AS total_risk_events,
    COALESCE(SUM(CASE WHEN al.action_status = '조치완료' THEN 1 ELSE 0 END), 0) AS resolved_count,
    COALESCE(SUM(CASE WHEN al.action_status IN ('미조치', '확인중') THEN 1 ELSE 0 END), 0) AS unresolved_count,
    COALESCE((
        SELECT re2.risk_case
        FROM risk_events re2
        WHERE re2.session_id = ms.session_id
        GROUP BY re2.risk_case
        ORDER BY COUNT(*) DESC, MOD(MIN(re2.risk_id) * 31, 997)
        LIMIT 1
    ), '해당없음') AS major_risk_case,
    COALESCE((
        SELECT re2.accident_type
        FROM risk_events re2
        WHERE re2.session_id = ms.session_id
        GROUP BY re2.accident_type
        ORDER BY COUNT(*) DESC, MOD(MIN(re2.risk_id) * 31, 997)
        LIMIT 1
    ), '해당없음') AS major_accident_type,
    COALESCE(MAX(re.risk_percent), 0.0) AS max_risk_percent,
    COALESCE(ROUND(AVG(re.risk_percent), 1), 0.0) AS avg_risk_percent,
    CONCAT(
        DATE_FORMAT(ms.session_date, '%Y-%m-%d'), ' ', ms.shift_type, ' 근무조 안전 인수인계 보고서입니다. ',
        '단일 카메라 CAM-01이 자재 적치 및 작업 통로 구역을 ',
        DATE_FORMAT(ms.start_time, '%H:%i'), '~', DATE_FORMAT(ms.end_time, '%H:%i'),
        ' 동안 모니터링했습니다. 총 분석 프레임 ', ms.analyzed_frames,
        '건 중 위험 이벤트 ', ms.risk_event_count,
        '건이 기록되었고, 정상 구간은 세션 요약값으로 저장되었습니다. ',
        '해당 세션의 최고 위험도는 ', COALESCE(MAX(re.risk_percent), 0.0),
        '%, 평균 위험도는 ', COALESCE(ROUND(AVG(re.risk_percent), 1), 0.0),
        '%입니다. 위험도는 가능성 × 중대성 ÷ 25 × 100 공식으로 산정했습니다. ',
        '위험 이벤트 총량과 사고유형별 분포는 2024년 건설업 산업재해 발생형태 통계를 1/10 축소하여 생성했습니다.'
    ) AS report_content,
    CASE
        WHEN COALESCE(SUM(CASE WHEN al.action_status IN ('미조치', '확인중') THEN 1 ELSE 0 END), 0) > 0
            THEN '미조치 또는 확인중 위험 이벤트가 있어 다음 근무조의 우선 확인이 필요합니다.'
        WHEN ms.risk_event_count = 0
            THEN '위험 이벤트가 감지되지 않았으며 정상 상태로 인수인계합니다.'
        ELSE '기록된 위험 이벤트는 조치 완료되었으며 동일 구역 반복 감지를 확인 바랍니다.'
    END AS next_shift_note,
    CASE WHEN MOD(ms.session_id * 17 + 9, 100) < 82 THEN '승인완료' ELSE '승인대기' END AS approval_status,
    CASE WHEN MOD(ms.session_id * 17 + 9, 100) < 82 THEN ((ms.manager_id % 4) + 1) ELSE NULL END AS approved_by,
    CASE WHEN MOD(ms.session_id * 17 + 9, 100) < 82 THEN DATE_SUB(ms.end_time, INTERVAL 5 MINUTE) ELSE NULL END AS approved_at,
    DATE_SUB(ms.end_time, INTERVAL 10 MINUTE) AS created_at
FROM monitoring_sessions ms
LEFT JOIN risk_events re
    ON ms.session_id = re.session_id
LEFT JOIN action_logs al
    ON re.risk_id = al.risk_id
GROUP BY ms.session_id;
