local Config = lib.require('config')
lib.locale()

local isUIOpen = false
local uiLocales -- built once, locales don't change at runtime

local function withIcons(jobs)
    jobs = jobs or {}
    for _, job in ipairs(jobs) do
        job.icon = Config.JobIcons[job.job] or 'fa-solid fa-briefcase'
    end
    return jobs
end

-- Every ui_* key in locales/<lang>.json is sent to the NUI, so new UI text
-- only needs adding to the locale files.
local UI_KEYS = {
    'ui_page_title', 'ui_my_jobs', 'ui_subtitle', 'ui_close', 'ui_back', 'ui_drag_hint',
    'ui_duty_label', 'ui_on_duty', 'ui_off_duty', 'ui_capacity_label', 'ui_max_jobs_footer',
    'ui_job_actions', 'ui_select_action', 'ui_switch_job', 'ui_switch_desc', 'ui_delete_job',
    'ui_delete_desc', 'ui_confirm_title', 'ui_confirm_text', 'ui_confirm', 'ui_cancel',
    'ui_no_jobs_title', 'ui_no_jobs_sub', 'ui_current_pill', 'ui_grade', 'ui_salary',
    'ui_switch_confirm_title', 'ui_switch_confirm_text', 'ui_delete_confirm_title', 'ui_delete_confirm_text',
}

local function getUILocales()
    if uiLocales then return uiLocales end

    uiLocales = {}
    for _, key in ipairs(UI_KEYS) do
        uiLocales[key] = locale(key)
    end
    return uiLocales
end

local function closeUI()
    isUIOpen = false
    SetNuiFocus(false, false)
end

local function openUI()
    if isUIOpen then return end

    local PlayerData = RSGCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then return end

    isUIOpen = true
    local jobs = withIcons(lib.callback.await('rsg-multijob:server:myJobs', false))
    if not isUIOpen then return end -- closed while waiting

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        jobs = jobs,
        currentJob = PlayerData.job.name,
        onDuty = PlayerData.job.onduty,
        maxJobs = Config.MaxJobs,
        locales = getUILocales(),
    })
end

RegisterNUICallback('closeUI', function(_, cb)
    closeUI()
    cb('ok')
end)

RegisterNUICallback('toggleDuty', function(_, cb)
    TriggerServerEvent('RSGCore:ToggleDuty')
    cb('ok')
end)

RegisterNUICallback('switchJob', function(data, cb)
    if type(data) == 'table' and type(data.job) == 'string' then
        TriggerServerEvent('rsg-multijob:server:changeJob', data.job)
    end
    cb('ok')
end)

RegisterNUICallback('deleteJob', function(data, cb)
    if type(data) == 'table' and type(data.job) == 'string' then
        TriggerServerEvent('rsg-multijob:server:deleteJob', data.job)
    end
    cb('ok')
end)

RegisterNetEvent('rsg-multijob:client:openmenu', openUI)

-- Server pushes the up-to-date list after any change (switch/add/delete/fire)
RegisterNetEvent('rsg-multijob:client:refreshJobs', function(jobs, currentJobName)
    if not isUIOpen then return end

    SendNUIMessage({
        action = 'refreshJobs',
        jobs = withIcons(jobs),
        currentJob = currentJobName,
    })
end)

-- Keep the duty indicator live while the menu is open.
-- (Job capture is handled server-side via RSGCore:Server:OnJobUpdate.)
RegisterNetEvent('RSGCore:Client:OnJobUpdate', function(job)
    if not isUIOpen or not job then return end

    SendNUIMessage({ action = 'updateDuty', onDuty = job.onduty })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and isUIOpen then
        closeUI()
    end
end)
