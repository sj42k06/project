-- =========================================================
-- safety_system_3shift_yearly_database_natural.sql
-- 목적:
-- 1) 기존 v2 구조를 단순화한 최종형 유지
-- 2) 보고서 생성 여부, 조치 내용, 탐지 신뢰도, 바운딩박스 좌표는 제거
-- 3) 바운딩박스가 그려진 이미지는 bbox_image_path에 저장
-- 4) 위험성평가 공식 추가: 위험도 = 가능성 × 중대성 ÷ 25 × 100
-- 5) 2024년 건설업 사고유형 비율은 유지
-- 6) 더미데이터 생성 순서를 섞어 같은 유형/상태가 몰리지 않게 생성
-- =========================================================

DROP DATABASE IF EXISTS safety_system;

CREATE DATABASE safety_system
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE safety_system;

SET SQL_SAFE_UPDATES = 0;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS handover_logs;
DROP TABLE IF EXISTS reports;
DROP TABLE IF EXISTS action_logs;
DROP TABLE IF EXISTS detection_results;
DROP TABLE IF EXISTS risk_events;
DROP TABLE IF EXISTS monitoring_sessions;
DROP TABLE IF EXISTS safety_rules;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

-- =========================================================
-- 1. 관리자 계정
-- =========================================================
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    login_id VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(50) NOT NULL,
    phone VARCHAR(20),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 2. 사고 케이스 / 위험 판단 기준
