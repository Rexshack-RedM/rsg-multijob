local Config = lib.require('config')
lib.locale()

--- Returns the number of jobs stored for a citizenid.
local function GetJobCount(cid)
    local result = MySQL.query.await('SELECT COUNT(*) as jobCount FROM player_jobs WHERE citizenid = ?', { cid })
    return result[1] and result[1].jobCount or 0
end

--- Returns the max number of jobs a citizenid is allowed to hold.
local function GetAllowedJobs(cid)
    return Config.AllowedMultipleJobs[cid] or Config.MaxJobs
end

--- Checks whether a citizenid already has jobName stored, returning its grade if so.
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

RSGCore.Commands.Add('myjobs', locale('sv_command_desc'), {}, false, function(source)
    TriggerClientEvent('rsg-multijob:client:openmenu', source)
end)

lib.callback.register('rsg-multijob:server:myJobs', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return {} end

    local storeJobs = {}
    local result = MySQL.query.await('SELECT * FROM player_jobs WHERE citizenid = ?', { Player.PlayerData.citizenid })

    for _, v in ipairs(result) do
        local job = RSGCore.Shared.Jobs[v.job]
        if not job then
            print(('[rsg-multijob] Skipping missing job from jobs.lua: "%s" | Citizen ID: %s'):format(v.job, Player.PlayerData.citizenid))
            goto continue
        end

        local grade = job.grades[tostring(v.grade)]
        if not grade then
            print(('[rsg-multijob] Skipping missing job grade for "%s". Grade: %s | Citizen ID: %s'):format(v.job, v.grade, Player.PlayerData.citizenid))
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
end)

RegisterNetEvent('rsg-multijob:server:changeJob', function(job)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(job) ~= 'string' then return end

    if Player.PlayerData.job.name == job then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_current_job_error'), type = 'error', duration = 5000 })
        return
    end

    local jobInfo = RSGCore.Shared.Jobs[job]
    if not jobInfo then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_invalid_job'), type = 'error', duration = 5000 })
        return
    end

    local cid = Player.PlayerData.citizenid
    local canSet, grade = CanSetJob(cid, job)

    if not canSet then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_job_specified'), type = 'error', duration = 5000 })
        return
    end

    Player.Functions.SetJob(job, grade)
    Player.Functions.SetJobDuty(false)
    TriggerClientEvent('RSGCore:Client:SetDuty', src, false)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_job') .. ': ' .. jobInfo.label, type = 'info', duration = 5000 })

    WebhookLog.JobSwitched(src, Player, jobInfo.label)
end)

