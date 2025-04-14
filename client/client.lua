local Config = lib.require('config')
lib.locale()

local function showMultijob()
    local PlayerData = RSGCore.Functions.GetPlayerData()

    if PlayerData.metadata['injail'] > 0 then
        return lib.notify({
            title = 'Error',
            description = 'You cannot do this while in jail.',
            type = 'error',
        })
    end

    local dutyStatus = PlayerData.job.onduty and locale('cl_lang_1') or locale('cl_lang_2')
    local dutyIcon = PlayerData.job.onduty and 'fa-solid fa-toggle-on' or 'fa-solid fa-toggle-off'
    local colorIcon = PlayerData.job.onduty and '#5ff5b4' or 'red'
    local jobMenu = {
        id = 'job_menu',
        title = locale('cl_lang_3'),
        options = {
            {
                title = locale('cl_lang_4'),
                description = locale('cl_lang_5') .. ': ' .. dutyStatus,
                icon = dutyIcon,
                iconColor = colorIcon,
                onSelect = function()
                    TriggerServerEvent('RSGCore:ToggleDuty')
                    Wait(500)
                    showMultijob()
                end,
            },
        },
    }
    local myJobs = lib.callback.await('rsg-multijob:server:myJobs', false)
    if myJobs then
        for _, job in ipairs(myJobs) do
            local isDisabled = PlayerData.job.name == job.job
            jobMenu.options[#jobMenu.options + 1] = {
                title = job.jobLabel,
                description = (locale('cl_lang_grade')..': %s [%s]\n'..locale('cl_lang_salary')..': $%s'):format(job.gradeLabel, tonumber(job.grade), job.salary),
                icon = Config.JobIcons[job.job] or 'fa-solid fa-briefcase',
                arrow = true,
                disabled = isDisabled,
                event = 'rsg-multijob:client:choiceMenu',
                args = {jobLabel = job.jobLabel, job = job.job, grade = job.grade},
            }
        end
        lib.registerContext(jobMenu)
        lib.showContext('job_menu')
    end
end

AddEventHandler('rsg-multijob:client:choiceMenu', function(args)
    local displayChoices = {
        id = 'choice_menu',
        title = locale('cl_job_actions'),
        menu = 'job_menu',
        options = {
            {
                title = locale('cl_switch_job'),
                description = (locale('cl_switch_your_job') .. ': %s'):format(args.jobLabel),
                icon = 'fa-solid fa-circle-check',
                onSelect = function()
                    TriggerServerEvent('rsg-multijob:server:changeJob', args.job)
                    Wait(100)
                    showMultijob()
                end,
            },
            {
                title = locale('cl_delete_job'),
                description = (locale('cl_delete_selected_job') .. ': %s'):format(args.jobLabel),
                icon = 'fa-solid fa-trash-can',
                onSelect = function()
                    TriggerServerEvent('rsg-multijob:server:deleteJob', args.job)
                    Wait(100)
                    showMultijob()
                end,
            },
        }
    }
    lib.registerContext(displayChoices)
    lib.showContext('choice_menu')
end)

RegisterNetEvent('RSGCore:Client:OnJobUpdate', function(JobInfo)
    TriggerServerEvent('rsg-multijob:server:newJob', JobInfo)
end)

RegisterNetEvent('rsg-multijob:client:openmenu', function()
	showMultijob()
end)
