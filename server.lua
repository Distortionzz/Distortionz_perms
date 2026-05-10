-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Distortionz Permissions — server                                 ║
-- ║                                                                  ║
-- ║ Authoritative rank store. Other distortionz_* scripts call into  ║
-- ║ this resource via exports for any permission decision. Never     ║
-- ║ trust the client cache for gating — it's UI-only.                ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ─── State ──────────────────────────────────────────────────────────
-- src -> tier string. Hydrated on player load, dropped on disconnect.
local sessionTiers = {}

-- ─── Helpers ────────────────────────────────────────────────────────
local function Debug(...)
    if Config.Debug then
        print(('[perms:server] %s'):format(table.concat({...}, ' ')))
    end
end

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    if not ok then return nil end
    return p
end

local function getCitizenId(src)
    local p = getPlayer(src)
    if not p or not p.PlayerData then return nil end
    return p.PlayerData.citizenid
end

local function tierWeight(tier)
    local entry = Config.Tiers[tier or 'none']
    return entry and entry.weight or 0
end

local function notify(src, message, notifyType, duration, title)
    notifyType = notifyType or 'primary'
    duration   = duration or 5000
    title      = title or Config.Notify.title
    if GetResourceState(Config.Notify.resource) == 'started' then
        TriggerClientEvent('distortionz_perms:client:notify', src, message, notifyType, duration, title)
        return
    end
    TriggerClientEvent('ox_lib:notify', src, {
        title = title, description = message, type = notifyType, duration = duration,
    })
end

-- ─── Bootstrap owners (config + convar merge) ──────────────────────
local function bootstrapOwners()
    local merged = {}
    for _, cid in ipairs(Config.BootstrapOwners or {}) do
        if cid and cid ~= '' then merged[cid] = true end
    end
    local convar = GetConvar('distortionz_perms_owners', '')
    if convar ~= '' then
        for cid in convar:gmatch('[^,%s]+') do merged[cid] = true end
    end

    local count = 0
    for cid in pairs(merged) do
        local current = DB.GetTier(cid)
        if current ~= 'owner' then
            DB.SetTier(cid, 'owner', 'bootstrap')
            count = count + 1
            print(('^2[distortionz_perms]^7 bootstrapped owner: %s'):format(cid))
        end
    end
    if count > 0 then
        print(('^2[distortionz_perms]^7 bootstrapped %d owner(s) from config/convar'):format(count))
    end
end

CreateThread(function()
    Wait(1500)   -- let DB schema settle
    bootstrapOwners()
end)

-- ─── Hydrate player on load ─────────────────────────────────────────
local function hydrate(src)
    local cid = getCitizenId(src)
    if not cid then sessionTiers[src] = 'none'; return 'none' end
    local tier = DB.GetTier(cid)
    sessionTiers[src] = tier
    Debug(('hydrate src=%d cid=%s tier=%s'):format(src, cid, tier))
    return tier
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    local src = (player and player.PlayerData and player.PlayerData.source) or source
    if src then hydrate(src) end
end)

AddEventHandler('qbx_core:server:onPlayerLoaded', function(src)
    if src then hydrate(src) end
end)

AddEventHandler('playerDropped', function()
    sessionTiers[source] = nil
end)

-- ─── Public exports ─────────────────────────────────────────────────
-- All exports take a server src (number) and resolve internally.
-- For citizenid-based lookups (offline players), use Get/SetTierByCid.

local function getTier(src)
    if not src then return 'none' end
    local cached = sessionTiers[src]
    if cached then return cached end
    return hydrate(src)
end
exports('GetTier', getTier)

local function isAtLeast(src, requiredTier)
    return tierWeight(getTier(src)) >= tierWeight(requiredTier)
end
exports('IsAtLeast', isAtLeast)

local function hasTier(src, tier)
    return getTier(src) == tier
end
exports('HasTier', hasTier)

exports('GetTierByCid', function(cid) return DB.GetTier(cid) end)

-- Returns true on success. Validates tier exists. Granter is logged for audit.
local function setTier(targetSrc, newTier, grantedBy)
    if not Config.Tiers[newTier] then return false, 'unknown tier' end
    local cid = getCitizenId(targetSrc)
    if not cid then return false, 'no citizenid' end
    DB.SetTier(cid, newTier, grantedBy)
    sessionTiers[targetSrc] = newTier
    if Config.Behavior.logRankChanges then
        print(('^3[distortionz_perms]^7 %s set to %s (by %s)'):format(cid, newTier, tostring(grantedBy)))
    end
    TriggerClientEvent('distortionz_perms:client:tierChanged', targetSrc, newTier)
    TriggerEvent('distortionz_perms:server:tierChanged', targetSrc, cid, newTier, grantedBy)
    return true
