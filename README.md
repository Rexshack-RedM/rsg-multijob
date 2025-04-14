# rsg-multijob
- converted to work with RSG Framework
- respect to the original creator Randolio : https://github.com/Randolio
- max job limit available for users, ability for certain CID to have more than max job - Mafiaborn

# Add SQL to your database
```sql
CREATE TABLE IF NOT EXISTS `player_jobs` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) DEFAULT NULL,
    `job` varchar(50) DEFAULT NULL,
    `grade` INT(11) DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
