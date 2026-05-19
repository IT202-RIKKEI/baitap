CREATE DATABASE final_review;
USE final_review;

-- tạo bảng
CREATE TABLE teams(
	team_id INT PRIMARY KEY AUTO_INCREMENT,
    team_name VARCHAR(100) NOT NULL,
    hq_country VARCHAR(50) NOT NULL,
    budget_cap DECIMAL(15,2) NOT NULL,
    current_rank INT DEFAULT 0
);

CREATE TABLE drivers(
	driver_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(100) NOT NULL,
    driver_number INT NOT NULL UNIQUE, 
    nationality VARCHAR(50) NOT NULL,
    annual_salary DECIMAL(12,2) NOT NULL,
    team_id INT,
    FOREIGN KEY (team_id) REFERENCES teams(team_id)
);

CREATE TABLE constructors_championship(
	championship_id INT PRIMARY KEY AUTO_INCREMENT,
    season_year YEAR NOT NULL,
    team_id INT,
    total_points DECIMAL(5,1) DEFAULT 0.0,
	FOREIGN KEY (team_id) REFERENCES teams(team_id)
);

CREATE TABLE races(
	race_id INT PRIMARY KEY AUTO_INCREMENT,
    race_name VARCHAR(100) NOT NULL,
    circuit_name VARCHAR(100) NOT NULL,
    race_date DATETIME NOT NULL,
    race_status VARCHAR(30) DEFAULT 'Scheduled'
);

CREATE TABLE race_results(
	result_id INT PRIMARY KEY AUTO_INCREMENT,
    driver_id INT, 
    race_id INT,
    grid_position INT NOT NULL,
    finish_position INT ,
    points_earned DECIMAL(4,1) DEFAULT 0.0,
    fastest_lap_speed DECIMAL(5,2) DEFAULT 0.00,
    FOREIGN KEY (driver_id) REFERENCES drivers(driver_id),
    FOREIGN KEY (race_id) REFERENCES races(race_id)
);

-- PHẦN 2 
-- CÂU 1 
INSERT INTO teams(team_name, hq_country, budget_cap, current_rank)
VALUES
('Red Bull Racing', 'Austria', 145000000.00, 1),
('Mercedes', 'Germany', 140000000.00, 2),
('Ferrari', 'Italy', 138000000.00, 3),
('McLaren', 'Britain', 132000000.00, 4),
('Aston Martin', 'Britain', 125000000.00, 5);

-- INSERT drivers
INSERT INTO drivers(full_name, driver_number, nationality, annual_salary, team_id)
VALUES
('Max Verstappen', 1, 'Dutch', 55000000.00, 1),
('Lewis Hamilton', 44, 'British', 45000000.00, 2),
('Charles Leclerc', 16, 'Monaco', 30000000.00, 3),
('Lando Norris', 4, 'British', 22000000.00, 4),
('Fernando Alonso', 14, 'Spanish', 18000000.00, 5);

-- INSERT constructors_championship
INSERT INTO constructors_championship(season_year, team_id, total_points)
VALUES
(2026, 1, 220.5),
(2026, 2, 185.0),
(2026, 3, 170.5),
(2026, 4, 140.0),
(2026, 5, 110.5);

-- INSERT races
INSERT INTO races(race_name, circuit_name, race_date, race_status)
VALUES
('Bahrain GP', 'Bahrain International Circuit', '2026-03-10 18:00:00', 'Finished'),
('Monaco GP', 'Circuit de Monaco', '2026-05-25 20:00:00', 'Finished'),
('Silverstone GP', 'Silverstone Circuit', '2026-07-15 19:00:00', 'Scheduled'),
('Suzuka GP', 'Suzuka Circuit', '2026-09-20 13:00:00', 'Scheduled'),
('Monza GP', 'Monza Circuit', '2026-10-05 16:00:00', 'Scheduled');

-- INSERT race_results
INSERT INTO race_results(driver_id, race_id, grid_position, finish_position, points_earned, fastest_lap_speed)
VALUES
(1, 1, 1, 1, 26.0, 245.50),
(2, 1, 3, 2, 18.0, 241.20),
(3, 1, 2, 3, 15.0, 239.80),
(4, 2, 4, NULL, 0.0, 210.00),
(5, 2, 5, 21, 1.0, 205.50);

-- câu 2
-- cập nhật
UPDATE drivers
SET annual_salary = annual_salary * 1.10
WHERE nationality = 'British'
AND driver_id IN (
    SELECT driver_id
    FROM race_results
    GROUP BY driver_id
    HAVING AVG(points_earned) > 15.0
);

-- xóa
DELETE FROM race_results
WHERE finish_position > 20;


-- phần 3
-- Câu 1
SELECT full_name, driver_number, nationality
FROM drivers
WHERE annual_salary > 20000000
OR nationality = 'Dutch';

