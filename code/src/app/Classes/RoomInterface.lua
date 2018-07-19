local skynet = skynet or require "skynet"

local prioQueue     = require "PriorityQueue"
local protoTypes    = require "ProtoTypes"

local packetHelper  = require "PacketHelper"

local baseClass     = require "HallInterface"

local class = {mt = {}}
local RoomInterface = class
class.mt.__index = class

setmetatable(class, baseClass.mt)

---------------------------------------------------------------
---!  @packet derived functions from HallInterface
---------------------------------------------------------------
local
___RoomInterface___ = function () end

---!@brief 创建RoomInterface的对象
---!@param conf        TODO
---!@return slef       返回创建的RoomInterface
class.create = function (conf)
    local self = baseClass.create(conf)
    setmetatable(self, class.mt)


    --- self.nextTableId  房间中桌子的数量
    self.nextTableId = 0
    --- self.allTables    房间中的所有桌子
    self.allTables = {}

    --- self.waitTables   将处于Idle状态的桌子放在prioQueue类型的对象中，可以通过prioQueue中定义的方法操作，如：pop（）拿出第一个元素
    self.waitTables     = prioQueue.create(function (obj) return obj.tableId end, function (obj) return -obj:getPlayerCount() end, "[WIDX]")
    ---! getKey, getPriority, queueIndexKey
    self.eventTables    = prioQueue.create(function (obj) return obj.tableId end, function (obj) return obj.timeout end, "[EIDX]")

    self.expireTables   = prioQueue.create(function (obj) return obj.tableId end, function (obj) return obj.expireTime end, "[EXPIREIDX]")

    ---！self.tickInterval  初始设定为0.2second
    self.tickInterval   = 20

    return self
end

---! @package table management
---！@brief 在房间中添加一个桌子
---！@return tab      通过GameClass.create()创建的对象
class.createTable = function (self)
    self.nextTableId = self.nextTableId + 1

    -- local cls = require (self.config.GameClass)
    -- local tab = cls.create(self)

    local tab = packetHelper.createObject(self.config.GameClass, self)

    self.allTables[tab.tableId] = tab

    return tab
end

---！@brief 获得一个处于Idle状态的桌子
---! @return table     获得的Table
class.getEmptyTable = function (self, reqSeatId, oldTableId)
    local table = nil
    self.waitTables:forEach(function (oneTable)
        if oneTable.tableId < protoTypes.CGGAME_ROOM_TABLE_MINID
            and oneTable.tableId ~= oldTableId
            and (not reqSeatId or oneTable:IsSeatEmpty(reqSeatId, true, false)) then

            table = oneTable
            return true
        end
    end)

    if table and table.tableId >= protoTypes.CGGAME_ROOM_TABLE_MINID then
        table = nil
    end

    if table == nil or table:getPlayerCount() >= self.config.MaxPlayer then
        table = self:createTable()
    end

    return table
end

---！@brief TODO
---! @param 
---! @return 
class.adjustToWaitTable = function (self, table)
    self.waitTables:removeObject(table)

    local tmpJoin = (table.status <= protoTypes.CGGAME_TABLE_STATUS_WAITSTART or self.config.JoinPlaying)
    if table:getPlayerCount() < self.config.BestPlayer and tmpJoin then
        self.waitTables:addObject(table)
    end
end

---！@brief  更新倒计时的时间
---! @param table        更新的倒计时的桌子
---！@param newTimeout   新的倒计时时间
class.updateTableTimeout = function (self, table, newTimeout)
    self.eventTables:removeObject(table)
    table.timeout = newTimeout + skynet.time()
    self.eventTables:addObject(table)
end

---！@brief  TODO
---! @param 
---! @return 
class.tick = function(self, dt)
    local now = skynet.time()
    local table = self.eventTables:top()
    while table and now >= table.timeout do
        table = self.eventTables:pop()
        --! event handler
        table:timeoutHandler()

        table = self.eventTables:top()
    end

    local table = self.expireTables:top()
    -- local delay = 5 * 60; -- 5 minutes protoTypes.CGGAME_ROOM_TABLE_EXPIRE_TIME -- 8小时停止游戏  12小时删除数据库
    while table and now >= table.expireTime do
        table = self.expireTables:pop()

        if not table:TermTable(true) then
            self.expireTables:addObject(table)
            break
        end

        table = self.expireTables:top()
    end
end

