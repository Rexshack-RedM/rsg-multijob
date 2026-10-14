CREATE TABLE IF NOT EXISTS `player_jobs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `job` VARCHAR(50) NOT NULL,
    `grade` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
);

-- Job definitions (replaces rsg-core/shared/jobs.lua). Created automatically on start too.
CREATE TABLE IF NOT EXISTS `multijob_jobs` (
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `type` VARCHAR(50) NULL DEFAULT NULL,
    `icon` VARCHAR(100) NULL DEFAULT NULL,
    `default_duty` TINYINT(1) NOT NULL DEFAULT 1,
    `off_duty_pay` TINYINT(1) NOT NULL DEFAULT 0,
    `grades` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`name`)
);
