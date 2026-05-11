USE safety_system;

DELIMITER $$

DROP PROCEDURE IF EXISTS generate_one_year_dummy_data $$

CREATE PROCEDURE generate_one_year_dummy_data()
BEGIN
    DECLARE current_day DATE;
    DECLARE end_day DATE;
    DECLARE i INT;
    DECLARE manager_id INT;
    DECLARE rule_num INT;
    DECLARE first_risk_id INT;
    DECLARE new_report_id INT;
    DECLARE risk_counter INT DEFAULT 0;
    DECLARE report_title_text VARCHAR(200);
    DECLARE report_content_text TEXT;

    SET current_day = '2025-05-12';
    SET end_day = '2026-05-11';

    WHILE current_day <= end_day DO

        -- 주말 제외: DAYOFWEEK 1=일요일, 7=토요일
        IF DAYOFWEEK(current_day) NOT IN (1, 7) THEN

            SET i = 1;
            SET first_risk_id = NULL;

            WHILE i <= 10 DO

                SET manager_id = ((DAYOFYEAR(current_day) + i) % 4) + 1;

                -- 하루 10회 중 7회 NORMAL, 3회 RISK
                IF i IN (3, 6, 9) THEN

                    SET risk_counter = risk_counter + 1;
                    SET rule_num = ((DAYOFYEAR(current_day) + i) % 5) + 1;

                    INSERT INTO risk_logs
                    (
                        rule_id,
                        detected_by,
                        detection_status,
                        description,
                        image_path,
                        action_status,
                        action_note,
                        detected_at
                    )
                    VALUES
                    (
                        rule_num,
                        manager_id,
                        'RISK',
                        CASE rule_num
                            WHEN 1 THEN '작업자가 안전모, 안전조끼, 안전화 등 보호구를 완전히 착용하지 않은 상태로 감지되었습니다.'
                            WHEN 2 THEN '작업자가 출입 금지 구역 또는 낙하물 위험 구역에 진입한 상황이 감지되었습니다.'
                            WHEN 3 THEN '중장비 작업 반경 내에 작업자가 접근한 위험 상황이 감지되었습니다.'
                            WHEN 4 THEN '작업 통로 또는 비상 통로에 자재물이 적치된 상태가 감지되었습니다.'
                            WHEN 5 THEN '작업 구역 내 작업자 밀집 위험이 감지되었습니다.'
                        END,
                        CONCAT('/uploads/dummy/result_', LPAD(risk_counter, 4, '0'), '.jpg'),
                        CASE 
                            WHEN risk_counter % 5 = 0 THEN '미조치'
                            ELSE '조치완료'
                        END,
                        CASE 
                            WHEN risk_counter % 5 = 0 THEN '현장 상황상 즉시 조치가 어려워 다음 관리자 확인이 필요합니다.'
                            ELSE '현장 확인 후 조치가 완료되었습니다.'
                        END,
                        DATE_ADD(
                            TIMESTAMP(current_day),
                            INTERVAL (8 + i) HOUR
                        )
                    );

                ELSE

                    INSERT INTO risk_logs
                    (
                        rule_id,
                        detected_by,
                        detection_status,
                        description,
                        image_path,
                        action_status,
                        action_note,
                        detected_at
                    )
                    VALUES
                    (
                        NULL,
                        manager_id,
                        'NORMAL',
                        '해당 시간대 현장 모니터링 결과 특이 위험 요소가 감지되지 않았습니다.',
                        NULL,
                        NULL,
                        NULL,
                        DATE_ADD(
                            TIMESTAMP(current_day),
                            INTERVAL (8 + i) HOUR
                        )
                    );

                END IF;

                IF i = 1 THEN
                    SET first_risk_id = LAST_INSERT_ID();
                END IF;

                SET i = i + 1;

            END WHILE;

            SET report_title_text = CONCAT(DATE_FORMAT(current_day, '%Y-%m-%d'), ' 일일 안전 인수인계 보고서');

            SET report_content_text = CONCAT(
                DATE_FORMAT(current_day, '%Y-%m-%d'),
                ' 현장 모니터링 결과입니다. 하루 총 10회의 분석 기록이 생성되었으며, 정상 상태와 위험 감지 상태가 함께 기록되었습니다. 위험 감지 건은 조치 상태와 함께 정리되어 다음 관리자에게 인수인계됩니다.'
            );

            INSERT INTO reports
            (
                risk_id,
                report_title,
                report_date,
                created_by,
                report_content,
                created_at
            )
            VALUES
            (
                first_risk_id,
                report_title_text,
                current_day,
                ((DAYOFYEAR(current_day)) % 4) + 1,
                report_content_text,
                TIMESTAMP(current_day, '18:00:00')
            );

            SET new_report_id = LAST_INSERT_ID();

            INSERT INTO handover_logs
            (
                report_id,
                from_user_id,
                to_user_id,
                handover_date,
                handover_status,
                confirmed_at,
                signature_check,
                sms_sent
            )
            VALUES
            (
                new_report_id,
                ((DAYOFYEAR(current_day)) % 4) + 1,
                ((DAYOFYEAR(current_day) + 1) % 4) + 1,
                DATE_ADD(current_day, INTERVAL 1 DAY),
                CASE 
                    WHEN current_day >= '2026-05-07' THEN '대기'
                    ELSE '확인완료'
                END,
                CASE 
                    WHEN current_day >= '2026-05-07' THEN NULL
                    ELSE TIMESTAMP(DATE_ADD(current_day, INTERVAL 1 DAY), '09:05:00')
                END,
                CASE 
                    WHEN current_day >= '2026-05-07' THEN FALSE
                    ELSE TRUE
                END,
                CASE 
                    WHEN current_day >= '2026-05-07' THEN FALSE
                    ELSE TRUE
                END
            );

        END IF;

        SET current_day = DATE_ADD(current_day, INTERVAL 1 DAY);

    END WHILE;

END $$

DELIMITER ;

CALL generate_one_year_dummy_data();

DROP PROCEDURE IF EXISTS generate_one_year_dummy_data;