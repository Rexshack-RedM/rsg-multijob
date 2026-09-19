-----------------------------------------------------------------------
-- Discord Webhook Logging for rsg-multijob
--
-- Exposes a global `Webhook` table so server/server.lua (and anything
-- else in this resource) can log an event without worrying about
-- queuing, rate limits, or missing/blank URLs.
-----------------------------------------------------------------------

local Config = lib.require('config')

Webhook = {}

-- Simple FIFO queue + processor so a burst of events (e.g. an admin
-- mass-removing jobs) can't spam Discord's rate limit or fire dozens of
-- concurrent HTTP requests at once.
local queue = {}
local processing = false

local function isValidUrl(url)
    return type(url) == 'string' and url ~= '' and url:find('^https?://')
end

local function processQueue()
    if processing then return end
    processing = true

    CreateThread(function()
        while #queue > 0 do
            local job = table.remove(queue, 1)

            PerformHttpRequest(job.url, function(statusCode, _, _)
                if statusCode ~= 200 and statusCode ~= 204 then
                    print(('[rsg-multijob] WARNING: Discord webhook "%s" returned HTTP %s'):format(job.eventName, tostring(statusCode)))
                end
            end, 'POST', json.encode(job.payload), { ['Content-Type'] = 'application/json' })

            -- Discord's webhook rate limit is ~5 requests / 2s per webhook,
            -- so a small delay between sends keeps this resource well clear of it.
            Wait(300)
        end

        processing = false
    end)
end

-- Builds and queues an embed for the given event.
--
-- eventName : string   -- must match a key under Config.Webhooks.Events
-- data      : table {
--     description = string,        -- optional, main embed body text
--     fields      = { { name, value, inline } , ... }, -- optional
--     title       = string,        -- optional, overrides the configured title
--     color       = number,        -- optional, overrides the configured color
-- }
function Webhook.Send(eventName, data)
    if not Config.Webhooks or not Config.Webhooks.Enabled then return end

    local eventCfg = Config.Webhooks.Events and Config.Webhooks.Events[eventName]
    if not eventCfg then
        print(('[rsg-multijob] WARNING: Webhook.Send called with unknown event "%s"'):format(tostring(eventName)))
        return
    end

    if not eventCfg.Enabled then return end

    data = data or {}

    local url = isValidUrl(eventCfg.URL) and eventCfg.URL or Config.Webhooks.DefaultURL
    if not isValidUrl(url) then
        -- No URL configured anywhere for this event; nothing to send to.
        return
    end

    local embed = {
        title = data.title or eventCfg.Title,
        description = data.description,
        color = data.color or eventCfg.Color or Config.Webhooks.DefaultColor,
        fields = data.fields or {},
        footer = {
            text = Config.Webhooks.FooterText or 'rsg-multijob',
            icon_url = Config.Webhooks.FooterIcon ~= '' and Config.Webhooks.FooterIcon or nil
        },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%S')
    }

    queue[#queue + 1] = {
        eventName = eventName,
        url = url,
        payload = {
            username = Config.Webhooks.BotName,
            avatar_url = Config.Webhooks.BotAvatar ~= '' and Config.Webhooks.BotAvatar or nil,
            embeds = { embed }
        }
    }

    processQueue()
end
