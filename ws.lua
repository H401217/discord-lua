function binInt(x,cap)
	ret=""
	while x~=1 and x~=0 do
		ret=tostring(x%2)..ret
		x=math.modf(x/2)
	end
	ret=tostring(x)..ret
	return string.rep("0",cap-#ret)..ret
end

function strBin(bin)
	local str = ""
	for i=1,#bin,8 do
		str=str..string.char(tonumber(bin:sub(i,i+7),2))
	end
	return str
end

function strInt(...)
	local arg = {...}
	local str = ""
	for k,v in pairs(arg) do
		str = str..string.char(tonumber(v))
	end
	return str
end

function binStr(str)
	local bin = ""
	for i=1,#str do
		bin=bin..binInt(string.byte(str:sub(i,i)),8)
	end
	return bin
end

local socket = require("socket")
local ssl = require("ssl")
local ws = {}

ws.client = function(newclient)
	local newclient = newclient or socket.tcp()
	local c = {_c = newclient}
	function c:connectm(ip,port,path,host,secure,headers)
		local path = path or "/"
		print("log1:",c._c:connect(ip,port))
		if secure then
			c._c = ssl.wrap(c._c,secure)
			print(c._c:dohandshake())
		end

		local host = host or ip..":"..port
		local sendstr = "GET "..path.." HTTP/1.1\nconnection: Upgrade\nsec-websocket-version: 13\nhost: "..host.."\nsec-websocket-key: H+/nnW7dfSMjhYQ4j5UkTQ==\nupgrade: websocket\n"
		for key,value in pairs(headers or {}) do
			sendstr = sendstr..key..": "..value.."\n"
		end
		sendstr = sendstr.."\n"
print(sendstr)
		print(c._c:send(sendstr))
		local dat = ""
		local _d,_e,_p
		repeat
			_d,_e,_p = c._c:receive()
			if _d or (_p~="" and _p~=nil) then
				dat=dat.. _d .."\n"
			end
		until _d == "\n" or _d == ""
--		print(dat)
	end

	function c:connect(host,path,port,secure,headers)
		local ip = socket.dns.toip(host)
		return self:connectm(ip,port or 80,path or "/",host,secure,headers)
	end

	function c:send(data,opcode) print("test01",data)
		opcode = opcode or 1
		opcode = binInt(opcode,4):sub(1,4)
		local MAX = math.floor(#data/125)
		for i=0,MAX do
			local dat = data:sub(126*i,126*i+125)
			local END = (i==MAX) and "1" or "0"
			local RSV = "000"
			local OP = (0==i) and opcode or "0000"
			local MASKED = "1"
			local LEN = binInt(#dat,7)
			local MASK = {
				math.random(1,255),
				math.random(1,255),
				math.random(1,255),
				math.random(1,255),
			}
			local sMASK = strInt(table.unpack(MASK)) --string
			local SEND = strBin(END..RSV..OP..MASKED..LEN)..sMASK
			local eDAT = "" --encoded
			for i = 1,#dat,1 do
				eDAT = eDAT..string.char( string.byte(dat:sub(i,i)) ~ MASK[((i-1)%4)+1] )
			end
			c._c:send(SEND..eDAT)
		end
	end
	
	function c:receive()
		local dat = c._c:receive(2)
		if dat then
			local c1 = binStr(dat:sub(1,1))
			local c2 = binStr(dat:sub(2,2))
			local END = (c1:sub(1,1)==1) and true or false
			local opcode = tonumber(c1:sub(5,8),2)
			local MASKED = (c2:sub(1,1)==1) and true or false
			local LEN = tonumber(c2:sub(2,8),2)
			
			if LEN == 126 or LEN == 127 then
				local extd = c._c:receive((LEN == 126) and 2 or 8 )
				if extd then
					LEN = tonumber(binStr(extd),2)
				end
			end
			local MASK = {}
			if MASKED then
				
			end
			local DATA
			if LEN > 0 then
				DATA = c._c:receive(LEN)
--print(binStr(DATA),"test02")
			end
			return DATA,opcode
		else
			return nil,"timeout"
		end
	end
	function c:settimeout(t) return c._c:settimeout(t) end
	function c:close(dat)
		c:send(dat or "closed",8)
		c._c:close()
	end
	
	return c
end


return ws