-- =========================================================
CREATE TABLE safety_rules (
    rule_id INT AUTO_INCREMENT PRIMARY KEY,
    case_name VARCHAR(150) NOT NULL,
    accident_type ENUM('떨어짐', '넘어짐', '부딪힘', '물체에 맞음', '끼임') NOT NULL,
    accident_count_2024 INT NOT NULL,
    law_name VARCHAR(120),
    law_content TEXT,
    detected_objects VARCHAR(255),
    risk_condition TEXT,
    sub_risk_description TEXT,
    recommendation TEXT,
    likelihood_score TINYINT NOT NULL,
    severity_score TINYINT NOT NULL,
    risk_score INT NOT NULL,
    risk_percent DECIMAL(5,1) NOT NULL,
    risk_formula VARCHAR(100) NOT NULL DEFAULT '가능성 × 중대성 ÷ 25 × 100',
    risk_level ENUM('주의', '위험', '즉각조치') NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 3. 근무/모니터링 세션
-- =========================================================
CREATE TABLE monitoring_sessions (
    session_id INT AUTO_INCREMENT PRIMARY KEY,
    camera_id VARCHAR(50) NOT NULL,
    monitored_area VARCHAR(150) NOT NULL,
    shift_type ENUM('오전', '오후', '야간') NOT NULL,
    session_date DATE NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    manager_id INT NOT NULL,
    analyzed_frames INT DEFAULT 0,
    normal_frames INT DEFAULT 0,
    risk_event_count INT DEFAULT 0,
    session_status ENUM('정상', '위험발생') DEFAULT '정상',
    handover_status ENUM('대기', '확인완료') DEFAULT '대기',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_session_manager
        FOREIGN KEY (manager_id)
        REFERENCES users(user_id)
);

-- =========================================================
-- 4. 위험 이벤트
-- =========================================================
CREATE TABLE risk_events (
    risk_id INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT NOT NULL,
    rule_id INT NOT NULL,
    detected_time DATETIME NOT NULL,
    risk_case VARCHAR(150) NOT NULL,
    accident_type ENUM('떨어짐', '넘어짐', '부딪힘', '물체에 맞음', '끼임') NOT NULL,
    likelihood_score TINYINT NOT NULL,
    severity_score TINYINT NOT NULL,
    risk_score INT NOT NULL,
    risk_percent DECIMAL(5,1) NOT NULL,
    risk_level ENUM('주의', '위험', '즉각조치') NOT NULL,
    description TEXT,
    image_path TEXT,
    bbox_image_path TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_event_session
        FOREIGN KEY (session_id)
        REFERENCES monitoring_sessions(session_id),
    CONSTRAINT fk_event_rule
        FOREIGN KEY (rule_id)
        REFERENCES safety_rules(rule_id)
);

-- =========================================================
-- 5. YOLO 탐지 결과
-- =========================================================
CREATE TABLE detection_results (
    detection_id INT AUTO_INCREMENT PRIMARY KEY,
    risk_id INT NOT NULL,
    object_name VARCHAR(50) NOT NULL,
    detected_count INT DEFAULT 1,
    CONSTRAINT fk_detection_event
        FOREIGN KEY (risk_id)
        REFERENCES risk_events(risk_id)
);

-- =========================================================
-- 6. 조치 기록
-- =========================================================
CREATE TABLE action_logs (
    action_id INT AUTO_INCREMENT PRIMARY KEY,
    risk_id INT NOT NULL,
    action_status ENUM('조치완료', '미조치', '확인중', '오탐') NOT NULL,
    action_manager_id INT NOT NULL,
    action_time DATETIME NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_action_event
        FOREIGN KEY (risk_id)
        REFERENCES risk_events(risk_id),
    CONSTRAINT fk_action_manager
        FOREIGN KEY (action_manager_id)
        REFERENCES users(user_id)
);

-- =========================================================
-- 7. 인수인계 보고서
-- =========================================================
CREATE TABLE reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    session_id INT NOT NULL,
    report_title VARCHAR(200) NOT NULL,
    report_date DATE NOT NULL,
    created_by INT NOT NULL,
    total_analyzed_frames INT DEFAULT 0,
    total_normal_frames INT DEFAULT 0,
    total_risk_events INT DEFAULT 0,
    resolved_count INT DEFAULT 0,
    unresolved_count INT DEFAULT 0,
    major_risk_case VARCHAR(150),
    major_accident_type VARCHAR(50),
    max_risk_percent DECIMAL(5,1) DEFAULT 0.0,
    avg_risk_percent DECIMAL(5,1) DEFAULT 0.0,
    report_content TEXT,
    next_shift_note TEXT,
    approval_status ENUM('작성중', '승인대기', '승인완료') DEFAULT '승인대기',
    approved_by INT NULL,
    approved_at DATETIME NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_report_session
        FOREIGN KEY (session_id)
        REFERENCES monitoring_sessions(session_id),
    CONSTRAINT fk_report_creator
        FOREIGN KEY (created_by)
        REFERENCES users(user_id),
    CONSTRAINT fk_report_approver
        FOREIGN KEY (approved_by)
        REFERENCES users(user_id)
);

-- =========================================================
-- 8. 인수인계 확인 기록
-- =========================================================
CREATE TABLE handover_logs (
    handover_id INT AUTO_INCREMENT PRIMARY KEY,
    report_id INT NOT NULL,
    from_user_id INT NOT NULL,
    to_user_id INT NOT NULL,
    handover_date DATETIME NOT NULL,
    handover_status ENUM('대기', '확인완료') DEFAULT '대기',
    confirmed_at DATETIME NULL,
    handover_note TEXT,
    signature_check BOOLEAN DEFAULT FALSE,
    sms_sent BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_handover_report
        FOREIGN KEY (report_id)
        REFERENCES reports(report_id),
    CONSTRAINT fk_handover_from_user
        FOREIGN KEY (from_user_id)
        REFERENCES users(user_id),
    CONSTRAINT fk_handover_to_user
        FOREIGN KEY (to_user_id)
        REFERENCES users(user_id)
);

-- =========================================================
-- 9. 관리자 더미 계정
-- =========================================================
INSERT INTO users (login_id, password, name, phone)
VALUES
('admin1', '1234', '관리자 A', '010-1000-0001'),
('admin2', '1234', '관리자 B', '010-1000-0002'),
('admin3', '1234', '관리자 C', '010-1000-0003'),
('admin4', '1234', '관리자 D', '010-1000-0004');

