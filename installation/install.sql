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

INSERT INTO `multijob_jobs` (`name`, `label`, `type`, `icon`, `default_duty`, `off_duty_pay`, `grades`, `updated_at`) VALUES
	('blklaw', 'Blackwater Law Enforcement', 'leo', 'fa-solid fa-shield', 0, 0, '{"1":{"payment":25,"name":"Deputy"},"2":{"payment":50,"isboss":true,"name":"Sheriff"},"0":{"payment":10,"name":"Recruit"}}', '2026-10-14 14:26:58'),
	('downesranch', 'Downes Rancher', 'rancher', NULL, 1, 0, '{"1":{"payment":5,"name":"Ranch Hand"},"2":{"payment":0,"isboss":true,"name":"Ranch Manager"},"0":{"payment":3,"name":"Trainee Rancher"}}', '2026-10-14 14:26:58'),
	('emeraldranch', 'Emerald Rancher', 'rancher', NULL, 1, 0, '{"1":{"payment":5,"name":"Ranch Hand"},"2":{"payment":0,"isboss":true,"name":"Ranch Manager"},"0":{"payment":3,"name":"Trainee Rancher"}}', '2026-10-14 14:26:58'),
	('hangingdogranch', 'Hanging Dog Rancher', 'rancher', NULL, 1, 0, '{"1":{"payment":5,"name":"Ranch Hand"},"2":{"payment":0,"isboss":true,"name":"Ranch Manager"},"0":{"payment":3,"name":"Trainee Rancher"}}', '2026-10-14 14:26:58'),
	('herbalist', 'Herbalist', NULL, NULL, 1, 0, '{"1":{"payment":0,"isboss":true,"name":"Master"},"0":{"payment":0,"name":"Apprentice"}}', '2026-10-14 14:26:58'),
	('hillhavenranch', 'Hill Haven Rancher', 'rancher', NULL, 1, 0, '{"1":{"payment":5,"name":"Ranch Hand"},"2":{"payment":0,"isboss":true,"name":"Ranch Manager"},"0":{"payment":3,"name":"Trainee Rancher"}}', '2026-10-14 14:26:58'),
	('macfarranch', 'Macfarlane Rancher', 'rancher', NULL, 1, 0, '{"1":{"payment":5,"name":"Ranch Hand"},"2":{"payment":0,"isboss":true,"name":"Ranch Manager"},"0":{"payment":3,"name":"Trainee Rancher"}}', '2026-10-14 14:26:58'),
	('medic', 'Medic', 'medic', 'fa-solid fa-user-nurse', 0, 0, '{"1":{"payment":25,"name":"Trainee"},"2":{"payment":50,"name":"Doctor"},"0":{"payment":5,"name":"Recruit"},"3":{"payment":75,"name":"Surgeon"},"4":{"payment":100,"isboss":true,"name":"Manager"}}', '2026-10-14 14:26:58'),
	('pronghornranch', 'Pronghorn Rancher', 'rancher', NULL, 1, 0, '{"1":{"payment":5,"name":"Ranch Hand"},"2":{"payment":0,"isboss":true,"name":"Ranch Manager"},"0":{"payment":3,"name":"Trainee Rancher"}}', '2026-10-14 14:26:58'),
	('rholaw', 'Rhodes Law Enforcement', 'leo', 'fa-solid fa-shield', 0, 0, '{"1":{"payment":25,"name":"Deputy"},"2":{"payment":50,"isboss":true,"name":"Sheriff"},"0":{"payment":10,"name":"Recruit"}}', '2026-10-14 14:26:58'),
	('stdenlaw', 'Saint Denis Law Enforcement', 'leo', 'fa-solid fa-shield', 0, 0, '{"1":{"payment":25,"name":"Deputy"},"2":{"payment":50,"isboss":true,"name":"Sheriff"},"0":{"payment":10,"name":"Recruit"}}', '2026-10-14 14:26:58'),
	('strlaw', 'Strawberry Law Enforcement', 'leo', 'fa-solid fa-shield', 0, 0, '{"1":{"payment":25,"name":"Deputy"},"2":{"payment":50,"isboss":true,"name":"Sheriff"},"0":{"payment":10,"name":"Recruit"}}', '2026-10-14 14:26:58'),
	('unemployed', 'Civilian', NULL, NULL, 1, 0, '{"0":{"payment":3,"name":"Freelancer"}}', '2026-10-14 14:26:58'),
	('vallaw', 'Valentine Law Enforcement', 'leo', 'fa-solid fa-shield', 0, 0, '{"1":{"payment":25,"name":"Deputy"},"2":{"payment":50,"isboss":true,"name":"Sheriff"},"0":{"payment":10,"name":"Recruit"}}', '2026-10-14 14:26:58');

