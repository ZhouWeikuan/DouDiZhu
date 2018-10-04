local skynet        = skynet or require "skynet"

local prioQueue     = require "PriorityQueue"
local protoTypes    = require "ProtoTypes"

local dbHelper      = require "DBHelper"
local debugHelper   = require "DebugHelper"
local packetHelper  = require "PacketHelper"
local strHelper     = require "StringHelper"
local tabHelper     = require "TableHelper"

local baseClass     = require "HallInterface"

local class = {mt = {}}
class.mt.__index = class

setmetatable(class, baseClass.mt)

---! @brief 创建RoomInterface的对象
---! @param conf        游戏配置文件
---! @return self       返回创建的RoomInterface
class.create = function (conf)
    local self = baseClass.create(conf)
    setmetatable(self, class.mt)

    --- self.nextTableId  房间中桌子的数量
    self.nextTableId = 0

    --- self.allTables    房间中的所有桌子
    self.allTables = {}

    ---! 等候表 self.waitTables   将处于Idle状态的桌子放在prioQueue类型的对象中，可以通过prioQueue中定义的方法操作，如：pop（）拿出第一个元素
    self.waitTables     = prioQueue.create(function (obj) return obj.tableId end, function (obj) return -obj:getPlayerCount() end, "[WIDX]")

    ---! 事件表 getKey, getPriority, queueIndexKey
    self.eventTables    = prioQueue.create(function (obj) return obj.tableId end, function (obj) return obj.timeout end, "[EIDX]")

    ---! 过期表
    self.expireTables   = prioQueue.create(function (obj) return obj.tableId end, function (obj) return obj.expireTime end, "[EXPIREIDX]")

    return self
end

---! @brief  定时执行
class.tick = function(self, dt)
    local now = skynet.time()

    ---! 执行延时动作
    self:executeEvents()

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

---! 收集用户信息 self.config.DBTableName
class.CollectUserStatus = function (self, user)
    local info = {}
    info.FUserCode  = user.FUserCode
    info.status     = user.status
    if user.is_offline then
        info.status = protoTypes.CGGAME_USER_STATUS_OFFLINE
    end

    local table = self.allTables[user.tableId]
    if table then
        info.tableId    = user.tableId
        info.seatId     = user.seatId
        info.tableStatus = table.status
    end

    local gameClass = require(self.config.GameClass)
    for k, f in ipairs(gameClass.UserStatus_Fields) do
        info[f] = user[f]
    end

    local data   = packetHelper:encodeMsg(gameClass.UserStatus_ProtoName, info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                        protoTypes.CGGAME_PROTO_SUBTYPE_USERSTATUS, data)
    return packet
end

---! 日志记录 屏蔽维语藏语
class.FilterText = function (self, chatInfo)
    local ForbiddenTxt = require "ForbiddenTxt"
    chatInfo.chatText = ForbiddenTxt.purify(chatInfo.chatText)

    debugHelper.cclog("[%s:%s]%s", chatInfo.speekerId, chatInfo.speakerNick, chatInfo.chatText)

    local text = ""
    local flag = true
    for p, c in utf8.codes(chatInfo.chatText) do
        if c > 256 and c < 8192 then
            text = text .. " "
        else
            text = text .. utf8.char(c)
        end
    end
    if flag then
        chatInfo.chatText = text
        return packetHelper:encodeMsg("CGGame.ChatInfo", chatInfo)
    end
end

---! 恢复之前的桌子
class.resumeOldTable = function (self, player)
    local table = self.allTables[player.tableId]
    if not table then
        return
    end

    table:SendTableMap("playerUsers", player.seatId)
    table:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_CONTINUE, player.seatId, player.FUserCode)

    if table.tableId >= protoTypes.CGGAME_ROOM_TABLE_MINID and table.tableId <= protoTypes.CGGAME_ROOM_TABLE_MAXID then
        local packet = self:getRoomPacket(table)
        self:gamePacketToUser(packet, player.FUserCode)

        if table.roomInfo and table.roomInfo.histInfo and table.roomInfo.histInfo.gameOver then
            table:SendRoomTableResult(true)
            table:SendRoomTableResultAll(player.FUserCode)
        end

        if self:sendExitInfo(table) then
            table:TermTable()
            table = nil
        end
    end

    if table and table.status > protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
        table:SendCurrentGameToSeat(player.seatId)
        table:RefreshGameWait()
        return true
    end

    if table then
        table:AnyPlayer_GameOverWaitStart()
        return true
    end
