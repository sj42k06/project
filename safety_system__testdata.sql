SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS safety_system
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_general_ci;

USE safety_system;

DROP VIEW IF EXISTS zone_risk_stats;

DROP TABLE IF EXISTS report_risks;
DROP TABLE IF EXISTS handover_reports;
DROP TABLE IF EXISTS risk_analysis;
DROP TABLE IF EXISTS risks;
DROP TABLE IF EXISTS scenario_results;
DROP TABLE IF EXISTS scenarios;
DROP TABLE IF EXISTS upload_files;
DROP TABLE IF EXISTS upload_batches;
DROP TABLE IF EXISTS zones;
DROP TABLE IF EXISTS users;

-- =========================================================
-- 1. 사용자 테이블
-- =========================================================
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE COMMENT '로그인 아이디',
    password VARCHAR(255) NOT NULL COMMENT '비밀번호',
    name VARCHAR(50) NOT NULL COMMENT '사용자 이름',
    role VARCHAR(20) NOT NULL DEFAULT 'worker' COMMENT 'worker | manager | admin',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT='시스템 사용자';

-- =========================================================
-- 2. 작업 구역 테이블
-- =========================================================
CREATE TABLE zones (
    zone_id INT AUTO_INCREMENT PRIMARY KEY,
    zone_name VARCHAR(100) NOT NULL UNIQUE COMMENT '구역 이름',
    qr_code_value VARCHAR(255) UNIQUE COMMENT 'QR 식별값',
    description VARCHAR(255) COMMENT '구역 설명',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT='작업 구역';

-- =========================================================
-- 3. 업로드 배치 테이블
-- 한 번의 업로드 작업(사진 여러 장 + 영상 포함 가능)
-- =========================================================
CREATE TABLE upload_batches (
    batch_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL COMMENT '업로드한 사용자',
    zone_id INT NULL COMMENT '기준 구역',
    batch_title VARCHAR(255) COMMENT '업로드 제목/세션명',
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('uploaded','analyzing','done','failed') NOT NULL DEFAULT 'uploaded',

    CONSTRAINT fk_batches_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT fk_batches_zone
        FOREIGN KEY (zone_id) REFERENCES zones(zone_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) COMMENT='업로드 작업 묶음';

-- =========================================================
-- 4. 업로드 파일 테이블
-- 사진, 영상, 필요하면 프레임까지 관리
-- =========================================================
CREATE TABLE upload_files (
    file_id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    original_name VARCHAR(255) NOT NULL COMMENT '원본 파일명',
    saved_name VARCHAR(255) NOT NULL COMMENT '서버 저장 파일명',
    file_path VARCHAR(255) NOT NULL COMMENT '파일 경로',
    file_type ENUM('image','video','frame') NOT NULL COMMENT '파일 유형',
    frame_count INT DEFAULT 0 COMMENT '영상일 경우 추출 프레임 수',
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_files_batch
        FOREIGN KEY (batch_id) REFERENCES upload_batches(batch_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT='업로드된 실제 파일 목록';

-- =========================================================
-- 5. 시나리오 정의 테이블
-- 분석 가능한 시나리오 목록
-- =========================================================
CREATE TABLE scenarios (
    scenario_id INT AUTO_INCREMENT PRIMARY KEY,
    scenario_code VARCHAR(100) NOT NULL UNIQUE COMMENT '내부 코드값',
    scenario_name VARCHAR(255) NOT NULL COMMENT '시나리오 이름',
    description TEXT COMMENT '시나리오 설명',
    is_active BOOLEAN DEFAULT TRUE COMMENT '활성 여부',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT='분석 가능한 시나리오 정의';

-- =========================================================
-- 6. 시나리오 분석 결과 테이블
-- 파일/배치별 시나리오 판정 결과
-- =========================================================
CREATE TABLE scenario_results (
    scenario_result_id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    file_id INT NULL,
    scenario_id INT NOT NULL,
    detected BOOLEAN NOT NULL DEFAULT FALSE COMMENT '감지 여부',
    risk_score INT NOT NULL DEFAULT 0 COMMENT '시나리오 점수',
    risk_level ENUM('LOW','MEDIUM','HIGH','CRITICAL') DEFAULT 'LOW',
    details TEXT COMMENT '세부 설명',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_scenario_batch
        FOREIGN KEY (batch_id) REFERENCES upload_batches(batch_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_scenario_file
        FOREIGN KEY (file_id) REFERENCES upload_files(file_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_scenario_def
        FOREIGN KEY (scenario_id) REFERENCES scenarios(scenario_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT='시나리오별 AI 분석 결과';

-- =========================================================
-- 7. 최종 위험 기록 테이블
-- 실제 위험으로 채택된 결과 저장
-- =========================================================
CREATE TABLE risks (
    risk_id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NULL,
    file_id INT NULL,
    zone_id INT NULL COMMENT '발생 구역',
    user_id INT NULL COMMENT '등록자',
    title VARCHAR(100) NOT NULL COMMENT '위험 제목',
    description TEXT COMMENT '위험 상세 설명',
    image_path VARCHAR(255) COMMENT '대표 이미지 경로',
    risk_level TINYINT NOT NULL COMMENT '1~5',
    status ENUM('미조치','조치중','완료') NOT NULL DEFAULT '미조치',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT chk_risk_level CHECK (risk_level BETWEEN 1 AND 5),

    CONSTRAINT fk_risks_batch
        FOREIGN KEY (batch_id) REFERENCES upload_batches(batch_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_risks_file
        FOREIGN KEY (file_id) REFERENCES upload_files(file_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_risks_zone
        FOREIGN KEY (zone_id) REFERENCES zones(zone_id)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT fk_risks_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) COMMENT='최종 위험 기록';

-- =========================================================
-- 8. AI 상세 분석 테이블
-- 위험 기록 1건당 분석 상세 1건
-- =========================================================
CREATE TABLE risk_analysis (
    analysis_id INT AUTO_INCREMENT PRIMARY KEY,
    risk_id INT NOT NULL UNIQUE COMMENT '위험 기록 1:1 연결',
    detected_objects TEXT COMMENT '감지 객체 목록',
    risk_type VARCHAR(100) NOT NULL COMMENT '위험 유형',
    law_result TEXT COMMENT '관련 법규/기준',
    action_guide TEXT COMMENT '조치 가이드',
    analysis_summary TEXT COMMENT '분석 요약',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_analysis_risk
        FOREIGN KEY (risk_id) REFERENCES risks(risk_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT='AI 상세 분석 결과';

-- =========================================================
-- 9. 인수인계 보고서 테이블
-- =========================================================
CREATE TABLE handover_reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NULL COMMENT '어느 업로드/분석 묶음 기준인지',
    zone_id INT NOT NULL COMMENT '해당 구역',
    report_date DATE NOT NULL COMMENT '보고 날짜',
    shift_type ENUM('주간','야간') NOT NULL COMMENT '교대 구분',
    summary_text TEXT NOT NULL COMMENT '보고서 본문',
    generated_by ENUM('manual','ai') NOT NULL DEFAULT 'ai' COMMENT '작성 주체',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_reports_batch
        FOREIGN KEY (batch_id) REFERENCES upload_batches(batch_id)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT fk_reports_zone
        FOREIGN KEY (zone_id) REFERENCES zones(zone_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT='인수인계 보고서';

-- =========================================================
-- 10. 보고서-위험 연결 테이블
-- =========================================================
CREATE TABLE report_risks (
    report_risk_id INT AUTO_INCREMENT PRIMARY KEY,
    report_id INT NOT NULL,
    risk_id INT NOT NULL,

    CONSTRAINT uq_report_risk UNIQUE (report_id, risk_id),

    CONSTRAINT fk_rr_report
        FOREIGN KEY (report_id) REFERENCES handover_reports(report_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_rr_risk
        FOREIGN KEY (risk_id) REFERENCES risks(risk_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT='보고서와 위험 기록 연결';

-- =========================================================
-- 뷰
-- =========================================================
CREATE VIEW zone_risk_stats AS
SELECT
    z.zone_id,
    z.zone_name,
    COUNT(r.risk_id) AS total_risk_count,
    SUM(CASE WHEN r.status = '미조치' THEN 1 ELSE 0 END) AS unresolved_count,
    SUM(CASE WHEN r.status = '조치중' THEN 1 ELSE 0 END) AS in_progress_count,
    SUM(CASE WHEN r.status = '완료' THEN 1 ELSE 0 END) AS resolved_count,
    SUM(CASE WHEN r.risk_level >= 4 THEN 1 ELSE 0 END) AS high_risk_count,
    ROUND(AVG(r.risk_level), 2) AS avg_risk_level
FROM zones z
LEFT JOIN risks r ON z.zone_id = r.zone_id
GROUP BY z.zone_id, z.zone_name;

-- =========================================================
-- 인덱스
-- =========================================================
CREATE INDEX idx_batches_user_id ON upload_batches(user_id);
CREATE INDEX idx_batches_zone_id ON upload_batches(zone_id);
CREATE INDEX idx_batches_uploaded_at ON upload_batches(uploaded_at);

CREATE INDEX idx_files_batch_id ON upload_files(batch_id);
CREATE INDEX idx_files_type ON upload_files(file_type);

CREATE INDEX idx_scenario_results_batch_id ON scenario_results(batch_id);
CREATE INDEX idx_scenario_results_file_id ON scenario_results(file_id);
CREATE INDEX idx_scenario_results_scenario_id ON scenario_results(scenario_id);
CREATE INDEX idx_scenario_results_detected ON scenario_results(detected);

CREATE INDEX idx_risks_batch_id ON risks(batch_id);
CREATE INDEX idx_risks_file_id ON risks(file_id);
CREATE INDEX idx_risks_zone_id ON risks(zone_id);
CREATE INDEX idx_risks_user_id ON risks(user_id);
CREATE INDEX idx_risks_status ON risks(status);
CREATE INDEX idx_risks_level ON risks(risk_level);
CREATE INDEX idx_risks_created_at ON risks(created_at);

CREATE INDEX idx_handover_zone_date ON handover_reports(zone_id, report_date);

-- =========================================================
-- 샘플 데이터
-- =========================================================

-- 사용자
INSERT INTO users (username, password, name, role) VALUES
('admin', '1234', '관리자', 'admin'),
('manager01', '1234', '박반장', 'manager'),
('worker01', '1234', '김작업', 'worker'),
('worker02', '1234', '이근무', 'worker');

-- 구역
INSERT INTO zones (zone_name, qr_code_value, description) VALUES
('A구역', 'zone_a_qr', '고소 작업 구역'),
('B구역', 'zone_b_qr', '출입 통제 구역'),
('C구역', 'zone_c_qr', '자재 적치 구역');

-- 시나리오 정의
INSERT INTO scenarios (scenario_code, scenario_name, description) VALUES
('zone_intrusion', '위험 구역 진입 감지', '위험 구역에 작업자가 진입했는지 판단'),
('no_safety_hook', '안전고리 미체결 감지', '고소 작업 중 보호 장치 미체결 여부 판단'),
('falling_object', '낙하 위험 감지', '위쪽 물체와 아래 작업자 관계를 기반으로 낙하 위험 판단'),
('helmet_missing', '안전모 미착용 감지', '작업자의 안전모 미착용 여부 판단'),
('vest_missing', '안전조끼 미착용 감지', '작업자의 안전조끼 미착용 여부 판단'),
('equipment_collision', '중장비 접근 위험 감지', '중장비와 작업자 간 충돌 위험 판단'),
('passage_obstacle', '통로 장애물 적치 감지', '통로 내 장애물 적치 여부 판단');

-- 업로드 배치
INSERT INTO upload_batches (user_id, zone_id, batch_title, status) VALUES
(1, 1, '추락사고 시나리오 테스트 1', 'done');

-- 업로드 파일
INSERT INTO upload_files (batch_id, original_name, saved_name, file_path, file_type, frame_count) VALUES
(1, 'fall_test_1.jpg', '1712200001-fall_test_1.jpg', 'uploads/1712200001-fall_test_1.jpg', 'image', 0),
(1, 'fall_test_2.jpg', '1712200002-fall_test_2.jpg', 'uploads/1712200002-fall_test_2.jpg', 'image', 0),
(1, 'fall_test_video.mp4', '1712200003-fall_test_video.mp4', 'uploads/1712200003-fall_test_video.mp4', 'video', 12);

-- 시나리오 결과
INSERT INTO scenario_results (batch_id, file_id, scenario_id, detected, risk_score, risk_level, details) VALUES
(1, 1, 1, TRUE, 60, 'HIGH', '위험 구역 내부에서 작업자 감지'),
(1, 1, 2, TRUE, 70, 'HIGH', '고소 작업 영역에서 안전고리 미체결 추정'),
(1, 2, 3, TRUE, 80, 'CRITICAL', '상부 적치물 아래 작업자 존재'),
(1, 3, 1, FALSE, 0, 'LOW', '위험 구역 진입 없음');

-- 최종 위험 기록
INSERT INTO risks (batch_id, file_id, zone_id, user_id, title, description, image_path, risk_level, status) VALUES
(1, 1, 1, 1, '추락 위험 감지', '고소 작업 구역에서 안전고리 미체결 및 위험 구역 접근이 감지됨', 'uploads/1712200001-fall_test_1.jpg', 4, '미조치'),
(1, 2, 3, 1, '낙하 위험 감지', '상부 자재와 하부 작업자 위치 관계상 낙하 위험이 높음', 'uploads/1712200002-fall_test_2.jpg', 5, '미조치');

-- AI 상세 분석
INSERT INTO risk_analysis (risk_id, detected_objects, risk_type, law_result, action_guide, analysis_summary) VALUES
(1, 'person, high_place, unsafe_hook, restricted_zone',
 '추락사고 위험',
 '고소 작업 시 추락 방지 조치 필요',
 '안전고리 체결 여부 재확인 및 위험 구역 통제 강화 필요',
 '고소 작업 위치에서 작업자가 감지되었으며, 보호 장치 미체결 가능성과 위험 구역 접근이 함께 확인됨'),
(2, 'person, upper_object, loading_area',
 '낙하물 사고 위험',
 '상부 적재물 관리 및 낙하 방지 조치 필요',
 '상부 자재 고정 상태 점검 및 하부 접근 통제 필요',
 '상부 적재물 아래에 작업자가 위치해 있어 낙하물 사고 가능성이 높음');

-- 인수인계 보고서
INSERT INTO handover_reports (batch_id, zone_id, report_date, shift_type, summary_text, generated_by) VALUES
(1, 1, '2026-04-02', '주간',
 'A구역 고소 작업 구간에서 추락 위험이 감지되었으며, 안전고리 미체결 가능성이 확인됨. 즉시 작업 중지 후 보호 장비 재점검 필요. 또한 C구역 자재 적치 구간에서 낙하 위험이 감지되어 하부 접근 통제 조치가 필요함.',
 'ai');

-- 보고서와 위험 연결
INSERT INTO report_risks (report_id, risk_id) VALUES
(1, 1),
(1, 2);

SET FOREIGN_KEY_CHECKS = 1;
-- =========================================================
-- 확인용 쿼리
-- =========================================================
SELECT '=== 테이블 목록 ===' AS info;
SHOW TABLES;

SELECT '=== 시나리오 목록 ===' AS info;
SELECT * FROM scenarios;

SELECT '=== 업로드 파일 목록 ===' AS info;
SELECT * FROM upload_files;

SELECT '=== 시나리오 분석 결과 ===' AS info;
SELECT sr.scenario_result_id, s.scenario_name, sr.detected, sr.risk_score, sr.risk_level
FROM scenario_results sr
JOIN scenarios s ON sr.scenario_id = s.scenario_id
ORDER BY sr.scenario_result_id;

SELECT '=== 최종 위험 기록 ===' AS info;
SELECT * FROM risks;

SELECT '=== 인수인계 보고서 ===' AS info;
SELECT * FROM handover_reports;

SELECT '=== 구역별 위험 통계 ===' AS info;
SELECT * FROM zone_risk_stats;