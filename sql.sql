CREATE TABLE IF NOT EXISTS `kamu_cezalar` (
    `license` VARCHAR(50) NOT NULL,
    `tasks_left` INT NOT NULL,
    `job` VARCHAR(16) NOT NULL,
    PRIMARY KEY (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