end

---! @brief 玩家是否已经坐下
---! @param
---! is player sit down or not? make it sit down anyway
class.PlayerContinue = function(self, player)
    if cluster then
        self:remoteDelAppGameUser(player)
    end

    if self:shouldQuitClean(player) then
        self:QuitTable(player)
    end

    if player.tableId and self:resumeOldTable(player) then
        return
    end

    player.tableId = nil
    player.seatId  = nil
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
        self.onlineUsers:removeObject(player, player.FUserCode)
    elseif not player.is_offline then
        player.is_offline = true
        if table then
            table:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_BREAK, player.seatId, player.FUserCode)
            if cluster then
                self:remoteAddAppGameUser(player)
            end
        end
    end

    local delay = skynet.time() - player.start_time
    player.FTotalTime = (player.FTotalTime or 0) + delay

    local keyName = "FUserCode"
    self:remoteUpdateDB(class.DBTableName, keyName, player[keyName], "FTotalTime", player.FTotalTime)

    local fields = {
        "appName", "agent", "gate", "client_fd", "address", "watchdog",
    }
    for _, key in ipairs(fields) do
        player[key] = nil
    end
end

---! @package table management
---! @brief 在房间中添加一个桌子
---! @return tab      通过GameClass.create()创建的对象
class.createTable = function (self)
    self.nextTableId = self.nextTableId + 1

    local tab = packetHelper.createObject(self.config.GameClass, self)
    self.allTables[tab.tableId] = tab

    return tab
end

---! @brief 获得一个处于Idle状态的桌子
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

    if table == nil or table:getPlayerCount() >= self.config.MaxPlayer then
        table = self:createTable()
    end

    return table
end

---! @brief 把 table 加到等待队列
class.adjustToWaitTable = function (self, table)
    self.waitTables:removeObject(table)

    local tmpJoin = (table.status <= protoTypes.CGGAME_TABLE_STATUS_WAITCONFIRM or self.config.JoinPlaying)
    if table:getPlayerCount() < self.config.BestPlayer and tmpJoin then
        self.waitTables:addObject(table)
    end
end

---! @brief  更新倒计时的时间
---! @param table        更新的倒计时的桌子
---! @param newTimeout   新的倒计时时间
class.updateTableTimeout = function (self, table, newTimeout)
    self.eventTables:removeObject(table)
    table.timeout = newTimeout + skynet.time()
    self.eventTables:addObject(table)
end

class.handleClubData = function (self, player, gameType, data)
    print("handle club data", player, gameType, data)
    return true
end

class.handleRoomData = function (self, player, gameType, data)
    print("handle room data", player, gameType, data)

    local roomInfo = nil
    if gameType == protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_RELEASE  then
        roomInfo = packetHelper:decodeMsg("CGGame.ExitInfo", data)
    else
        roomInfo = packetHelper:decodeMsg("CGGame.RoomInfo", data)
    end
    if not roomInfo then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_UNKNOWN_COMMAND, player.FUserCode)
        return
    end

    local player = self:getUserInfo(roomInfo.ownerId, true)
    if not player then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_USERINFO, player.FUserCode)
        return
    end

    local ret
    if data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_CREATE  then
        ret = self:CreateRoom(player, roomInfo)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_JOIN  then
        ret = self:JoinRoom(player, roomInfo)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_RELEASE  then
        ret = self:ReleaseRoom(player, roomInfo)
    elseif data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_RESULT_ALL then
        ret = self:ResultRoom(player, roomInfo)
    else
        debugHelper.cclog("unknown handleRoomData", data.subType)
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_UNKNOWN_COMMAND, player.FUserCode)
    end

    return ret
