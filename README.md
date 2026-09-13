<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# ⚙️ rsg-multijob
**Multi-job management system for RedM using RSG Core.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> Allows players to hold and switch between multiple jobs dynamically.
> Integrates seamlessly with RSG Core, the duty/job grade system, and Discord logging.

---

## 🛠️ Dependencies
- [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠
- [**ox_lib**](https://github.com/Rexshack-RedM/ox_lib) ⚙️ *(menu, notifications, locales, callbacks)*
- [**oxmysql**](https://github.com/Rexshack-RedM/oxmysql) 🗄️ *(database queries)*

---

## ✨ Features
- 💼 **Hold multiple jobs at once**, with a configurable default cap and per-player overrides.
- 🔄 **Switch between held jobs** instantly via `/myjobs` or the `OpenMultijobMenu` export.
- 🗑️ **Drop a held job** yourself from the same menu.
- 🛠️ **Duty toggle** built into the menu (calls `RSGCore:ToggleDuty`).
- 🔐 **Per-citizen job limits** — grant specific players (staff, testers, etc.) a higher cap than the server default.
- 🎨 **Configurable job icons** using FontAwesome, shown next to each job in the menu.
- 🔔 **Localized `ox_lib` notifications** for every success/error state — no hardcoded UI strings.
- 🌍 **8 languages built in**: English, French, Spanish, Italian, Portuguese (BR), Greek, Czech, Polish.
- 🔔 **Discord webhook logging** for job adds, switches, deletions, limit hits, admin removals, and `rsg-bossmenu` firings — fully optional, rate-limited, and safe to leave installed even with no webhook configured.
- 🧩 **Server & client exports** so other resources can query or modify a player's jobs without firing events directly.
- 🔗 **`rsg-bossmenu` integration** — firing an employee automatically drops their multijob entry.
- 🩹 **Hardened against common exploits**: job/grade assignment is always validated server-side against the player's actual job data, never trusted from the client.

---

## 📂 Installation
1. Place the `rsg-multijob` folder inside your `resources/[rsg]` directory.
2. Import the SQL below (or let your server create it manually).
3. Add to your `server.cfg`, after `oxmysql` and `ox_lib`:
   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure rsg-core
   ensure rsg-multijob
   ```
4. (Optional) Configure Discord webhook logging — see [Discord Webhook Logging](#-discord-webhook-logging) below.
5. Restart your server.

### 🗄️ SQL Structure
```sql
CREATE TABLE IF NOT EXISTS `player_jobs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) DEFAULT NULL,
  `job` varchar(50) DEFAULT NULL,
  `grade` int(11) DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `citizenid_job` (`citizenid`, `job`)
);
```
The unique key on `(citizenid, job)` prevents duplicate rows if the same job update ever fires twice.

---

## ⚙️ Configuration (`config.lua`)

### Job limits & icons
```lua
MaxJobs = 2, -- default number of jobs any player can hold

AllowedMultipleJobs = {
    -- Override the default cap for specific citizens (e.g. staff/testers)
    ['LVD86398'] = 5,
    ['QXG67827'] = 2,
},

JobIcons = {
    -- FontAwesome 6 class shown next to each job in the /myjobs menu
    ['vallaw'] = 'fa-solid fa-shield',
    ['medic']  = 'fa-solid fa-user-nurse',
    ['miner']  = 'fa-solid fa-hill-rockslide',
    ['farmer'] = 'fa-solid fa-wheat-awn',
    -- add an entry per job name; anything missing falls back to a generic briefcase icon
},
```

### Discord webhook logging
```lua
Webhooks = {
    ['default'] = '', -- used for any category left blank below
    ['jobAdded'] = '',
    ['jobSwitched'] = '',
    ['jobDeleted'] = '',
    ['jobMaxReached'] = '',
    ['adminRemove'] = '',
    ['employeeFired'] = '',
},

WebhookSettings = {
    enabled = false, -- master switch; set true once a webhook URL is configured
    botName = 'RSG Multijob',
    botAvatar = 'https://...',
    serverName = 'RSG RedM Server', -- shown in the embed footer
    logs = {
        jobAdded = true,
        jobSwitched = true,
        jobDeleted = true,
        jobMaxReached = true,
        adminRemove = true,
        employeeFired = true,
    },
    queueIntervalMs = 350, -- drip-feed delay between queued webhook deliveries
}
```
See [Discord Webhook Logging](#-discord-webhook-logging) for full setup steps.

---

## 💬 Commands

| Command | Description |
|----------|--------------|
| `/myjobs` | Opens the multi-job selection menu |
| `/removejob [id] [jobname]` | (Admin) Removes a job from a player |

---

## 🔔 Discord Webhook Logging

`server/webhook.lua` sends Discord embeds for multijob activity. It's fully optional and safe to
leave installed even with no webhook configured — logging is silently skipped until you turn it on.

### Setup
1. Create one or more webhooks in your Discord server (Channel Settings → Integrations → Webhooks).
2. In `config.lua`, paste the URL(s) into `Webhooks`. You only need `default` — every category falls
   back to it — or set a different URL per category to route logs into separate channels.
3. Set `WebhookSettings.enabled = true`.
4. Toggle individual categories off under `WebhookSettings.logs` if you don't want to log them.

### What gets logged
| Category | Trigger |
|---|---|
| `jobAdded` | Player is granted a new tracked job for the first time |
| `jobSwitched` | Player switches their active job to one they already hold (`/myjobs`) |
| `jobDeleted` | Player removes one of their own held jobs from the menu |
| `jobMaxReached` | Player hits their multijob cap and the new job assignment is reverted |
| `adminRemove` | An admin uses `/removejob` |
| `employeeFired` | `rsg-bossmenu` fires an employee, removing their multijob entry |

Every embed includes the player's name, citizen ID, and Discord mention (when resolvable), plus
job/grade details relevant to that event. Outbound requests are queued and drip-fed
(`WebhookSettings.queueIntervalMs`, default 350ms) so a burst of activity can't trip Discord's rate
limiter.

### Sending your own custom logs
Other resources (or your own code) can push an embed through the same queue:
```lua
exports['rsg-multijob']:SendCustomLog('adminRemove', 'Custom Title', 3066993, {
    { name = 'Field', value = 'Value', inline = true },
})
```

---

## 🧩 Exports

### Server
| Export | Description |
|---|---|
| `GetJobCount(citizenid)` | Number of jobs the player currently holds |
| `CanTakeNewJob(citizenid)` | Whether the player is under their job cap |
| `HasJob(citizenid, jobName)` | Whether the player holds a specific job (+ grade) |
| `GetPlayerJobs(citizenid)` | Full list of the player's held jobs with labels/grades/salary |
| `AddJobToPlayer(citizenid, jobName, grade)` | Grants a job, or updates its grade if already held |
| `RemoveJobFromPlayer(citizenid, jobName)` | Removes a held job |
| `GetMaxJobs(citizenid)` | The player's effective job cap |
| `SendCustomLog(category, title, color, fields)` | Sends a custom embed through the webhook queue |

```lua
local jobs = exports['rsg-multijob']:GetPlayerJobs('ABC12345')
for _, jobData in ipairs(jobs) do
    print(jobData.jobLabel .. ' - Grade: ' .. jobData.gradeLabel .. ' - Salary: $' .. jobData.salary)
end
```

### Client
| Export | Description |
|---|---|
| `OpenMultijobMenu()` | Opens the multijob menu for the local player |

```lua
exports['rsg-multijob']:OpenMultijobMenu()
```

Full parameter/return docs live in `README_EXPORTS.md`.

---

## 🧠 How It Works

### Server Side
- Maintains a table of player jobs in MySQL (`player_jobs`), keyed by `citizenid`.
- When `RSGCore` changes a player's active job, the client relays that change to the server, which
  re-validates it against the player's actual, server-authoritative job data before ever touching
  the database or granting a new entry — client-supplied job/grade data is never trusted outright.
- Enforces `Config.MaxJobs` (or a per-citizen override from `Config.AllowedMultipleJobs`), reverting
  the player to a previously held job (or `unemployed`) if the cap is exceeded.
- Fires the relevant Discord webhook log for each state change, if enabled.

### Client Side
- Opens a context menu via `ox_lib.registerContext` showing the duty toggle and every held job.
- The currently active job is shown disabled; selecting another opens a Switch/Delete sub-menu.
- All menu text and notifications are pulled from `ox_lib` locales — nothing is hardcoded.

---

## 🌍 Locales
All text strings are managed via `ox_lib.locale()` and are available in:
- `en`, `fr`, `es`, `it`, `pt-br`, `el`, `cs`, `pl`

Example English keys:
```json
{
  "cl_lang_1": "On Duty",
  "cl_lang_2": "Off Duty",
  "cl_lang_3": "My Jobs"
}
```

---

## 💎 Credits
- **RSG Admin Team** — framework integration & localization support
