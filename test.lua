local dis = require("discord")

local cjson = require("cjson")
--3276798
local client = dis:Client({dis.Intents.GUILDS})
local token = "bot_token"

function client._onAll(data)
	print("event",data)
end

function client.onReady(data)
	client.updatePresence{
		since=os.time(),
		activities = {
			{name="LuaRocks",type=0}
		},
		status="online",
		afk=false,
	}
	--[[client.interactions:overwriteGuild(1044037175844544552,{
	{name="info",description="Obtener la info del bot"}
	})]]
end

function client.onInteractionCreate(interaction)
	if interaction.data.type == 1 then
		if interaction.data.name == "info" then
			interaction:reply({content="hi",embeds={
				{title="Informacion del bot",
				color=0x00ffff,
				fields={
					{name="Tiempo en linea",value=tostring(os.clock())},
					{name="Hora",value="<t:"..os.time()..">"},
					{name="RAM usada",value=tostring(collectgarbage("count"))},
					{name="Procesador",value=os.getenv("PROCESSOR_ARCHITECTURE")}
				},
				footer={text="El bot usa Lua y LuaRocks"}
				}
			}})
		end
	end
end

client.login(token)