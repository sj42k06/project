DROP DATABASE IF EXISTS safety_system_schemas;

CREATE DATABASE safety_system_schemas
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE safety_system_schemas;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS report_items;
DROP TABLE IF EXISTS reports;
DROP TABLE IF EXISTS risk_events;
DROP TABLE IF EXISTS detections;
DROP TABLE IF EXISTS frames;
DROP TABLE IF EXISTS videos;

SET FOREIGN_KEY_CHECKS = 1;

-- 1. videos
-- 업로드된 원본 영상 정보를 저장하는 테이블
CREATE TABLE videos (
    video_id INT AUTO_INCREMENT PRIMARY KEY,
    video_path VARCHAR(255),
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. frames
-- 영상에서 일정 시간 간격으로 추출한 프레임 이미지를 저장하는 테이블
CREATE TABLE frames (
    frame_id INT AUTO_INCREMENT PRIMARY KEY,
    video_id INT,
    frame_path VARCHAR(255),
    captured_at DATETIME,
    FOREIGN KEY (video_id) REFERENCES videos(video_id)
);

-- 3. detections
-- AI(YOLO 등)가 프레임에서 탐지한 객체 결과를 저장하는 테이블
-- 예: person, helmet, vest
CREATE TABLE detections (
    detection_id INT AUTO_INCREMENT PRIMARY KEY,
    frame_id INT,
    object_type VARCHAR(50),
    confidence FLOAT,
    FOREIGN KEY (frame_id) REFERENCES frames(frame_id)
);

-- 4. risk_events
-- 탐지 결과를 바탕으로 판단한 위험 이벤트를 저장하는 테이블
-- 예: 안전모 미착용, 안전조끼 미착용, 낙하물 위험
CREATE TABLE risk_events (
    risk_id INT AUTO_INCREMENT PRIMARY KEY,
    frame_id INT,
    risk_type VARCHAR(100),
    risk_level VARCHAR(20),
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (frame_id) REFERENCES frames(frame_id)
);

-- 5. reports
-- 영상 전체를 바탕으로 생성된 보고서의 기본 정보를 저장하는 테이블
CREATE TABLE reports (
    report_id INT AUTO_INCREMENT PRIMARY KEY,
    video_id INT,
    summary TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (video_id) REFERENCES videos(video_id)
);

-- 6. report_items
-- 보고서 안에 들어가는 시간대별 타임라인 항목을 저장하는 테이블
-- 예: 09:00 정상 / 09:10 안전모 미착용 / 09:20 주의 필요
CREATE TABLE report_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    report_id INT,
    frame_id INT,
    event_time DATETIME,

    -- 상태를 3개로 제한
    status ENUM('정상', '주의', '위험') NOT NULL,

    description TEXT,
    FOREIGN KEY (report_id) REFERENCES reports(report_id),
    FOREIGN KEY (frame_id) REFERENCES frames(frame_id)
);