-- =========================================================
-- 10. 사고 케이스 5종
-- =========================================================
INSERT INTO safety_rules
(case_name, accident_type, accident_count_2024, law_name, law_content, detected_objects,
 risk_condition, sub_risk_description, recommendation,
 likelihood_score, severity_score, risk_score, risk_percent, risk_level)
VALUES
(
'출입 금지 구역 또는 낙하물 위험 구역 무단 진입 감지',
'떨어짐',
6911,
'출입통제 및 고소작업 안전기준',
'출입 금지 구역 및 낙하물 위험 구역에는 허가된 인원 외 접근을 제한해야 한다.',
'person, danger_zone',
'작업자가 출입 금지 구역 또는 낙하물 위험 구역 내부에 진입한 상태',
'낙하물에 맞음, 구조물과의 부딪힘 위험도 함께 존재할 수 있음',
'위험구역 접근을 즉시 통제하고 안전 표지 및 차단 장치를 확인한다.',
3, 5, 15, 60.0, '즉각조치'
),
(
'작업 통로 및 비상 통로 자재물 적치 감지',
'넘어짐',
4654,
'작업장 통로 확보 기준',
'작업 통로와 비상 통로는 항상 이동 가능한 상태로 유지해야 한다.',
'material, box, pallet, obstacle',
'작업 통로 또는 비상 통로에 자재물이 일정 시간 이상 놓여 있는 상태',
'비상 대피 지연 및 이동 중 부딪힘 위험이 함께 발생할 수 있음',
'통로에 적치된 자재물을 제거하고 이동 경로를 확보한다.',
4, 2, 8, 32.0, '위험'
),
(
'안전모, 안전조끼, 안전화 등 안전복 미착용',
'물체에 맞음',
2780,
'산업안전보건기준 보호구 착용 기준',
'작업자는 작업 환경에 적합한 보호구를 착용해야 한다.',
'person, helmet, vest, boots',
'작업자가 안전모, 안전조끼, 안전화 중 하나 이상을 착용하지 않은 상태',
'추락 또는 협착 사고 발생 시 부상 정도가 커질 수 있음',
'작업 전 보호구 착용 여부를 확인하고 미착용 시 즉시 착용 후 작업을 진행한다.',
4, 3, 12, 48.0, '위험'
),
(
'작업자 밀집 위험 감지',
'부딪힘',
2733,
'작업장 안전관리 기준',
'작업 구역 내 과도한 인원 밀집은 충돌 및 사고 위험을 높일 수 있다.',
'person',
'특정 작업 구역 내 작업자 수가 기준 인원을 초과한 상태',
'끼임, 넘어짐, 동선 충돌 위험이 함께 증가할 수 있음',
'작업자를 분산 배치하고 작업 동선을 조정한다.',
3, 2, 6, 24.0, '주의'
),
(
'중장비 작업 반경 내 인원 접근 감지',
'끼임',
2265,
'중장비 작업 안전기준',
'중장비 작업 중에는 작업 반경 내 인원 접근을 제한해야 한다.',
'person, excavator, forklift, heavy_equipment',
'작업자가 중장비 작업 반경 내부에 접근한 상태',
'중장비와의 부딪힘 위험이 함께 발생할 수 있음',
'중장비 작업 반경 내 인원을 즉시 대피시키고 안전거리를 확보한다.',
3, 5, 15, 60.0, '즉각조치'
);

-- =========================================================
-- 11. 더미데이터 생성 프로시저
-- 핵심:
-- - 최종 사고유형별 건수는 2024년 건설업 통계의 1/10 유지
-- - temp_event_plan에서 생성 순서를 섞어 같은 사고유형이 몰리지 않게 함
-- - 조치/승인/인수인계 상태도 규칙적 블록이 생기지 않도록 분산
-- =========================================================

DELIMITER $$

DROP PROCEDURE IF EXISTS generate_three_shift_dummy_data $$

