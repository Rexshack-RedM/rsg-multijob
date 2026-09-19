local Config = lib.require('config')
lib.locale()

-- citizenid -> timestamp (ms) the player may next switch jobs
local switchCooldowns = {}

RSGCore.Commands.Add('myjobs', locale('sv_command_desc'), {}, false, function(source)
    local src = source
    TriggerClientEvent('rsg-multijob:client:openmenu', src)
end)

local function GetJobCount(cid)
    local result = MySQL.query.await('SELECT COUNT(*) as jobCount FROM player_jobs WHERE citizenid = ?', { cid })
    return result[1] and result[1].jobCount or 0
end

local function CanSetJob(cid, jobName)
    local jobs = MySQL.query.await('SELECT job, grade FROM player_jobs WHERE citizenid = ?', { cid })
    if not jobs then return false, nil end

    for _, jobData in ipairs(jobs) do
        if jobData.job == jobName then
            return true, jobData.grade
        end
    end
    return false, nil
end

-- Returns whether `src` currently holds a boss-grade in `jobName`
local function IsBossOf(Player, jobName)
    if not Player or Player.PlayerData.job.name ~= jobName then return false end

    local job = RSGCore.Shared.Jobs[jobName]
    if not job then return false end

    local grade = job.grades[tostring(Player.PlayerData.job.grade.level)]
    return grade ~= nil and grade.isboss == true
end

-- Builds the { job, salary, jobLabel, gradeLabel, grade } list for a player's stored jobs
local function BuildJobList(citizenid)
    local storeJobs = {}
    local result = MySQL.query.await('SELECT * FROM player_jobs WHERE citizenid = ?', { citizenid })

    for _, v in ipairs(result) do
        local job = RSGCore.Shared.Jobs[v.job]

        if not job then
            print(('[rsg-multijob] WARNING: Missing job from jobs.lua: "%s" | Citizen ID: %s'):format(v.job, citizenid))
            goto continue
        end

        local grade = job.grades[tostring(v.grade)]

        if not grade then
            print(('[rsg-multijob] WARNING: Missing grade %s for job "%s" | Citizen ID: %s'):format(v.grade, v.job, citizenid))
            goto continue
        end

        storeJobs[#storeJobs + 1] = {
            job = v.job,
            salary = grade.payment,
            jobLabel = job.label,
            gradeLabel = grade.name,
            grade = v.grade,
        }

        ::continue::
    end
    return storeJobs
end

-- Pushes the current job list straight to the client, instead of the client
-- blind-waiting a fixed delay and re-fetching (avoids a race with the DB write).
local function PushJobs(src, Player)
    TriggerClientEvent('rsg-multijob:client:refreshJobs', src, BuildJobList(Player.PlayerData.citizenid), Player.PlayerData.job.name)
end

RSGCore.Functions.CreateCallback('rsg-multijob:server:checkjobs', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end

    cb(GetJobCount(Player.PlayerData.citizenid) < Config.MaxJobs)
end)

lib.callback.register('rsg-multijob:server:myJobs', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return {} end

    return BuildJobList(Player.PlayerData.citizenid)
end)

RegisterNetEvent('rsg-multijob:server:changeJob', function(job)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if type(job) ~= 'string' then return end

    local cid = Player.PlayerData.citizenid
    local now = GetGameTimer()
    local readyAt = switchCooldowns[cid]

    if readyAt and now < readyAt then
        local secondsLeft = math.ceil((readyAt - now) / 1000)
        TriggerClientEvent('rNotify:NotifyLeft', src, "ON COOLDOWN", ("You can switch jobs again in %ss"):format(secondsLeft), "generic_textures", "tick", 5000)
        return
    end

    if Player.PlayerData.job.name == job then
        TriggerClientEvent('rNotify:NotifyLeft', src, "CURRENT JOB", "You are already working this job", "generic_textures", "tick", 5000)
        return
    end

    local jobInfo = RSGCore.Shared.Jobs[job]
    if not jobInfo then
        TriggerClientEvent('rNotify:NotifyLeft', src, "INVALID JOB", "This job does not exist", "generic_textures", "tick", 5000)
        return
    end

    local canSet, grade = CanSetJob(cid, job)

    if not canSet then
        TriggerClientEvent('rNotify:NotifyLeft', src, "ERROR", "You do not hold this job", "generic_textures", "tick", 5000)
        return
    end

    local gradeInfo = jobInfo.grades[tostring(grade)]
    if not gradeInfo then
        TriggerClientEvent('rNotify:NotifyLeft', src, "ERROR", "Invalid grade for this job", "generic_textures", "tick", 5000)
        return
    end

    switchCooldowns[cid] = now + (Config.JobSwitchCooldown or 3000)

    Player.Functions.SetJob(job, grade)
    Player.Functions.SetJobDuty(false)
    TriggerClientEvent('RSGCore:Client:SetDuty', src, false)
    TriggerClientEvent('rNotify:NotifyLeft', src, "JOB CHANGED", "Current Job: " .. jobInfo.label, "generic_textures", "tick", 5000)
    PushJobs(src, Player)
end)

