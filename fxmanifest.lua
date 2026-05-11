fx_version "bodacious"
game "gta5"
lua54 "yes"

ui_page "nui/index.html"

files {
	"nui/index.html",
	"nui/nui.js"
}

client_scripts {
	"@vrp/config/Native.lua",
	"@PolyZone/client.lua",
	"@vrp/lib/Utils.lua",
	"config.lua",
	"client.lua"
}

server_scripts {
	"@vrp/lib/Utils.lua",
	"config.lua",
	"server.lua"
}

shared_scripts {
	"@vrp/config/Global.lua"
}

data_file "ITEMTYPE_IMG" "stream/props.ytyp"