CREATE PROCEDURE generate_three_shift_dummy_data()
BEGIN
    DECLARE current_day DATE;
    DECLARE end_day DATE;
    DECLARE shift_no INT;
    DECLARE shift_name VARCHAR(20);
    DECLARE shift_start DATETIME;
    DECLARE shift_end DATETIME;
    DECLARE manager_id_value INT;
    DECLARE global_session_counter INT DEFAULT 0;
    DECLARE frame_count INT DEFAULT 960;

    DECLARE total_sessions INT DEFAULT 0;

    DECLARE done INT DEFAULT FALSE;
    DECLARE plan_rule_id INT;
    DECLARE plan_seq_no INT;
    DECLARE selected_case_name VARCHAR(150);
    DECLARE selected_accident_type VARCHAR(50);
    DECLARE selected_likelihood_score TINYINT;
    DECLARE selected_severity_score TINYINT;
    DECLARE selected_risk_score INT;
    DECLARE selected_risk_percent DECIMAL(5,1);
    DECLARE selected_risk_level VARCHAR(20);

    DECLARE target_session_id INT;
    DECLARE target_start_time DATETIME;
    DECLARE target_manager_id INT;
    DECLARE detected_dt DATETIME;
    DECLARE global_risk_counter INT DEFAULT 0;
    DECLARE new_risk_id INT;
    DECLARE status_seed INT;

    DECLARE cur_event_plan CURSOR FOR
        SELECT rule_id, seq_no
        FROM temp_event_plan
        ORDER BY sort_key, rule_id, seq_no;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    SET current_day = '2025-05-11';
    SET end_day = '2026-05-11';

    -- 1) 평일 3교대 세션 생성
    WHILE current_day <= end_day DO
        IF DAYOFWEEK(current_day) NOT IN (1, 7) THEN
            SET shift_no = 1;
            WHILE shift_no <= 3 DO
                SET global_session_counter = global_session_counter + 1;
                SET shift_name = CASE WHEN shift_no = 1 THEN '오전' WHEN shift_no = 2 THEN '오후' ELSE '야간' END;
                SET shift_start = CASE
                    WHEN shift_no = 1 THEN TIMESTAMP(current_day, '06:00:00')
                    WHEN shift_no = 2 THEN TIMESTAMP(current_day, '14:00:00')
                    ELSE TIMESTAMP(current_day, '22:00:00')
                END;
                SET shift_end = CASE
                    WHEN shift_no = 1 THEN TIMESTAMP(current_day, '14:00:00')
                    WHEN shift_no = 2 THEN TIMESTAMP(current_day, '22:00:00')
                    ELSE TIMESTAMP(DATE_ADD(current_day, INTERVAL 1 DAY), '06:00:00')
                END;
                SET manager_id_value = ((global_session_counter - 1) % 4) + 1;

                INSERT INTO monitoring_sessions
                (camera_id, monitored_area, shift_type, session_date, start_time, end_time,
                 manager_id, analyzed_frames, normal_frames, risk_event_count, session_status,
                 handover_status, created_at)
                VALUES
                ('CAM-01', '자재 적치 및 작업 통로 구역', shift_name, current_day, shift_start, shift_end,
                 manager_id_value, frame_count, frame_count, 0, '정상', '확인완료', shift_start);

                SET shift_no = shift_no + 1;
            END WHILE;
        END IF;

        SET current_day = DATE_ADD(current_day, INTERVAL 1 DAY);
    END WHILE;

    SELECT COUNT(*) INTO total_sessions FROM monitoring_sessions;

    -- 2) 사고유형별 목표 건수를 보존하면서 생성 순서를 섞기 위한 임시 계획표
    DROP TEMPORARY TABLE IF EXISTS temp_seq;
    CREATE TEMPORARY TABLE temp_seq (
        n INT PRIMARY KEY
    );

    INSERT INTO temp_seq (n)
    WITH RECURSIVE seq AS (
        SELECT 1 AS n
        UNION ALL
        SELECT n + 1 FROM seq WHERE n < 700
    )
    SELECT n FROM seq;

    DROP TEMPORARY TABLE IF EXISTS temp_event_plan;
    CREATE TEMPORARY TABLE temp_event_plan (
        plan_id INT AUTO_INCREMENT PRIMARY KEY,
        rule_id INT NOT NULL,
        seq_no INT NOT NULL,
        sort_key INT NOT NULL
    );

    INSERT INTO temp_event_plan (rule_id, seq_no, sort_key)
    SELECT 1, n, MOD(n * 97 + 1 * 389, 1000003)
    FROM temp_seq WHERE n <= 691;

    INSERT INTO temp_event_plan (rule_id, seq_no, sort_key)
    SELECT 2, n, MOD(n * 97 + 2 * 389, 1000003)
    FROM temp_seq WHERE n <= 465;

    INSERT INTO temp_event_plan (rule_id, seq_no, sort_key)
    SELECT 3, n, MOD(n * 97 + 3 * 389, 1000003)
    FROM temp_seq WHERE n <= 278;

    INSERT INTO temp_event_plan (rule_id, seq_no, sort_key)
    SELECT 4, n, MOD(n * 97 + 4 * 389, 1000003)
    FROM temp_seq WHERE n <= 273;

    INSERT INTO temp_event_plan (rule_id, seq_no, sort_key)
    SELECT 5, n, MOD(n * 97 + 5 * 389, 1000003)
    FROM temp_seq WHERE n <= 226;

    -- 3) 섞인 순서대로 위험 이벤트 생성
    OPEN cur_event_plan;

    event_loop: LOOP
        FETCH cur_event_plan INTO plan_rule_id, plan_seq_no;

        IF done THEN
            LEAVE event_loop;
        END IF;

        SET global_risk_counter = global_risk_counter + 1;

        SELECT case_name, accident_type, likelihood_score, severity_score, risk_score, risk_percent, risk_level
        INTO selected_case_name, selected_accident_type, selected_likelihood_score, selected_severity_score, selected_risk_score, selected_risk_percent, selected_risk_level
        FROM safety_rules
        WHERE rule_id = plan_rule_id;

        -- 세션 배정도 규칙적 블록을 피하기 위해 섞어서 배치
        SET target_session_id = MOD(global_risk_counter * 137 + plan_rule_id * 19, total_sessions) + 1;

        SELECT start_time, manager_id
        INTO target_start_time, target_manager_id
        FROM monitoring_sessions
        WHERE session_id = target_session_id;

        SET detected_dt = DATE_ADD(
            target_start_time,
            INTERVAL ((global_risk_counter * 37 + plan_rule_id * 11) MOD 460) MINUTE
        );

        INSERT INTO risk_events
        (session_id, rule_id, detected_time, risk_case, accident_type,
         likelihood_score, severity_score, risk_score, risk_percent, risk_level,
         description, image_path, bbox_image_path, created_at)
        VALUES
        (target_session_id, plan_rule_id, detected_dt, selected_case_name, selected_accident_type,
         selected_likelihood_score, selected_severity_score, selected_risk_score, selected_risk_percent, selected_risk_level,
         CONCAT(selected_case_name, ' 상황이 감지되었습니다. 대표 사고유형은 ', selected_accident_type,
                '이며, 위험도는 가능성 ', selected_likelihood_score, '점 × 중대성 ', selected_severity_score,
                '점 ÷ 25 × 100 = ', selected_risk_percent, '%로 산정되었습니다.'),
         CONCAT('/uploads/dummy/original/event_', LPAD(global_risk_counter, 5, '0'), '.jpg'),
         CONCAT('/uploads/dummy/bbox/event_', LPAD(global_risk_counter, 5, '0'), '_bbox.jpg'),
         detected_dt);

        SET new_risk_id = LAST_INSERT_ID();

        IF plan_rule_id = 1 THEN
            INSERT INTO detection_results (risk_id, object_name, detected_count) VALUES
            (new_risk_id, 'person', 1),
            (new_risk_id, 'danger_zone', 1);
        ELSEIF plan_rule_id = 2 THEN
            INSERT INTO detection_results (risk_id, object_name, detected_count) VALUES
            (new_risk_id, 'box', 3),
            (new_risk_id, 'pallet', 1);
        ELSEIF plan_rule_id = 3 THEN
            INSERT INTO detection_results (risk_id, object_name, detected_count) VALUES
            (new_risk_id, 'person', 1),
            (new_risk_id, 'helmet', 0),
            (new_risk_id, 'vest', 0),
            (new_risk_id, 'boots', 0);
        ELSEIF plan_rule_id = 4 THEN
            INSERT INTO detection_results (risk_id, object_name, detected_count) VALUES
            (new_risk_id, 'person', 6);
        ELSE
            INSERT INTO detection_results (risk_id, object_name, detected_count) VALUES
            (new_risk_id, 'person', 1),
            (new_risk_id, 'forklift', 1);
        END IF;

        -- 최종 비율은 조치완료 80%, 미조치 20% 유지
        -- 단, 위험 이벤트 생성 순서가 섞여 있으므로 화면에서는 한쪽 상태가 뭉쳐 보이지 않음
        INSERT INTO action_logs
        (risk_id, action_status, action_manager_id, action_time, created_at)
        VALUES
        (new_risk_id,
         CASE WHEN global_risk_counter % 5 = 0 THEN '미조치' ELSE '조치완료' END,
         target_manager_id,
         CASE WHEN global_risk_counter % 5 = 0 THEN NULL ELSE DATE_ADD(detected_dt, INTERVAL 15 MINUTE) END,
         detected_dt);

    END LOOP;

    CLOSE cur_event_plan;

    DROP TEMPORARY TABLE IF EXISTS temp_event_plan;
    DROP TEMPORARY TABLE IF EXISTS temp_seq;

    -- 4) 세션 요약값 갱신
    UPDATE monitoring_sessions ms
    LEFT JOIN (
        SELECT session_id, COUNT(*) AS cnt
        FROM risk_events
        GROUP BY session_id
    ) x ON ms.session_id = x.session_id
    SET ms.risk_event_count = COALESCE(x.cnt, 0),
        ms.normal_frames = GREATEST(ms.analyzed_frames - COALESCE(x.cnt, 0), 0),
        ms.session_status = CASE WHEN COALESCE(x.cnt, 0) = 0 THEN '정상' ELSE '위험발생' END
    WHERE ms.session_id IS NOT NULL;

    -- 5) 세션별 보고서 생성
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

    -- 6) 인수인계 로그 생성
    INSERT INTO handover_logs
    (report_id, from_user_id, to_user_id, handover_date, handover_status,
     confirmed_at, handover_note, signature_check, sms_sent, created_at)
    SELECT
        r.report_id,
        r.created_by AS from_user_id,
        CASE WHEN r.created_by = 4 THEN 1 ELSE r.created_by + 1 END AS to_user_id,
        DATE_ADD(r.created_at, INTERVAL 5 MINUTE) AS handover_date,
        CASE
            WHEN r.approval_status = '승인대기' THEN '대기'
            WHEN MOD(r.report_id * 23 + 7, 100) < 88 THEN '확인완료'
            ELSE '대기'
        END AS handover_status,
        CASE
            WHEN r.approval_status = '승인대기' THEN NULL
            WHEN MOD(r.report_id * 23 + 7, 100) < 88 THEN DATE_ADD(r.created_at, INTERVAL 20 MINUTE)
            ELSE NULL
        END AS confirmed_at,
        r.next_shift_note AS handover_note,
        CASE
            WHEN r.approval_status = '승인대기' THEN FALSE
            WHEN MOD(r.report_id * 23 + 7, 100) < 88 THEN TRUE
            ELSE FALSE
        END AS signature_check,
        CASE
            WHEN r.approval_status = '승인대기' THEN FALSE
            WHEN MOD(r.report_id * 23 + 7, 100) < 88 THEN TRUE
            ELSE FALSE
        END AS sms_sent,
        ms.end_time AS created_at
    FROM reports r
    JOIN monitoring_sessions ms ON r.session_id = ms.session_id;

    UPDATE monitoring_sessions ms
    JOIN reports r ON ms.session_id = r.session_id
    JOIN handover_logs hl ON r.report_id = hl.report_id
    SET ms.handover_status = hl.handover_status
    WHERE ms.session_id IS NOT NULL;