end

---! Room Tables
class.createRoomDBInfo = function (self, player)
    local tabName = "TRoomInfo"
    local keyName = "FRoomID"
    local info = nil
    repeat
        local roomId = math.random(protoTypes.CGGAME_ROOM_TABLE_MINID, protoTypes.CGGAME_ROOM_TABLE_MAXID)
        info = self:remoteLoadDB(tabName, keyName, roomId)
    until info.FOwnerID == ""

    local fldName = "FOwnerID"
    info[fldName] = player.FUserCode
    self:remoteUpdateDB(tabName, keyName, info.FRoomID, fldName, info[fldName])
    return info
end

---! 释放房间table
class.releaseRoomTable = function (self, table)
    if table.tableId < protoTypes.CGGAME_ROOM_TABLE_MINID then
        return
    end

    self.waitTables:removeObject(table)
    self.eventTables:removeObject(table)
    self.expireTables:removeObject(table)

    self:addDelayEvent(10, function()
        self.allTables[table.tableId] = nil
    end)

    local roomInfo = table.roomInfo or {}
    local histInfo = roomInfo.histInfo or {}
    histInfo.gameOver = true
    local count = histInfo.gameCount or 0
    if count <= 0 then
        return
    end

    local tabName = "TRoomInfo"
    local keyName = "FRoomID"
    local info = self:remoteLoadDB(tabName, keyName, table.tableId)
    self:updateLoadDB(tabName, keyName, table.tableId, "FGameCount", count)
end

