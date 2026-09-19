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

-- Builds the localized UI text table sent to the NUI
local function getUILocales()
    return {
        pageTitle = locale('cl_ui_page_title'),
        myJobs = locale('cl_lang_3'),
        subtitle = locale('cl_ui_subtitle'),
        close = locale('cl_ui_close'),
        back = locale('cl_ui_back'),
        dutyLabel = locale('cl_lang_4'),
        dutyOn = locale('cl_lang_1'),
        dutyOff = locale('cl_lang_2'),
        capacityLabel = locale('cl_ui_capacity_label'),
        maxJobsFooter = locale('cl_ui_max_jobs_footer'),
        jobActions = locale('cl_job_actions'),
        selectAction = locale('cl_ui_select_action'),
        switchJob = locale('cl_switch_job'),
        switchDesc = locale('cl_switch_your_job'),
        deleteJob = locale('cl_delete_job'),
        deleteDesc = locale('cl_delete_selected_job'),
        confirmTitle = locale('cl_ui_confirm_title'),
        confirmText = locale('cl_ui_confirm_text'),
        confirm = locale('cl_ui_confirm'),
        cancel = locale('cl_ui_cancel'),
        noJobsTitle = locale('cl_ui_no_jobs_title'),
        noJobsSub = locale('cl_ui_no_jobs_sub'),
        currentPill = locale('cl_ui_current_pill'),
        grade = locale('cl_lang_grade'),
        salary = locale('cl_lang_salary'),
        switchConfirmTitle = locale('cl_ui_switch_confirm_title'),
        switchConfirmText = locale('cl_ui_switch_confirm_text'),
        deleteConfirmTitle = locale('cl_ui_delete_confirm_title'),
        deleteConfirmText = locale('cl_ui_delete_confirm_text'),
        notice = locale('cl_ui_notice'),
    }
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
        maxJobs = Config.MaxJobs,
        locales = getUILocales()
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
