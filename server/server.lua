local Config = lib.require('config')
lib.locale()

RSGCore.Commands.Add('myjobs', locale('sv_command_desc'), {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    TriggerClientEvent('rsg-multijob:client:openmenu', src)
end)

RSGCore.Functions.CreateCallback('rsg-multijob:server:checkjobs', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid
    -- Look up allowed jobs; if not defined, use the default Config.MaxJobs.
    local allowedJobs = Config.AllowedMultipleJobs[citizenid] or Config.MaxJobs

    local result = MySQL.query.await('SELECT COUNT(*) as jobCount FROM player_jobs WHERE citizenid = ?', { citizenid })
    local jobCount = result[1].jobCount
    if jobCount < allowedJobs then
        cb(true)
    else
        cb(false)
    end
end)


local function GetJobCount(cid)
    local result = MySQL.query.await('SELECT COUNT(*) as jobCount FROM player_jobs WHERE citizenid = ?', {cid})
    local jobCount = result[1].jobCount
    return jobCount
end

local function CanSetJob(cid, jobName)
    local jobs = MySQL.query.await('SELECT job, grade FROM player_jobs WHERE citizenid = ? ', {cid})
    if not jobs then return false, nil end

    for _, jobData in ipairs(jobs) do
        if jobData.job == jobName then
            return true, jobData.grade
        end
    end
    return false, nil
end

lib.callback.register('rsg-multijob:server:myJobs', function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local storeJobs = {}
    local result = MySQL.query.await('SELECT * FROM player_jobs WHERE citizenid = ?', {Player.PlayerData.citizenid})
    for k, v in pairs(result) do
        local job = RSGCore.Shared.Jobs[v.job]

        if not job then
            return error(('MISSING JOB FROM jobs.lua: "%s" | CITIZEN ID: %s'): format(v.job, Player.PlayerData.citizenid))
        end

        local grade = job.grades[tostring(v.grade)]

        if not grade then
            return error(('MISSING JOB GRADE for "%s". GRADE MISSING: %s | CITIZEN ID: %s'): format(v.job, v.grade, Player.PlayerData.citizenid))
        end

        storeJobs[#storeJobs + 1] = {
            job = v.job,
            salary = grade.payment,
            jobLabel = job.label,
            gradeLabel = grade.name,
            grade = v.grade,
        }
    end
    return storeJobs
end)

RegisterNetEvent('rsg-multijob:server:changeJob', function(job)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if Player.PlayerData.job.name == job then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_current_job_error'), type = 'error', duration = 5000 })
        return 
    end

    local jobInfo = RSGCore.Shared.Jobs[job]
    if not jobInfo then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_invalid_job'), type = 'error', duration = 5000 })
        return
    end

    local cid = Player.PlayerData.citizenid
    local canSet, grade = CanSetJob(cid, job)

    if not canSet then
        return
    end

    Player.Functions.SetJob(job, grade)
    Player.Functions.SetJobDuty(false)
    TriggerClientEvent('RSGCore:Client:SetDuty', src, false)
    TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_job') .. ': ' .. jobInfo.label, type = 'info', duration = 5000 })
end)

RegisterNetEvent('rsg-multijob:server:newJob', function(newJob)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local cid = Player.PlayerData.citizenid
    
    if newJob.name == 'unemployed' then 
        return 
    end
    
    local hasJob = MySQL.query.await('SELECT * FROM player_jobs WHERE citizenid = ? AND job = ?', {cid, newJob.name})
    if hasJob[1] then
        MySQL.query.await('UPDATE player_jobs SET grade = ? WHERE job = ? and citizenid = ?', {newJob.grade.level, newJob.name, cid})
        return
    end
    
    local allowedJobs = Config.AllowedMultipleJobs[cid] or Config.MaxJobs
    if GetJobCount(cid) >= allowedJobs then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_job_max'), type = 'error', duration = 5000 })
        local previousJob = MySQL.query.await('SELECT job, grade FROM player_jobs WHERE citizenid = ? LIMIT 1', {cid})
        if previousJob[1] then
            Player.Functions.SetJob(previousJob[1].job, previousJob[1].grade)
        else
            Player.Functions.SetJob('unemployed', 0)
        end
        return
    end
    

    MySQL.insert.await('INSERT INTO player_jobs (citizenid, job, grade) VALUE (?, ?, ?)', {cid, newJob.name, newJob.grade.level})
end)

RegisterNetEvent('rsg-multijob:server:deleteJob', function(job)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? and job = ?', {Player.PlayerData.citizenid, job})
    TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_job_deleted') .. ' ' .. RSGCore.Shared.Jobs[job].label .. ' '.. locale('sv_job_deleted_2'), type = 'success', duration = 5000 })
    if Player.PlayerData.job.name == job then
        Player.Functions.SetJob('unemployed', 0)
    end
end)

RegisterNetEvent('rsg-bossmenu:server:FireEmployee', function(target) -- Removes job when fired from rsg-bossmenu.
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Employee = RSGCore.Functions.GetPlayerByCitizenId(target)
    if Employee then
        local oldJob = Employee.PlayerData.job.name
        MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', {Employee.PlayerData.citizenid, oldJob})
    else
        local player = MySQL.query.await('SELECT * FROM players WHERE citizenid = ? LIMIT 1', { target })
        if player[1] then
            Employee = player[1]
            Employee.job = json.decode(Employee.job)
            if Employee.job.grade.level > Player.PlayerData.job.grade.level then return end
            MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', {target, Employee.job.name})
        end
    end
end)

local function adminRemoveJob(src, id, job)
    local Player = RSGCore.Functions.GetPlayer(id)
    local cid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT * FROM player_jobs WHERE citizenid = ? AND job = ?', {cid, job})
    if not result[1] then
        return TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_job_specified'), type = 'error', duration = 5000 })
    end
    if result[1] then
        MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', {cid, job})
        TriggerClientEvent('ox_lib:notify', src, {title = ('Job: %s was removed from ID: %s'):format(job, id), type = 'success', duration = 5000 })
        if Player.PlayerData.job.name == job then
            Player.Functions.SetJob('unemployed', 0)
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_job_does'), type = 'error', duration = 5000 })
    end
end

RSGCore.Commands.Add('removejob', locale('sv_command_remove'), { { name = 'id', help = locale('sv_command_r_id')  }, { name = 'job', help = locale('sv_command_r_name') } }, true, function(source, args)
    local src = source
    if not args[1] then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_provide'), type = 'error', duration = 5000 })
        return
    end
    if not args[2] then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_provide_name'), type = 'error', duration = 5000 })
        return
    end
    local id = tonumber(args[1])
    local Player = RSGCore.Functions.GetPlayer(id)
    if not Player then TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_not_online'), type = 'error', duration = 5000 }) return end

    adminRemoveJob(src, id, args[2])
end, 'admin')
