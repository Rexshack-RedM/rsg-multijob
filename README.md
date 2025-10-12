<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# ⚙️ rsg-multijob
**Multi-job management system for RedM using RSG Core.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> Allows players to have and switch between multiple jobs dynamically.  
> Integrates seamlessly with RSG Core and the duty/job grade system.

---

## 🛠️ Dependencies
- [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠  
- [**ox_lib**](https://github.com/overextended/ox_lib) ⚙️ *(menu & notifications)*  

**Locales:** `en`, `fr`, `es`, `it`, `pt-br`, `el`  
**License:** GPL‑3.0  

---

## ✨ Features
- 💼 **Hold multiple jobs** at once (configurable maximum).  
- 🔄 **Switch between jobs** instantly using `/myjobs` or via menu.  
- 🔔 **Localized notifications** through `ox_lib`.  
- 🧩 **SQL storage** for persistence (`player_jobs` table).  
- 🛠️ **Duty toggle** supported (calls `RSGCore:ToggleDuty`).  
- 🎨 **Configurable job icons** using FontAwesome.  
- 🔐 **Whitelist system** to allow specific players more jobs.  
- 🌍 Multi-language support built-in.  

---

## ⚙️ Configuration (`config.lua`)
```lua
Config = {}

-- Maximum jobs per player (default: 3)
Config.MaxJobs = 3

-- Specific citizens who can have more jobs
Config.AllowedMultipleJobs = {
    "CITIZEN1234",  -- Example: admins, testers
    "CITIZEN5678"
}

-- Job icons (FontAwesome)
Config.JobIcons = {
    ['rancher'] = 'fa-solid fa-cow',
    ['vallaw'] = 'fa-solid fa-shield-halved',
    ['doctor'] = 'fa-solid fa-briefcase-medical',
    ['blacksmith'] = 'fa-solid fa-hammer',
    ['miner'] = 'fa-solid fa-mountain',
    ['hunter'] = 'fa-solid fa-paw',
    ['butcher'] = 'fa-solid fa-cutlery',
}
```

> 💡 You can use any **FontAwesome 6** icon class.  
> Icons appear next to the job name in the `/myjobs` menu.

---

## 🧠 How It Works

### Server Side
- Maintains a table of player jobs in MySQL (`player_jobs`).  
- On resource start, all player jobs are loaded and linked to their citizenid.  
- When a player adds or switches job:
  - Verifies against `Config.MaxJobs` (or whitelist exception).  
  - Updates both **RSGCore job data** and **SQL table**.  
  - Triggers localized notification with job name & grade.  

### Client Side
- Opens a **context menu** using `ox_lib.registerContext`.  
- Displays all jobs (current job highlighted).  
- Selecting one job calls `TriggerServerEvent('rsg-multijob:switchJob', job)`  
- Displays success/failure notification.

---

## 💬 Commands

| Command | Description |
|----------|--------------|
| `/myjobs` | Opens the multi-job selection menu |
| `/addjob [jobname] [grade]` | (Admin) Adds a new job to a player |
| `/removejob [jobname]` | (Admin) Removes a job from a player |

---

## 🗄️ SQL Structure
```sql
CREATE TABLE IF NOT EXISTS `player_jobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `job` varchar(50) DEFAULT NULL,
  `grade` int(11) DEFAULT 0,
  PRIMARY KEY (`id`)
);
```

---

## 🧩 Integration with RSG Core

Every time a player switches job:
- Their job is updated in `PlayerData.job`.  
- All server checks (`Player.PlayerData.job.name`) instantly reflect the change.  
- If the new job supports `onDuty`, it triggers a call to `RSGCore:ToggleDuty`.  

Example usage:
```lua
local Player = RSGCore.Functions.GetPlayer(source)
print(Player.PlayerData.job.name) -- returns the currently active job
```

---

## 📂 Installation
1. Place `rsg-multijob` inside your `resources/[rsg]` folder.  
2. Import `rsg-multijob.sql` (or manually create the table above).  
3. Add to your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure rsg-multijob
   ```
4. Restart your server.

---

## 🌍 Locales
All text strings are managed via `ox_lib.locale()` and are available in:
- `en`, `fr`, `es`, `it`, `pt-br`, `el`

Example English keys:
```json
{
  "cl_lang_1": "You have switched to job: %{job}",
  "cl_lang_2": "You already have this job!",
  "cl_lang_3": "You cannot hold more than %{max} jobs."
}
```

---

## 💎 Credits
- **Randolio** — Original multijob system concept & design https://github.com/Randolio
- **Mafiaborn** — RSG Core adaptation & maintenance  
- **RSG / Rexshack-RedM** — framework integration & localization support  
- Community translators  
- License: GPL‑3.0  
