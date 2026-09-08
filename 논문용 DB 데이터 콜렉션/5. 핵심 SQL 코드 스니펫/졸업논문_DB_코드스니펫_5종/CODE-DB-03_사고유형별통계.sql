-- 코드 스니펫 3
-- 기능: 2024년 사고 통계와 테스트용 데이터의 사고 유형별 비율 비교
-- 출처: 졸업작품 최종 데이터베이스 SQL 800~809행

SELECT
    re.accident_type AS 사고유형,
    sr.accident_count_2024 AS 원본_2024_건수,
    COUNT(*) AS 더미_발생건수,
    ROUND(sr.accident_count_2024 / (SELECT SUM(accident_count_2024) FROM safety_rules) * 100, 1) AS 원본_비율,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM risk_events) * 100, 1) AS 더미_비율
FROM risk_events re
JOIN safety_rules sr ON re.rule_id = sr.rule_id
GROUP BY re.accident_type, sr.accident_count_2024
ORDER BY 더미_발생건수 DESC;
