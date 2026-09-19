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

-- Best-effort display name for webhook logs: falls back to the Rockstar/account
-- name if charinfo isn't populated (e.g. an offline citizenid lookup elsewhere).
local function GetCharName(Player)
    if not Player then return 'Unknown' end

    local info = Player.PlayerData.charinfo
    if info and (info.firstname or info.lastname) then
        return (('%s %s'):format(info.firstname or '', info.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    end

    return GetPlayerName(Player.PlayerData.source) or 'Unknown'
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
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_cooldown'), locale('sv_cooldown_desc'):format(secondsLeft), "generic_textures", "tick", 5000)
        return
    end

    if Player.PlayerData.job.name == job then
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_current_job'), locale('sv_current_job_error'), "generic_textures", "tick", 5000)
        return
    end

    local jobInfo = RSGCore.Shared.Jobs[job]
    if not jobInfo then
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_invalid_job'), locale('sv_invalid_job_desc'), "generic_textures", "tick", 5000)
        return
    end

    local canSet, grade = CanSetJob(cid, job)

    if not canSet then
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_error'), locale('sv_not_hold_job'), "generic_textures", "tick", 5000)
        return
    end

    local gradeInfo = jobInfo.grades[tostring(grade)]
    if not gradeInfo then
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_error'), locale('sv_invalid_grade'), "generic_textures", "tick", 5000)
        return
    end

    switchCooldowns[cid] = now + (Config.JobSwitchCooldown or 3000)

    Player.Functions.SetJob(job, grade)
    Player.Functions.SetJobDuty(false)
    TriggerClientEvent('RSGCore:Client:SetDuty', src, false)
    TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_job_changed'), locale('sv_job') .. ': ' .. jobInfo.label, "generic_textures", "tick", 5000)

    Webhook.Send('JobSwitched', {
        description = ('**%s** switched their active job to **%s**.'):format(GetCharName(Player), jobInfo.label),
        fields = {
            { name = 'Player', value = ('%s (`%s`)'):format(GetCharName(Player), cid), inline = true },
            { name = 'Server ID', value = tostring(src), inline = true },
            { name = 'New Job', value = ('%s — %s'):format(jobInfo.label, gradeInfo.name), inline = true },
        }
    })

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
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_max_jobs'), locale('sv_job_max'), "generic_textures", "tick", 5000)
        return
    end

    MySQL.insert.await('INSERT INTO player_jobs (citizenid, job, grade) VALUES (?, ?, ?)', { cid, newJob.name, newJob.grade.level })

    Webhook.Send('JobAdded', {
        description = ('**%s** was granted the job **%s**.'):format(GetCharName(Player), RSGCore.Shared.Jobs[newJob.name].label),
        fields = {
            { name = 'Player', value = ('%s (`%s`)'):format(GetCharName(Player), cid), inline = true },
            { name = 'Server ID', value = tostring(src), inline = true },
            { name = 'Job', value = ('%s — %s'):format(RSGCore.Shared.Jobs[newJob.name].label, newJob.grade.name or tostring(newJob.grade.level)), inline = true },
        }
    })

    PushJobs(src, Player)
end)

RegisterNetEvent('rsg-multijob:server:deleteJob', function(job)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if type(job) ~= 'string' then return end

    local canSet = CanSetJob(Player.PlayerData.citizenid, job)
    if not canSet then
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_error'), locale('sv_not_hold_job'), "generic_textures", "tick", 5000)
        return
    end

    MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { Player.PlayerData.citizenid, job })

    local jobInfo = RSGCore.Shared.Jobs[job]
    TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_job_deleted'), locale('sv_job_deleted') .. ' ' .. (jobInfo and jobInfo.label or job) .. ' ' .. locale('sv_job_deleted_2'), "generic_textures", "tick", 5000)

    Webhook.Send('JobDeleted', {
        description = ('**%s** removed the job **%s** from their own menu.'):format(GetCharName(Player), jobInfo and jobInfo.label or job),
        fields = {
            { name = 'Player', value = ('%s (`%s`)'):format(GetCharName(Player), Player.PlayerData.citizenid), inline = true },
            { name = 'Server ID', value = tostring(src), inline = true },
            { name = 'Job', value = jobInfo and jobInfo.label or job, inline = true },
        }
    })

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

        local jobInfo = RSGCore.Shared.Jobs[oldJob]
        Webhook.Send('EmployeeFired', {
            description = ('**%s** fired **%s** from **%s**.'):format(GetCharName(Player), GetCharName(Employee), jobInfo and jobInfo.label or oldJob),
            fields = {
                { name = 'Fired By', value = ('%s (`%s`)'):format(GetCharName(Player), Player.PlayerData.citizenid), inline = true },
                { name = 'Employee', value = ('%s (`%s`)'):format(GetCharName(Employee), Employee.PlayerData.citizenid), inline = true },
                { name = 'Job', value = jobInfo and jobInfo.label or oldJob, inline = true },
            }
        })

        PushJobs(Employee.PlayerData.source, Employee)
    else
        local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ? LIMIT 1', { target })
        if not player[1] then return end

        local offlineJob = json.decode(player[1].job)

        if not IsBossOf(Player, offlineJob.name) then return end
        if offlineJob.grade.level > Player.PlayerData.job.grade.level then return end

        MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { target, offlineJob.name })

        local jobInfo = RSGCore.Shared.Jobs[offlineJob.name]
        local offlineCharName = (player[1].charinfo and json.decode(player[1].charinfo)) or nil
        Webhook.Send('EmployeeFired', {
            description = ('**%s** fired an offline employee from **%s**.'):format(GetCharName(Player), jobInfo and jobInfo.label or offlineJob.name),
            fields = {
                { name = 'Fired By', value = ('%s (`%s`)'):format(GetCharName(Player), Player.PlayerData.citizenid), inline = true },
                { name = 'Employee', value = ('`%s`%s'):format(target, offlineCharName and (' (' .. (offlineCharName.firstname or '') .. ' ' .. (offlineCharName.lastname or '') .. ')') or ''), inline = true },
                { name = 'Job', value = jobInfo and jobInfo.label or offlineJob.name, inline = true },
            }
        })
    end
