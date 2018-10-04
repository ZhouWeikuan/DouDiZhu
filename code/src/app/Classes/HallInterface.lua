---! 系统库
local skynet    = skynet or require "skynet"

---! 依赖库
local NumSet        = require "NumSet"
local PrioQueue     = require "PriorityQueue"

local protoTypes    = require "ProtoTypes"

local dbHelper      = require "DBHelper"
local debugHelper   = require "DebugHelper"
local packetHelper  = require "PacketHelper"
local strHelper     = require "StringHelper"
local tabHelper     = require "TableHelper"

---! HallInterface
local class = {mt = {}}
class.mt.__index = class

---! proto fields
class.UserInfo_ProtoName = "CGGame.UserInfo"
class.UserInfo_Fields = {
    "FUserCode", "FNickName", "FUserName", "FOSType", "FPassword",
    "FTotalTime", "FAvatarID", "FAvatarUrl", "FAvatarData",
    "FMobile", "FEmail", "FIDCard", "FLastIP", "FLastLoginTime", "FRegTime",
    "FLongitude", "FLatitude", "FAltitude", "FLocation", "FNetSpeed",
}
class.DBTableName = "TUser"

---! creator
class.create = function (conf)
    local self = {}
    setmetatable(self, class.mt)
    self.config = conf

    self.tickInterval = conf.TickInterval or 20

    --- self.onlineUsers 存放用户信息，可以通过getObject()获得其中的用户信息data【uid】
    self.onlineUsers = NumSet.create()
    self.eventQueue = PrioQueue.create(function (obj) return obj end, function (obj) return obj.timeout end, "[EQueue]")

    return self
end

---!@brief  access game mode in config
class.getMode = function(self)
    return self.config.gameMode
end

---! 增加延时事件
class.addDelayEvent = function (self, delay, func)
    local event = {
        timeout = skynet.time() + delay,
        handler = func,
    }
    self.eventQueue:addObject(event)
end

---! 延时事件处理
class.executeEvents = function (self)
    local now       = skynet.time()
    local event     = self.eventQueue:top()
    while event and now >= event.timeout do
        event = self.eventQueue:pop()
        event.handler()

        event = self.eventQueue:top()
    end
end

---! 定时驱动
class.tick = function (self, dt)
    print("HallInterface game tick frame")
end

class.remoteExecDB = function (self, strSQL)
    if not cluster then
        return
    end
    local app, addr = clsHelper.getMainAppAddr(clsHelper.kDBService)
    if not app or not addr then
        return
    end

    local flg, ret = pcall(cluster.call, app, addr, "execDB", strSQL)
    ret = ret or {}
    if not flg or not ret then
        print("Failed to execDB", ret)
    end
    return ret
end

class.remoteLoadDB = function (self, tableName, keyName, keyValue, noInsert)
    if not cluster then
        return
    end
    local app, addr = clsHelper.getMainAppAddr(clsHelper.kDBService)
    if not app or not addr then
        return
    end

    local flg, ret = pcall(cluster.call, app, addr, "loadDB", tableName, keyName, keyValue, noInsert)
    ret = ret or {}
    if not flg or not ret then
        print("Failed to loadDB", tableName, keyName, keyValue)
    end
    return ret
end

class.remoteUpdateDB = function (self, tableName, keyName, keyValue, fieldName, fieldValue)
    if not cluster then
        return
    end
    local app, addr = clsHelper.getMainAppAddr(clsHelper.kDBService)
    if not app or not addr then
        return
    end

    local flg = pcall(cluster.send, app, addr, "updateDB", tableName, keyName, keyValue, fieldName, fieldValue)
    if not flg then
        print("Failed to updateDB", tableName, keyName, keyValue, fieldName, fieldValue)
    end
end

class.remoteDeltaDB = function (self, tableName, keyName, keyValue, fieldName, deltaValue)
    if not cluster then
        return
    end
    local app, addr = clsHelper.getMainAppAddr(clsHelper.kDBService)
    if not app or not addr then
        return
    end

    local flg = pcall(cluster.send, app, addr, "deltaDB", tableName, keyName, keyValue, fieldName, deltaValue)
    if not flg then
        print("Failed to deltaDB", tableName, keyName, keyValue, fieldName, deltaValue)
    end
end

