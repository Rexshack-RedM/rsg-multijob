# RSG-Multijob Exports Documentation

This document describes the available exports for the `rsg-multijob` resource.

## Server Exports

### GetJobCount
Get the number of jobs a player has.

**Parameters:**
- `citizenid` (string) - The citizen ID of the player

**Returns:**
- `number` - The number of jobs the player has

**Example:**
```lua
local jobCount = exports['rsg-multijob']:GetJobCount('ABC12345')
print('Player has ' .. jobCount .. ' jobs')
```

---

### CanTakeNewJob
Check if a player can take a new job based on their max allowed jobs.

**Parameters:**
- `citizenid` (string) - The citizen ID of the player

**Returns:**
- `boolean` - Whether the player can take a new job

**Example:**
```lua
local canTake = exports['rsg-multijob']:CanTakeNewJob('ABC12345')
if canTake then
    print('Player can take a new job')
end
```

---

### HasJob
Check if a player has a specific job.

**Parameters:**
- `citizenid` (string) - The citizen ID of the player
- `jobName` (string) - The name of the job to check

**Returns:**
- `boolean` - Whether the player has the job
- `number|nil` - The grade of the job if the player has it

**Example:**
```lua
local hasJob, grade = exports['rsg-multijob']:HasJob('ABC12345', 'vallaw')
if hasJob then
    print('Player has vallaw job at grade ' .. grade)
end
```

---

### GetPlayerJobs
Get all jobs for a player.

**Parameters:**
- `citizenid` (string) - The citizen ID of the player

**Returns:**
- `table` - Array of job data with the following structure:
  - `job` (string) - Job name
  - `grade` (number) - Job grade
  - `jobLabel` (string) - Job display label
  - `gradeLabel` (string) - Grade display label
  - `salary` (number) - Grade salary

**Example:**
```lua
local jobs = exports['rsg-multijob']:GetPlayerJobs('ABC12345')
for _, jobData in ipairs(jobs) do
    print(jobData.jobLabel .. ' - Grade: ' .. jobData.gradeLabel .. ' - Salary: $' .. jobData.salary)
end
```

---

### AddJobToPlayer
Add a job to a player. If the player already has the job, it will update the grade. Will fail if the player has reached their max job limit.

**Parameters:**
- `citizenid` (string) - The citizen ID of the player
- `jobName` (string) - The name of the job to add
- `grade` (number) - The grade of the job

**Returns:**
- `boolean` - Whether the job was added successfully

**Example:**
```lua
local success = exports['rsg-multijob']:AddJobToPlayer('ABC12345', 'vallaw', 2)
if success then
    print('Job added successfully')
else
    print('Failed to add job - player may have reached max jobs or job is unemployed')
end
```

---

### RemoveJobFromPlayer
Remove a job from a player.

**Parameters:**
- `citizenid` (string) - The citizen ID of the player
- `jobName` (string) - The name of the job to remove

**Returns:**
- `boolean` - Whether the job was removed successfully

**Example:**
```lua
local success = exports['rsg-multijob']:RemoveJobFromPlayer('ABC12345', 'vallaw')
if success then
    print('Job removed successfully')
else
    print('Failed to remove job - player may not have this job')
end
```

---

### GetMaxJobs
Get the maximum number of jobs allowed for a player.

**Parameters:**
- `citizenid` (string) - The citizen ID of the player

**Returns:**
- `number` - The maximum number of jobs allowed for the player

**Example:**
```lua
local maxJobs = exports['rsg-multijob']:GetMaxJobs('ABC12345')
print('Player can have up to ' .. maxJobs .. ' jobs')
```

---

## Client Exports

### OpenMultijobMenu
Open the multijob menu for the local player.

**Parameters:** None

**Returns:** None

**Example:**
```lua
exports['rsg-multijob']:OpenMultijobMenu()
```

---

## Usage in Other Resources

To use these exports in your own resources, simply call them using the `exports` global:

**Server-side:**
```lua
-- In your server script
RegisterCommand('checkjobs', function(source, args)
    local Player = RSGCore.Functions.GetPlayer(source)
    local jobs = exports['rsg-multijob']:GetPlayerJobs(Player.PlayerData.citizenid)
    print(json.encode(jobs, {indent = true}))
end)
```

**Client-side:**
```lua
-- In your client script
RegisterCommand('openjobs', function()
    exports['rsg-multijob']:OpenMultijobMenu()
end)
```
