-- 코드 스니펫 1
-- 기능: 위험 이벤트 저장 구조와 외래키 관계 정의
-- 출처: 졸업작품 최종 데이터베이스 SQL 84~106행

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