class.remoteAddAppGameUser = function (self, user)
    if not cluster then
        return
    end
    local app, addr = clsHelper.getMainAppAddr(clsHelper.kMainInfo)
    if not app or not addr then
        return
    end

    local flg = pcall(cluster.send, app, addr, "addAppGameUser", user.FUniqueID, self.config.GameId)
    if not flg then
        print("Failed to addAppGameUser", user.FUniqueID, self.config.GameId)
    end
end

class.remoteDelAppGameUser = function (self, user)
    if not cluster then
        return
    end
    local app, addr = clsHelper.getMainAppAddr(clsHelper.kMainInfo)
    if not app or not addr then
        return
    end

    local flg = pcall(cluster.send, app, addr, "delAppGameUser", user.FUniqueID, self.config.GameId)
    if not flg then
        print("Failed to delAppGameUser", user.FUniqueID, self.config.GameId)
    end
end

---! @brief 发送玩家的信息
---! @param recvUid            玩家的游戏ID
---! @param sendUid
class.SendUserInfo = function (self, recvCode, sendCode)
    local info = self:getUserInfo(sendCode)
    if not info then
        return
    end

    local packet = self:CollectUserInfo(info)
    self:hallPacketToUser(packet, recvCode)
end

---! 收集用户信息 TUser class.DBTableName
class.CollectUserInfo = function (self, info)
    local need = {}
    for k, f in ipairs(class.UserInfo_Fields) do
        need[f] = info[f]
    end

    local data   = packetHelper:encodeMsg(class.UserInfo_ProtoName, need)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                        protoTypes.CGGAME_PROTO_SUBTYPE_USERINFO, data)
    return packet
end

---! @brief 发送玩家的状态
---! @param user    玩家的游戏数据
---! @param uid     接受的用户的ID
class.SendUserStatus = function(self, recvCode, sendCode)
    local user = self:getUserInfo(sendCode)
    if not user then
        return
    end

    local packet = self:CollectUserStatus(user)
    self:sendPacketToUser(packet, recvCode)
end

---! 收集用户信息 self.config.DBTableName
class.CollectUserStatus = function (self, user)
end

---! @brief 房间的进入提示文本
---! @param
class.SendHallText = function(self, code)
    local text = self.config.HallText
    if not text or not code then
        return
    end

    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                        protoTypes.CGGAME_PROTO_SUBTYPE_HALLTEXT, text)
    self:hallPacketToUser(packet, code)
end

---! @brief 房间的进入提示文本
---! @param
class.SendGameText = function(self, code)
    local text = self.config.GameText
    if not text or not code then
        return
    end

    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                        protoTypes.CGGAME_PROTO_SUBTYPE_GAMETEXT, text)
    self:gamePacketToUser(packet, code)
end

---! @brief 发送用户聊天
class.SendUserChat = function (self, fromCode, msgBody)
    local user = self:getUserInfo(fromCode)
    if not user or not msgBody then
        return
    end

    ---! 日志记录 屏蔽维语藏语
    local chatInfo = packetHelper:decodeMsg("CGGame.ChatInfo", msgBody)
    if chatInfo.chatType ~= 1 then
        local d = self:FilterText(chatInfo)
        msgBody = d or msgBody
    end

    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                        protoTypes.CGGAME_PROTO_SUBTYPE_CHAT, msgBody)

    if user.tableId then
        local table = self.allTables[user.tableId]

        if table then
            table:groupAction("playerUsers", function (seatId, code)
                self:hallPacketToUser(packet, code)
            end)

            return
        end
    end

    self:hallPacketToUser(packet, fromCode)
end

