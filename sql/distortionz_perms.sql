-- =====================================================================
--  Distortionz Perms — schema. Safe to run any time (IF NOT EXISTS).
-- =====================================================================

CREATE TABLE IF NOT EXISTS distortionz_perms_ranks (
    license    VARCHAR(60) PRIMARY KEY,
    tier       VARCHAR(32) NOT NULL,
    granted_by VARCHAR(60) NULL,
    granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_tier (tier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- citizenid -> license directory, built up automatically as players
-- connect. Lets citizenid-based lookups (offline admin actions,
-- /setrank by cid) keep working even though ranks themselves are
-- keyed by license.
CREATE TABLE IF NOT EXISTS distortionz_perms_identities (
    citizenid  VARCHAR(50) PRIMARY KEY,
    license    VARCHAR(60) NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_license (license)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