end)

local function adminRemoveJob(src, id, job)
    local Player = RSGCore.Functions.GetPlayer(id)
    if not Player then
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_error'), locale('sv_not_online'), "generic_textures", "tick", 5000)
        return
    end

    local cid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT * FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, job })

    if not result[1] then
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_error'), locale('sv_job_specified'), "generic_textures", "tick", 5000)
        return
    end

    MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', { cid, job })
    TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_job_removed'), locale('sv_job_removed_desc'):format(job, id), "generic_textures", "tick", 5000)

    local AdminPlayer = RSGCore.Functions.GetPlayer(src)
    local jobInfo = RSGCore.Shared.Jobs[job]
    Webhook.Send('JobRemovedByAdmin', {
        description = ('An admin removed the job **%s** from **%s**.'):format(jobInfo and jobInfo.label or job, GetCharName(Player)),
        fields = {
            { name = 'Admin', value = AdminPlayer and ('%s (`%s`)'):format(GetCharName(AdminPlayer), AdminPlayer.PlayerData.citizenid) or ('Server ID `%s`'):format(tostring(src)), inline = true },
            { name = 'Target Player', value = ('%s (`%s`) — ID %s'):format(GetCharName(Player), cid, tostring(id)), inline = true },
            { name = 'Job', value = jobInfo and jobInfo.label or job, inline = true },
        }
    })

    if Player.PlayerData.job.name == job then
        Player.Functions.SetJob('unemployed', 0)
    end

    PushJobs(id, Player)
end

RSGCore.Commands.Add('removejob', locale('sv_command_remove'), { { name = 'id', help = locale('sv_command_r_id') }, { name = 'job', help = locale('sv_command_r_name') } }, true, function(source, args)
    local src = source

    if not args[1] then
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_error'), locale('sv_provide'), "generic_textures", "tick", 5000)
        return
    end

    if not args[2] then
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_error'), locale('sv_provide_name'), "generic_textures", "tick", 5000)
        return
    end

    local id = tonumber(args[1])
    if not id then
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_error'), locale('sv_invalid_id'), "generic_textures", "tick", 5000)
        return
    end

    local Player = RSGCore.Functions.GetPlayer(id)

    if not Player then
        TriggerClientEvent('rNotify:NotifyLeft', src, locale('sv_title_error'), locale('sv_not_online'), "generic_textures", "tick", 5000)
        return
    end

    adminRemoveJob(src, id, args[2])
end, 'admin')

AddEventHandler('playerDropped', function()
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then switchCooldowns[Player.PlayerData.citizenid] = nil end
end)