---! @brief 发送礼物
class.SendUserGift = function (self, fromCode, msgBody)
    local user = self:getUserInfo(fromCode, true)
    if not user or not msgBody then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_INFO, fromCode)
        return
    end

    local giftInfo = packetHelper:decodeMsg("CGGame.GiftInfo", msgBody)
    if not giftInfo or not giftInfo.giftName or giftInfo.srcSeatId == 0
        or giftInfo.dstSeatId == 0 or giftInfo.srcSeatId == giftInfo.dstSeatId then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_INFO, fromCode)
        return
    end

    user.FCounter = user.FCounter or 0
    local cost = nil
    local gameClass = nil
    if self.config.GameClass then
        gameClass = require(self.config.GameClass)
    end
    if gameClass and gameClass.getGiftPrice then
        cost = gameClass:getGiftPrice(giftInfo.giftName)
    end
    if not cost then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_INFO, fromCode)
        return
    elseif user.FCounter < cost then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_COUNTER_FAILED, fromCode)
        return
    end

    giftInfo.coinCost = cost
    user.FCounter = user.FCounter - cost
    if cluster then
        remoteDeltaDB(self.config.DBTableName, "FUserCode", user.FUserCode, "FCounter", -cost)
    end

    msgBody = packetHelper:encodeMsg("CGGame.GiftInfo", giftInfo)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME,
                        protoTypes.CGGAME_PROTO_SUBTYPE_GIFT, msgBody)

    if user.tableId then
        local table = self.allTables[user.tableId]

        if table then
            table:groupAction("playerUsers", function (seatId, code)
                self:sendPacketToUser(packet, code)
            end)
            table:groupAction("standbyUsers", function (seatId, code)
                self:sendPacketToUser(packet, code)
            end)
            return
        end
    end

    self:gamePacketToUser(packet, fromCode)
end

class.fetchUserFromDB = function (self, keyName, keyValue)
    ---! access from db
    local user = self:remoteLoadDB(class.DBTableName, keyName, keyValue)
    local ret = self:remoteLoadDB(self.config.DBTableName, keyName, keyValue)
    if ret then
        if ret.FUserCode and type(ret.FUserCode) == 'string' then
            print(ret.FUserCode, type(ret.FUserCode), debug.traceback())
        end
        tabHelper.copyTable(user, ret)
    end

    if strHelper.isNullKey(user.FRegTime) then
        local stamp = dbHelper.timestamp()
        self:remoteUpdateDB(class.DBTableName, keyName, keyValue, 'FRegTime', stamp)
    end

    return user
end

---!@brief 获取用户的信息
---!@param uid     用户的Id
---!@return user   返回的用户信息
class.getUserInfo = function (self, code, fetchDB)
    local user = self.onlineUsers:getObject(code)
    if user and type(user.FUserCode) == 'string' then
        print("user.FUserCode", user.FUserCode, debug.traceback())
    end
    if not user and fetchDB and cluster then
        user = self:fetchUserFromDB("FUserCode", code)
    end
    if type(user.FUserCode) == 'string' then
        print("user.FUserCode", user.FUserCode, debug.traceback())
    end
    return user
end

class.clearOldPlayer = function (self, player)
    local user = self.onlineUsers:getObject(player.FUserCode)
    if not user then
        user = player
        ---user.status 用户的状态
        user.status = protoTypes.CGGAME_USER_STATUS_IDLE
        return user
    end

    if user.is_offline then
        user.is_offline = nil
    else
        if user.appName and user.watchdog and user.client_fd then
            pcall(cluster.send, user.appName, user.watchdog, "closeAgent", user.client_fd)
        end
    end

    local fields = {
        "appName", "agent", "gate", "client_fd", "address", "watchdog",
    }
    for _, key in ipairs(fields) do
        user[key] = player[key]
    end

    return user
end

---! 增加玩家
class.addPlayer = function (self, player)
    if cluster then
        local user = self:fetchUserFromDB("FUniqueID", player.FUniqueID)
        tabHelper.copyTable(player, user)
    end

    local keyName = "FUserCode"
    player = self:clearOldPlayer(player)
    self.onlineUsers:addObject(player, player[keyName])

    player.start_time = skynet.time()
    debugHelper.cclog("[%s] add player %s, left %d", os.date("%D %T"), tostring(player), self:getAvailPlayerNum())

    player.FLastLoginTime = dbHelper.timestamp()
    self:remoteUpdateDB(class.DBTableName, "FUniqueID", player["FUniqueID"], 'FLastLoginTime', player.FLastLoginTime)

    self:PlayerContinue(player)

    return player[keyName]
end

class.PlayerContinue = function (self, player)
end

class.PlayerBreak = function (self, player)
end