---！@brief 添加用户
---! @param player        用户的数据
class.addPlayer = function(self, player)
    ---! you can send room info here
    ---! self:sendRoomInfo
    local needDB = nil
    local user = self:getUserInfo(player.FUniqueID)
    if user then
        if user.is_offline then
            user.is_offline = nil
        else
            if user.gate and user.agent and user.client_fd then
                local helper = require "TaskHelper"
                helper.closeGateAgent(user.gate, user.client_fd)
            end
        end

        user.gate       = player.gate
        user.agent      = player.agent
        user.client_fd  = player.client_fd
        user.address    = player.address
        user.watchdog   = player.watchdog

        user.reqTableId = player.reqTableId
    else
        user = player
        ---user.status 用户的状态
        user.status = protoTypes.CGGAME_USER_STATUS_IDLE

        needDB = true
    end
    if user.address then
        user.address    = string.gsub(user.address, ":%d+", "")
    end
    self.onlineUsers:addObject(user, user.FUniqueID)

    user.start_time = skynet.time()
    local debugHelper  = require "DebugHelper"
    debugHelper.cclog("[%s] add player %s, left %d", os.date("%D %T"), tostring(user), self:getAvailPlayerNum())

    if needDB and snax then
        local dbHelper = require "DBHelper"
        user.FNickName = dbHelper.trimSQL(user.FNickName)
        local nick = user.FNickName
        local ostp = dbHelper.trimSQL(user.FOSType)
        local url  = dbHelper.trimSQL(user.FAvatarUrl)
        local stamp= dbHelper.timestamp()

        ---!  db handler should handle this?
        local db = snax.uniqueservice("DBService")
        local info = db.req.loadDB(user.FUniqueID)
        packetHelper.copyTable(info, user)

        local ret = clusterHelper.snax_call(clusterHelper.get_InfoServer(), "DBService", function(proxy)
            local info = proxy.req.loadDB(user.FUniqueID)

            if not info.FNickName or info.FNickName == "" then
                info.FNickName = nick
                proxy.req.updateDB(user.FUniqueID, "FNickName", nick)
            else
                info.FNickName = dbHelper.trimSQL(info.FNickName)
            end
            proxy.req.updateDB(user.FUniqueID, "FOSType", ostp)

            local stringHelper = require "StringHelper"
            if not stringHelper.isInnerAddr(user.address) then
                proxy.req.updateDB(user.FUniqueID, "FLastIP", user.address)
            end

            proxy.req.updateDB(user.FUniqueID, 'FLastLoginTime', stamp)

            return info
        end)
        if ret then
            packetHelper.copyTable(ret, user)
        end
    end

    self:PlayerContinue(user)
end

class.handleBuyChips = function (self, args, isScore)
    local dbHelper = require "DBHelper"
    local uid = dbHelper.trimSQL(args.msgBody)
    local count = tonumber(args.subType) or 0

    if not uid then
        return ""
    end

    local user = self:getUserInfo(uid, true)
    if not user then
        return ""
    end

    local fieldName = isScore and "FScore" or "FCounter"
    local oldValue = (user[fieldName] or 0)
    local newValue = oldValue + count
    user[fieldName] = newValue
    if snax then
        local db = snax.uniqueservice("DBService")
        db.req.updateDB(user.FUniqueID, fieldName, user[fieldName])

        local cmd = "INSERT TCheatRecord (FUniqueID, FGameID, FFieldName, FValue, FOldValue, FNewValue) VALUES ";
        cmd = cmd .. string.format("('%s', '%s', '%s', '%d', '%d', '%d')", uid, self.config.GameId, fieldName, count, oldValue, newValue) 
        db.req.execDB(cmd)
    end

    local ok = uid

    local player = self:getUserInfo(uid)
    if not player then
        -- not in game, don't send update info
        return ok
    end

    if user.tableId then
        local table = self.allTables[user.tableId]
        if table then
            table:groupAction("playerUsers", function (seatId, uid)
                self:SendUserInfo(uid, user.FUniqueID)
                self:SendUserStatus(uid, user.FUniqueID)
            end)
            return ok
        end
    end

    self:SendUserInfo(user.FUniqueID, user.FUniqueID)
    self:SendUserStatus(user.FUniqueID, user.FUniqueID)
    return ok
end

class.CheckUserDailyBonus = function (self, msg)
    local uid = msg.msgBody
    if not uid or not snax then
        return ""
    end

    local db = snax.uniqueservice("DBService")
    if db then
        local info = db.req.loadDB(uid)

        local dbHelper = require "DBHelper"
        local now = os.time()
        local day = dbHelper.getDiffDate(info.FSaveDate, now)
        if day >= 1 then
            local count = 1
            if day == 1 then
                count = (info.FSaveCount or 0) + 1
                count = math.min(count, 7)
            end
            db.req.updateDB(uid, "FSaveDate", now)
            db.req.updateDB(uid, "FSaveCount", count)

            local gameClass = require(self.config.GameClass)
            local bonus = gameClass:getDailyBonusCounter(count)

            info.FCounter = (info.FCounter or 0) + bonus
            db.req.updateDB(uid, "FCounter", info.FCounter)
        end
    end

    return uid
end

class.FetchUserFromDB = function (self, uid)
    local user = nil
    if not uid or uid == "" or not snax then
        return user
    end

    user = {}
    user.FUniqueID = uid

    local db = clusterHelper.snax_proxy(clusterHelper.get_InfoServer(), "DBService")
    if db then
        local info = db.req.loadDB(uid)
        packetHelper.copyTable(info, user)
    end

    db = snax.uniqueservice("DBService")
    if db then
        local info = db.req.loadDB(uid)
        packetHelper.copyTable(info, user)
    end

    return user
end

class.UpdateUserInfo = function (self, msg)
    local uid = ""
    if not msg.msgBody then
        return uid
    end

    if not snax then
        return uid
    end

    local raw = packetHelper:decodeMsg(class.UserInfo_ProtoName, msg.msgBody)
    if not raw.FUniqueID then
        return uid
    else
        uid = raw.FUniqueID
    end

    local user = self:getUserInfo(uid)
    local dest = user or {}
    packetHelper.copyTable(raw, dest)

    local fields = {
        "FNickName", "FAvatarID", "FAvatarUrl", "FLastIP",
        "FLongitude", "FLatitude", "FAltitude", "FLocation",
    }
    local db = clusterHelper.snax_proxy(clusterHelper.get_InfoServer(), "DBService")

    local dbHelper = require "DBHelper"
    for _, f in ipairs(fields) do
        if dest[f]then
            dest[f] = dbHelper.trimSQL(dest[f])
            db.req.updateDB(uid, f, dest[f])
        end
    end

    return uid
end

class.checkAgentValid = function (self, db, agentCode)
    local cmd = string.format("SELECT * FROM TAgent WHERE FAgentCode = '%s'", agentCode);
    local row = db.req.execDB(cmd)
    local info = row and row[1] or nil
    local code = info and info.FAgentCode or nil
    if code and code > 0 then
        return true
    end
    return false
