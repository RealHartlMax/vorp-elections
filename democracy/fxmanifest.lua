fx_version 'cerulean'

game "rdr3"
author 'Jeffy & Beffy of Godz Country & RealHartlMax'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

shared_scripts {
	'config.lua',
	'config/system.lua',
	'config/offices.lua',
	'config/locations.lua',
	'lang.lua',
	'lang/en.lua',
	'lang/de.lua'
}

ui_page 'ui/index.html'

files {
	'ui/index.html',
	'ui/style.css',
	'ui/app.js'
}

client_scripts {
	'client.lua',
	
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server.lua'
}
