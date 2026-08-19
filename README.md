# Distortionz Perms

> Shared permissions tier store for Qbox/FiveM — Owner / Admin / Mod ranks consumed by all distortionz_* staff scripts.

![FiveM](https://img.shields.io/badge/FiveM-cerulean-yellow?style=flat-square&labelColor=181b20)
![Qbox](https://img.shields.io/badge/Qbox-required-red?style=flat-square&labelColor=dfb317)
![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)
![Version](https://img.shields.io/github/v/release/Distortionzz/Distortionz_Perms?style=flat-square&color=d4aa62&label=version)

---

## Overview

The canonical permissions backend for the Distortionz stack. Stores tiers (Mod/Admin/Owner) per **license** (not citizenid) in MySQL, exposes exports + event hooks for other scripts to consume, and falls back to FiveM ace permissions when no DB rank is set. Powers `distortionz_admin`, `distortionz_reports`, `distortionz_metrics`, and any future staff-gated script.

## Features

- 4 tiers: `none` → `mod` → `admin` → `owner` with monotonic weights for `>=` checks
- **License-keyed storage** in MySQL — citizenid is per-character, so a demoted or banned player could shed it just by deleting and remaking their character. License is tied to the actual account and survives that.
- **Self-maintained identity directory** (`distortionz_perms_identities`) mapping citizenid → license, built up automatically as players connect. This is what lets citizenid-based lookups (`Get/SetTierByCid`, offline admin actions, `/setrank <citizenid>`) keep working without any other resource having to change how it calls this one — resolution to license happens entirely inside this resource.
- **Bootstrap owners** via `Config.BootstrapOwners` array OR `distortionz_perms_owners` convar (comma-separated), keyed by **license**. This runs at boot before anyone's necessarily connected, so there's no identity mapping yet to resolve a citizenid through — license is knowable offline (your Cfx.re/Steam account, or the join log the first time you connect), which sidesteps that chicken-and-egg problem entirely.
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

**Bootstrap your first Owner** (one of these) — use your **license**, not your citizenid:

```lua
-- Option A: edit config.lua
Config.BootstrapOwners = { 'license:YOUR_LICENSE_HERE' }
```

```cfg
# Option B: server.cfg (preferred — keeps script config pristine)
set distortionz_perms_owners "license:YOUR_LICENSE_HERE"
```

Don't know your license offhand? Connect once with `/mycid` available and check
the server console join log for a line containing `license:` — or pull it from
your Cfx.re/Steam account page.

## Commands

- `/setrank <citizenid> <tier>` — set someone's rank (Owner-only by default). Still takes a citizenid for convenience — resolved to a license internally via the identity directory. Fails with a clear message if that citizenid has never connected while this resource was running (nothing to resolve it to yet).
- `/myrank` — show your current tier
- `/mycid` — show your own citizenid, for quoting in support tickets/bug reports/admin chat

## API

```lua
-- Server
local Permissions = exports.distortionz_perms
local tier = Permissions:GetTier(source)        -- 'none' | 'mod' | 'admin' | 'owner'
local ok   = Permissions:IsAtLeast(source, 'admin')

-- Server — citizenid-keyed variants, for offline targets (e.g. an admin
-- panel that only has a citizenid on hand). Resolved to a license via the
-- identity directory internally; 'none' / false if that citizenid has
-- never connected while this resource was running.
local tier = Permissions:GetTierByCid(citizenid)
local ok, err = Permissions:SetTierByCid(citizenid, 'admin', grantedByLabel)

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
