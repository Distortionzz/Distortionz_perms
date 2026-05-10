# Distortionz Perms

> Shared permissions tier store for Qbox/FiveM — Owner / Admin / Mod ranks consumed by all distortionz_* staff scripts.

![FiveM](https://img.shields.io/badge/FiveM-cerulean-yellow?style=flat-square&labelColor=181b20)
![Qbox](https://img.shields.io/badge/Qbox-required-red?style=flat-square&labelColor=dfb317)
![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)
![Version](https://img.shields.io/github/v/release/Distortionzz/Distortionz_Perms?style=flat-square&color=d4aa62&label=version)

---

## Overview

The canonical permissions backend for the Distortionz stack. Stores tiers (Mod/Admin/Owner) per citizenid in MySQL, exposes exports + event hooks for other scripts to consume, and falls back to FiveM ace permissions when no DB rank is set. Powers `distortionz_admin`, `distortionz_reports`, `distortionz_metrics`, and any future staff-gated script.

## Features

- 4 tiers: `none` → `mod` → `admin` → `owner` with monotonic weights for `>=` checks
- **Citizenid-keyed storage** in MySQL
- **Bootstrap owners** via `Config.BootstrapOwners` array OR `distortionz_perms_owners` convar (comma-separated) — solves the chicken-and-egg of needing an Owner before anyone can `/setrank`
- **Ace fallback** — if no DB rank exists, checks `distortionz.owner` / `distortionz.admin` / `distortionz.mod` ace groups
- **Client-side cache** with auto-refresh on `playerSpawned` + manual `RefreshTier()` export for race-fix scenarios
- **Server export** `Permissions.GetTier(src)` + `IsAtLeast(src, tier)` for callers
- **Events** fired on tier change so consumers can re-evaluate access

## Dependencies

| Resource | Required | Purpose |
|---|---|---|
| `qbx_core` | yes | Player citizenid resolution |
| `ox_lib` | yes | Callbacks |
| `oxmysql` | yes | Tier persistence |

## Installation

```cfg
ensure oxmysql
ensure distortionz_perms
```

**Bootstrap your first Owner** (one of these):

```lua
-- Option A: edit config.lua
Config.BootstrapOwners = { 'YOUR_CITIZEN_ID' }
```

```cfg
# Option B: server.cfg (preferred — keeps script config pristine)
set distortionz_perms_owners "YOUR_CITIZEN_ID"
```

## Commands

- `/setrank <citizenid> <tier>` — set someone's rank (Owner-only by default)
- `/myrank` — show your current tier

## API

```lua
-- Server
local Permissions = exports.distortionz_perms
local tier = Permissions:GetTier(source)        -- 'none' | 'mod' | 'admin' | 'owner'
local ok   = Permissions:IsAtLeast(source, 'admin')

-- Client
local tier = exports.distortionz_perms:GetTier()
exports.distortionz_perms:RefreshTier()         -- force a fresh server-side fetch
```

## Configuration

See [`config.lua`](config.lua) for tier weights, bootstrap owners, ace fallback toggles, client cache TTL.

## Credits

- **Author:** Distortionz
- **Framework:** [Qbox Project](https://github.com/Qbox-project)

## License

MIT — see [LICENSE](LICENSE).