-- Fires when the player's active job changes (RSGCore:Client:OnJobUpdate -> here).
-- IMPORTANT: newJob is client-supplied, so it is only ever trusted to describe
-- the job/grade the server itself just assigned to this player (Player.PlayerData.job).
-- Never take newJob.name/newJob.grade at face value, or any player can grant
-- themselves an arbitrary job + grade by firing this event manually.
RegisterNetEvent('rsg-multijob:server:newJob', function(newJob)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(newJob) ~= 'table' or type(newJob.name) ~= 'string' then return end

    if newJob.name == 'unemployed' then return end

    -- Only trust this update if it matches the player's actual, server-authoritative job.
    local activeJob = Player.PlayerData.job
    if not activeJob or activeJob.name ~= newJob.name then return end

    local gradeLevel = activeJob.grade and activeJob.grade.level
    if gradeLevel == nil then return end

    local jobInfo = RSGCore.Shared.Jobs[newJob.name]
    if not jobInfo or not jobInfo.grades[tostring(gradeLevel)] then return end

    local cid = Player.PlayerData.citizenid

    local hasJob = MySQL.query.await('SELECT 1 FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, newJob.name })
    if hasJob[1] then
        MySQL.query.await('UPDATE player_jobs SET grade = ? WHERE job = ? AND citizenid = ?', { gradeLevel, newJob.name, cid })
        return
    end

    local allowedJobs = GetAllowedJobs(cid)
    if GetJobCount(cid) >= allowedJobs then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_job_max'), type = 'error', duration = 5000 })
        WebhookLog.JobMaxReached(src, Player, jobInfo.label, allowedJobs)

        local previousJob = MySQL.query.await('SELECT job, grade FROM player_jobs WHERE citizenid = ? LIMIT 1', { cid })
        if previousJob[1] then
            Player.Functions.SetJob(previousJob[1].job, previousJob[1].grade)
        else
            Player.Functions.SetJob('unemployed', 0)
        end
        return
    end

    MySQL.insert.await('INSERT INTO player_jobs (citizenid, job, grade) VALUES (?, ?, ?)', { cid, newJob.name, gradeLevel })
    WebhookLog.JobAdded(src, Player, jobInfo.label, jobInfo.grades[tostring(gradeLevel)].name)
end)

RegisterNetEvent('rsg-multijob:server:deleteJob', function(job)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(job) ~= 'string' then return end

    local jobInfo = RSGCore.Shared.Jobs[job]
    if not jobInfo then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_invalid_job'), type = 'error', duration = 5000 })
        return
    end

    local cid = Player.PlayerData.citizenid
    local existing = MySQL.query.await('SELECT 1 FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, job })
    if not existing[1] then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_job_specified'), type = 'error', duration = 5000 })
        return
    end

    MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, job })
    TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_job_deleted') .. ' ' .. jobInfo.label .. ' ' .. locale('sv_job_deleted_2'), type = 'success', duration = 5000 })
    WebhookLog.JobDeleted(src, Player, jobInfo.label)

    if Player.PlayerData.job.name == job then
        Player.Functions.SetJob('unemployed', 0)
    end
end)

-- Removes a multijob entry when a player is fired from rsg-bossmenu.
RegisterNetEvent('rsg-bossmenu:server:FireEmployee', function(target)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local Employee = RSGCore.Functions.GetPlayerByCitizenId(target)
    if Employee then
        local oldJob = Employee.PlayerData.job.name
        if Employee.PlayerData.job.grade.level > Player.PlayerData.job.grade.level then return end
        MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { Employee.PlayerData.citizenid, oldJob })
        WebhookLog.EmployeeFired(src, Employee.PlayerData.citizenid, oldJob)
        return
    end

    local players = MySQL.query.await('SELECT job FROM players WHERE citizenid = ? LIMIT 1', { target })
    local offlinePlayer = players[1]
    if not offlinePlayer then return end

    local ok, jobData = pcall(json.decode, offlinePlayer.job)
    if not ok or not jobData or not jobData.name then return end
    if jobData.grade.level > Player.PlayerData.job.grade.level then return end

    MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { target, jobData.name })
    WebhookLog.EmployeeFired(src, target, jobData.name)
end)

local function adminRemoveJob(src, id, job)
    local Player = RSGCore.Functions.GetPlayer(id)
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_not_online'), type = 'error', duration = 5000 })
        return
    end

    local cid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT 1 FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, job })
    if not result[1] then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_job_specified'), type = 'error', duration = 5000 })
        return
    end

    MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, job })
    TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_job_removed_admin'):format(job, id), type = 'success', duration = 5000 })
    WebhookLog.AdminRemove(src, id, cid, job)

    if Player.PlayerData.job.name == job then
        Player.Functions.SetJob('unemployed', 0)
    end
end

RSGCore.Commands.Add('removejob', locale('sv_command_remove'), {
    { name = 'id', help = locale('sv_command_r_id') },
    { name = 'job', help = locale('sv_command_r_name') },
}, true, function(source, args)
    local src = source
    if not args[1] then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_provide'), type = 'error', duration = 5000 })
        return
    end
    if not args[2] then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_provide_name'), type = 'error', duration = 5000 })
        return
    end

    local id = tonumber(args[1])
    if not id or not RSGCore.Functions.GetPlayer(id) then
        TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_not_online'), type = 'error', duration = 5000 })
        return
    end

    adminRemoveJob(src, id, args[2])
end, 'admin')