---! @brief 在onlineUsers中清除用户，并且将player清空
---! @param player       玩家的数据
class.removePlayer = function(self, player)
    local user = self:getUserInfo(player.FUserCode)
    if not user then
        return
    end

    if user.agent == player.agent and user.appName == player.appName
            and user.agentSign == player.agentSign then
        self:PlayerBreak(user)
    end

    local delay = skynet.time() - user.start_time
    debugHelper.cclog("[%s] remove player %s in %f sec, left %d", os.date("%D %T"), tostring(user), delay, self:getAvailPlayerNum())
end

class.SendACLToUser = function(self, aclType, code)
    local aclInfo = {
        aclType = aclType,
    }
    local data = packetHelper:encodeMsg("CGGame.AclInfo", aclInfo)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                        protoTypes.CGGAME_PROTO_SUBTYPE_ACL, data)
    self:hallPacketToUser(packet, code)
end

class.agentQuit = function (self, player)
    self:removePlayer(player)
end

class.hallUserInfo = function (self, code, data)
    if not cluster then
        return
    end

    local raw = packetHelper:decodeMsg(class.UserInfo_ProtoName, data)
    if raw.FUserCode ~= code then
        return
    end

    name = "FUserCode"
    local user = self:getUserInfo(raw[name], true)
    for _, key in ipairs(raw.fieldNames) do
        user[key] = dbHelper.trimSQL(raw[key])
        self:remoteUpdateDB(class.DBTableName, name, raw[name], key, user[key])
    end
    local key = "FLastIP"
    self:remoteUpdateDB(class.DBTableName, name, raw[name], key, user[key])

    self:SendUserInfo(code, code)
end

class.checkAgentValid = function (self, agentCode)
    local cmd = string.format("SELECT * FROM TAgent WHERE FAgentCode = '%s'", agentCode);
    local row = self:remoteExecDB(cmd)
    local info = row and row[1] or nil
    local code = info and info.FAgentCode or nil
    if code and code > 0 then
        return true
    end
    return false
end

class.getBindBonus = function (self, gameId)
    local cmd = string.format("SELECT FBindBonus FROM TGame WHERE FGameID = '%s'", gameId)
    local row = self:remoteExecDB(cmd)
    local info = row and row[1] or nil
    local value = info and info.FBindBonus or 0
    return value
end

class.hallUserStatus = function (self, code, data)
    if not cluster then
        return
    end

    local gameClass = require(self.config.GameClass)
    local raw = packetHelper:decodeMsg(gameClass.UserStatus_ProtoName, data)
    if raw.FUserCode ~= code then
        return
    end

    local user = self:getUserInfo(code, true)
    local dest = user or {}

    local field = "FAgentCode"
    if raw[field] then
        if dest[field] and dest[field] > 0 then
            self:sendACLToUser(protoTypes.CGGAME_ACL_STATUS_ALREADY)
        elseif not self:checkAgentValid(raw[field]) then
            self:sendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_AGENTCODE)
        else
            local name = 'FUserCode'
            dest[field] = dbHelper.trimSQL(raw[field])
            self:remoteUpdateDB(class.config.DBTableName, name, code, field, dest[field])

            local count = self:getBindBonus(self.config.GameId)
            field = 'FCounter'
            dest[field] = (dest[field] or 0) + count
            self:remoteDeltaDB(class.config.DBTableName, name, code, field, count)

            return code
        end
    end
    self:SendUserStatus(code, code)
end

class.hallShareBonus = function (self, code, data)
    local info = self:getUserInfo(code)
    local now = os.time()
    local day = dbHelper.getDiffDate(info.FShareDate, now)
    local count = 1
    if day >= 1 then
        count = 1
    else
        count = (info.FShareCount or 0) + 1
    end

    local gameClass = require(self.config.GameClass)
    local maxCnt = gameClass:getShareBonusMaxCount()
    if count > maxCnt then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_SHARE_EXCEED, code)
        return
    end

    local num = gameClass:getShareBonusCurValue()
    local keyName = "FUserCode"
    self:remoteUpdateDB(self.config.DBTableName, keyName, code, "FShareDate", now)
    self:remoteUpdateDB(self.config.DBTableName, keyName, code, "FShareCount", count)

    info.FCounter = (info.FCounter or 0) + num
    self:remoteDeltaDB(self.config.DBTableName, keyName, code, "FCounter", num)

    local bonusInfo = {
        maxCount = maxCnt,
        curCount = count,
        bonusNum = num,
    }
    local data = packetHelper:encodeMsg("CGGame.ShareBonusInfo", bonusInfo)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_BONUS,
                        protoTypes.CGGAME_PROTO_SUBTYPE_BONUS_SHARE, data)
    return uid, packet
