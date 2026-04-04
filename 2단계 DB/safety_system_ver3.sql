SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE DATABASE IF NOT EXISTS safety_system
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_general_ci;

USE safety_system;

-- =========================================================
-- 기존 객체 정리
-- =========================================================
DROP VIEW IF EXISTS zone_risk_stats;

DROP TABLE IF EXISTS report_risks;
DROP TABLE IF EXISTS handover_reports;
DROP TABLE IF EXISTS risk_analysis;
DROP TABLE IF EXISTS risks;
DROP TABLE IF EXISTS scenario_results;
DROP TABLE IF EXISTS extracted_frames;
DROP TABLE IF EXISTS upload_files;
DROP TABLE IF EXISTS upload_batches;
DROP TABLE IF EXISTS scenarios;
DROP TABLE IF EXISTS zones;
DROP TABLE IF EXISTS users;

-- 1. 사용자 테이블
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE COMMENT '로그인 아이디',
    password VARCHAR(255) NOT NULL COMMENT '비밀번호',
    name VARCHAR(50) NOT NULL COMMENT '사용자 이름',
    role VARCHAR(20) NOT NULL DEFAULT 'worker' COMMENT 'worker | manager | admin',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT='시스템 사용자';

-- 2. 작업 구역 테이블
CREATE TABLE zones (
    zone_id INT AUTO_INCREMENT PRIMARY KEY,
    zone_name VARCHAR(100) NOT NULL UNIQUE COMMENT '구역 이름',
    description VARCHAR(255) COMMENT '구역 설명',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT='작업 구역';

-- 3. 시나리오 정의 테이블
CREATE TABLE scenarios (
    scenario_id INT AUTO_INCREMENT PRIMARY KEY,
    scenario_code VARCHAR(100) NOT NULL UNIQUE COMMENT '내부 코드값',
    scenario_name VARCHAR(255) NOT NULL COMMENT '시나리오 이름',
    description TEXT COMMENT '시나리오 설명',
    is_active BOOLEAN DEFAULT TRUE COMMENT '활성 여부',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT='분석 가능한 시나리오 정의';

-- 4. 업로드 배치 테이블
CREATE TABLE upload_batches (
    batch_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL COMMENT '업로드한 사용자',
    zone_id INT NULL COMMENT '기준 구역',
    scenario_id INT NOT NULL COMMENT '선택된 분석 시나리오',
    batch_title VARCHAR(255) COMMENT '업로드 제목/세션명',
    upload_type ENUM('images', 'video') NOT NULL COMMENT '업로드 유형',
    status ENUM('uploaded','frame_extracted','analyzing','done','report_generated','failed')
        NOT NULL DEFAULT 'uploaded' COMMENT '처리 상태',
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_batches_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT fk_batches_zone
        FOREIGN KEY (zone_id) REFERENCES zones(zone_id)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT fk_batches_scenario
        FOREIGN KEY (scenario_id) REFERENCES scenarios(scenario_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) COMMENT='업로드 작업 묶음';

-- 5. 업로드 파일 테이블
CREATE TABLE upload_files (
    file_id INT AUTO_INCREMENT PRIMARY KEY,
    batch_id INT NOT NULL,
    original_name VARCHAR(255) NOT NULL COMMENT '원본 파일명',
    saved_name VARCHAR(255) NOT NULL COMMENT '서버 저장 파일명',
    file_path VARCHAR(500) NOT NULL COMMENT '서버 저장 경로',
    file_type ENUM('image','video') NOT NULL COMMENT '원본 파일 유형',
    source_type ENUM('image','video') NOT NULL COMMENT '입력 출처 유형',
    file_ext VARCHAR(20) COMMENT '파일 확장자',
    file_size BIGINT COMMENT '파일 크기(byte)',
    mime_type VARCHAR(100) COMMENT 'MIME 타입',
    frame_count INT DEFAULT 0 COMMENT '영상일 경우 추출 프레임 수',
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_files_batch
        FOREIGN KEY (batch_id) REFERENCES upload_batches(batch_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT='업로드된 원본 파일 목록';

-- 6. 추출 프레임 테이블
CREATE TABLE extracted_frames (
    frame_id INT AUTO_INCREMENT PRIMARY KEY,
    video_file_id INT NOT NULL COMMENT '원본 영상 파일 ID',
    batch_id INT NOT NULL COMMENT '어느 업로드 배치에서 나온 프레임인지',
    frame_order INT NOT NULL COMMENT '프레임 순서',
    timestamp_sec DECIMAL(10,2) NULL COMMENT '영상 내 추출 시점(초)',
    frame_name VARCHAR(255) NOT NULL COMMENT '프레임 저장 파일명',
    frame_path VARCHAR(500) NOT NULL COMMENT '프레임 저장 경로',
    source_type ENUM('frame') NOT NULL DEFAULT 'frame' COMMENT '프레임 구분용',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_frames_video
        FOREIGN KEY (video_file_id) REFERENCES upload_files(file_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_frames_batch
        FOREIGN KEY (batch_id) REFERENCES upload_batches(batch_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT uq_video_frame_order UNIQUE (video_file_id, frame_order)
) COMMENT='영상에서 추출한 프레임 목록';

-- 7. 시나리오 분석 결과 테이블
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

-- 8. 최종 위험 기록 테이블
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

-- 9. AI 상세 분석 테이블
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

-- 10. 인수인계 보고서 테이블
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

-- 11. 보고서-위험 연결 테이블
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

-- 뷰
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

-- 인덱스
CREATE INDEX idx_batches_user_id ON upload_batches(user_id);
CREATE INDEX idx_batches_zone_id ON upload_batches(zone_id);
CREATE INDEX idx_batches_scenario_id ON upload_batches(scenario_id);
CREATE INDEX idx_batches_uploaded_at ON upload_batches(uploaded_at);
CREATE INDEX idx_batches_status ON upload_batches(status);

CREATE INDEX idx_files_batch_id ON upload_files(batch_id);
CREATE INDEX idx_files_type ON upload_files(file_type);
CREATE INDEX idx_files_source_type ON upload_files(source_type);

CREATE INDEX idx_frames_video_file_id ON extracted_frames(video_file_id);
CREATE INDEX idx_frames_batch_id ON extracted_frames(batch_id);
CREATE INDEX idx_frames_video_order ON extracted_frames(video_file_id, frame_order);

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

SET FOREIGN_KEY_CHECKS = 1;

-- 확인용 쿼리
SHOW TABLES;
SHOW FULL TABLES WHERE TABLE_TYPE = 'VIEW';

SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM zones;
SELECT COUNT(*) FROM scenarios;
SELECT COUNT(*) FROM upload_batches;
SELECT COUNT(*) FROM upload_files;
SELECT COUNT(*) FROM extracted_frames;
SELECT COUNT(*) FROM risks;
SELECT COUNT(*) FROM handover_reports;
