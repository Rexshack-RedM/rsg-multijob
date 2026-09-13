RSGCore = exports['rsg-core']:GetCoreObject()

return {
    MaxJobs = 2,
    AllowedMultipleJobs = {
        -- ['LVD86398'] = 5,
        -- ['QXG67827'] = 2,
        -- ['VFL05832'] = 2,
        -- ['YCS40333'] = 2,
        -- ['KHS69755'] = 2,
        -- ['FQS93449'] = 2,
        -- ['KYJ85969'] = 2,
        -- ['CBS40094'] = 2,
    },
    JobIcons = {
        ['vallaw'] = 'fa-solid fa-shield',
        ['rholaw'] = 'fa-solid fa-shield',
        ['blklaw'] = 'fa-solid fa-shield',
        ['strlaw'] = 'fa-solid fa-shield',
        ['stdenlaw'] = 'fa-solid fa-shield',
        ['medic'] = 'fa-solid fa-user-nurse',
        ['miner'] = 'fa-solid fa-hill-rockslide',
        ['farmer'] = 'fa-solid fa-wheat-awn',
    },

    ----------------------------------------------------------------------
    -- Discord Webhook Logging
    ----------------------------------------------------------------------
    Webhooks = {
        -- 'default' is used for any category below that is left blank.
        ['default'] = '', -- e.g. 'https://discord.com/api/webhooks/xxxx/xxxx'
        ['jobAdded'] = '',
        ['jobSwitched'] = '',
        ['jobDeleted'] = '',
        ['jobMaxReached'] = '',
        ['adminRemove'] = '',
        ['employeeFired'] = '',
    },

    WebhookSettings = {
        enabled = false, -- master switch; set true once a webhook URL is configured
        botName = 'RSG Multijob',
        botAvatar = 'https://raw.githubusercontent.com/Rexshack-RedM/rsg-core/main/logo.png',
        -- Server name shown in the embed footer, useful if you route multiple
        -- servers' logs into one Discord channel.
        serverName = 'RSG RedM Server',
        -- Per-event toggles. Set to false to silence a specific category
        -- without touching the webhook URL.
        logs = {
            jobAdded = true,       -- player gained a new tracked job
            jobSwitched = true,    -- player switched their active job via /myjobs
            jobDeleted = true,     -- player removed one of their own jobs
            jobMaxReached = true,  -- player hit their multijob cap
            adminRemove = true,    -- /removejob admin command used
            employeeFired = true,  -- rsg-bossmenu fired an employee
        },
        -- Basic outbound rate limiting so a burst of events can't get the
        -- webhook URL rate-limited or banned by Discord.
        queueIntervalMs = 350,
    },
}
