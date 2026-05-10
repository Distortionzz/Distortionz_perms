-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Distortionz Permissions — client                                 ║
-- ║                                                                  ║
-- ║ Caches the player's own tier locally for cheap UI gating in      ║
-- ║ other distortionz_* scripts. NEVER use this for security — the   ║
-- ║ server is always authoritative.                                  ║
-- ╚══════════════════════════════════════════════════════════════════╝

local cachedTier = 'none'
local lastFetchedAt = 0

local function Notify(message, notifyType, duration, title)
    notifyType = notifyType or 'primary'
    duration   = duration or 5000
    title      = title or Config.Notify.title
    if notifyType == 'inform' then notifyType = 'info' end
    if GetResourceState(Config.Notify.resource) == 'started' then
        exports[Config.Notify.resource]:Notify(message, notifyType, duration, title)
        return
    end
    lib.notify({
        title = title, description = message, type = notifyType, duration = duration,
    })
end

RegisterNetEvent('distortionz_perms:client:notify', function(message, notifyType, duration, title)
    Notify(message, notifyType, duration, title)
end)

-- ─── Cache ──────────────────────────────────────────────────────────
local function refreshTier()
    local tier = lib.callback.await('distortionz_perms:cb:getOwnTier', false)
    cachedTier = tier or 'none'
    lastFetchedAt = GetGameTimer()
    return cachedTier
end

-- Public refresh — other distortionz_* scripts call this when they
-- need a known-fresh tier (e.g. before showing a "no permission" toast).
exports('RefreshTier', refreshTier)

RegisterNetEvent('distortionz_perms:client:tierChanged', function(newTier)
    cachedTier = newTier or 'none'
    lastFetchedAt = GetGameTimer()
    local entry = Config.Tiers[cachedTier]
    Notify(('Your rank is now: %s'):format(entry and entry.label or cachedTier), 'inform')
end)

-- ─── Public exports for other distortionz_* scripts ─────────────────
-- UI-only. Don't gate destructive actions on this.
exports('GetCachedTier', function() return cachedTier end)

exports('IsAtLeastCached', function(requiredTier)
    local req = Config.Tiers[requiredTier]
    local own = Config.Tiers[cachedTier]
    if not req or not own then return false end
    return own.weight >= req.weight
end)

exports('GetTierConfig', function() return Config.Tiers end)

-- ─── Periodic refresh ───────────────────────────────────────────────
CreateThread(function()
    Wait(2000)
    refreshTier()
    if not Config.Behavior.clientCacheEnabled then return end
    while true do
        Wait((Config.Behavior.clientCacheRefreshS or 60) * 1000)
        refreshTier()
    end
end)

-- Refresh whenever the player respawns / reconnects to the world so
-- the cache reflects any rank changes that happened while loading.
AddEventHandler('playerSpawned', function()
    -- Tiny stagger so the server-side hydrate finishes first
    SetTimeout(500, function() pcall(refreshTier) end)
end)
