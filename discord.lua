local Discord = {}

local function warn(str)
	print("Warning: "..str)
end

Discord.ws = require("ws")
Discord.sock = require("socket")

Discord.params = {
	mode = "client",
	protocol = "tlsv1_2",
	options = {"all", "no_sslv2", "no_sslv3", "no_tlsv1"},
	verify = "none",
}

Discord.Intents = {
	GUILDS = 1,
	GUILD_MEMBERS = 2,
	GUILD_MODERATION = 4,
	GUILD_EMOJIS_AND_STICKERS = 8,
	GUILD_INTEGRATIONS = 16,
	GUILD_WEBHOOKS = 32,
	GUILD_INVITES = 64,
	GUILD_VOICE_STATES = 128,
	GUILD_PRESENCES = 256,
	GUILD_MESSAGES = 512,
	GUILD_MESSAGE_REACTIONS = 1024,
	GUILD_MESSAGE_TYPING = 2048,
	DIRECT_MESSAGES = 4096,
	DIRECT_MESSAGE_REACTIONS = 8192,
	DIRECT_MESSAGE_TYPING = 16384,
	MESSAGE_CONTENT = 32768,
	GUILD_SCHEDULED_EVENTS = 65536,
	AUTO_MODERATION_CONFIGURATION = 1048576,
	AUTO_MODERATION_EXECUTION = 2097152
}