end

class.getBindBonus = function (self, db, gameId)
    local cmd = string.format("SELECT FBindBonus FROM TGame WHERE FGameID = '%s'", gameId)
    local row = db.req.execDB(cmd)
    local info = row and row[1] or nil
    local value = info and info.FBindBonus or 0

    return value
end

class.UpdateUserStatus = function (self, msg)
    local uid = ""
    if not msg.msgBody then
        return uid
    end

    if not snax then
        return uid
    end

    local gameClass = require(self.config.GameClass)
    local raw = packetHelper:decodeMsg(gameClass.UserStatus_ProtoName, msg.msgBody)
    if not raw.FUniqueID then
        return uid
    else
        uid = raw.FUniqueID
    end

    local user = self:getUserInfo(uid, true)
    local dest = user or {}

    db = snax.uniqueservice("DBService")
    local field = "FAgentCode"
    if raw[field] then
        if dest[field] and dest[field] > 0 then
            return uid, protoTypes.CGGAME_ACL_STATUS_ALREADY_AGENTCODE
        elseif not self:checkAgentValid(db, raw[field]) then
            return uid, protoTypes.CGGAME_ACL_STATUS_INVALID_AGENTCODE
        else
            local dbHelper = require "DBHelper"
            dest[field] = dbHelper.trimSQL(raw[field])
            db.req.updateDB(uid, field, dest[field])

            local name = 'FCounter'
            dest[name] = (dest[name] or 0) + self:getBindBonus(db, self.config.GameId)
            db.req.updateDB(uid, name, dest[name])

            return uid
        end
    end

    return uid
end


---！@brief RoomInterface中的默认消息
---! @param player        用户的数据
---！@param data          TODO
class.handleGameData = function (self, player, data)
    local user = self:getUserInfo(player.FUniqueID)
    if user then
        player = user
    end

    local seatId = nil
    if data.msgBody then
        seatId = math.tointeger(data.msgBody) or 0
        if seatId < 1 or seatId > self.config.MaxPlayer then
            seatId = nil
        end
    end

    local debugHelper = require "DebugHelper"
    if data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_SITDOWN  then
        self:SitDown(player, seatId)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_STANDUP  then
        self:StandUp(player, true)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_QUITTABLE  then
        self:QuitTable(player)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_READY  then
        self:PlayerReady(player)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_CHANGETABLE  then
        self:ChangeTable(player, seatId)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_USERINFO then
        self:SendUserInfo(player.FUniqueID, data.msgBody)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_USERSTATUS then
        self:SendUserStatus(player.FUniqueID, data.msgBody)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_CHAT then
        self:SendUserChat(player.FUniqueID, data.msgBody)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_GIFT then
        self:SendUserGift(player.FUniqueID, data.msgBody)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ROOMSEAT then
        self:RoomSeat(player, seatId)
    elseif player.tableId then
        local table = self.allTables[player.tableId]
        if table then
            table:handleGameData(player, data)
        else
            debugHelper.cclog("traceback: unknown table " .. player.tableId)
            player.tableId = nil
        end
    else
        debugHelper.cclog("unknown handleGameData")
    end
end

class.handleRoomData = function (self, data)
    local roomInfo = nil

    if data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_RELEASE  then
        roomInfo = packetHelper:decodeMsg("CGGame.ExitInfo", data.msgBody)
    else
        roomInfo = packetHelper:decodeMsg("CGGame.RoomInfo", data.msgBody)
    end
    if not roomInfo then 
        return protoTypes.CGGAME_ACL_STATUS_UNKNOWN_COMMAND
    end

    local player = self:getUserInfo(roomInfo.ownerId, true)
    if not player then
        return protoTypes.CGGAME_ACL_STATUS_INVALID_USERINFO
    end

    local debugHelper = require "DebugHelper"
    local acl, packet
    if data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_CREATE  then
        acl, packet = self:CreateRoom(player, roomInfo)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_JOIN  then
        acl, packet = self:JoinRoom(player, roomInfo)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_RELEASE  then
        acl, packet = self:ReleaseRoom(player, roomInfo)
    else
        debugHelper.cclog("unknown handleRoomData", data.subType)
        acl = protoTypes.CGGAME_ACL_STATUS_UNKNOWN_COMMAND
    end
    return acl, packet
end

---！@brief 在onlineUsers中清除用户，并且将player清空 
---! @param player       玩家的数据
class.removePlayer = function(self, player)
    local user = self:getUserInfo(player.FUniqueID)
    if not user then
        return
    end

    if user.agent == player.agent and user.client_fd == player.client_fd then
        self:PlayerBreak(user)
    end

    local delay = skynet.time() - user.start_time
    local debugHelper         = require "DebugHelper"
    debugHelper.cclog("[%s] remove player %s in %f sec, left %d", os.date("%D %T"), tostring(user), delay, self:getAvailPlayerNum())
end

local 
___djgbase2___ = function () end
----------------------------------------------------------------
---!  @packet common library functions from djgbase2
------------------------------------------------------------------
---! @brief  玩家的默认数据 
---! @param  pgeneraluser      玩家的通用设置
---！@param  pusergame         用户的游戏数据
---！@param  buffer            缓存中的数据
---！@param  shSize            正在游戏的玩家的数量
class.DefaultPlayerData = function (self,pgeneraluser,pusergame,buffer,shSize)
end

---! @brief 房间的管理机制
---! @param
class.SendRoomText = function(self, uid)
    local text = self.config.RoomText  
    if not text then
        return
    end

    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_ROOMTEXT, nil, text)
    self:sendPacketToUser(packet, uid)