---! 找到待付款人
class.findChargePlayers = function (self, table)
    local roomInfo      = table.roomInfo
    local roomDetails   = roomInfo.roomDetails or {}
    local payType       = roomDetails.payType or 0
    local histInfo      = roomInfo.histInfo or {}
    local gameCount     = histInfo.gameCount or 0
    if forced and gameCount <= 0 then
        return
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
    table:groupAction("playingUsers", function (seatId, code)
        local o = histInfo.seatScore[code] or histInfo.seatScore[seatId]
        players[#players + 1] = code
        if not winuser or (o and o.score > winuser.score) then
            winuser = o
            winners = {code}
        elseif o and o.score == winuser.score then
            winners[#winners + 1] = code
        end
    end)

    if forced and payType == protoTypes.CGGAME_ROOM_PAYTYPE_WINNER then
        players = winners
    elseif gameCount >= 1 and payType == protoTypes.CGGAME_ROOM_PAYTYPE_OWNER then
        --creator
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
        return
    end

    local cost = roomDetails.costCoins or protoTypes.CGGAME_ROOM_LEAST_COINS
    if payType == protoTypes.CGGAME_ROOM_PAYTYPE_PLAYERS
            and roomDetails.AAPrice
            and roomDetails.AAPrice >= protoTypes.CGGAME_ROOM_LEAST_COINS then
        cost = roomDetails.AAPrice
    else
        cost = math.floor((cost + #players - 1) / #players)
    end

    return players, cost
end

---! 房卡场付款
class.roomTablePayBill = function (self, table, forced)
    local roomInfo = table.roomInfo
    if not cluster or not roomInfo or roomInfo.isPayed then
        return
    end

    local players, cost = self:findChargePlayers(table)
    if not players or not cost then
        return
    end

    local keyName = "FUserCode"
    for _, code in ipairs(players) do
        local info = self:getUserInfo(code)
        info.FCounter = info.FCounter - cost
        self:remoteDeltaDB(self.config.DBTableName, keyName, code, "FCounter", -cost)
        --- print(code, "pay", cost)

        local obj = {}
        obj.FGameID     = self.config.GameId
        obj.FRoomID     = roomInfo.FRoomID
        obj.FUniqueID   = info.FUniqueID
        obj.FCounter    = cost
        obj.FNewCounter = info.FCounter
        obj.FOldCounter = info.FCounter + cost

        local cmd = dbHelper.insert_sql("TUseRecord", obj)
        self:remoteExecDB(cmd)
    end

    roomInfo.isPayed = true
end

---! 创建房卡桌子
class.createRoomTable = function (self, roomInfo)
    if not roomInfo then return end

    local tab = self.allTables[roomInfo.FRoomID]
    if not tab and strHelper.isNullKey(roomInfo.FOpenTime) then
        tab = packetHelper.createObject(self.config.GameClass, self)
        tab.tableId     = roomInfo.FRoomID
        tab.roomInfo    = roomInfo

        self.allTables[tab.tableId] = tab

        tab.openTime = os.time()
        tab.expireTime = os.time() + 10 * 60
        self.expireTables:addObject(tab)
        -- print("open table", tab.tableId, tab.openTime)

        local dbName = "TRoomInfo"
        local keyName= "FRoomID"
        local info = self:remoteLoadDB(dbName, keyName, tab.tableId)

        roomInfo.FOpenTime = dbHelper.timestamp()
        self:remoteUpdateDB(dbName, keyName, info.FRoomID, "FOpenTime", roomInfo.FOpenTime)

        roomInfo.FGameID = self.config.GameId
        self:remoteUpdateDB(dbName, keyName, info.FRoomID, "FGameID", roomInfo.FGameID)
    end

    return tab
end

---! 获得房卡桌子的packet
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

---! 创建房间
class.CreateRoom = function (self, player, roomInfo)
    if player.FCounter < protoTypes.CGGAME_ROOM_LEAST_COINS then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_COUNTER_FAILED, player.FUserCode)
        return
    end

    local packDetails = roomInfo.roomDetails
    roomInfo = self:createRoomDBInfo(player)
    if not roomInfo then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_ROOM_DB_FAILED, player.FUserCode)
        return
    end

    local table = self:createRoomTable(roomInfo)
    if not table then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_ROOM_CREATE_FAILED, player.FUserCode)
        return
    elseif table.extractRoomDetails then
        roomInfo.packDetails = packDetails
        roomInfo.roomDetails = table:extractRoomDetails(packDetails)
        roomInfo.FOwnerName  = player.FNickName
    else
        table:TermTable()
        -- 不支持房卡模式
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_ROOM_NOT_SUPPORT, player.FUserCode)
        return
    end

    local payType = roomInfo.roomDetails.payType or 0
    if payType < protoTypes.CGGAME_ROOM_PAYTYPE_OWNER
            or payType > protoTypes.CGGAME_ROOM_PAYTYPE_WINNER then
        -- payType 不支持
        table:TermTable()
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_ROOM_NO_SUCH_PAYTYPE, player.FUserCode)
        return
    end

    local packet = self:getRoomPacket(table)
    self:sendPacketToUser(packet, player.FUserCode)
end

---! 加入房间
class.JoinRoom = function (self, player, roomInfo)
    if not roomInfo or roomInfo.roomId < protoTypes.CGGAME_ROOM_TABLE_MINID
            or roomInfo.roomId > protoTypes.CGGAME_ROOM_TABLE_MAXID then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_INFO, player.FUserCode)
        return
    end

    local table = self.allTables[roomInfo.roomId]
    if not table then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_ROOM_FIND_FAILED, player.FUserCode)
        return
    end

    local info = table.roomInfo
    if not info or info.FRoomID ~= roomInfo.roomId then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_ROOM_JOIN_FAILED, player.FUserCode)
        return
    end

    if player.FCounter < protoTypes.CGGAME_ROOM_LEAST_COINS then
        if info.histInfo or info.FOwnerID == player.FUserCode then
            -- room started or player is room owner
        else
            self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_COUNTER_FAILED, player.FUserCode)
            return
        end
    end

    local packet = self:getRoomPacket(table)
    self:sendPacketToUser(packet, player.FUserCode)
end

---! 更新退出投票
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
    for i = 1,self.config.MaxPlayer do
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

---! 发送退出信息
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
    table:SendDataToTable(protoTypes.CGGAME_PROTO_MAINTYPE_ROOM, protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_RELEASE, data)
    return exit
