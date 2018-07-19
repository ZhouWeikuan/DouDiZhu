local skynet = skynet or require "skynet"

local class = {mt = {}}
local HallInterface = class
class.mt.__index = class
---!@brief 创建一个HallInterface对象
---!@param conf
---!@return self     返回HallInterface
class.create = function (conf)
    local self = {}
    setmetatable(self, class.mt)
    --- self.tickInterval TODO
    self.tickInterval = 5
    --- self.config  TODO
    self.config = conf

    local numset = require "NumSet"
    --- self.onlineUser 存放用户信息，可以通过getObject()获得其中的用户信息data【uid】
    self.onlineUsers = numset.create()

    return self
end

---!@brief  TODO
---!@param 
class.getMode = function(self)
    return self.config.gameMode
end

---!@brief  TODO
---!@param 
class.tick = function(self, dt)
end

---!@brief 添加用户到onlineUsers
---!@param player      用户信息
class.addPlayer = function(self, player)
end

---!@brief TODO
---!@param 
class.handleGameData = function (self, player, data)
    print("you should derive HallInterface:handleGameData")
end

class.handleRoomData = function (self, data)
    print("you should derive HallInterface:handleGameData")
end

---!@brief 将用户从onllineUsers中移除
---!@param 
class.removePlayer = function(self, player)
end

---!@brief 获取用户的信息
---!@param uid     用户的Id    
---!@return user   返回的用户信息
class.getUserInfo = function (self, uid, tryDB)
    local user = self.onlineUsers:getObject(uid)
    if not user and tryDB and snax then
        local packetHelper  = require "PacketHelper"

        user = {}
        user.FUniqueID = uid

        local ret = clusterHelper.snax_call(clusterHelper.get_InfoServer(), "DBService", function(proxy)
            local info = proxy.req.loadDB(user.FUniqueID)
            return info
        end)

        if ret then
            packetHelper.copyTable(ret, user)
        end

        local db = snax.uniqueservice("DBService")
        local info = db.req.loadDB(user.FUniqueID)
        packetHelper.copyTable(info, user)
    end
    return user;
end

---!@brief 获得用户数量
---!@return count  用户的具体数量
class.getAvailPlayerNum = function(self)
    local clients = self.onlineUsers:getCount()
    local max = self.config.MaxConnections
    local count = max - clients;
    if count < 0 then count = 0 end

    return count
end

---!@brief 获得系统内部状态
---!@return info 内部状态的描述
class.get_stat = function (self)
    return "HallInterface"
end

---!@brief 发送消息给用户
---!@param packet       消息的内容
---!@param uid          用户Id
class.sendPacketToUser = function (self, packet, uid)
    local user = self:getUserInfo(uid)
    if not user or not user.agent then
        return
    end

    if snax then
        skynet.send(user.agent, "lua", "sendProtocolPacket", packet)
    else
        user.agent:recvPacket(packet)
    end
end


return HallInterface