end

class.UserInfo_ProtoName = "CGGame.UserInfo"
class.UserInfo_Fields = {
    "FUniqueID", "FNickName", "FUserName", "FAvatarID", "FOSType", "FPassword",
    "FMobile", "FEmail", "FIDCard", "FLastIP", "FLastLoginTime", "FRegTime",
    "FBreak", "FTotal", "FTotalTime", "FAvatarUrl", "FAvatarData",
    "FLongitude", "FLatitude", "FAltitude", "FLocation",
}

---! @brief 发送玩家的信息
---! @param recvUid            玩家的游戏ID
---！@param sendUid            
class.SendUserInfo = function(self, recvUid, sendUid)
    local info = self:getUserInfo(sendUid)
    if not info then
        return
    end

    local packet = self:CollectUserInfo(info)
    self:sendPacketToUser(packet, recvUid)
end

class.CollectUserInfo = function (self,info)
    local need = {}
    for k, f in ipairs(class.UserInfo_Fields) do
        need[f] = info[f]
    end

    local ask = packetHelper:encodeMsg(class.UserInfo_ProtoName, need)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA,
    protoTypes.CGGAME_PROTO_SUBTYPE_USERINFO, ask)

    return packet
end

---! @brief 发送玩家的状态
---! @param user    玩家的游戏数据
---！@param uid     接受的用户的ID
class.SendUserStatus = function(self, recvUid, sendUid)
    local user = self:getUserInfo(sendUid)
    if not user then
        return
    end

    local packet = self:CollectUserStatus(user)
    self:sendPacketToUser(packet, recvUid)
end

class.CollectUserStatus = function (self, user)
    local info = {}
    info.FUniqueID   = user.FUniqueID
    info.status     = user.status
    if user.is_offline then
        info.status = protoTypes.CGGAME_USER_STATUS_OFFLINE
    end
    info.tableId    = user.tableId
    info.seatId     = user.seatId
    local table = self.allTables[user.tableId]
    if table then
        info.tableStatus = table.status
    end

    local gameClass = require(self.config.GameClass)
    for k, f in ipairs(gameClass.UserStatus_Fields) do
        info[f] = user[f]
    end

    local ask = packetHelper:encodeMsg(gameClass.UserStatus_ProtoName, info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA,
    protoTypes.CGGAME_PROTO_SUBTYPE_USERSTATUS, ask)

    return packet
end

class.SendUserChat = function (self, fromUid, msgBody)
    local user = self:getUserInfo(fromUid)
    if not user or not msgBody then
        return
    end

    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA,
    protoTypes.CGGAME_PROTO_SUBTYPE_CHAT, msgBody)

    if user.tableId then
        local table = self.allTables[user.tableId]

        if table then
            table:groupAction("playerUsers", function (seatId, uid)
                self:sendPacketToUser(packet, uid)
            end)

            return
        end
    end

    self:sendPacketToUser(packet, fromUid)
end

class.SendUserGift = function (self, fromUid, msgBody)
    local user = self:getUserInfo(fromUid)
    if not user or not msgBody then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_INFO, fromUid)
        return
    end

    local giftInfo = packetHelper:decodeMsg("CGGame.GiftInfo", msgBody)
    if not giftInfo or not giftInfo.giftName or giftInfo.srcSeatId == 0
        or giftInfo.dstSeatId == 0 or giftInfo.srcSeatId == giftInfo.dstSeatId then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_INFO, fromUid)
        return
    end

    local cost = nil
    local gameClass = require(self.config.GameClass)
    if gameClass and gameClass.getGiftPrice then
        cost = gameClass:getGiftPrice(giftInfo.giftName)
    end
    if not cost then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_INFO, fromUid)
        return
    elseif user.FCounter < cost then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_COUNTER_LACK, fromUid)
        return
    end

    giftInfo.coinCost = cost
    user.FCounter = (user.FCounter or 0) - cost
    if snax then
        local db = snax.uniqueservice("DBService")
        db.req.updateDB(user.FUniqueID, "FCounter", user.FCounter)
    end

    msgBody = packetHelper:encodeMsg("CGGame.GiftInfo", giftInfo)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA,
    protoTypes.CGGAME_PROTO_SUBTYPE_GIFT, msgBody)

    if user.tableId then
        local table = self.allTables[user.tableId]

        if table then
            table:groupAction("playerUsers", function (seatId, uid)
                self:sendPacketToUser(packet, uid)
            end)

            return
        end
    end

    self:sendPacketToUser(packet, fromUid)
end

class.SendACLToUser = function(self, aclType, uid)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_ACL, aclType, nil)
    self:sendPacketToUser(packet, uid)
end

--- Room Tables 
class.createRoomDBInfo = function (self, player) 
    local serverName = clusterHelper.get_RoomServer()
    if not serverName then return end

    local roomInfo = clusterHelper.snax_call(serverName, "DBService", function(proxy)
        local info = nil
        repeat
            local roomId = math.random(protoTypes.CGGAME_ROOM_TABLE_MINID, protoTypes.CGGAME_ROOM_TABLE_MAXID)
            info = proxy.req.loadDB(roomId)
        until info.FOwnerID == ""

        info.FOwnerID = player.FUniqueID
        proxy.req.updateDB(info.FRoomID, "FOwnerID", info.FOwnerID)

        return info
    end)
    return roomInfo
end

