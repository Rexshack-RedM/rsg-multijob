local Config = lib.require('config')
lib.locale()

local isUIOpen = false

local function withIcons(jobs)
    if jobs then
        for _, job in ipairs(jobs) do
            job.icon = Config.JobIcons[job.job] or 'fa-solid fa-briefcase'
        end
    end
    return jobs or {}
end

-- Open the multijob UI
local function showMultijob()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    local myJobs = withIcons(lib.callback.await('rsg-multijob:server:myJobs', false))

    SetNuiFocus(true, true)
    isUIOpen = true

    SendNUIMessage({
        action = 'open',
        jobs = myJobs,
        currentJob = PlayerData.job.name,
        onDuty = PlayerData.job.onduty,
        maxJobs = Config.MaxJobs
    })
end

-- Close UI callback
RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    isUIOpen = false
    cb('ok')
end)

-- Toggle duty callback
RegisterNUICallback('toggleDuty', function(data, cb)
    TriggerServerEvent('RSGCore:ToggleDuty')
    cb('ok')
end)

-- Switch job callback
RegisterNUICallback('switchJob', function(data, cb)
    TriggerServerEvent('rsg-multijob:server:changeJob', data.job)
    cb('ok')
end)

-- Delete job callback
RegisterNUICallback('deleteJob', function(data, cb)
    TriggerServerEvent('rsg-multijob:server:deleteJob', data.job)
    cb('ok')
end)

-- Event to open menu
RegisterNetEvent('rsg-multijob:client:openmenu', function()
    showMultijob()
end)

-- Server pushes the up-to-date job list after any change (switch/add/delete/fire),
-- instead of the client guessing a delay and re-fetching.
RegisterNetEvent('rsg-multijob:client:refreshJobs', function(myJobs, currentJobName)
    if not isUIOpen then return end

    SendNUIMessage({
        action = 'refreshJobs',
        jobs = withIcons(myJobs),
        currentJob = currentJobName
    })
end)

-- Update job event
RegisterNetEvent('RSGCore:Client:OnJobUpdate', function(JobInfo)
    TriggerServerEvent('rsg-multijob:server:newJob', JobInfo)

    if isUIOpen then
        SendNUIMessage({
            action = 'updateDuty',
            onDuty = JobInfo.onduty
        })
    end
end)

-- Close UI on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        SetNuiFocus(false, false)
    end
end)
