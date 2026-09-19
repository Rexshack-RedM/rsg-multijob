# rsg-multijob

A multi-job system for **RSG-Core** (RedM). Lets players hold and switch between several jobs at once, gives admins a command to strip a job from a player, keeps `rsg-bossmenu` firings in sync, and logs everything to Discord via webhooks.

Version: `2.0.6`

## Features

- **Multiple jobs per character** — players can hold up to a configurable number of jobs at the same time (`Config.MaxJobs`), stored per `citizenid` in a `player_jobs` database table.
- **In-game NUI menu** — a "Wild West"-themed job registry UI (`/myjobs`) showing each job's label, grade, salary and an icon, with a capacity indicator, duty toggle, job switching and job deletion, all with confirmation prompts.
- **Job switching with cooldown** — players can switch their active job between any job they hold, subject to `Config.JobSwitchCooldown` to prevent rapid job-hopping.
- **Automatic job capture** — whenever RSGCore reports a job update for a player (e.g. hired via `rsg-bossmenu` or another job script), this resource automatically records/updates that job in the player's `player_jobs` list (up to the max jobs limit).
- **Self-service job removal** — players can delete a job from their own registry from the UI or resign their current job (falls back to `unemployed`).
- **Admin job removal** — `/removejob [id] [job]` command (admin-restricted) to forcibly remove a job from any online player.
- **rsg-bossmenu integration** — listens for `rsg-bossmenu:server:FireEmployee` so a boss firing an employee (online or offline) also removes that job from the employee's multijob list. Verifies the firer actually holds a boss grade for that job and outranks the target before acting.
- **Discord webhook logging** — optional, queued (rate-limit safe) Discord embeds for: job added, job switched, job deleted (self), job removed (admin), and employee fired. Each event can be enabled/disabled and routed to its own webhook URL independently.
- **Multi-language support** — UI and server messages are localized via `ox_lib` locales; English, French, Spanish, Italian, and Greek are included out of the box.
- **Version checker** — checks a GitHub-hosted `version.txt` on resource start and warns in the console if the server is running an outdated (or newer/dev) build.

## Requirements

- [RSG-Core](https://github.com/Rexshack-RedM) framework
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- `rsg-bossmenu` (optional — only needed for the employee-firing sync feature)
- A notification resource providing the `rNotify:NotifyLeft` client event

## Installation

1. Download/clone this resource into your server's resources folder, e.g. `resources/[rsg]/rsg-multijob`.
2. Create the required database table (run against your server's database):

   ```sql
   CREATE TABLE IF NOT EXISTS `player_jobs` (
       `id` INT NOT NULL AUTO_INCREMENT,
       `citizenid` VARCHAR(50) NOT NULL,
       `job` VARCHAR(50) NOT NULL,
       `grade` INT NOT NULL DEFAULT 0,
       PRIMARY KEY (`id`),
       KEY `citizenid` (`citizenid`)
   );
   ```

3. Add the resource to your `server.cfg`, after `ox_lib`, `oxmysql` and `rsg-core`, and after `rsg-bossmenu` if you use it:

   ```
   ensure ox_lib
   ensure oxmysql
   ensure rsg-core
   ensure rsg-bossmenu
   ensure rsg-multijob
   ```

4. Restart your server (or `refresh` + `ensure rsg-multijob`).

## Configuration

All settings live in `config.lua`.

### General

| Setting | Description |
|---|---|
| `MaxJobs` | Maximum number of jobs a single player can hold at once. |
| `JobSwitchCooldown` | Milliseconds a player must wait between switching jobs. |
| `JobIcons` | Table mapping a job name (as used in RSGCore's `jobs.lua`) to a Font Awesome icon class shown in the UI. Any job not listed falls back to `fa-solid fa-briefcase`. |

### Discord Webhooks (`Config.Webhooks`)

| Setting | Description |
|---|---|
| `Enabled` | Master on/off switch for all webhook logging. |
| `DefaultURL` | Webhook URL used for any event that doesn't set its own `URL`. |
| `BotName` / `BotAvatar` | Username and avatar shown for the webhook messages. |
| `FooterText` / `FooterIcon` | Footer text/icon applied to every embed. |
| `DefaultColor` | Decimal RGB color used when an event doesn't set its own `Color`. |
| `Events.<EventName>.Enabled` | Enable/disable logging for that specific event. |
| `Events.<EventName>.URL` | Route this event to a different Discord webhook than `DefaultURL`. |
| `Events.<EventName>.Title` / `Color` | Embed title/color for that event. |

Configurable events: `JobAdded`, `JobSwitched`, `JobDeleted`, `JobRemovedByAdmin`, `EmployeeFired`.

Leave `DefaultURL` (and any per-event `URL`) blank to disable webhook posting for that event — a blank/invalid URL is treated as "not configured" and simply skipped.

### Locales

Language files live in `locales/*.json` (`en`, `fr`, `es`, `it`, `el`). The active locale follows your server's `ox_lib` locale setting. To add a language, copy `locales/en.json`, translate the values, and save it as `locales/<code>.json`.

## Usage

### Player commands

- `/myjobs` — opens the multi-job UI, showing every job the player currently holds. From here a player can:
  - Toggle duty for their active job.
  - Switch their active job to any other job they hold (with a confirmation prompt).
  - Delete a job from their registry (with a confirmation prompt) — if it was their active job, they become `unemployed`.

### Admin commands

- `/removejob [id] [job]` — (requires the `admin` ACE permission) removes the specified job from the specified player's multijob list. The player must be online. If it was their active job, they become `unemployed`.

### How jobs get added

Jobs are added to a player's multijob list automatically: whenever RSGCore fires a job update for the player (for example, being hired through `rsg-bossmenu` or any other script that calls `Player.Functions.SetJob`), this resource records that job (and grade) against the player's `citizenid`, up to `Config.MaxJobs`. If the player is already at their job limit, they'll be notified and the new job won't be added to their list (though RSGCore's own active job may still change, depending on the hiring script).

### Firing employees

If you use `rsg-bossmenu`, firing an employee through it also removes that job from the fired player's multijob registry — whether they're online or offline — as long as the person doing the firing actually holds a boss grade in that job and outranks the target.

### Exports (for other resources)

`rsg-multijob` exposes server-side exports so other scripts can grant or revoke jobs without going through the UI or duplicating the DB logic. `identifier` accepts either an online player's server id (number) or a `citizenid` (string) — a citizenid works whether the player is online or offline.

```lua
-- Add (or upgrade) a job. grade defaults to 0. bypassMax (optional) skips Config.MaxJobs.
-- Returns: success (boolean), errorReason ('invalid_job' | 'invalid_grade' | 'player_not_found' | 'max_jobs')
local success, err = exports['rsg-multijob']:AddJob(identifier, 'gunsmith', 0, false)

-- Remove a job. If it's the player's active job and they're online, they become 'unemployed'.
-- Returns: success (boolean), errorReason ('invalid_job' | 'player_not_found' | 'job_not_held')
local success, err = exports['rsg-multijob']:RemoveJob(identifier, 'gunsmith')

-- Read a player's stored multijob list: array of { job, salary, jobLabel, gradeLabel, grade }
local jobs = exports['rsg-multijob']:GetJobs(identifier)
```

Both `AddJob` and `RemoveJob` push a live UI refresh to the player if they're online, and log to the configured Discord webhook the same way the in-game actions do.
