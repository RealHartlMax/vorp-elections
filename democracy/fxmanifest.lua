fx_version 'cerulean'

game "rdr3"
author 'Jeffy & Beffy of Godz Country'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

shared_scripts {
	'config.lua',

}

client_scripts {
	'client.lua',
	
}

server_scripts {
	'server.lua',
	'@oxmysql/lib/MySQL.lua'
}