end

class.hallDailyBonus = function (self, code, data)
    local keyName = "FUserCode"
    local info = self:remoteLoadDB(self.config.DBTableName, keyName, code)
    local now = os.time()
    local day = dbHelper.getDiffDate(info.FSaveDate, now)
    if day < 1 then
        return
    end

    local count = 1
    if day == 1 then
        count = (info.FSaveCount or 0) + 1
        count = math.min(count, 7)
    end
    self:remoteUpdateDB(self.config.DBTableName, keyName, code, "FSaveDate", now)
    self:remoteUpdateDB(self.config.DBTableName, keyName, code, "FSaveCount", count)

    local gameClass = require(self.config.GameClass)
    local bonus = gameClass:getDailyBonusCounter(count)

    info.FCounter = (info.FCounter or 0) + bonus
    self:remoteDeltaDB(self.config.DBTableName, keyName, code, "FCounter", bonus)
end

class.hallBonus = function (self, code, data)
    if not cluster then
    end

    local user = self:getUserInfo(code)
    if not user or user.FUserCode ~= code then
        return
    end

    local info = packetHelper:decodeMsg("CGGame.ProtoInfo", data)
    if info.mainType == protoTypes.CGGAME_PROTO_BONUS_DAILY then
        self:hallDailyBonus(code, info.msgBody)
    elseif info.mainType == protoTypes.CGGAME_PROTO_BONUS_SHARE then
        self:hallShareBonus(code, info.msgBody)
    else
        skynet.error("Unknown bonus type", info.mainType)
    end
end

class.handleHallData = function (self, player, hallType, data)
    if hallType == protoTypes.CGGAME_PROTO_SUBTYPE_MYINFO then
        self:hallUserInfo(player.FUserCode, data)
    elseif hallType == protoTypes.CGGAME_PROTO_SUBTYPE_MYSTATUS then
        self:hallUserStatus(player.FUserCode, data)
    elseif hallType == protoTypes.CGGAME_PROTO_SUBTYPE_BONUS then
        self:hallBonus(player.FUserCode, data)
    elseif hallType == protoTypes.CGGAME_PROTO_SUBTYPE_USERINFO then
        local info = packetHelper:decodeMsg("CGGame.HallInfo", data)
        self:SendUserInfo(player.FUserCode, info.FUserCode)
    elseif hallType == protoTypes.CGGAME_PROTO_SUBTYPE_USERSTATUS then
        local info = packetHelper:decodeMsg("CGGame.HallInfo", data)
        self:SendUserStatus(player.FUserCode, info.FUserCode)
    else
        skynet.error("Unknown hall type", hallType, data)
        return
    end
    return true
end

class.handleClubData = function (self, player, gameType, data)
    print("HallInterface: handle club data", player, gameType, data)
end

class.handleRoomData = function (self, player, gameType, data)
    print("HallInterface: handle room data", player, gameType, data)
end

class.handleGameData = function (self, player, gameType, data)
    print("HallInterface: handle game data", player, gameType, data)
end

---!@brief 获得用户数量
---!@return count  用户的具体数量
class.getAvailPlayerNum = function(self)
    local clients = self.onlineUsers:getCount()
    local max = self.config.MaxConnections
    return max - clients
end

class.logStat = function (self)
    print (string.format("online player: %d\n", self.onlineUsers:getCount()))
end

---!@brief 发送消息给用户
---!@param packet       消息的内容
---!@param uid          用户Id
class.hallPacketToUser = function (self, packet, code)
    self:sendPacketToUser(packet, code, 0)
end

class.gamePacketToUser = function (self, packet, code)
    self:sendPacketToUser(packet, code, 1)
end

class.sendPacketToUser = function (self, packet, code, api)
    local user = self:getUserInfo(code, true)
    if not user or not user.agent then
        return
    end

    if user.apiLevel < (api or 0) then
        return
    end

    if cluster then
        skynet.send(user.agent, "lua", "sendProtocolPacket", packet)
    else
        user.agent:recvPacket(packet)
    end
end


return class

