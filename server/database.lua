-- ╔══════════════════════════════════════════════════════════════════╗
-- ║ Distortionz Permissions — database layer                         ║
-- ╚══════════════════════════════════════════════════════════════════╝

DB = DB or {}

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS distortionz_perms_ranks (
    citizenid VARCHAR(50) PRIMARY KEY,
    tier      VARCHAR(32) NOT NULL,
    granted_by VARCHAR(50) NULL,
    granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_tier (tier)
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

-- ─── CRUD ───────────────────────────────────────────────────────────
function DB.GetTier(citizenid)
    if not citizenid or citizenid == '' then return 'none' end
    local rows = MySQL.query.await(
        'SELECT tier FROM distortionz_perms_ranks WHERE citizenid = ? LIMIT 1',
        { citizenid }
    )
    if rows and rows[1] and rows[1].tier then return rows[1].tier end
    return 'none'
end

function DB.SetTier(citizenid, tier, grantedBy)
    if not citizenid or citizenid == '' then return false end
    if tier == 'none' then
        MySQL.query.await('DELETE FROM distortionz_perms_ranks WHERE citizenid = ?', { citizenid })
        return true
    end
    MySQL.query.await([[
        INSERT INTO distortionz_perms_ranks (citizenid, tier, granted_by)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE tier = VALUES(tier), granted_by = VALUES(granted_by)
    ]], { citizenid, tier, grantedBy })
    return true
end

function DB.ListByTier(tier)
    local rows = MySQL.query.await(
        'SELECT citizenid, tier, granted_by, granted_at FROM distortionz_perms_ranks WHERE tier = ? ORDER BY granted_at',
        { tier }
    )
    return rows or {}
end

function DB.ListAll()
    local rows = MySQL.query.await(
        'SELECT citizenid, tier, granted_by, granted_at, updated_at FROM distortionz_perms_ranks ORDER BY tier DESC, granted_at',
        {}
    )
    return rows or {}
end