-- Câu 2
SELECT team_name, hq_country
FROM teams
WHERE current_rank BETWEEN 1 AND 3
AND (
    hq_country LIKE 'M%'
    OR hq_country LIKE 'G%'
);

-- Câu 3
SELECT race_id, race_name, race_date
FROM races
ORDER BY race_date DESC
LIMIT 2 OFFSET 2;

-- phần 3 
-- câu 1 
SELECT 
    d.full_name,
    t.team_name,
    SUM(rr.points_earned) AS total_points,
    MAX(rr.fastest_lap_speed) AS highest_speed
FROM drivers d
JOIN teams t ON d.team_id = t.team_id
JOIN race_results rr ON d.driver_id = rr.driver_id
GROUP BY d.driver_id, d.full_name, t.team_name;

-- Câu 2
SELECT 
    t.team_name,
    SUM(rr.points_earned) AS total_team_points
FROM teams t
JOIN drivers d ON t.team_id = d.team_id
JOIN race_results rr ON d.driver_id = rr.driver_id
GROUP BY t.team_id, t.team_name
HAVING SUM(rr.points_earned) > 50;

-- Câu 3
SELECT driver_id, full_name, annual_salary
FROM drivers
WHERE annual_salary = (
    SELECT MAX(annual_salary)
    FROM drivers
);

-- PHẦN 5: INDEX & VIEW
-- Câu 1
CREATE INDEX idx_driver_perf
ON race_results(finish_position, points_earned);

-- Câu 2
CREATE VIEW view_team_financials AS
SELECT
    t.team_name,
    COUNT(d.driver_id) AS total_drivers,
    SUM(d.annual_salary) AS total_salary
FROM teams t
JOIN drivers d ON t.team_id = d.team_id
WHERE d.annual_salary > 0
GROUP BY t.team_id, t.team_name;

-- PHẦN 6: TRIGGER
-- Câu 1
DELIMITER //
CREATE TRIGGER trg_bonus_salary
AFTER INSERT ON race_results
FOR EACH ROW
BEGIN
    IF NEW.points_earned > 25 THEN
        UPDATE drivers
        SET annual_salary = annual_salary + 50000
        WHERE driver_id = NEW.driver_id;
    END IF;
END //
DELIMITER ;

-- Câu 2
DELIMITER //
CREATE TRIGGER trg_update_constructor_points
AFTER UPDATE ON races
FOR EACH ROW
BEGIN
    IF NEW.race_status = 'Finished' THEN
        UPDATE constructors_championship
        SET total_points = total_points + 10
        WHERE team_id = (
            SELECT d.team_id
            FROM race_results rr
            JOIN drivers d ON rr.driver_id = d.driver_id
            WHERE rr.race_id = NEW.race_id
            AND rr.finish_position = 1
            LIMIT 1
        );
    END IF;
END //
DELIMITER ;

-- PHẦN 7: STORED PROCEDURE
-- Câu 1
DELIMITER //
CREATE PROCEDURE proc_evaluate_driver(IN p_driver_id INT)
BEGIN
    DECLARE total_driver_points DECIMAL(10,1);
    SELECT SUM(points_earned)
    INTO total_driver_points
    FROM race_results
    WHERE driver_id = p_driver_id;

    IF total_driver_points > 100 THEN
        SELECT 'World Champion Class' AS evaluation;
    ELSEIF total_driver_points BETWEEN 50 AND 100 THEN
        SELECT 'Podium Contender' AS evaluation;
    ELSE
        SELECT 'Midfield Driver' AS evaluation;
    END IF;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE proc_transfer_driver(
    IN p_driver_id INT,
    IN p_new_team_id INT
)
BEGIN
    DECLARE v_old_team_id INT;
    DECLARE v_total_salary DECIMAL(15,2);
    DECLARE v_budget_cap DECIMAL(15,2);
    START TRANSACTION;
    SELECT team_id
    INTO v_old_team_id
    FROM drivers
    WHERE driver_id = p_driver_id;

    UPDATE drivers
    SET team_id = p_new_team_id
    WHERE driver_id = p_driver_id;

    CREATE TABLE IF NOT EXISTS driver_transfer_history (
        transfer_id INT AUTO_INCREMENT PRIMARY KEY,
        driver_id INT,
        old_team_id INT,
        new_team_id INT,
        transfer_date DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    INSERT INTO driver_transfer_history(
        driver_id,
        old_team_id,
        new_team_id
    )
    VALUES(
        p_driver_id,
        v_old_team_id,
        p_new_team_id
    );

    SELECT SUM(annual_salary)
    INTO v_total_salary
    FROM drivers
    WHERE team_id = p_new_team_id;

    SELECT budget_cap
    INTO v_budget_cap
    FROM teams
    WHERE team_id = p_new_team_id;

    IF v_total_salary > v_budget_cap THEN
        ROLLBACK;
    ELSE
        COMMIT;
    END IF;
END //
DELIMITER ;

