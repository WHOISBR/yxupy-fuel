fx_version 'bodacious'
game 'gta5'

author 'yxupy'
description 'esx legacy fuel added a ui for it :P'
version '1.0'

client_scripts {
	'config.lua',
	'functions/functions_client.lua',
	'source/fuel_client.lua'
}

server_scripts {
	'config.lua',
	'source/fuel_server.lua'
}

exports {
	'GetFuel',
	'SetFuel'
}

ui_page 'html/ui.html'

files {
  'html/ui.html',
  'html/*.otf',
  'html/*.js'
}