END $$

DELIMITER ;

CALL generate_three_shift_dummy_data();

DROP PROCEDURE IF EXISTS generate_three_shift_dummy_data;

-- =========================================================
-- 12. 확인용 조회
-- =========================================================

SELECT 'users' AS table_name, COUNT(*) AS count_value FROM users
UNION ALL SELECT 'safety_rules', COUNT(*) FROM safety_rules
UNION ALL SELECT 'monitoring_sessions', COUNT(*) FROM monitoring_sessions
UNION ALL SELECT 'risk_events', COUNT(*) FROM risk_events
UNION ALL SELECT 'detection_results', COUNT(*) FROM detection_results
UNION ALL SELECT 'action_logs', COUNT(*) FROM action_logs
UNION ALL SELECT 'reports', COUNT(*) FROM reports
UNION ALL SELECT 'handover_logs', COUNT(*) FROM handover_logs;

SELECT report_date, COUNT(*) AS report_count
FROM reports
GROUP BY report_date
ORDER BY report_date DESC
LIMIT 10;

SELECT shift_type, COUNT(*) AS session_count, SUM(risk_event_count) AS risk_event_total
FROM monitoring_sessions
GROUP BY shift_type
ORDER BY FIELD(shift_type, '오전', '오후', '야간');

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

SELECT
    re.risk_case AS 사고_케이스,
    re.accident_type AS 대표_사고유형,
    re.likelihood_score AS 가능성,
    re.severity_score AS 중대성,
    re.risk_score AS 위험점수,
    re.risk_percent AS 위험도,
    re.risk_level AS 위험등급,
    COUNT(*) AS 더미_발생건수
