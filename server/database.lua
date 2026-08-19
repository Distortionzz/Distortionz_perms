-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Distortionz Permissions — database layer                         ║
-- ║                                                                  ║
-- ║ Ranks are keyed by LICENSE, not citizenid. citizenid is per-      ║
-- ║ character — a demoted or banned player could shed it just by     ║
-- ║ deleting and remaking their character. License is tied to the    ║
-- ║ actual account and survives that.                                ║
-- ║                                                                  ║
-- ║ distortionz_perms_identities is a citizenid -> license directory ║
-- ║ this resource builds up itself as players connect (see hydrate() ║
-- ║ in server.lua), so citizenid-based lookups (offline admin        ║
-- ║ actions, /setrank by cid) still work without any other resource  ║
-- ║ having to change how it calls this one.                          ║
-- ╚══════════════════════════════════════════════════════════════════╝

DB = DB or {}

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS distortionz_perms_ranks (
    license    VARCHAR(60) PRIMARY KEY,
    tier       VARCHAR(32) NOT NULL,
    granted_by VARCHAR(60) NULL,
    granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_tier (tier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS distortionz_perms_identities (
    citizenid  VARCHAR(50) PRIMARY KEY,
    license    VARCHAR(60) NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_license (license)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

CreateThread(function()
    local ok, err = pcall(function()
        MySQL.query.await(SCHEMA, {})
    end)
    if not ok then
        print(('^1[distortionz_perms] ^7DB schema bootstrap FAILED: %s'):format(tostring(err)))
        return
    end
    print('^2[distortionz_perms]^7 DB schema verified.')
end)

-- ─── Identity directory ─────────────────────────────────────────────

--- Upserted every time a player is seen (see hydrate()). This is what lets
--- citizenid-based lookups keep working even though ranks themselves are
--- stored by license.
function DB.RecordIdentity(citizenid, license)
    if not citizenid or citizenid == '' or not license or license == '' then return end
    MySQL.query.await([[
        INSERT INTO distortionz_perms_identities (citizenid, license)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE license = VALUES(license)
    ]], { citizenid, license })
end

--- nil if this citizenid has never been seen while perms was running.
function DB.ResolveLicense(citizenid)
    if not citizenid or citizenid == '' then return nil end
    local rows = MySQL.query.await(
        'SELECT license FROM distortionz_perms_identities WHERE citizenid = ? LIMIT 1',
        { citizenid }
    )
    return rows and rows[1] and rows[1].license or nil
end

-- ─── Ranks (keyed by license) ───────────────────────────────────────

function DB.GetTier(license)
    if not license or license == '' then return 'none' end
    local rows = MySQL.query.await(
        'SELECT tier FROM distortionz_perms_ranks WHERE license = ? LIMIT 1',
        { license }
    )
    if rows and rows[1] and rows[1].tier then return rows[1].tier end
    return 'none'
end

function DB.SetTier(license, tier, grantedBy)
    if not license or license == '' then return false end
    if tier == 'none' then
        MySQL.query.await('DELETE FROM distortionz_perms_ranks WHERE license = ?', { license })
        return true
    end
    MySQL.query.await([[
        INSERT INTO distortionz_perms_ranks (license, tier, granted_by)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE tier = VALUES(tier), granted_by = VALUES(granted_by)
    ]], { license, tier, grantedBy })
    return true
end

function DB.ListByTier(tier)
    local rows = MySQL.query.await(
        'SELECT license, tier, granted_by, granted_at FROM distortionz_perms_ranks WHERE tier = ? ORDER BY granted_at',
        { tier }
    )
    return rows or {}
end

function DB.ListAll()
    local rows = MySQL.query.await(
        'SELECT license, tier, granted_by, granted_at, updated_at FROM distortionz_perms_ranks ORDER BY tier DESC, granted_at',
        {}
    )
    return rows or {}
end
