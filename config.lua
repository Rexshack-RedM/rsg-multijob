RSGCore = exports['rsg-core']:GetCoreObject()

return {
    MaxJobs = 3,
    JobSwitchCooldown = 3000, -- ms a player must wait between job switches
    JobIcons = {
        ['vallaw'] = 'fa-solid fa-shield',
        ['rholaw'] = 'fa-solid fa-shield',
        ['blklaw'] = 'fa-solid fa-shield',
        ['strlaw'] = 'fa-solid fa-shield',
        ['stdenlaw'] = 'fa-solid fa-shield',
        ['medic'] = 'fa-solid fa-user-nurse',
        ['priest'] = 'fa-solid fa-user-nurse',
        ['banker'] = 'fa-solid fa-shield',
        ['judge'] = 'fa-solid fa-shield',
        ['wagonmechanic'] = 'fa-solid fa-shield',
        ['reporter'] = 'fa-solid fa-shield',
        ['bountyhunter'] = 'fa-solid fa-shield',
        ['gunsmith'] = 'fa-solid fa-shield',
        ['taxi'] = 'fa-solid fa-shield',
        ['saloonowner'] = 'fa-solid fa-shield',
        ['undertaker'] = 'fa-solid fa-shield',
        ['traindriver'] = 'fa-solid fa-shield',
        ['fireman'] = 'fa-solid fa-shield',
        ['drugdealer'] = 'fa-solid fa-shield',
        ['valgang'] = 'fa-solid fa-shield',
        ['rhogang'] = 'fa-solid fa-shield',
        ['stdengang'] = 'fa-solid fa-shield',
        ['strgang'] = 'fa-solid fa-shield',
        ['blkgang'] = 'fa-solid fa-shield',
        ['wagonrepairs'] = 'fa-solid fa-shield',
        ['horsebreeder'] = 'fa-solid fa-shield',
        ['merchant'] = 'fa-solid fa-shield',
        ['barber'] = 'fa-solid fa-shield',
        ['tailor'] = 'fa-solid fa-shield',
    },

    -----------------------------------------------------------------------
    -- Discord Webhook Logging
    -----------------------------------------------------------------------
    Webhooks = {
        Enabled = true, -- master on/off switch for all webhook logging

        -- Used for any event below that doesn't have its own URL set
        DefaultURL = '', -- e.g. 'https://discord.com/api/webhooks/XXXXXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'

        BotName = 'RSG MultiJob',
        BotAvatar = '', -- URL to an image, leave blank for Discord default
        FooterText = 'rsg-multijob',
        FooterIcon = '',
        DefaultColor = 3092790, -- decimal RGB, used if an event has no Color set

        -- Per-event configuration. Set `URL` on an event to route it to a
        -- different Discord channel than DefaultURL, or set `Enabled = false`
        -- to silence just that one event.
        Events = {
            JobAdded = {
                Enabled = true,
                URL = '',
                Title = '📋 Job Added',
                Color = 3066993, -- green
            },
            JobSwitched = {
                Enabled = true,
                URL = '',
                Title = '🔁 Job Switched',
                Color = 3447003, -- blue
            },
            JobDeleted = {
                Enabled = true,
                URL = '',
                Title = '🗑️ Job Deleted',
                Color = 15158332, -- red
            },
            JobRemovedByAdmin = {
                Enabled = true,
                URL = '',
                Title = '🛠️ Job Removed (Admin)',
                Color = 15105570, -- orange
            },
            EmployeeFired = {
                Enabled = true,
                URL = '',
                Title = '🔥 Employee Fired',
                Color = 10038562, -- dark red
            },
        }
    }
}
