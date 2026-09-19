fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-multijob'
version '2.0.8'

shared_scripts { 
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts { 
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/webhook.lua',
    'server/server.lua',
    'server/versionchecker.lua'
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

server_exports {
    'AddJob',
    'RemoveJob',
    'GetJobs',
}

lua54 'yes'