Discord.https = require("ssl.https")
Discord.socks = require("ssl")
Discord.ltn12 = require("ltn12")
Discord.json = require("cjson")
Discord.splitText = function(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={}
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                table.insert(t, str)
        end
        return t
end

function Discord:req(path,method,headers,body)
	local t = {}
	local s,c,h = self.https.request{
		url = "https://discord.com/api/v10"..path,
		sink = self.ltn12.sink.table(t),
		source = (body~=nil) and self.ltn12.source.string(body) or nil,
		protocol = "tlsv1_2",
		method = method or "GET",
		headers = headers
	}
	return table.concat(t),h,c,s
end
Discord.token = "" --bot token
function Discord:httpB(path,method,body) --bot requests
	return self:req(path,method,{Authorization="Bot "..self.token,["User-Agent"]="DiscordBot (::1, v10)"},body)
end
function Discord:http(path,method,body,token) --bearer
	return self:req(path,method,{Authorization="Bearer "..token},body)
end

Discord.MainURL = "discord.com"
Discord.API = 10

function Discord:Client(intents)
	local client = {}
	client.Intents = 0
	if type(intents) == "table" then
		for k,v in ipairs(intents) do
			client.Intents = client.Intents + v
		end
	else client.Intents = tonumber(intents) or 0
	end

	client.updatePresence = function() end
	client.updateVoiceState = function() end

	client.asyncClients = {}
	client.asyncFunctions = {}

	client.removeasync = {}

	client.httpAsync=function(url,t,func)
		t.sec = (t.sec==nil) and true or t.sec
		t.method = t.method or "GET"
		t.path = t.path or "/"
		t.headers = t.headers or {}
		local c = self.sock.tcp()
		table.insert(client.asyncClients,c)
		local _ip = self.sock.dns.toip(url)
		print(_ip)
		local s = c:connect(_ip,(t.sec) and 443 or 80)
		if not s then
			if func then func("failed to connect") return end
		end
		
		if t.sec then
			c=self.socks.wrap(c,self.params)
			c:dohandshake()
		end
		local headers = ""
		t.headers["Host"]=url
		t.headers["Transfer-Encoding"]=(t.method=="POST" or t.method=="PUT" or t.method == "PATCH") and "chunked" or nil
		t.headers["Authorization"]= "Bot "..self.token
		t.headers["User-Agent"]="DiscordBot (localhost, 10)"
		t.headers["Content-Type"]=(t.method~='DELETE') and "application/json" or nil
		for k,v in pairs(t.headers) do
			headers = headers..k..":"..v.."\r\n"
		end
		c:send(t.method.." "..t.path.." HTTP/1.1\r\n")
		c:send(headers.."\r\n")
		print(t.method,t.path,headers,t.body)
		local body = t.body or ""
		print(body)
		local received = {body="",headers={},code=0,try=0,reqleft=nil,chunked=false}
		local funkey = tostring(math.random(0,2^31))
		repeat
			if client.asyncFunctions[funkey] then 
				funkey=tostring(math.random(0,2^31))
			end
		until not client.asyncFunctions[funkey]
		client.asyncFunctions[funkey] = (function()
			if #body > 0 then
				local chunk = body:sub(0,512)
				body = body:sub(512)
				c:send(("%X"):format(#chunk).."\r\n")
				c:send(chunk.."\r\n")
				if #body==0 then local sss=c:send("00\r\n\r\n") end
			else
				local headnum = 0
				for _,i in pairs(received.headers) do
					headnum=headnum+1
				end
				if received.code == 0 then
					local r1 = c:receive()
					print(r1)
					received.code = tonumber(self.splitText(r1)[2])
					received.try=received.try+1
					if received.try >= 25 then
						c:close()
						table.insert(client.removeasync,funkey) print("TIMEOUT-sv")
						func("server timeout")
					end
				elseif headnum==0 then
					local r1 = ""
					repeat	
						r1 = c:receive()
						if r1~="" then
							local f1 = r1:find(":")
							local s1 = {r1:sub(0,f1-1),r1:sub(f1+1)}
							received.headers[s1[1]:lower()]=(s1[2]:sub(1,1))==" " and s1[2]:sub(2) or s1[2] --remove optional whitespace
						end
					until r1==""
					received.chunked = (received.headers["transfer-encoding"] == "chunked")
					received.reqleft = received.headers["content-length"] or nil
				else
					if received.reqleft then
						received.body=c:receive(received.reqleft)
						c:close()
						table.insert(client.removeasync,funkey)
						func(received)
					elseif received.chunked then
						local hex = c:receive()
						hex=tonumber(hex,16)
						if hex == 0 then
							c:close()
							table.insert(client.removeasync,funkey)
							func(received)
						elseif hex then
							local b = c:receive(hex)
							received.body = received.body..b
						end
					else
						c:close()
						table.insert(client.removeasync,funkey)
						func(received)
					end
				end
			end
		end)
	end

	client.applicationid = ""

	client.login = function(token)
		self.token = token
--		local req = self:httpB("/gateway/bot","GET")
--		print(req)
local function connect(retrying)
		if retrying then print("connection retry") else print("eoeoeoeoeoeoe") end
		local connection = self.ws.client()
		local conx = {
			lastACK = os.clock(), --last heart beat ack
			hbrate = 0, --rate
			hbclock = -99999,--heart beat clock
			handshake = true, --check if handshake isn't made
			seq = self.json.null, --sequence number
			resume = {
				can = false,
				url = "",
				id = "",
			},
		}

		client.updatePresence = function(D)
			connection:send(self.json.encode{op=3,d=D})
		end
		client.updateVoiceState = function(D)
			connection:send(self.json.encode{op=4,d=D})
		end
		--connection:settimeout(0.5)

--		local function connect(retrying)

			connection:connect("gateway.discord.gg","/?v=10&encoding=json",443,self.params)
print("connected")
			local dat,op = connection:receive()
			if dat and op == 1 then
				local js = self.json.decode(dat)
				conx.hbrate = js.d.heartbeat_interval/1000
			else connection:close() connect(true)
			end
			print(conx.hbrate,os.clock(),conx.hbclock)
			connection:settimeout(0.5)
			while 1 do
				for a,b in pairs(client.asyncFunctions) do b() for c,d in pairs(client.removeasync) do client.asyncFunctions[d]=nil client.removeasync[c]=nil end end
				local dat,opcode = connection:receive()
				if (os.clock()-conx.hbclock >= conx.hbrate) or (opcode == 9) then
					connection:send(self.json.encode{op=1,d=conx.seq})
					conx.hbclock = os.clock()
				end
				if opcode == 8 then
					print(dat)
					local h1 = ("%X"):format(string.byte(dat:sub(1,1)))
					local h2 = ("%X"):format(string.byte(dat:sub(2,2)))
					local h3 = h1..string.rep("0",2-#h2)..h2
					print("closed with error", tonumber(h3,16) ) break
				end

				if dat then
					local js = self.json.decode(dat)
					local opD = js.op
					if js.s ~= self.json.null then
						conx.seq = js.s
					end
					
					if opD == 11 then
						conx.lastACK = os.clock()
					elseif opD == 0 then
						local ev = js.t
						if ev == "READY" then
							conx.resume.can = true
							conx.resume.url = tostring(js.d.resume_gateway_url):sub(7,9999)
							conx.resume.id = js.d.session_id
							if js.d.application then
								client.applicationid=js.d.application.id
							else
								warn("Application ID wasn't found!")
							end
						end
						if type(client._onAll)=="function" then
							client._onAll(dat)
						end
						local split = self.splitText(ev,"_")
						local nam = "on"
						for k,v in pairs(split) do
							nam = nam..string.upper(v:sub(1,1))..string.lower(v:sub(2,999999))
						end

						if type(client[nam])=="function" then
							local obj = js.d
							if js.t == "INTERACTION_CREATE" then
								obj.reply = function(self,content) 
									client.httpAsync("discord.com",{
										sec=true,
										path="/api/v10/interactions/"..self.id.."/"..self.token.."/callback",
										body=Discord.json.encode({type=4,data=content}),
										method="POST"},
										function(i)
											print(i.body)
											return true
										end)
								end	
							end
							client[nam](obj)
						end
					end

					
					if conx.handshake == true then
						conx.handshake = false
						connection:send(self.json.encode{op=2,d={token=self.token,properties={os="lua",browser="lua",device="lua"},intents=client.Intents}})
					end
				end
				if os.clock()-conx.lastACK>= conx.hbrate+5 then
					connection:close()
					connect(true)
				end
			end
		end

		connect()
	end

	client.interactions = {}

	client.interactions.getAll = function(self,func)
		return client.httpAsync(Discord.MainURL,{path="/api/v"..Discord.API.."/applications/"..client.applicationid.."/commands"},function(i) func(Discord.json.decode(i.body)) end)
	end

	client.interactions.getGuild = function(self,id,func)
		return client.httpAsync(Discord.MainURL,{path="/api/v"..Discord.API.."/applications/"..client.applicationid.."/guilds/"..id.."/commands"},function(i) func(Discord.json.decode(i.body)) end)
	end

	client.interactions.overwriteGuild = function(self,id,tab,func)
		if not func then func=function() end end
		print("o")
		self:getGuild(id,function(list)
			print(list,Discord.json.encode(list))
			local removeindex = {}
			for i,v in pairs(tab) do
				for a,b in ipairs(list) do
					print(i,v,a,b)
					if b.name == v.name and b.description == v.description then
						table.insert(removeindex,i)
						break
					end
				end
			end
			for a,b in ipairs(removeindex) do
				tab[b]=nil
			end
			print("toy actualizando?",#tab,Discord.json.encode(tab))
			if #tab == 0 then return end --Can't update existing commands
			client.httpAsync(Discord.MainURL,
			{path="/api/v"..Discord.API.."/applications/"..client.applicationid.."/guilds/"..id.."/commands", method="PUT", body = Discord.json.encode(tab)},
			function(i) func(Discord.json.decode(i.body)) end)
		end)
	end
	
	return client
end

return Discord