end

---! 释放房间
class.ReleaseRoom = function (self, player, exitInfo)
    if not exitInfo or exitInfo.roomId < protoTypes.CGGAME_ROOM_TABLE_MINID
        or exitInfo.roomId > protoTypes.CGGAME_ROOM_TABLE_MAXID then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_INFO, player.FUserCode)
        return
    end

    -- when request
    -- gameCount == agree or not, ownerId = who
    local table = self.allTables[exitInfo.roomId]
    if not table or player.seatId ~= exitInfo.seatId then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_INFO, player.FUserCode)
        return
    end

    local roomInfo = table.roomInfo
    if not roomInfo then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_INFO, player.FUserCode)
        return
    end

    local exit = self:updateExitInfo(table, exitInfo)
    exit = self:sendExitInfo(table, player.seatId, exit)

    if exit then
        table:TermTable()
    end
end

---! 发送所有局的结果
class.ResultRoom = function (self, player, roomInfo)
    local table = self.allTables[roomInfo.roomId]
    if not table then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_INFO, player.FUserCode)
        return
    end

    local roomInfo = table.roomInfo
    if not roomInfo or not roomInfo.histInfo or not roomInfo.histInfo.gameOver then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_INVALID_INFO, player.FUserCode)
        return
    end

    table:SendRoomTableResultAll(player.FUserCode)
end


---! @brief RoomInterface 中的默认游戏消息
---! @param player        用户的数据
---! @param gameType      游戏协议
---! @param data          数据
class.handleGameData = function (self, player, gameType, data)
    local user = self:getUserInfo(player.FUserCode)
    if user then
        player = user
    end

    if gameType == protoTypes.CGGAME_PROTO_SUBTYPE_SITDOWN then
        local seatInfo = self:parseSeatInfo(player, data)
        self:SitDown(player, seatInfo)
    elseif gameType == protoTypes.CGGAME_PROTO_SUBTYPE_STANDUP then
        self:StandUp(player, true)
    elseif gameType == protoTypes.CGGAME_PROTO_SUBTYPE_QUITTABLE then
        self:QuitTable(player)
    elseif gameType == protoTypes.CGGAME_PROTO_SUBTYPE_QUITSTAGE then
        ---! quit stage is not valid here
    elseif gameType == protoTypes.CGGAME_PROTO_SUBTYPE_READY then
        self:PlayerReady(player)
    elseif gameType == protoTypes.CGGAME_PROTO_SUBTYPE_CONFIRM then
        self:ConfirmStart(player)
    elseif gameType == protoTypes.CGGAME_PROTO_SUBTYPE_STANDBY then
        self:PlayerStandBy(player)
    elseif gameType == protoTypes.CGGAME_PROTO_SUBTYPE_CHANGETABLE  then
        local seatInfo = self:parseSeatInfo(player, data)
        self:ChangeTable(player, seatInfo)
    elseif gameType == protoTypes.CGGAME_PROTO_SUBTYPE_GIFT then
        self:SendUserGift(player.FUserCode, data)
    elseif player.tableId then
        local table = self.allTables[player.tableId]
        if table then
            table:handleGameData(player, gameType, data)
        else
            debugHelper.cclog("traceback: unknown table " .. player.tableId)
            player.tableId = nil
        end
    else
        debugHelper.cclog("unknown handleGameData")
    end

    return true
end

---! @brief 玩家站起来，或者在桌子外
---! @param player      玩家的游戏数据
---! @return true       玩家standup成功
---! @return nil        玩家standup失败
class.StandUp = function (self, player, force)
    if not player.tableId then
        return true
    end

    local table = self.allTables[player.tableId]
    if not table or (player.seatId > 0 and table.playerUsers:getObjectAt(player.seatId) ~= player.FUserCode) then
        player.tableId = nil
        player.seatId  = nil
        return true
    end

    if player.seatId < 0 then
        table.standbyUsers:removeObject(player.FUserCode)
        table:handlePlayerQuitTable(player)
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

