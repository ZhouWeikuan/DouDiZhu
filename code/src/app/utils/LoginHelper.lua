local skynet = skynet or require "skynet"
local crypt = skynet.crypt or require "skynet.crypt"

local AuthUtils = require "AuthUtils"

local strHelper    = require "StringHelper"
local packetHelper = require "PacketHelper"

local RemoteSocket = require "RemoteSocket"

local protoTypes   = require "ProtoTypes"


---! create the class metatable
local class = {mt = {}}
class.mt.__index = class

---! create delegate object
class.create = function (const)
    local self = {}
    setmetatable(self, class.mt)

    self.message = ""
    self.agentList = {}
    self.const = const

    return self
end

class.createFromLayer = function (delegate, handler, botName, authInfo, const)
    if delegate.login then
        delegate.login:releaseFromLayer(delegate)
    end

    local login = class.create(const)
    delegate.login = login

    login:getOldLoginList()
    login:tryConnect()

    if login.remotesocket then
        local BotPlayer = require(botName)
        local agent     = BotPlayer.create(delegate, authInfo, handler)
        delegate.agent  = agent
        handler.agent   = agent

        delegate.agent:sendAuthOptions(protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME)
        return true
    end
end

class.tickCheck = function (self, delegate)
    if self.remotesocket and self.remotesocket:isClosed() then
        self.remotesocket = nil
    end

    if not self.remotesocket then
        self:tryConnect()

        if not self.remotesocket then
            if MessageBox then
                MessageBox("请确定网络正常后再重试，或联系我们客服QQ群: 543221539", "网络出错")

                local app = cc.exports.appInstance
                local view = app:createView("LineScene")
                view:showWithScene()
            else
                print("请确定网络正常后再重试，或联系我们客服QQ群: 543221539", "网络出错")
            end
            return
        end

        delegate.agent:sendAuthOptions(protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME)
        return true
    end
end

class.closeSocket = function (self)
    if self.remotesocket then
        self.remotesocket:close()
        self.remotesocket = nil
    end
end

class.releaseFromLayer = function (self, delegate)
    self:closeSocket()
    delegate.login = nil
end

---! agent list, maybe better two host:port for each site
local def_agent_list = {"192.168.0.121:8201", "192.168.0.122:8201"}

---! check for all agents, find the best one if doCheck
class.checkAllLoginServers = function (self, doCheck)
    local best = table.concat(def_agent_list, ",")
    if not doCheck then
        return best
    end

    local probs = def_agent_list
    local diff  = 9999
    for i, item in ipairs(probs) do
        local oldTime = skynet.time()
        local host, port = string.match(item, "(%d+.%d+.%d+.%d+):(%d+)")
        local conn = RemoteSocket.create(host, port)
        if conn and conn.sockfd then
            local tmp = skynet.time() - oldTime
            print("diff for item ", item, " is ", tmp)
            if not best or diff > tmp then
                diff = tmp
                best = item
            end
            conn:close()
        end
    end

    return best
end

class.getOldLoginList = function (self, refreshLogin, checkForeign)
	self.message = "msgParsingOldLoginServers"

	local data = AuthUtils.getItem(AuthUtils.keyLoginList, "")
	if refreshLogin or data == "" then
		data = self:checkAllLoginServers(checkForeign)
	end

	self.agentList = {}

	local arr = {}
	for w in string.gmatch(data, "[^,]+") do
        table.insert(arr, w)
    end

    if #arr < 1 then
		arr = def_agent_list
    end

    for _, v in ipairs(arr) do
    	local host, port = string.match(v, "(%d+.%d+.%d+.%d+):(%d+)")
    	local one = {}
    	one.host = host
    	one.port = port

    	local r = tostring(math.random())
    	self.agentList[r] = one
    end
end

class.sendHeartBeat = function (self)
    local info = {}
    info.fromType  = protoTypes.CGGAME_PROTO_HEARTBEAT_CLIENT
    info.timestamp = skynet.time()

    local data = packetHelper:encodeMsg("CGGame.HeartBeat", info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                        protoTypes.CGGAME_PROTO_SUBTYPE_HEARTBEAT, data)
    if self.remotesocket then
        self.remotesocket:sendPacket(packet)
    end
    -- print("sendHeartBeat", self.remotesocket)
end

class.tryConnect = function (self)
	self.message = "msgTryLoginServers"

	for k, v in pairs(self.agentList) do
		local conn = RemoteSocket.create(v.host, v.port)
		if conn and conn.sockfd then
            if self.remotesocket then
                self.remotesocket:close()
                self.remotesocket = nil
            end

			self.remotesocket = conn
			print("agent to ", v.host, v.port, " success")
			return conn
		end
	end

	return nil
end

class.getAgentList = function (self)
    self.message = "msgRefreshLoginServerList"

    local data = packetHelper:encodeMsg("CGGame.AgentList", {})
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                        protoTypes.CGGAME_PROTO_SUBTYPE_AGENTLIST, data)
	self.remotesocket:sendPacket(packet)
end

class.tryHall = function (self, gameMode)
    self.message = "msgRefreshHallServerList"
    local const = self.const

    local info = {
        gameId         = const.GAMEID,
        gameMode       = gameMode or 0,
        gameVersion    = const.GAMEVERSION,
    }

    local data = packetHelper:encodeMsg("CGGame.HallInfo", info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                        protoTypes.CGGAME_PROTO_SUBTYPE_HALLJOIN, data)
	self.remotesocket:sendPacket(packet)
end

class.sendUserInfo = function (self)
    local authInfo = AuthUtils.getAuthInfo()

    local info = {
        FUserCode   = authInfo.userCode,
        FNickName   = authInfo.nickname,
        FOSType     = authInfo.osType,
        FPlatform   = authInfo.platform,
    }
    info.fieldNames = {"FUserCode", "FNickName", "FOSType", "FPlatform"}

    print("send user info", info)
    local debugHelper = require "DebugHelper"
    debugHelper.cclog("send user info", info)
    debugHelper.printDeepTable(info)
    debugHelper.printDeepTable(authInfo)

    local data = packetHelper:encodeMsg("CGGame.UserInfo", info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                        protoTypes.CGGAME_PROTO_SUBTYPE_MYINFO, data)
	self.remotesocket:sendPacket(packet)
end

class.tryGame = function (self, gameMode)
    self.message = "msgRefreshGameServerList"
    local const = self.const

    local info = {
        gameId         = const.GAMEID,
        gameMode       = gameMode or 0,
        gameVersion    = const.GAMEVERSION,
    }

    local data = packetHelper:encodeMsg("CGGame.HallInfo", info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME,
                        protoTypes.CGGAME_PROTO_SUBTYPE_GAMEJOIN, data)
	self.remotesocket:sendPacket(packet)
end


return class

