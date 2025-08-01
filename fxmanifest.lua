fx_version 'cerulean'
game 'gta5'

author 'NoHaxJustFrozen'
description 'Kamu Ceza'
version '1.0.2'

shared_scripts {
    'config.lua'
}

client_scripts {
    '@ox_lib/init.lua',
    '@PolyZone/client.lua',
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependency 'ox_lib'
dependency 'PolyZone'
dependency 'oxmysql'
