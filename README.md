# rsg-multijob

A multi-job system for **RSG-Core** (RedM). Lets players hold and switch between several jobs at once, gives admins a command to strip a job from a player, keeps `rsg-bossmenu` firings in sync, and logs everything to Discord via webhooks.

Version: `3.1.0`

## Features

- **Multiple jobs per character** — players can hold up to a configurable number of jobs at the same time (`Config.MaxJobs`), stored per `citizenid` in a `player_jobs` database table.
- **Server-authoritative** — jobs are only ever recorded from the player's real RSGCore job on the server; nothing the client sends can add a job or grade.
- **In-game NUI menu** — a "Wild West"-themed job registry UI (`/myjobs`) showing each job's label, grade, salary and an icon, with a capacity indicator, duty toggle, job switching and job deletion, all with confirmation prompts. Your current job can be opened too, so you can resign from it.
- **Job switching with cooldown** — players can switch their active job between any job they hold, subject to `Config.JobSwitchCooldown` to prevent rapid job-hopping.
- **Automatic job capture** — whenever RSGCore reports a job update for a player (e.g. hired via `rsg-bossmenu` or another job script), this resource automatically records/updates that job in the player's `player_jobs` list (up to the max jobs limit).
- **Self-service job removal** — players can delete a job from their own registry from the UI or resign their current job (falls back to `unemployed`).
- **Admin job removal** — `/removejob [id] [job]` command (admin-restricted) to remove a job from a player by server ID (online) or citizen ID (online or offline).
- **rsg-bossmenu integration** — listens for `rsg-bossmenu:server:FireEmployee` so a boss firing an employee (online or offline) also removes that job from the employee's multijob list. Verifies the firer actually holds a boss grade for that job and outranks the target before acting.
- **Discord webhook logging** — optional, queued (rate-limit safe) Discord embeds for: job added, job switched, job deleted (self), job removed (admin), and employee fired. Each event can be enabled/disabled and routed to its own webhook URL independently.
- **ox_lib notifications** — all player messages use `ox_lib` notify.
- **Multi-language support** — UI and server messages are localized via `ox_lib` locales; English, German, Greek, Spanish, French, Japanese, Dutch, Polish, Brazilian Portuguese, Romanian and Italian are included.
- **Version checker** — checks a GitHub-hosted `version.txt` on resource start and warns in the console if the server is running an outdated (or newer/dev) build.

## Job Definitions & Admin Panel (v3.1.0)

rsg-multijob now **owns every job on the server**. Job definitions live in the `multijob_jobs` database table instead of `rsg-core/shared/jobs.lua`, and are registered with rsg-core at runtime through its `AddJob` / `UpdateJob` / `RemoveJob` exports, which also sync `RSGCore.Shared.Jobs` to every client.

- **First start:** if `multijob_jobs` is empty, every job rsg-core currently has (your existing `jobs.lua`) is imported, with `shared/default_jobs.lua` filling any gaps. After that the database is the source of truth.
- **`/jobadmin`** (permission set by `Config.Admin.Permission`, default `admin`) opens the admin panel, where you can:
  - create jobs (ID, label, type, Font Awesome icon, on-duty-at-login, off-duty pay)
  - add, rename or re-pay grades, and toggle boss grades
  - edit existing jobs. Online holders are refreshed straight away (duty state is kept), and anyone above a removed grade drops to the highest remaining one
  - delete jobs. They are removed from every player's multijob list, and anyone using one (online or offline) becomes unemployed. `unemployed` can't be deleted
  - **Import from Core**: pull in any job another resource registered that isn't managed yet
- Every server callback re-checks admin permission and validates the data, so the NUI is never trusted.
- New webhook events: `JobCreated`, `JobUpdated`, `JobDefinitionDeleted`.
- New exports: `GetJobDefinition(name)` and `GetJobDefinitions()`.

### Migrating from rsg-core jobs.lua

1. Run `install.sql` (the table is also created automatically).
2. In `server.cfg`, start `rsg-multijob` **directly after `rsg-core`** and before your other `rsg-*` job resources.
3. Start the server once so your jobs are imported. You can then trim `rsg-core/shared/jobs.lua` down to just `RSGShared.ForceJobDefaultDutyAtLogin` and the `unemployed` job. Keep those: the duty flag is read by rsg-core itself, and `unemployed` is rsg-core's fallback.

> **Note:** some resources copy `RSGCore.Shared.Jobs` once when they start. A brand-new job created in `/jobadmin` is live in rsg-core and on clients straight away, but such a resource (e.g. a boss menu that reads grade lists) only sees it after that resource is restarted.

