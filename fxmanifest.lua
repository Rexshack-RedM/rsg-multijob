fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-multijob'
version '3.1.2'

shared_scripts { 
    '@ox_lib/init.lua',
}

client_scripts { 
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/webhook.lua',
    'server/jobs.lua',
    'server/server.lua',
    'server/admin.lua',
    'server/versionchecker.lua'
}

ui_page 'html/index.html'

files {
    'shared/config.lua',
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/admin.css',
    'html/admin.js',
}

server_exports {
    'AddJob',
    'RemoveJob',
    'GetJobs',
    'HasJob',
    'CanTakeJob',
    'GetJobCount',
    'GetJobDefinition',
    'GetJobDefinitions',
}

lua54 'yes'