---! 在之前站起的位置上坐下
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

---! 安排在选定的位置上
class.SeatPlayer = function (self, player, table, seatId)
    table.playerUsers:setObjectAt(seatId, player.FUserCode)
    player.tableId = table.tableId
    player.seatId  = seatId

    self:adjustToWaitTable(table)

    player.status = protoTypes.CGGAME_USER_STATUS_SITDOWN
    table:handlePlayerJoined(player, true)
    if self.config.JoinStandup then
        player.status = protoTypes.CGGAME_USER_STATUS_STANDUP
        table:handlePlayerStandUp(player)
    end
end

---! 房卡场坐下
class.sitDownRoomTable = function (self, player, table, seatId)
    seatId = seatId or table:FindOneEmptySeat()
    if not table:IsSeatEmpty(seatId, true, false) then
        self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_ROOM_JOIN_FULL, player.FUserCode)
        return
    end

    local packet = self:getRoomPacket(table)
    self:sendPacketToUser(packet, player.FUserCode)

    self:SeatPlayer(player, table, seatId)
    return true
end

---! 根据seatInfo参数坐下
class.sitWithOption = function (self, player, seatInfo)
    if seatInfo.roomId >= protoTypes.CGGAME_ROOM_TABLE_MINID
            and seatInfo.roomId <= protoTypes.CGGAME_ROOM_TABLE_MAXID then
        --- 加入房卡场
        local tab = self.allTables[seatInfo.roomId]
        if tab then
            if self:sitDownRoomTable(player, tab, seatInfo.seatId) then
                if tab.roomInfo and tab.roomInfo.histInfo and tab.roomInfo.histInfo.gameOver then
                    tab:SendRoomTableResult(true)
                    tab:SendRoomTableResultAll(player.FUserCode)
                end
                return true
            end
            return
        else
            self:SendACLToUser(protoTypes.CGGAME_ACL_STATUS_ROOM_FIND_FAILED, player.FUserCode)
            return
        end
        return true
    end

    local table = self.allTables[seatInfo.roomId]
    if not table or not table:canPlayerSitdown(player) then
        return nil
    end

    local find = table:FindOneEmptySeat(seatInfo.seatId)
    if not find then
        return nil
    end

    self:SeatPlayer(player, table, find)
    return true
end

---! 解析数据
class.parseSeatInfo = function (self, player, data)
    local seatInfo = packetHelper:decodeMsg("CGGame.SeatInfo", data or "")
    seatInfo = tabHelper.cloneTable(seatInfo)
    if not seatInfo.roomId or seatInfo.roomId <= 0 or not self.allTables[seatInfo.roomId] then
        seatInfo.roomId = nil
        if player.tableId and player.tableId > 0 then
            seatInfo.roomId = player.tableId
        end
    end
    if not seatInfo.seatId or seatInfo.seatId <= 0 then
        seatInfo.seatId = nil
        if player.seatId and player.seatId > 0 then
            seatInfo.seatId = player.seatId
        elseif (seatInfo.roomId or 0) > 0 then
            local table = self.allTables[seatInfo.roomId]
            if table then
                seatInfo.seatId = table:FindOneEmptySeat()
            end
        end
    end
    if not seatInfo.seatId then
        seatInfo.roomId = nil
    end
    if not seatInfo.roomId then
        local oldTableId = player.oldTableId or -1
        local table = self:getEmptyTable(seatInfo.seatId, oldTableId)
        seatInfo.roomId = table.tableId
        seatInfo.seatId = table:FindOneEmptySeat()
    end
    return seatInfo
end

---! @brief 用户坐下
---! @param player      玩家的游戏数据
---! @return true       玩家已经在桌子上了，可能是Sitdown, Ready, Standup, Play中的任意状态
---! @return nil        没有成功坐上桌子, player.tableId, player.seatId 无意义
class.SitDown = function(self, player, seatInfo)
    if seatInfo.roomId ~= player.tableId or seatInfo.seatId ~= player.seatId then
        if player.tableId and not self:QuitTable(player, true) then
            -- print("player can't quit")
            return
        end
    end

    ---! standup to Sitdown
    if player.status == protoTypes.CGGAME_USER_STATUS_STANDUP then
        return self:SitOldSeat(player)
    end

    if player.tableId then
        ---! already in table?
        return true
    end

    return self:sitWithOption(player, seatInfo)