class.releaseRoomTable = function (self, table)
    if table.tableId < protoTypes.CGGAME_ROOM_TABLE_MINID then
        return
    end

    self.waitTables:removeObject(table)
    self.eventTables:removeObject(table)
    self.expireTables:removeObject(table)
    self.allTables[table.tableId] = nil

    local serverName = clusterHelper.get_RoomServer()
    if not serverName then
        return
    end

    local roomInfo = table.roomInfo or {}
    local histInfo = roomInfo.histInfo or {}
    local count = histInfo.gameCount or 0
    if count <= 0 then
        return
    end
    clusterHelper.snax_call(serverName, "DBService", function(proxy)
        info = proxy.req.loadDB(table.tableId)

        info.FGameCount = count
        proxy.req.updateDB(info.FRoomID, "FGameCount", info.FGameCount)
    end)
end

class.roomTablePayBill = function (self, table, forced)
    local roomInfo = table.roomInfo
    if not snax or not roomInfo or roomInfo.isPayed then
        -- print("no roomInfo or room payed ", snax, roomInfo)
        return
    end

    local roomDetails = roomInfo.roomDetails or {}
    local payType = roomDetails.payType or 0

    local histInfo = roomInfo.histInfo or {}
    local gameCount = histInfo.gameCount or 0
    -- local passCount = roomDetails.passCount or 8
    -- print("game count, passCount", gameCount, passCount)
    if forced then 
        if gameCount <= 0 then
            -- print("forced but no play")
            return
        end
    end

    if (payType == protoTypes.CGGAME_ROOM_PAYTYPE_OWNER or payType == protoTypes.CGGAME_ROOM_PAYTYPE_PLAYERS) and gameCount >= 1 then
        -- creater pay, or AA pay
    elseif forced and payType == protoTypes.CGGAME_ROOM_PAYTYPE_WINNER then
        -- winner pay
    else
        -- print("not this time to pay", gameCount, passCount, forced, payType)
        return
    end

    local creator   = roomInfo.FOwnerID
    local winners   = {}
    local winuser   = nil
    local players   = {}
    table:groupAction("playingUsers", function (seatId, uid)
        local o = histInfo.seatScore[uid] or histInfo.seatScore[seatId]
        players[#players + 1] = uid
        if not winuser or (o and o.score > winuser.score) then
            winuser = o
            winners = {uid}
        elseif o and o.score == winuser.score then
            winners[#winners + 1] = uid
        end
    end)

    if forced and payType == protoTypes.CGGAME_ROOM_PAYTYPE_WINNER then
        --[[ print("winners pay: ", winuser.score)
        local str = ""
        for _, uid in ipairs(winners) do
            str = str .. tostring(uid) .. ", "
        end
        print (str) --]]

        players = winners
    elseif gameCount >= 1 and payType == protoTypes.CGGAME_ROOM_PAYTYPE_OWNER then
        --creator
        -- print("creator pay", creator)

        players = {}
        players[#players + 1] = creator
    elseif gameCount >= 1 and payType == protoTypes.CGGAME_ROOM_PAYTYPE_PLAYERS then
        -- AA pay
        -- print ("AA pay")
    else
        -- print("payType is not good", payType)
        return
    end

    if #players <= 0 then
        -- print("no players found")
        return
    end

    local cost = roomDetails.costCoins or protoTypes.CGGAME_ROOM_LEAST_COINS
    cost = math.floor(cost / #players)
    local db = snax.uniqueservice("DBService")
    for _, uid in ipairs(players) do
        xpcall(function ()
            local info = self:getUserInfo(uid, true)
            info.FCounter = info.FCounter - cost
            db.req.updateDB(info.FUniqueID, "FCounter", info.FCounter)
            -- print(uid, "pay", cost)
        end,
        function (err)
            print(err)
        end)
    end

    roomInfo.isPayed = true
end

class.createRoomTable = function (self, roomInfo)
    if not roomInfo then return end
    
    local tab = self.allTables[roomInfo.FRoomID]
    if not tab then
        if not roomInfo.FOpenTime or roomInfo.FOpenTime == "" then
            tab = packetHelper.createObject(self.config.GameClass, self)
            tab.tableId     = roomInfo.FRoomID
            tab.roomInfo    = roomInfo

            self.allTables[tab.tableId] = tab

            tab.openTime = os.time()
            tab.expireTime = os.time() + 10 * 60
            self.expireTables:addObject(tab)
            -- print("open table", tab.tableId, tab.openTime)

            local serverName = clusterHelper.get_RoomServer()
            if serverName then
                clusterHelper.snax_call(serverName, "DBService", function(proxy)
                    info = proxy.req.loadDB(tab.tableId)

                    local dbHelper = require "DBHelper"
                    roomInfo.FOpenTime = dbHelper.timestamp()
                    proxy.req.updateDB(info.FRoomID, "FOpenTime", roomInfo.FOpenTime)

                    roomInfo.FGameID = self.config.GameId
                    proxy.req.updateDB(info.FRoomID, "FGameID", roomInfo.FGameID)
                end)
            end
        end
    end

    return tab
end

class.sitDownRoomTable = function (self, player, table)
    local find = nil
    local lim = self.config.BestPlayer or self.config.MaxPlayer
    for i = 1, lim do
        if table:IsSeatEmpty(i, true, false) then
            find = i
            break
        end
    end

    if find then
        -- TODO send room Info
        local packet = self:getRoomPacket(table)
        self:sendPacketToUser(packet, player.FUniqueID)

        self:SeatPlayer(player, table, find)

        return true
    end

    -- TODO room table is full
    self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_ROOM_JOIN_FULL, player.FUniqueID)
    return nil
end

class.getRoomPacket = function (self, table)
    local roomInfo = table.roomInfo or {}
    local info = {}
    info.roomId         = roomInfo.FRoomID
    info.expireTime     = table.expireTime
    info.openTime       = table.openTime
    info.ownerId        = roomInfo.FOwnerID
    info.ownerName      = roomInfo.FOwnerName
    info.roomDetails    = roomInfo.packDetails

    local data = packetHelper:encodeMsg("CGGame.RoomInfo", info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_ROOMDATA, 
                                            protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_INFO, data)
    return packet
end

class.CreateRoom = function (self, player, roomInfo)
    if player.FCounter < protoTypes.CGGAME_ROOM_LEAST_COINS then
        return protoTypes.CGGAME_ACL_STATUS_COUNTER_LACK
    end

    local packDetails = roomInfo.roomDetails
    
    roomInfo = self:createRoomDBInfo(player)
    if not roomInfo then
        return protoTypes.CGGAME_ACL_STATUS_ROOM_DB_FAILED
    end

    local table = self:createRoomTable(roomInfo)
    if not table then
        return protoTypes.CGGAME_ACL_STATUS_ROOM_CREATE_FAILED
    elseif table.extractRoomDetails then
        roomInfo.packDetails = packDetails
        roomInfo.roomDetails = table:extractRoomDetails(packDetails)
        roomInfo.FOwnerName  = player.FNickName
    else
        table:TermTable()
        -- 不支持房卡模式
        return protoTypes.CGGAME_ACL_STATUS_ROOM_NOT_SUPPORT
    end

    local payType = roomInfo.roomDetails.payType or 0
    if payType < protoTypes.CGGAME_ROOM_PAYTYPE_OWNER
        or payType > protoTypes.CGGAME_ROOM_PAYTYPE_WINNER then
        -- payType 不支持
        table:TermTable()
        return protoTypes.CGGAME_ACL_STATUS_ROOM_NO_SUCH_PAYTYPE
    end

    local packet = self:getRoomPacket(table)
    return protoTypes.CGGAME_ACL_STATUS_SUCCESS, packet
end

class.JoinRoom = function (self, player, roomInfo)
    if not roomInfo or roomInfo.roomId < protoTypes.CGGAME_ROOM_TABLE_MINID
        or roomInfo.roomId > protoTypes.CGGAME_ROOM_TABLE_MAXID then
        return protoTypes.CGGAME_ACL_STATUS_INVALID_INFO
    end

    local table = self.allTables[roomInfo.roomId]
    if not table then
        return protoTypes.CGGAME_ACL_STATUS_ROOM_FIND_FAILED
    end

    local info = table.roomInfo
    if not info or info.FRoomID ~= roomInfo.roomId then
        return protoTypes.CGGAME_ACL_STATUS_ROOM_JOIN_FAILED
    end

    if player.FCounter < protoTypes.CGGAME_ROOM_LEAST_COINS then
        if info.histInfo or info.FOwnerID == player.FUniqueID then
            -- room started or player is room owner
        else
            return protoTypes.CGGAME_ACL_STATUS_COUNTER_LACK
        end
    end

    local packet = self:getRoomPacket(table)
    return protoTypes.CGGAME_ACL_STATUS_SUCCESS, packet
end

class.updateExitInfo = function (self, table, exitInfo)
    local roomInfo = table.roomInfo
    if exitInfo.mask == 0 then
        -- reject
        roomInfo.exitInfo = nil
        return
    end

    if not roomInfo.exitInfo then
        roomInfo.exitInfo   = exitInfo
        exitInfo.mask       = exitInfo.mask or 0
        exitInfo.timeout    = os.time() + 5 * 60
        exitInfo.seatId     = nil
    end

    roomInfo.exitInfo.mask = roomInfo.exitInfo.mask | exitInfo.mask

    local exit = true
    for i=1,self.config.MaxPlayer do
        if (table.playerUsers:getObjectAt(i) ~= nil) and (roomInfo.exitInfo.mask & (1 << i)) == 0 then
            exit = false
            break
        end
    end

    if roomInfo.exitInfo.timeout < os.time() then
        exit = true
    end

    if exit then
        roomInfo.exitInfo = nil
    end

    return exit
end

class.sendExitInfo = function (self, table, seatId, exit)
    local roomInfo = table.roomInfo
    if not roomInfo then
        return
    end

    if roomInfo.exitInfo and os.time() > (roomInfo.exitInfo.timeout or 0) then
        -- roomInfo.exitInfo = nil
        exit = true
    end

    local info = {}
    info.seatId     = seatId
    if roomInfo.exitInfo then
        local exitInfo  = roomInfo.exitInfo
        info.roomId     = exitInfo.roomId
        info.mask       = exitInfo.mask
        info.ownerId    = exitInfo.ownerId
        info.timeout    = exitInfo.timeout - os.time()
        if info.timeout < 0 then
            info.timeout = 0
        end
    end

    if exit then
        info.timeout    = -1
    end

    local data = packetHelper:encodeMsg("CGGame.ExitInfo", info)
    table:SendDataToTable(protoTypes.CGGAME_PROTO_TYPE_ROOMDATA, protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_RELEASE, data)

    return exit
end

class.ReleaseRoom = function (self, player, exitInfo)
    if not exitInfo or exitInfo.roomId < protoTypes.CGGAME_ROOM_TABLE_MINID
        or exitInfo.roomId > protoTypes.CGGAME_ROOM_TABLE_MAXID then
        -- TODO:send acl to client
        return protoTypes.CGGAME_ACL_STATUS_INVALID_INFO
    end

    local table = self.allTables[exitInfo.roomId]
    if not table then
        -- TODO table create failed
        return protoTypes.CGGAME_ACL_STATUS_INVALID_INFO
    end

    -- when request
    -- gameCount == agree or not, ownerId = who
    if player.seatId ~= exitInfo.seatId then
        return protoTypes.CGGAME_ACL_STATUS_INVALID_INFO
    end

    local roomInfo = table.roomInfo
    if not roomInfo then
        return protoTypes.CGGAME_ACL_STATUS_INVALID_INFO
    end

    local exit = self:updateExitInfo(table, exitInfo)
    exit = self:sendExitInfo(table, player.seatId, exit)

    if exit then
        table:TermTable()
    end

    return protoTypes.CGGAME_ACL_STATUS_SUCCESS
end


---! @brief 玩家站起来
---! @param player      玩家的游戏数据
---! @return true       玩家standup成功
---！@return nil        玩家standup失败
class.StandUp = function (self, player, force)
    if not player.tableId then
        return true
    end

    local table = self.allTables[player.tableId]
    if not table or table.playerUsers:getObjectAt(player.seatId) ~= player.FUniqueID then 
        player.tableId = nil
        player.seatId  = nil
        return true
    end

    if not table:canPlayerStandUp(player, force) then
        return nil
    end

    player.status = protoTypes.CGGAME_USER_STATUS_STANDUP
    table:handlePlayerStandUp(player)
    return true
end


class.SitOldSeat = function (self, player)
    if not player.tableId or not player.seatId then
        return
    end
    local table = self.allTables[player.tableId]
    if not table then
        return
    end
    if table:canPlayerSitdown(player) then
        player.status = protoTypes.CGGAME_USER_STATUS_SITDOWN
        table:handlePlayerJoined(player, false)
        return true
    end
end

class.FindOneEmptySeat = function (self, table, reqSeatId)
    if reqSeatId and table:IsSeatEmpty(reqSeatId, true, false) then
        return reqSeatId
    end

    reqSeatId = self.config.SeatOrder and 1 or math.random(1, self.config.MaxPlayer)
    for i = reqSeatId, self.config.MaxPlayer do
        if table:IsSeatEmpty(i, true, false) then
            return i
        end
    end

    for i = reqSeatId - 1, 1, -1 do
        if table:IsSeatEmpty(i, true, false) then
            return i
        end
    end
end

class.SeatPlayer = function (self, player, table, seatId)
    table.playerUsers:setObjectAt(seatId, player.FUniqueID)
    player.tableId = table.tableId
    player.seatId  = seatId

    self:adjustToWaitTable(table)

    player.status = protoTypes.CGGAME_USER_STATUS_SITDOWN
    table:handlePlayerJoined(player, true)
end

--- ! @brief sit down on requested tableId and requested seatId
class.RoomSeat = function(self, player, seatId)
    if not player.tableId or not seatId or seatId <= 0 or seatId > self.config.MaxPlayer then
        -- print("invalid seat option", player.tableId, seatId)
        return
    end

    local table = self.allTables[player.tableId]
    if not table or not table:IsSeatEmpty(seatId, true, false) then
        -- print("invalid table or seat", table, seatId)
        return
    end

    if not self:QuitTable(player, true) then
        -- print("player can't quit")
        return
    end

    -- TODO send room Info
    local packet = self:getRoomPacket(table)
    self:sendPacketToUser(packet, player.FUniqueID)

    -- print("do seat player")
    self:SeatPlayer(player, table, seatId)
    return true
end

---! @brief 用户坐下
---! @param player      玩家的游戏数据
---！@return true       玩家已经在桌子上了，可能是Sitdown, Ready, Standup, Play中的任意状态
---! @return nil        没有成功坐上桌子, player.tableId, player.seatId 无意义
class.SitDown = function(self, player, reqSeatId)
    ---! standup to Sitdown
    if player.status == protoTypes.CGGAME_USER_STATUS_STANDUP then
        return self:SitOldSeat(player)
    end

    if player.tableId then
        ---! already in table?
        return true
    end

    local oldTableId = player.oldTableId or -1
    local table = self:getEmptyTable(reqSeatId, oldTableId)
    if not table or not table:canPlayerSitdown(player) then
        return nil
    end

    local find = self:FindOneEmptySeat(table, reqSeatId)
    if find then
        self:SeatPlayer(player, table, find)
        return true
    end

    return nil
end

---! @brief 玩家准备
---! @param player      玩家的游戏数据
---! @rerurn true   玩家已经成功的ready       
---! @rerurn nil   
class.PlayerReady = function(self, player)
    if not player.tableId then
        if not self:SitDown(player) then
            return
        end
    end

    local table = self.allTables[player.tableId]
    if not table then
        return
    end

    if table.playerUsers:getObjectAt(player.seatId) ~= player.FUniqueID then
        self:QuitTable(player)
        return
    end

    if table.status > protoTypes.CGGAME_TABLE_STATUS_WAITSTART
        or player.status == protoTypes.CGGAME_USER_STATUS_READY then
        return
    end

    if not table:canPlayerReady(player) then
        return
    end

    player.status = protoTypes.CGGAME_USER_STATUS_READY;

    table:handlePlayerReady(player)
    return true
end

---! @brief 玩家离开桌子但是还在房间里
---! @param palyer         玩家的数据
---！@return true          玩家已经成功的离开了桌子
---！@retuen nil           玩家离开桌子失败
class.QuitTable = function(self, player, force)
    if not player.tableId then
        return true
    end

    if not self:StandUp(player, force) then
        return nil
    end

    local table = self.allTables[player.tableId]
    if not table then
        return
    end

    table.playerUsers:setObjectAt(player.seatId, nil)

    player.status  = protoTypes.CGGAME_USER_STATUS_IDLE
    if table:getPlayerCount() == 0 then
        table.status = protoTypes.CGGAME_TABLE_STATUS_IDLE
    end

    self:adjustToWaitTable(table)

    table:handlePlayerQuitTable(player)
    player.tableId = nil
    player.seatId  = nil

    if player.is_offline then
        self.onlineUsers:removeObject(player, player.FUniqueID)
    end

    return true
end

---! @brief 玩家换桌
class.ChangeTable = function (self, player, reqSeatId)
    player.oldTableId = player.tableId
    if self:QuitTable(player) then
        self:SitDown(player, reqSeatId)
        if self.config.AutoStart then
            self:PlayerReady(player)
        end
    end
end

---! @brief 玩家离开房间的处理
---! @param
class.PlayerGoOut = function(self,pusergame)
end

---! @brief 
---! @param
class.PlayerBreak = function(self, player)
    if not player then
        return
    end

    local table = nil
    if player.tableId and player.seatId then
        table = self.allTables[player.tableId]
    end

    if (not table or not table.roomInfo) and self:QuitTable(player) then
        self.onlineUsers:removeObject(player, player.FUniqueID)
    elseif not player.is_offline then
        player.is_offline = true
        if table then
            table:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_BREAK, player.seatId, player.FUniqueID)
        end
        local node = snax.uniqueservice("NodeService")
        node.post.add_hall_user(player.FUniqueID)
    end

    local delay = skynet.time() - player.start_time
    player.FTotalTime = (player.FTotalTime or 0) + delay

    local db = clusterHelper.snax_proxy(clusterHelper.get_InfoServer(), "DBService")
    db.req.updateDB(player.FUniqueID, "FTotalTime", player.FTotalTime)

    player.gate      = nil
    player.agent     = nil
    player.address   = nil
    player.watchdog  = nil
    player.client_fd = nil
end

class.shouldQuitClean = function (self, player)
    if player.tableId then
        local table = self.allTables[player.tableId]
        if table.roomInfo then
            return false
        end
    end
    return true
end

---! @brief 玩家是否已经坐下
---! @param
---! is player sit down or not? make it sit down anyway
class.PlayerContinue = function(self, player)
    if snax then
        local node = snax.uniqueservice("NodeService")
        node.post.del_hall_user(player.FUniqueID)
    end

    if self:shouldQuitClean(player) then
        self:QuitTable(player)
    end

    if player.tableId then
        local table = self.allTables[player.tableId]
        if table then
            table:SendTableMap("playerUsers", player.seatId)
            table:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_CONTINUE, player.seatId, player.FUniqueID)

            if table.tableId >= protoTypes.CGGAME_ROOM_TABLE_MINID and table.tableId <= protoTypes.CGGAME_ROOM_TABLE_MAXID then
                local packet = self:getRoomPacket(table)
                self:sendPacketToUser(packet, player.FUniqueID)

                if self:sendExitInfo(table) then
                    table:TermTable()
                    table = nil
                end
            end

            if table and table.status > protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
                table:SendCurrentGameToSeat(player.seatId)
                table:RefreshGameWait()
                return
            end

            if table then
                table:AnyPlayer_GameOverWaitStart()
                return
            end
        end
    end

    player.tableId = nil
    player.seatId  = nil

    if player.reqTableId and player.reqTableId >= protoTypes.CGGAME_ROOM_TABLE_MINID
        and player.reqTableId <= protoTypes.CGGAME_ROOM_TABLE_MAXID then
        local tab = self.allTables[player.reqTableId]
        if tab then
            self:sitDownRoomTable(player, tab)
        else
            self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_ROOM_FIND_FAILED, player.FUniqueID)
        end
        return
    end

    if snax and player.client_fd and player.client_fd < 0 then
        self:SitDown(player, 1)
    else
        self:SitDown(player)
    end
