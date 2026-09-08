-- 코드 스니펫 4
-- 기능: 조치 상태별 건수와 비율 계산
-- 출처: 졸업작품 최종 데이터베이스 SQL 824~827행

SELECT action_status AS 조치상태, COUNT(*) AS 건수,
       ROUND(COUNT(*) / (SELECT COUNT(*) FROM action_logs) * 100, 1) AS 비율
FROM action_logs
GROUP BY action_status;