end
exports('SetTier', setTier)

local function setTierByCid(cid, newTier, grantedBy)
    if not Config.Tiers[newTier] then return false, 'unknown tier' end
    if not cid or cid == '' then return false, 'no citizenid' end
    DB.SetTier(cid, newTier, grantedBy)
    -- If this citizenid has an active session, update the cache + notify
    for src, _ in pairs(sessionTiers) do
        if getCitizenId(src) == cid then
            sessionTiers[src] = newTier
            TriggerClientEvent('distortionz_perms:client:tierChanged', src, newTier)
            break
        end
    end
    if Config.Behavior.logRankChanges then
        print(('^3[distortionz_perms]^7 %s set to %s (by %s, offline-set)'):format(cid, newTier, tostring(grantedBy)))
    end
    TriggerEvent('distortionz_perms:server:tierChanged', nil, cid, newTier, grantedBy)
    return true
end
exports('SetTierByCid', setTierByCid)

exports('ListAll', function() return DB.ListAll() end)
exports('GetTierConfig', function() return Config.Tiers end)

-- ─── Callbacks for client UI ────────────────────────────────────────
lib.callback.register('distortionz_perms:cb:getOwnTier', function(src)
    return getTier(src)
end)

lib.callback.register('distortionz_perms:cb:listStaff', function(src)
    if not isAtLeast(src, 'admin') then return nil end
    return DB.ListAll()
end)

-- ─── Commands ───────────────────────────────────────────────────────
-- /setrank <id> <tier>  — owner-only by default; admins can promote up to mod
RegisterCommand('setrank', function(src, args)
    if src == 0 then
        -- Console: full power
        local targetCid, tier = args[1], args[2]
        if not targetCid or not tier then
            print('Usage (console): setrank <citizenid> <none|mod|admin|owner>')
            return
        end
        local ok, err = setTierByCid(targetCid, tier, 'console')
        print(ok and ('OK — %s set to %s'):format(targetCid, tier) or ('FAIL — %s'):format(err))
        return
    end

    local targetIdRaw, newTier = args[1], args[2]
    local targetId = tonumber(targetIdRaw)
    if not targetId or not newTier then
        notify(src, 'Usage: /setrank <player_id> <none|mod|admin|owner>', 'error')
        return
    end
    if not Config.Tiers[newTier] then
        notify(src, 'Unknown tier: ' .. tostring(newTier), 'error')
        return
    end

    local granterTier = getTier(src)
    -- Owner can set anything. Admin can set up to mod. Mod can't grant.
    if granterTier == 'owner' then
        -- ok
    elseif granterTier == 'admin' and tierWeight(newTier) <= tierWeight('mod') then
        -- ok
    else
        notify(src, 'Insufficient permission to grant that tier.', 'error')
        return
    end

    -- Can't promote someone above your own tier
    if tierWeight(newTier) > tierWeight(granterTier) then
        notify(src, "Can't grant a tier higher than your own.", 'error')
        return
    end

    local granterCid = getCitizenId(src) or ('src:' .. tostring(src))
    local ok, err = setTier(targetId, newTier, granterCid)
    if ok then
        notify(src, ('Set player %d to %s.'):format(targetId, newTier), 'success')
    else
        notify(src, 'Failed: ' .. tostring(err), 'error')
    end
end, false)

RegisterCommand('myrank', function(src)
    if src == 0 then print('Console has implicit owner-equivalent power.'); return end
    local tier = getTier(src)
    local entry = Config.Tiers[tier] or Config.Tiers.none
    notify(src, ('You are: %s'):format(entry.label), 'inform', 5000, 'Your Rank')
end, false)

-- ─── Startup banner ────────────────────────────────────────────────
CreateThread(function()
    Wait(500)
    print(('^5[distortionz_perms:server]^7 v%s loaded — tiers=%d')
        :format(Config.Script.version or '?', (function()
            local n = 0; for _ in pairs(Config.Tiers) do n = n + 1 end; return n
        end)()))
end)
