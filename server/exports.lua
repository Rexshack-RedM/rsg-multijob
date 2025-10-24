-- Server Exports for rsg-multijob

-- Get the number of jobs a player has
-- @param citizenid string - The citizen ID of the player
-- @return number - The number of jobs the player has
exports('GetJobCount', function(citizenid)
    local result = MySQL.query.await('SELECT COUNT(*) as jobCount FROM player_jobs WHERE citizenid = ?', {citizenid})
    return result[1].jobCount or 0
end)

-- Check if a player can take a new job
-- @param citizenid string - The citizen ID of the player
-- @return boolean - Whether the player can take a new job
exports('CanTakeNewJob', function(citizenid)
    local Config = lib.require('config')
    local allowedJobs = Config.AllowedMultipleJobs[citizenid] or Config.MaxJobs
    local result = MySQL.query.await('SELECT COUNT(*) as jobCount FROM player_jobs WHERE citizenid = ?', {citizenid})
    local jobCount = result[1].jobCount or 0
    return jobCount < allowedJobs
end)

-- Check if a player has a specific job
-- @param citizenid string - The citizen ID of the player
-- @param jobName string - The name of the job to check
-- @return boolean - Whether the player has the job
-- @return number|nil - The grade of the job if the player has it
exports('HasJob', function(citizenid, jobName)
    local jobs = MySQL.query.await('SELECT job, grade FROM player_jobs WHERE citizenid = ?', {citizenid})
    if not jobs then return false, nil end
    
    for _, jobData in ipairs(jobs) do
        if jobData.job == jobName then
            return true, jobData.grade
        end
    end
    return false, nil
end)

-- Get all jobs for a player
-- @param citizenid string - The citizen ID of the player
-- @return table - Array of job data with job name, grade, label, and salary
exports('GetPlayerJobs', function(citizenid)
    local storeJobs = {}
    local result = MySQL.query.await('SELECT * FROM player_jobs WHERE citizenid = ?', {citizenid})
    
    for k, v in pairs(result) do
        local job = RSGCore.Shared.Jobs[v.job]
        if job then
            local grade = job.grades[tostring(v.grade)]
            if grade then
                storeJobs[#storeJobs + 1] = {
                    job = v.job,
                    salary = grade.payment,
                    jobLabel = job.label,
                    gradeLabel = grade.name,
                    grade = v.grade,
                }
            end
        end
    end
    return storeJobs
end)

-- Add a job to a player
-- @param citizenid string - The citizen ID of the player
-- @param jobName string - The name of the job to add
-- @param grade number - The grade of the job
-- @return boolean - Whether the job was added successfully
exports('AddJobToPlayer', function(citizenid, jobName, grade)
    local Config = lib.require('config')
    
    if jobName == 'unemployed' then 
        return false 
    end
    
    -- Check if player already has this job
    local hasJob = MySQL.query.await('SELECT * FROM player_jobs WHERE citizenid = ? AND job = ?', {citizenid, jobName})
    if hasJob[1] then
        -- Update grade if job exists
        MySQL.query.await('UPDATE player_jobs SET grade = ? WHERE job = ? and citizenid = ?', {grade, jobName, citizenid})
        return true
    end
    
    -- Check if player can take more jobs
    local allowedJobs = Config.AllowedMultipleJobs[citizenid] or Config.MaxJobs
    local result = MySQL.query.await('SELECT COUNT(*) as jobCount FROM player_jobs WHERE citizenid = ?', {citizenid})
    local jobCount = result[1].jobCount or 0
    
    if jobCount >= allowedJobs then
        return false
    end
    
    -- Add the job
    MySQL.insert.await('INSERT INTO player_jobs (citizenid, job, grade) VALUE (?, ?, ?)', {citizenid, jobName, grade})
    return true
end)

-- Remove a job from a player
-- @param citizenid string - The citizen ID of the player
-- @param jobName string - The name of the job to remove
-- @return boolean - Whether the job was removed successfully
exports('RemoveJobFromPlayer', function(citizenid, jobName)
    local result = MySQL.query.await('SELECT * FROM player_jobs WHERE citizenid = ? AND job = ?', {citizenid, jobName})
    if not result[1] then
        return false
    end
    
    MySQL.query.await('DELETE FROM player_jobs WHERE citizenid = ? AND job = ?', {citizenid, jobName})
    return true
end)

-- Get max allowed jobs for a player
-- @param citizenid string - The citizen ID of the player
-- @return number - The maximum number of jobs allowed for the player
exports('GetMaxJobs', function(citizenid)
    local Config = lib.require('config')
    return Config.AllowedMultipleJobs[citizenid] or Config.MaxJobs
end)