end


---! @brief 玩家断线
---! @param pusergame       玩家的游戏数据
class.PlayerOffline = function(self,pusergame)
end

---!@brief 获得系统内部状态
---!@return info 内部状态的描述
class.get_stat = function (self)
    local lines = {"RoomInterface status"}
    table.insert(lines, string.format("next table Id is %d:", self.nextTableId))

    table.insert(lines, "expireTables:")
    self.expireTables:forEach(function(tab)
        table.insert(lines, string.format("\ttableId: %d, openTime:%d expireTime:%d", tab.tableId, tab.openTime, tab.expireTime)) 
    end)

    table.insert(lines, "eventTables:")
    self.eventTables:forEach(function(tab)
        table.insert(lines, string.format("\ttableId: %d, timeout:%f", tab.tableId, tab:GetTimeOut())) 
    end)

    table.insert(lines, "waitTables:")
    self.waitTables:forEach(function(tab)
        table.insert(lines, string.format("\ttableId: %d, player count:%d", tab.tableId, tab:getPlayerCount())) 
    end)

    table.insert(lines, "allTables:")
    for _, tab in pairs(self.allTables) do
        table.insert(lines, string.format("\n\ttableId: %s, mask=%s, status=%s, timeout=%s",
                                    tostring(tab.tableId), tostring(tab.waitMask), tostring(tab.status), tostring(tab:GetTimeOut()))) 
        table.insert(lines, "\tplayingUsers")
        tab.playingUsers:forEach(function(sid, uid)
            table.insert(lines, string.format("\t\tsid=%d, uid=%s", sid, uid))
        end)
        table.insert(lines, "\tplayerUsers")
        tab.playerUsers:forEach(function(sid, uid)
            table.insert(lines, string.format("\t\tsid=%d, uid=%s", sid, uid))
        end)
    end

    return table.concat(lines, "\n")
end


return RoomInterface
