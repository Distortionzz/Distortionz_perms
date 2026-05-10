Config = Config or {}

-- ─── Script meta ────────────────────────────────────────────────────
Config.Script = {
    name    = 'Distortionz Permissions',
    version = '1.0.2',
}

Config.VersionCheck = {
    enabled      = true,
    checkOnStart = true,
    url          = 'https://raw.githubusercontent.com/Distortionzz/Distortionz_Perms/main/version.json',
}
Config.CurrentVersion = '1.0.2'

-- ─── Notifications ──────────────────────────────────────────────────
Config.Notify = {
    title    = 'Permissions',
    resource = 'distortionz_notify',
}

-- ─── Tier hierarchy ─────────────────────────────────────────────────
-- Numeric weights so ">= mod" works cleanly in code via IsAtLeast.
-- Add custom tiers here if you need (e.g. 'support' between none and mod);
-- just keep the weights monotonically increasing.
Config.Tiers = {
    none  = { weight = 0, label = 'Player',     color = '#7d8590' },
    mod   = { weight = 1, label = 'Moderator',  color = '#3fb950' },
    admin = { weight = 2, label = 'Admin',      color = '#d29922' },
    owner = { weight = 3, label = 'Owner',      color = '#f85149' },
}

-- ─── Bootstrap owners ───────────────────────────────────────────────
-- Chicken-and-egg: someone needs to be Owner before anyone can /setrank.
-- Put your own citizenid(s) here OR set the convar `distortionz_perms_owners`
-- in server.cfg (comma-separated). Both are merged on boot.
--   set distortionz_perms_owners "ABC12345,XYZ67890"
Config.BootstrapOwners = {
    -- 'YOUR_CITIZEN_ID_HERE',
}

-- ─── Behavior ───────────────────────────────────────────────────────
Config.Behavior = {
    -- Cache tier on client for fast UI gating. Server is always
    -- authoritative — never trust the client for permission checks.
    clientCacheEnabled = true,
    -- Refresh client cache every N seconds (covers rank changes that
    -- happen mid-session without requiring a relog).
    clientCacheRefreshS = 60,
    -- Print a console line whenever a rank is set/removed.
    logRankChanges      = true,
}

-- ─── Debug ──────────────────────────────────────────────────────────
Config.Debug = false