end

---! @brief 玩家准备
---! @param player      玩家的游戏数据
---! @rerurn true   玩家已经成功的ready
---! @rerurn nil
class.PlayerReady = function(self, player)
    if not player.tableId then
        local seatInfo = self:parseSeatInfo(player, "")
        if not self:SitDown(player, seatInfo) then
            return
        end
    end

    local table = self.allTables[player.tableId]
    if not table then
        return
    end

    if table.playerUsers:getObjectAt(player.seatId) ~= player.FUserCode then
        self:QuitTable(player)
        return
    end

    if table.status > protoTypes.CGGAME_TABLE_STATUS_WAITREADY
            or player.status == protoTypes.CGGAME_USER_STATUS_READY
            or not table:canPlayerReady(player) then
        return
    end

    player.status = protoTypes.CGGAME_USER_STATUS_READY
    table:handlePlayerReady(player)
    return true
end

---! 玩家确认，开始游戏
class.ConfirmStart = function(self, player)
    if not player.tableId or not player.seatId then
        return
    end

    local table = self.allTables[player.tableId]
    if not table or table.status ~= protoTypes.CGGAME_TABLE_STATUS_WAITCONFIRM
            or table.waitMask ~= 1 << player.seatId then
        return
    end

    table.waitMask = 0
    table.status = protoTypes.CGGAME_TABLE_STATUS_WAITREADY
    table:CheckGameStart()
end

---! @brief 玩家从桌上站起，变成旁观
---! @param player      玩家的游戏数据
---! @return true       玩家standup成功
---! @return nil        玩家standup失败
class.PlayerStandBy = function (self, player)
    if not player.tableId then
        return
    end

    if player.seatId < 0 then
        return true
    end

    local table = self.allTables[player.tableId]
    if not table or (player.seatId > 0 and table.playerUsers:getObjectAt(player.seatId) ~= player.FUserCode) then
        player.tableId = nil
        player.seatId  = nil
        return
    end

    if not table:canPlayerStandBy(player) then
        return
    end

    table.playerUsers:setObjectAt(player.seatId, nil)
    table.standbyUsers:addObject(player.FUserCode)

    player.status = protoTypes.CGGAME_USER_STATUS_STANDBY
    table:handlePlayerStandBy(player)
    player.seatId = -1
    return true
end

---! @brief 玩家离开桌子但是还在房间里
---! @param palyer         玩家的数据
---! @return true          玩家已经成功的离开了桌子
---! @retuen nil           玩家离开桌子失败
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
        self.onlineUsers:removeObject(player, player.FUserCode)
    end

    return true
end

---! @brief 玩家换桌
class.ChangeTable = function (self, player, seatInfo)
    player.oldTableId = player.tableId
    if self:QuitTable(player) then
        self:SitDown(player, seatInfo)
        if self.config.AutoReady then
            self:PlayerReady(player)
        end
    end
end

---! 退出前是否应该清除玩家
class.shouldQuitClean = function (self, player)
    if player.tableId then
        local table = self.allTables[player.tableId]
        if table and table.roomInfo then
            return false
        end
    end
    return true
end

---!@brief 获得系统内部状态
---!@return info 内部状态的描述
class.logStat = function (self)
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
        tab.playingUsers:forEach(function(sid, code)
            table.insert(lines, string.format("\t\tsid=%d, code=%s", sid, code))
        end)
        table.insert(lines, "\tplayerUsers")
        tab.playerUsers:forEach(function(sid, code)
            table.insert(lines, string.format("\t\tsid=%d, code=%s", sid, code))
        end)
    end

    debugHelper.cclog(table.concat(lines, "\n"))
end


return class