## Requirements

- [RSG-Core](https://github.com/Rexshack-RedM) framework
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- `rsg-bossmenu` (optional — only needed for the employee-firing sync feature)

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

Language files live in `locales/*.json`: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro` (plus `it`). The active language follows your server's `ox_lib` locale, e.g. `setr ox:locale "de"` in `server.cfg`.

All player-facing text lives in these files — notifications, command help, every piece of NUI text (`ui_*` keys) and the Discord webhook messages (`wh_*` keys). Nothing is hardcoded in the Lua, HTML or JS. Webhook embed titles are set per event in `config.lua`.

To add a language, copy `locales/en.json`, translate the values (keep each `%s` placeholder), and save it as `locales/<code>.json`.

## Usage

### Player commands

- `/myjobs` — opens the multi-job UI, showing every job the player currently holds. From here a player can:
  - Toggle duty for their active job.
  - Switch their active job to any other job they hold (with a confirmation prompt).
  - Delete a job from their registry (with a confirmation prompt) — if it was their active job, they become `unemployed`.

### Admin commands

- `/removejob [id] [job]` — (requires the `admin` permission) removes the job from the player's multijob list. `id` can be a server ID (online player) or a citizen ID (online or offline). If it was their active job, they become `unemployed`.

### How jobs get added

Jobs are added to a player's multijob list automatically, server-side: whenever RSGCore fires `RSGCore:Server:OnJobUpdate` for the player (for example, being hired through `rsg-bossmenu` or any other script that calls `Player.Functions.SetJob`), this resource records that job (and grade) against the player's `citizenid`, up to `Config.MaxJobs`. If the player is already at their job limit, they'll be notified and the new job won't be added to their list (though RSGCore's own active job may still change, depending on the hiring script).

### Firing employees

If you use `rsg-bossmenu`, firing an employee through it also removes that job from the fired player's multijob registry — whether they're online or offline — as long as the person doing the firing is on that job with a boss grade, and the target's stored grade is not above theirs.

### Exports (for other resources)

`rsg-multijob` exposes server-side exports so other scripts can grant or revoke jobs without going through the UI or duplicating the DB logic. `identifier` accepts either an online player's server id (number) or a `citizenid` (string) — a citizenid works whether the player is online or offline.

```lua
-- Add (or upgrade) a job. grade defaults to 0. bypassMax (optional) skips Config.MaxJobs.
-- Returns: success (boolean), errorReason ('invalid_job' | 'invalid_grade' | 'player_not_found' | 'max_jobs')
local success, err = exports['rsg-multijob']:AddJob(identifier, 'gunsmith', 0, false)

-- Remove a job. If it's the player's active job they become 'unemployed' (online, or saved to the DB if offline).
-- Returns: success (boolean), errorReason ('invalid_job' | 'player_not_found' | 'job_not_held')
local success, err = exports['rsg-multijob']:RemoveJob(identifier, 'gunsmith')

-- Read a player's stored multijob list: array of { job, salary, jobLabel, gradeLabel, grade }
local jobs = exports['rsg-multijob']:GetJobs(identifier)

-- Check (without changing anything) whether a player could take a job. bypassMax is optional.
-- Returns: canTake (boolean), reason ('invalid_job' | 'player_not_found' | 'already_held' | 'max_jobs')
local canTake, reason = exports['rsg-multijob']:CanTakeJob(identifier, 'gunsmith', false)

-- Check whether a player holds a job. Returns: held (boolean), grade (number|nil)
local held, grade = exports['rsg-multijob']:HasJob(identifier, 'gunsmith')

-- Returns: count (number), max (Config.MaxJobs)
local count, max = exports['rsg-multijob']:GetJobCount(identifier)
```

Example — a job-hiring NPC:

```lua
local ok, reason = exports['rsg-multijob']:CanTakeJob(src, 'gunsmith')
if not ok then
    if reason == 'max_jobs' then
        lib.notify(src, { description = 'You already have too many jobs.', type = 'error' })
    elseif reason == 'already_held' then
        lib.notify(src, { description = 'You already work here.', type = 'inform' })
    end
    return
end
exports['rsg-multijob']:AddJob(src, 'gunsmith', 0)
```

A citizenid passed to any export is checked against the `players` table, so an unknown/mistyped citizenid returns `player_not_found` instead of creating an orphan row.

Both `AddJob` and `RemoveJob` push a live UI refresh to the player if they're online, and log to the configured Discord webhook the same way the in-game actions do.

## Support

If you find this useful, you can support development here: https://buymeacoffee.com/rexshack
