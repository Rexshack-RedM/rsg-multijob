-----------------------------------------------------------------------
-- Job admin panel (/jobadmin)
-- Every callback re-checks permission server-side; the NUI is never trusted.
-----------------------------------------------------------------------

local Config = lib.require('shared.config')
lib.locale()

local lastAction = {}
local THROTTLE_MS = 500

local function IsAdmin(src)
    return src and src > 0 and RSGCore.Functions.HasPermission(src, Config.Admin.Permission) == true
end

local function Throttled(src)
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < THROTTLE_MS then return true end
    lastAction[src] = now
    return false
end

local function AdminTag(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return GetPlayerName(src) or tostring(src) end
    local ci = Player.PlayerData.charinfo or {}
    return ('%s %s (`%s`)'):format(ci.firstname or '', ci.lastname or '', Player.PlayerData.citizenid)
end

-- NUI-friendly list: grades as ordered arrays, sorted by label
local function BuildAdminList()
    local counts = JobRegistry.HolderCounts()
    local online = {}
    for _, Player in pairs(RSGCore.Functions.GetRSGPlayers() or {}) do
        local j = Player.PlayerData.job and Player.PlayerData.job.name
        if j then online[j] = (online[j] or 0) + 1 end
    end

    local list = {}
    for name, def in pairs(JobRegistry.All()) do
        local grades, n = {}, 0
        for _ in pairs(def.grades) do n = n + 1 end
        for lvl = 0, n - 1 do
            local g = def.grades[tostring(lvl)]
            grades[#grades + 1] = { name = g.name, payment = g.payment, isboss = g.isboss == true }
        end

        list[#list + 1] = {
            name = name,
            label = def.label,
            type = def.type or '',
            icon = def.icon or Config.JobIcons[name] or '',
            defaultDuty = def.defaultDuty == true,
            offDutyPay = def.offDutyPay == true,
            grades = grades,
            holders = counts[name] or 0,
            active = online[name] or 0,
        }
    end

    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end

local function Result(ok, msgKey, extra, ...)
    local r = extra or {}
    r.ok = ok
    r.message = msgKey and locale(msgKey, ...) or nil
    if ok then r.jobs = BuildAdminList() end
    return r
end

-----------------------------------------------------------------------
-- Command
-----------------------------------------------------------------------

RSGCore.Commands.Add(Config.Admin.Command, locale('cmd_jobadmin_desc'), {}, false, function(source)
    if not JobRegistry.IsLoaded() then
        TriggerClientEvent('ox_lib:notify', source, { title = locale('title_error'), description = locale('adm_err_not_loaded'), type = 'error' })
        return
    end
    TriggerClientEvent('rsg-multijob:client:openAdmin', source)
end, Config.Admin.Permission)

-----------------------------------------------------------------------
-- Callbacks
-----------------------------------------------------------------------

lib.callback.register('rsg-multijob:server:admin:getJobs', function(source)
    if not IsAdmin(source) or not JobRegistry.IsLoaded() then return nil end
    return BuildAdminList()
end)

lib.callback.register('rsg-multijob:server:admin:saveJob', function(source, job, isNew)
    if not IsAdmin(source) then return { ok = false, message = locale('adm_err_perm') } end
    if Throttled(source) then return { ok = false, message = locale('adm_err_slow') } end

    isNew = isNew == true
    local def, err = JobRegistry.Save(job, isNew)
    if not def then return Result(false, err) end

    local gradeCount = 0
    for _ in pairs(def.grades) do gradeCount = gradeCount + 1 end

    Webhook.Send(isNew and 'JobCreated' or 'JobUpdated', {
        description = locale(isNew and 'wh_job_created' or 'wh_job_updated', def.label, def.name),
        fields = {
            { name = locale('wh_field_admin'), value = AdminTag(source), inline = true },
            { name = locale('wh_field_job'), value = ('%s (`%s`)'):format(def.label, def.name), inline = true },
            { name = locale('wh_field_grades'), value = tostring(gradeCount), inline = true },
        }
    })

    return Result(true, isNew and 'adm_ok_created' or 'adm_ok_saved', { saved = def.name }, def.label)
end)

lib.callback.register('rsg-multijob:server:admin:deleteJob', function(source, name)
    if not IsAdmin(source) then return { ok = false, message = locale('adm_err_perm') } end
    if Throttled(source) or type(name) ~= 'string' then return { ok = false, message = locale('adm_err_slow') } end

    local def = JobRegistry.Get(name)
    local label = def and def.label or name
    local ok, err, holders = JobRegistry.Delete(name)
    if not ok then return Result(false, err) end

    Webhook.Send('JobDefinitionDeleted', {
        description = locale('wh_job_def_deleted', label, name),
        fields = {
            { name = locale('wh_field_admin'), value = AdminTag(source), inline = true },
            { name = locale('wh_field_job'), value = ('%s (`%s`)'):format(label, name), inline = true },
            { name = locale('wh_field_holders'), value = tostring(holders), inline = true },
        }
    })

    return Result(true, 'adm_ok_deleted', nil, label, holders)
end)

lib.callback.register('rsg-multijob:server:admin:importCore', function(source)
    if not IsAdmin(source) then return { ok = false, message = locale('adm_err_perm') } end
    if Throttled(source) then return { ok = false, message = locale('adm_err_slow') } end

    local n = JobRegistry.ImportFromCore()
    return Result(true, 'adm_ok_imported', nil, n)
end)

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)
