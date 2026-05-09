DROP DATABASE IF EXISTS safety_system;

CREATE DATABASE safety_system
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE safety_system;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS handover_logs;
DROP TABLE IF EXISTS reports;
DROP TABLE IF EXISTS risk_logs;
DROP TABLE IF EXISTS safety_rules;
DROP TABLE IF EXISTS users;

SET FOREIGN_KEY_CHECKS = 1;

-- 1. 현장 관리자 계정 테이블
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    login_id VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(50) NOT NULL,
    phone VARCHAR(20)
);

-- 2. 안전 기준 / 사고 케이스 테이블
CREATE TABLE safety_rules (
    rule_id INT AUTO_INCREMENT PRIMARY KEY,
    case_name VARCHAR(100) NOT NULL,
    law_name VARCHAR(100),
    law_content TEXT,
    detected_objects VARCHAR(255),
    risk_condition TEXT,
    recommendation TEXT
);

-- 3. AI 위험 탐지 기록 테이블
CREATE TABLE risk_logs (
    risk_id INT AUTO_INCREMENT PRIMARY KEY,
    rule_id INT NULL,
    detected_by INT NOT NULL,
    detection_status ENUM('NORMAL', 'RISK') NOT NULL,
    description TEXT,
    image_path TEXT,
    action_status ENUM('조치완료', '미조치') NULL,
    action_note TEXT,
    detected_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_risk_rule
        FOREIGN KEY (rule_id)
        REFERENCES safety_rules(rule_id),

    CONSTRAINT fk_risk_user
        FOREIGN KEY (detected_by)
        REFERENCES users(user_id)
);

-- 4. 보고서 저장 테이블
CREATE TABLE reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    risk_id INT NOT NULL,
    report_title VARCHAR(200) NOT NULL,
    report_date DATE NOT NULL,
    created_by INT NOT NULL,
    report_content TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_report_risk
        FOREIGN KEY (risk_id)
        REFERENCES risk_logs(risk_id),

    CONSTRAINT fk_report_user
        FOREIGN KEY (created_by)
        REFERENCES users(user_id)
);

-- 5. 인수인계 기록 테이블
CREATE TABLE handover_logs (
    handover_id INT AUTO_INCREMENT PRIMARY KEY,
    report_id INT NOT NULL,
    from_user_id INT NOT NULL,
    to_user_id INT NOT NULL,
    handover_date DATE NOT NULL,
    handover_status ENUM('대기', '확인완료') DEFAULT '대기',
    confirmed_at DATETIME NULL,
    signature_check BOOLEAN DEFAULT FALSE,
    sms_sent BOOLEAN DEFAULT FALSE,

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