FROM risk_events re
GROUP BY re.risk_case, re.accident_type, re.likelihood_score, re.severity_score, re.risk_score, re.risk_percent, re.risk_level
ORDER BY 더미_발생건수 DESC;

SELECT action_status AS 조치상태, COUNT(*) AS 건수,
       ROUND(COUNT(*) / (SELECT COUNT(*) FROM action_logs) * 100, 1) AS 비율
FROM action_logs
GROUP BY action_status;

SELECT approval_status AS 승인상태, COUNT(*) AS 건수
FROM reports
GROUP BY approval_status;

SELECT handover_status AS 인수인계상태, COUNT(*) AS 건수
FROM handover_logs
GROUP BY handover_status;

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

SELECT
    re.risk_id, ms.shift_type, ms.session_date, re.detected_time, re.risk_case,
    re.accident_type, re.likelihood_score, re.severity_score, re.risk_score, re.risk_percent,
    re.risk_level, al.action_status, re.bbox_image_path
FROM risk_events re
JOIN monitoring_sessions ms ON re.session_id = ms.session_id
JOIN action_logs al ON re.risk_id = al.risk_id
WHERE al.action_status IN ('미조치', '확인중')
ORDER BY re.detected_time DESC
LIMIT 20;


-- 위험성평가 기준 확인
SELECT
    case_name AS 사고_케이스,
    likelihood_score AS 가능성,
    severity_score AS 중대성,
    risk_score AS 위험점수,
    risk_percent AS 위험도,
    risk_formula AS 산정공식,
    risk_level AS 위험등급
FROM safety_rules
ORDER BY rule_id;

SET SQL_SAFE_UPDATES = 1;
