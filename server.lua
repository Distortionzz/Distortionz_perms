-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Distortionz Permissions — server                                 ║
-- ║                                                                  ║
-- ║ Authoritative rank store. Other distortionz_* scripts call into  ║
-- ║ this resource via exports for any permission decision. Never     ║
-- ║ trust the client cache for gating — it's UI-only.                ║
-- ║                                                                  ║
-- ║ Ranks are keyed by LICENSE, not citizenid — see database.lua for ║
-- ║ why. Every export keeps its original name/shape so nothing else  ║
-- ║ in the stack has to change; the license resolution happens       ║
-- ║ entirely inside this file.                                       ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ─── State ──────────────────────────────────────────────────────────
-- src -> tier string. Hydrated on player load, dropped on disconnect.
local sessionTiers = {}
-- src -> license, cached alongside sessionTiers so setTierByCid can find
-- and update a live session without re-resolving identifiers every time.
local sessionLicenses = {}

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

--- FiveM's own identifier, not a framework field — works standalone or
--- Qbox, and is what actually survives a character being deleted.
local function getLicense(src)
    if not src or src == 0 then return nil end
    local ok, license = pcall(GetPlayerIdentifierByType, src, 'license')
    if ok and license and license ~= '' then return license end
    return nil
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
-- Keyed by LICENSE, not citizenid — this runs at boot, before anyone has
-- necessarily connected yet, so there's no identity mapping to resolve a
-- citizenid through. License is knowable offline (your Cfx.re/Steam
-- account), so it has no chicken-and-egg problem.
local function bootstrapOwners()
    local merged = {}
    for _, license in ipairs(Config.BootstrapOwners or {}) do
        if license and license ~= '' then merged[license] = true end
    end
    local convar = GetConvar('distortionz_perms_owners', '')
    if convar ~= '' then
        for license in convar:gmatch('[^,%s]+') do merged[license] = true end
    end

    local count = 0
    for license in pairs(merged) do
        local current = DB.GetTier(license)
        if current ~= 'owner' then
            DB.SetTier(license, 'owner', 'bootstrap')
            count = count + 1
            print(('^2[distortionz_perms]^7 bootstrapped owner: %s'):format(license))
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
    local license = getLicense(src)
    if not license then sessionTiers[src] = 'none'; sessionLicenses[src] = nil; return 'none' end

    -- Keep the citizenid -> license directory current so offline,
    -- citizenid-based lookups (admin's staff panel) keep working.
    local cid = getCitizenId(src)
    if cid then DB.RecordIdentity(cid, license) end

    local tier = DB.GetTier(license)
    sessionTiers[src]    = tier
    sessionLicenses[src] = license
    Debug(('hydrate src=%d license=%s tier=%s'):format(src, license, tier))
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
    sessionTiers[source]    = nil
    sessionLicenses[source] = nil
end)

-- ─── Public exports ─────────────────────────────────────────────────
-- All exports take a server src (number) and resolve internally.
-- For citizenid-based lookups (offline players), use Get/SetTierByCid —
-- they resolve citizenid -> license through the identity directory.

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

exports('GetTierByCid', function(cid)
    local license = DB.ResolveLicense(cid)
    if not license then return 'none' end
    return DB.GetTier(license)
end)

-- Returns true on success. Validates tier exists. Granter is logged for audit.
local function setTier(targetSrc, newTier, grantedBy)
    if not Config.Tiers[newTier] then return false, 'unknown tier' end
    local license = getLicense(targetSrc)
    if not license then return false, 'no license' end
    DB.SetTier(license, newTier, grantedBy)
    sessionTiers[targetSrc] = newTier
    if Config.Behavior.logRankChanges then
        print(('^3[distortionz_perms]^7 %s set to %s (by %s)'):format(license, newTier, tostring(grantedBy)))
    end
    local cid = getCitizenId(targetSrc)
    TriggerClientEvent('distortionz_perms:client:tierChanged', targetSrc, newTier)
    TriggerEvent('distortionz_perms:server:tierChanged', targetSrc, cid, newTier, grantedBy)
    return true
end
exports('SetTier', setTier)

--- cid here is whatever the caller has on hand (e.g. admin's staff panel,
--- which is citizenid-keyed like the rest of that UI). Resolved to a
--- license via the identity directory before touching the rank table.
--- Fails cleanly if this citizenid has never connected while perms was
--- running — there's nothing to resolve it to yet.
local function setTierByCid(cid, newTier, grantedBy)
    if not Config.Tiers[newTier] then return false, 'unknown tier' end
    if not cid or cid == '' then return false, 'no citizenid' end

    local license = DB.ResolveLicense(cid)
    if not license then return false, 'this player has never connected — no known license yet' end

    DB.SetTier(license, newTier, grantedBy)

    -- Match by license, not citizenid — catches the case where the admin
    -- granted against one of this account's characters but the player is
    -- currently online on a different one.
    for src, sessionLicense in pairs(sessionLicenses) do
        if sessionLicense == license then
            sessionTiers[src] = newTier
            TriggerClientEvent('distortionz_perms:client:tierChanged', src, newTier)
            break
        end
    end
    if Config.Behavior.logRankChanges then
        print(('^3[distortionz_perms]^7 %s set to %s (by %s, offline-set via cid %s)'):format(license, newTier, tostring(grantedBy), cid))
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
        -- Console: takes a citizenid for convenience (what you'd have on
        -- hand from a player list); resolved to license internally.
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

    local granterLicense = getLicense(src) or ('src:' .. tostring(src))
    local ok, err = setTier(targetId, newTier, granterLicense)
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

-- Self-service lookup so a player can quote their own citizenid — support
-- tickets, bug reports, an admin asking "what's your CID" in chat, etc.
RegisterCommand('mycid', function(src)
    if src == 0 then print('Console has no citizenid.'); return end
    local cid = getCitizenId(src)
    if not cid then
        notify(src, 'No character loaded yet.', 'error', 4000, 'Citizen ID')
        return
    end
    notify(src, cid, 'inform', 8000, 'Your Citizen ID')
end, false)

-- ─── Startup banner ────────────────────────────────────────────────
CreateThread(function()
    Wait(500)
    print(('^5[distortionz_perms:server]^7 v%s loaded — tiers=%d')
        :format(Config.Script.version or '?', (function()
            local n = 0; for _ in pairs(Config.Tiers) do n = n + 1 end; return n
        end)()))
end)
