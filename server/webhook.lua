-----------------------------------------------------------------------
-- Discord Webhook Logging for rsg-multijob
-----------------------------------------------------------------------
-- Sends embeds to Discord for job add/switch/delete/max-reached and
-- admin actions. Configure URLs + toggles in config.lua (Webhooks /
-- WebhookSettings). Everything here is a no-op if WebhookSettings.enabled
-- is false or no URL is configured for a category, so it's always safe
-- to leave installed even without Discord set up.
-----------------------------------------------------------------------

local Config = lib.require('config')
lib.locale()

local WebhookLog = {}

local Colors = {
    success = 3066993,  -- green
    error   = 15158332, -- red
    info    = 3447003,  -- blue
    warning = 15844367, -- yellow
}

-- Simple FIFO queue + drip-feed loop so a burst of events (e.g. an admin
-- mass-removing jobs) can't spam Discord's rate limiter.
local queue = {}
local queueRunning = false

local function processQueue()
    if queueRunning then return end
    queueRunning = true

    CreateThread(function()
        while #queue > 0 do
            local job = table.remove(queue, 1)
            PerformHttpRequest(job.url, function(statusCode, _, _)
                if statusCode ~= 200 and statusCode ~= 204 then
                    print(('[rsg-multijob:webhook] Failed to deliver webhook (HTTP %s) for category "%s"'):format(tostring(statusCode), job.category))
                end
            end, 'POST', json.encode(job.payload), { ['Content-Type'] = 'application/json' })

            Wait(Config.WebhookSettings.queueIntervalMs or 350)
        end
        queueRunning = false
    end)
end

--- Resolves the webhook URL to use for a given log category, falling back
--- to the 'default' URL when no category-specific one is set.
local function getWebhookUrl(category)
    local webhooks = Config.Webhooks
    if not webhooks then return nil end

    local url = webhooks[category]
    if url and url ~= '' then return url end

    local default = webhooks['default']
    if default and default ~= '' then return default end

    return nil
end