RegisterNetEvent('rsg-multijob:server:newJob', function(newJob)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not newJob or not newJob.name or newJob.name == 'unemployed' then return end
    if not RSGCore.Shared.Jobs[newJob.name] then return end

    local cid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT * FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, newJob.name })

    if result[1] then
        MySQL.query.await('UPDATE player_jobs SET grade = ? WHERE job = ? AND citizenid = ?', { newJob.grade.level, newJob.name, cid })
        PushJobs(src, Player)
        return
    end

    if GetJobCount(cid) >= Config.MaxJobs then
        TriggerClientEvent('rNotify:NotifyLeft', src, "MAX JOBS", "You have reached the maximum number of jobs", "generic_textures", "tick", 5000)
        return
    end

    MySQL.insert.await('INSERT INTO player_jobs (citizenid, job, grade) VALUES (?, ?, ?)', { cid, newJob.name, newJob.grade.level })
    PushJobs(src, Player)
end)

RegisterNetEvent('rsg-multijob:server:deleteJob', function(job)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if type(job) ~= 'string' then return end

    local canSet = CanSetJob(Player.PlayerData.citizenid, job)
    if not canSet then
        TriggerClientEvent('rNotify:NotifyLeft', src, "ERROR", "You do not hold this job", "generic_textures", "tick", 5000)
        return
    end

    MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { Player.PlayerData.citizenid, job })

    local jobInfo = RSGCore.Shared.Jobs[job]
    TriggerClientEvent('rNotify:NotifyLeft', src, "JOB DELETED", "You have removed " .. (jobInfo and jobInfo.label or job) .. " from your jobs", "generic_textures", "tick", 5000)

    if Player.PlayerData.job.name == job then
        Player.Functions.SetJob('unemployed', 0)
    end

    PushJobs(src, Player)
end)

-- NOTE: this listens for rsg-bossmenu's fire event so multijob stays in sync with it.
-- Only a caller who actually holds a boss-grade in the target's job may fire them.
RegisterNetEvent('rsg-bossmenu:server:FireEmployee', function(target)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local Employee = RSGCore.Functions.GetPlayerByCitizenId(target)

    if Employee then
        local oldJob = Employee.PlayerData.job.name

        if not IsBossOf(Player, oldJob) then return end
        if Employee.PlayerData.job.grade.level > Player.PlayerData.job.grade.level then return end

        MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { Employee.PlayerData.citizenid, oldJob })
        Employee.Functions.SetJob('unemployed', 0)
        PushJobs(Employee.PlayerData.source, Employee)
    else
        local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ? LIMIT 1', { target })
        if not player[1] then return end

        local offlineJob = json.decode(player[1].job)

        if not IsBossOf(Player, offlineJob.name) then return end
        if offlineJob.grade.level > Player.PlayerData.job.grade.level then return end

        MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { target, offlineJob.name })
    end
end)

local function adminRemoveJob(src, id, job)
    local Player = RSGCore.Functions.GetPlayer(id)
    if not Player then
        TriggerClientEvent('rNotify:NotifyLeft', src, "ERROR", "Player not online", "generic_textures", "tick", 5000)
        return
    end

    local cid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT * FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, job })

    if not result[1] then
        TriggerClientEvent('rNotify:NotifyLeft', src, "ERROR", "Job not found for specified player", "generic_textures", "tick", 5000)
        return
    end

    MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, job })
    TriggerClientEvent('rNotify:NotifyLeft', src, "JOB REMOVED", "Job: " .. job .. " was removed from ID: " .. id, "generic_textures", "tick", 5000)

    if Player.PlayerData.job.name == job then
        Player.Functions.SetJob('unemployed', 0)
    end

    PushJobs(id, Player)
end

RSGCore.Commands.Add('removejob', locale('sv_command_remove'), { { name = 'id', help = locale('sv_command_r_id') }, { name = 'job', help = locale('sv_command_r_name') } }, true, function(source, args)
    local src = source

    if not args[1] then
        TriggerClientEvent('rNotify:NotifyLeft', src, "ERROR", "Please provide an ID", "generic_textures", "tick", 5000)
        return
    end

    if not args[2] then
        TriggerClientEvent('rNotify:NotifyLeft', src, "ERROR", "Please provide a job name", "generic_textures", "tick", 5000)
        return
    end

    local id = tonumber(args[1])
    if not id then
        TriggerClientEvent('rNotify:NotifyLeft', src, "ERROR", "Invalid ID", "generic_textures", "tick", 5000)
        return
    end

    local Player = RSGCore.Functions.GetPlayer(id)

    if not Player then
        TriggerClientEvent('rNotify:NotifyLeft', src, "ERROR", "Player not online", "generic_textures", "tick", 5000)
        return
    end

    adminRemoveJob(src, id, args[2])
end, 'admin')

AddEventHandler('playerDropped', function()
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then switchCooldowns[Player.PlayerData.citizenid] = nil end
end)
