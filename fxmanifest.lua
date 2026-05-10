fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Distortionz'
description 'Distortionz Permissions — shared rank/tier system (mod/admin/owner) consumed by all distortionz_* staff scripts.'
version '1.0.2'
repository 'https://github.com/Distortionzz/Distortionz_Perms'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server.lua',
    'version_check.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