--- Pulls a readable name / citizenid / discord identifier for a player,
--- falling back gracefully when the player has already dropped or a raw
--- citizenid string was passed instead of a Player object.
local function resolveIdentity(source, Player)
    local identity = {
        name = locale('sv_wh_unknown'),
        citizenid = locale('sv_wh_unknown'),
        discord = locale('sv_wh_na'),
    }

    if Player and Player.PlayerData then
        local charinfo = Player.PlayerData.charinfo
        if charinfo then
            local fullName = ('%s %s'):format(charinfo.firstname or '', charinfo.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
            if fullName ~= '' then identity.name = fullName end
        end
        identity.citizenid = Player.PlayerData.citizenid or identity.citizenid
    end

    if source then
        local discordId = GetPlayerIdentifierByType(tostring(source), 'discord')
        if discordId then
            identity.discord = ('<@%s>'):format(discordId:gsub('discord:', ''))
        end
    end

    return identity
end

--- Queues a Discord embed for delivery.
-- @param category string - one of Config.WebhookSettings.logs keys, also used to pick the webhook URL
-- @param title string - embed title
-- @param color number - embed color (use Colors.success/error/info/warning or a raw decimal)
-- @param fields table - array of { name = string, value = string, inline = boolean }
local function sendLog(category, title, color, fields)
    local settings = Config.WebhookSettings
    if not settings or not settings.enabled then return end
    if settings.logs and settings.logs[category] == false then return end

    local url = getWebhookUrl(category)
    if not url then return end

    local payload = {
        username = settings.botName or 'RSG Multijob',
        avatar_url = settings.botAvatar,
        embeds = {
            {
                title = title,
                color = color or Colors.info,
                fields = fields,
                footer = { text = settings.serverName or 'RSG RedM Server' },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            },
        },
    }

    queue[#queue + 1] = { url = url, payload = payload, category = category }
    processQueue()
end

local function identityFields(identity, extra)
    local fields = {
        { name = locale('sv_wh_field_player'), value = identity.name, inline = true },
        { name = locale('sv_wh_field_citizenid'), value = identity.citizenid, inline = true },
        { name = locale('sv_wh_field_discord'), value = identity.discord, inline = true },
    }

    if extra then
        for _, field in ipairs(extra) do
            fields[#fields + 1] = field
        end
    end

    return fields
end

----------------------------------------------------------------------
-- Public logging API (exported so other event handlers can call in)
----------------------------------------------------------------------

--- A new job was recorded for a player (first time they've taken it).
function WebhookLog.JobAdded(source, Player, jobLabel, gradeLabel)
    local identity = resolveIdentity(source, Player)
    sendLog('jobAdded', locale('sv_wh_title_job_added'), Colors.success, identityFields(identity, {
        { name = locale('sv_wh_field_job'),   value = jobLabel,                        inline = true },
        { name = locale('sv_wh_field_grade'), value = gradeLabel or locale('sv_wh_na'), inline = true },
    }))
end

--- A player switched their active job to one they already hold.
function WebhookLog.JobSwitched(source, Player, jobLabel)
    local identity = resolveIdentity(source, Player)
    sendLog('jobSwitched', locale('sv_wh_title_job_switched'), Colors.info, identityFields(identity, {
        { name = locale('sv_wh_field_new_active_job'), value = jobLabel, inline = true },
    }))
end

--- A player deleted one of their own held jobs via the menu.
function WebhookLog.JobDeleted(source, Player, jobLabel)
    local identity = resolveIdentity(source, Player)
    sendLog('jobDeleted', locale('sv_wh_title_job_deleted'), Colors.warning, identityFields(identity, {
        { name = locale('sv_wh_field_job_removed'), value = jobLabel, inline = true },
    }))
end

--- A player hit their multijob cap and their new job assignment was reverted.
function WebhookLog.JobMaxReached(source, Player, attemptedJob, allowedJobs)
    local identity = resolveIdentity(source, Player)
    sendLog('jobMaxReached', locale('sv_wh_title_job_max'), Colors.error, identityFields(identity, {
        { name = locale('sv_wh_field_attempted_job'), value = attemptedJob,          inline = true },
        { name = locale('sv_wh_field_job_limit'),     value = tostring(allowedJobs), inline = true },
    }))
end

--- An admin used /removejob on a player.
function WebhookLog.AdminRemove(adminSource, targetId, targetCitizenid, jobName)
    local adminIdentity = resolveIdentity(adminSource, RSGCore.Functions.GetPlayer(adminSource))
    sendLog('adminRemove', locale('sv_wh_title_admin_remove'), Colors.warning, {
        { name = locale('sv_wh_field_admin'),         value = adminIdentity.name,                          inline = true },
        { name = locale('sv_wh_field_admin_discord'), value = adminIdentity.discord,                       inline = true },
        { name = locale('sv_wh_field_target_id'),     value = tostring(targetId),                          inline = true },
        { name = locale('sv_wh_field_target_cid'),    value = targetCitizenid or locale('sv_wh_unknown'),  inline = true },
        { name = locale('sv_wh_field_job_removed'),   value = jobName,                                     inline = true },
    })
end

--- rsg-bossmenu fired an employee, removing their multijob entry.
function WebhookLog.EmployeeFired(bossSource, targetCitizenid, jobName)
    local bossIdentity = resolveIdentity(bossSource, RSGCore.Functions.GetPlayer(bossSource))
    sendLog('employeeFired', locale('sv_wh_title_employee_fired'), Colors.error, {
        { name = locale('sv_wh_field_fired_by'),     value = bossIdentity.name,                          inline = true },
        { name = locale('sv_wh_field_boss_discord'), value = bossIdentity.discord,                       inline = true },
        { name = locale('sv_wh_field_target_cid'),   value = targetCitizenid or locale('sv_wh_unknown'), inline = true },
        { name = locale('sv_wh_field_job'),          value = jobName,                                    inline = true },
    })
end

_G.WebhookLog = WebhookLog

exports('SendCustomLog', function(category, title, color, fields)
    sendLog(category, title, color, fields)
end)
