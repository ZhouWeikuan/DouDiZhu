local skynet = skynet or require "skynet"

local protoTypes    = require "ProtoTypes"
local packetHelper  = (require "PacketHelper").create("protos/CGGame.pb")

local class = {mt = {}}
local GameTable = class
class.mt.__index = class

local
___GameTable___ = function () end

---!@brief 创建GameTable对象
---!@param room      房间的信息
---!@return self     GameTable对象
class.create = function (room)
    local self = {}
    setmetatable(self, class.mt)
    --- self.room = room 房间（room）的数据
    self.room       = room

    self.config     = room.config
    --- self.tableId  桌子的Id号
    self.tableId    = room.nextTableId

    --- self.autoStart  = conf.autoStart
    --- self.status 桌子的状态
    self.status     = protoTypes.CGGAME_TABLE_STATUS_IDLE
    --- self.timeout 本桌的超时设置
    self.timeout    = 0

    local SeatArray = require "SeatArray"
    --- self.playerUsers 给用户设定座位号
    self.playerUsers = SeatArray.create()
    --- self.playingUsers 给正在游戏中的玩家设定座位号
    self.playingUsers = SeatArray.create()

    return self
end

---!@brief TODO 注释函数的意思，和参数的意义
---!@param
---!@return
class.groupAction = function (self, listName, func)
    local list = self[listName]
    list:forEach(func)
end

---!@brief 判断是否有足够的玩家准备
---!@return true      count >= self.config.MinPlayer
---!@return false     count <  self.config.MinPlayer
class.hasEnoughReadyPlayers = function (self)
    local count = 0
    --- self.config.MaxPlayer  本桌能容纳的最大玩家数
    for i=1,self.config.MaxPlayer do
        local uid = self.playerUsers:getObjectAt(i)
        if uid then
            local user = self.room:getUserInfo(uid)
            if not user then
                self.playerUsers:setObjectAt(i, nil)
                return nil
            elseif user.status >= protoTypes.CGGAME_USER_STATUS_READY then
                count = count + 1
            elseif user.status == protoTypes.CGGAME_USER_STATUS_SITDOWN then
                return nil
            end
        end
    end
    --- self.config.MinPlayer   最少多少玩家ready可以开始游戏
    return count >= self.config.MinPlayer
end


---!@brief 获得本桌中玩家的数量
---!@return count 玩家的数量
class.getPlayerCount = function (self)
    local count = 0
    for i=1,self.config.MaxPlayer do
        if self.playerUsers:getObjectAt(i) ~= nil then
            count = count + 1
        end
    end
    return count
end

---!@brief  倒计时的设置
---!@param  userInfo         用户信息
---!@return nil              退出函数
class.handlePlayerJoined = function (self, userInfo, bRefresh)
    self:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_SITDOWN, userInfo.seatId, userInfo.FUniqueID)
    self:SendTableMap("playerUsers", userInfo.seatId)

    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
        if bRefresh then
            self:SendCurrentGameToSeat(userInfo.seatId)
            self:RefreshGameWait()
        end
        return
    end

    local newTimeout = nil
    if self.status == protoTypes.CGGAME_TABLE_STATUS_IDLE then
        newTimeout = protoTypes.CGGAME_TIMEOUT_WAITSTART
        self.status = protoTypes.CGGAME_TABLE_STATUS_WAITSTART
    end

    self:AnyPlayer_GameOverWaitStart(newTimeout)
end

class.canPlayerSitdown = function (self, userInfo)
    if not userInfo.status or userInfo.status == protoTypes.CGGAME_USER_STATUS_IDLE
        or userInfo.status == protoTypes.CGGAME_USER_STATUS_STANDUP then
        return true
    end
    return nil
end

---!@brief  判断玩家是否可以进行standup的操作
---!@param  userInfo         用户信息
---!@return nil              用户不可以进行standup操作
---!@return true             用户可以进行standup操作
---! each game should derive from it to check whether you can stand up or not
class.canPlayerStandUp = function (self, userInfo, force)
    if userInfo.status >= protoTypes.CGGAME_USER_STATUS_PLAYING then
        return nil
    end
    return true
end

class.canPlayerReady = function (self, userInfo)
    if userInfo.status == protoTypes.CGGAME_USER_STATUS_SITDOWN then
        return true
    end
    return nil
end

---!@brief 玩家操作standup
---!@param userInfo         用户信息
---!@return nil             无法进行操作
class.handlePlayerStandUp = function (self, userInfo)
    self:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_STANDUP, userInfo.seatId, userInfo.FUniqueID)

    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
        return
    end

    self:AnyPlayer_GameOverWaitStart()
end

---!@brief 玩家操作ready
---!@param userInfo       用户信息
class.handlePlayerReady = function (self, userInfo)
    self:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_READY, userInfo.seatId, userInfo.FUniqueID)

    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
        return
    end

    self:AnyPlayer_GameOverWaitStart()
end

---!@brief 玩家操作退出Table
---!@param userInfo        用户信息
class.handlePlayerQuitTable = function (self, userInfo)
    self:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_QUITTABLE, userInfo.seatId, userInfo.FUniqueID)

    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_BROADCAST, protoTypes.CGGAME_MSG_EVENT_QUITTABLE, packetHelper:makeProtoData(userInfo.seatId, nil, userInfo.FUniqueID))
    self:sendPacketToUser(packet, userInfo.FUniqueID)

    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
        return
    end

    if self.config.MinPlayer == self.config.MaxPlayer and self.tableId < protoTypes.CGGAME_ROOM_TABLE_MINID then
        -- 不可随意退出的桌子
        self.gameInfo = {}
    end

    self:AnyPlayer_GameOverWaitStart()
end

---!@brief  TODO 注释函数作用
---!@param userInfo        用户信息
---!@param data            TODO 注释data意义
class.handleGameData = function (self, userInfo, data)
    print ("Unknown game data, subType = ", data.subType)
end

---!@brief 超时操作
class.timeoutHandler = function (self)
    if self.status == protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
        self:ClearWaitUser()
        self:AnyPlayer_WaitStartTimeout()
    else
        print("unknown status %d", self.status)
        self.room.eventTables:removeObject(self)
    end
end

---!@brief 发送数据到Table
---!@param packet      发送到Table的消息包
class.sendPacketToTable = function (self, packet)
    self:groupAction("playerUsers", function (seatId, uid)
        self.room:sendPacketToUser(packet, uid)
    end)
end

---!@brief 发送数据到用户
---!@param packet       发送到用户的消息包
---!@param uid          用户的Id
class.sendPacketToUser = function (self, packet, uid)
    self.room:sendPacketToUser(packet, uid)
end

class.SendACLToTable = function(self, aclType)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_ACL, aclType, nil)
    self:sendPacketToTable(packet)
end

class.GetTimeOut = function (self)
    local to = self.timeout - skynet.time()
    return to
end

local
___djgbase2___ = function () end
----------------------------------------------------------
---! from djgbase2
----------------------------

---! @brief Table中的座位的状态的显示
---! @param uiSign      游戏模式
---！@param chRoom      房间的索引序号
---！@param chMinTable  接受消息最小的索引序号
---! @param chMaxTable  接收消息最大的索引序号
---！@param pusergame   玩家的游戏信息
---！@param bTable      
class.SendTableMap = function (self, fieldName, seatId)
    local map = {
        field   = fieldName,
        uid     = {},
        seatId  = {},
    }
    self:groupAction(fieldName, function (sid, uid)
        table.insert(map.uid, uid)
        table.insert(map.seatId, sid)
    end)

    local userId = self.playerUsers:getObjectAt(seatId)
    if not userId then
        return
    end
    local packet = packetHelper:encodeMsg("CGGame.TableMapInfo", map)
    self:SendGameDataToUser(userId, protoTypes.CGGAME_PROTO_SUBTYPE_TABLEMAP, packet)
end


class.SwapSeats = function (self)
    local lim = self.config.MaxPlayer
    for i=1,lim do
        local j = math.random(1, lim)
        if i ~= j then
            local tmp = self.playerUsers:getObjectAt(i)
            local uid = self.playerUsers:getObjectAt(j)
            self.playerUsers:setObjectAt(i, uid)
            self.playerUsers:setObjectAt(j, tmp)
        end
    end

    for i=1,lim do
        local uid = self.playerUsers:getObjectAt(i)
        if uid then
            local user = self.room:getUserInfo(uid)
            if user then
                user.seatId = i
            end
            self:SendTableMap("playerUsers", i)
        end
    end
end

class.SendGameInfo = function (self, seatId)
    print ("you must derive SendGameInfo for each game")
end

---! @brief 获取游戏中下一个要操作的玩家座位
---! @param pusergame   玩家的游戏信息
---！@param pchSite     发送消息时的索引的地址
---！@param bClockwise  向前还是向后的索引
---! step should be 1, or -1
class.GetNextPlayer = function(self, seatId, step)
    step = step or 1
    local prevId = seatId
    repeat
        seatId = seatId + step
        if seatId > self.config.MaxPlayer then
            seatId = 1
        elseif seatId < 1 then
            seatId = self.config.MaxPlayer
        end
        if self.playingUsers:getObjectAt(seatId) then
            return seatId
        end
    until prevId == seatId

    return 1
end

---! @brief 发送给玩家的游戏数据
---! @brief 发送游戏数据到用户 
---! @param uid         用户Id
---! @param subType     数据类型
---! @param data        数据内容
class.SendGameDataToUser = function (self, uid, subType, data)
    if not subType or subType == 0 then
        print(debug.traceback())
    end
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA, subType, data);
    self:sendPacketToUser(packet, uid) 
end


---!@brief 发送游戏数据到Table
---!@param subType       数据的类型
---!@param data          数据的内容
class.SendGameDataToTable = function (self, subType, data)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA, subType, data);
    self:groupAction("playerUsers", function (seatId, uid)
        self:sendPacketToUser(packet, uid)
    end)
end

class.SendDataToTable = function (self, mainType, subType, data)
    local packet = packetHelper:makeProtoData(mainType, subType, data);
    self:groupAction("playerUsers", function (seatId, uid)
        self:sendPacketToUser(packet, uid)
    end)
end


---! @brief 等待进入游戏
---! @param pusergame   玩家的游戏消息
---！@param shWaitMask  等待时的Mask
---！@param chTableStatus Table的状态消息
---！@param shTimeout   用户在游戏中的超时设置
class.SendGameWait = function(self, mask, newStatus, newTimeout)
    self.status = newStatus
    self.room:updateTableTimeout(self, newTimeout)
    self.waitMask = mask

    local wait = {
        tableStatus = newStatus,
        timeout     = newTimeout,
        waitMask    = mask,
    }

    local data = packetHelper:encodeMsg("CGGame.WaitUserInfo", wait)

    self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_WAITUSER, data)
end

class.RefreshGameWait = function (self)
    local status    = self.status
    local timeout   = self:GetTimeOut()
    local waitmask  = self.waitMask

    self:SendGameWait(waitmask, status, timeout)
end

---!@brief 等待用户
---!@param player        用户数据
---!@return true         TODO 注释
class.IsWaitSeat = function (self, seatId)
    local mask = (1 << seatId)
    if (self.waitMask & mask) ~= 0 then
        return true
    end

    return nil
end

class.IsSeatEmpty = function (self, seatId, checkPlayerUser, checkPlayingUser)
    if checkPlayerUser and self.playerUsers:getObjectAt(seatId) ~= nil then
        return 
    end
    if checkPlayingUser and self.playingUsers:getObjectAt(seatId) ~= nil then
        return
    end

    return true
end

class.GetWaitingSeats = function (self)
    local seats = {}
    for i = 1, self.config.MaxPlayer do
        if (self.waitMask & (1 << i)) ~= 0 then
            seats[i] = i
        end
    end

    return seats
end

---! @brief 清除超时的玩家
---! @param ptable      Table的数据
---！@param pusergame   玩家的游戏数据
class.ClearWaitUser = function(self)
    local readyCount = 0
    local quits = {}
    self:groupAction("playerUsers", function (seatId, uid)
        local user = self.room:getUserInfo(uid)
        if not user then
            quits[uid] = seatId
            return
        end
        if user.is_offline and self.roomInfo == nil then
            quits[uid] = seatId
        elseif user.tableId ~= self.tableId or user.seatId ~= seatId then
            -- print ("tableid or seatId mis match!", self.tableId, seatId, user.tableId, user.seatId)
            quits[uid] = seatId
        elseif user.status == protoTypes.CGGAME_USER_STATUS_SITDOWN then
            quits[uid] = seatId
        elseif user.status == protoTypes.CGGAME_USER_STATUS_PLAYING then
            -- print("reset playing to ready")
            user.status = protoTypes.CGGAME_USER_STATUS_READY
            readyCount = readyCount + 1
        elseif user.status == protoTypes.CGGAME_USER_STATUS_READY then
            readyCount = readyCount + 1
        elseif user.status == protoTypes.CGGAME_USER_STATUS_STANDUP then
        else --- stand up?
            print("uncleared user status ", user.status)
        end
    end)
    for uid, sid in pairs(quits) do
        local user = self.room:getUserInfo(uid)
        if not user or user.tableId ~= self.tableId or user.seatId ~= sid then
            self.playerUsers:setObjectAt(sid, nil)
        else
            self.room:QuitTable(user)
        end
    end
end


---! @brief 设置进入游戏的条件 
---! @param pusergame   玩家的游戏数据
class.SetTable2Idle = function(self, pusergame)
end


---! @brief 获取玩家的索引序号
---! @param uiSign      游戏的模式
---！@param ptable      Table的数据
---！@param chSite      玩家接受消息的索引号
---！@param pusergame   玩家的游戏数据
---！@param pgeneraluser玩家的通用设置 
class.GetSiteUser = function(self, uiSign, ptable, chSite, pusergame, pgeneraluser)
end


---! @brief 发送当前游戏消息
---! @param pusergame   玩家的游戏数据
---！@param ptable      Table的数据
---！@param shSiteMask  游戏中site的mask
class.SendCurrentGameToSeat = function(self, seatId)
    self:SendTableMap("playingUsers", seatId)
    self:SendGameInfo(seatId)
end

---!@brief 发送当前游戏消息
---!@param seatId         座位号
---!@param mask           位，用于表示那个座位有人
class.SendCurrentGameToTable = function (self)
    self:groupAction("playerUsers", function (seatId, uid)
        self:SendCurrentGameToSeat(seatId)
    end)
end

---!@brief 玩家开始游戏
---!@return nil 直接退出函数
class.PlayerStartGame = function (self)
    if self.status ~= protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
        return
    end

    if self.gameStart then
        if self:RefreshPlayingUsers() then
            self.status = protoTypes.CGGAME_TABLE_STATUS_PLAYING
            self:gameStart()
        else
            self:AnyPlayer_GameOverWaitStart()
        end
    else
        print("GameTable's function gameStart not found!")
    end
end

---! @brief 所有玩家等待mask
---! @return mask    返回mask
class.GetAllPlayingUserMask = function (self)
    local mask = 0
    for i=1, self.config.MaxPlayer do
        local uid = self.playingUsers:getObjectAt(i)
        if uid then
            mask = mask | (1<<i)
        end
    end

    return mask
end


---! @brief 将已准备的玩家放入索引的范围
---! @param proom       房间的数据信息
---！@param ptable      Table的数据信息
class.RefreshPlayingUsers = function(self)
    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
        return nil
    end

    local oldUsers = {}
    local count = 0
    self.playingUsers:clear()
    self:groupAction("playerUsers", function(seatId, uid)
        local user = self.room:getUserInfo(uid)
        if user and user.status == protoTypes.CGGAME_USER_STATUS_READY then
            user.status = protoTypes.CGGAME_USER_STATUS_PLAYING
            self.playingUsers:setObjectAt(seatId, uid)

            table.insert(oldUsers, user)

            count = count + 1
        end
    end)

    if count >= self.config.MinPlayer then
        return true
    end

    for _, user in ipairs(oldUsers) do
        user.status = protoTypes.CGGAME_USER_STATUS_READY
    end

    return nil
end


---! @brief 查看相邻玩家的ID号
---! @param pusergame   玩家的数据信息
---！@param bClockwise  获取前一个或后一个玩家
---！@param pchsite     发送消息索引的序号
class.AnyPlayer_GetNextPlayerID = function(self, seatId, step)
    local nextSeatId = self:GetNextPlayer(seatId, step)
    if nextSeatId then
        local nextUserId = self.playingUsers:getObjectAt(nextSeatId)
        return nextUserId
    end
    return nil
end


---! @brief 获取下一个玩家的索引号
---! @param ptable      Table的数据信息
---！@param chCurSite   当前发送信息的索引
---！@param bClockwise  获取前一个或后一个玩家
class.AnyPlayer_GetNextPlayerSite = function(self, seatId, step)
    local nextSeatId = self:GetNextPlayer(seatId, step)
    return nextSeatId
end


---! @brief 所有玩家等待mask
---! @return mask    返回mask
class.AnyPlayer_GetAllPlayerWaitMask = function (self)
    local mask = 0
    for i=1, self.config.MaxPlayer do
        local uid = self.playerUsers:getObjectAt(i)
        if uid then
            local u = self.room:getUserInfo(uid)
            if u and u.status == protoTypes.CGGAME_USER_STATUS_SITDOWN then
                if not self.roomInfo and self.config.AutoStart then
                    if self:canPlayerReady(u) then
                        u.status = protoTypes.CGGAME_USER_STATUS_READY
                    else
                        u.status = protoTypes.CGGAME_USER_STATUS_STANDUP
                    end
                else
                    mask = mask | (1<<i)
                end
            end
        end
    end

    return mask
end


---! @brief 设置玩家强制退出
---! @param proom       房间的数据信息
---！@param pusergame   玩家的数据信息
class.AnyPlayer_SetPlayerForceQuit = function(self, userInfo)
    if self.status == protoTypes.CGGAME_TABLE_STATUS_IDLE then
        userInfo.tableId = nil
        return nil
    end

    if userInfo.status == protoTypes.CGGAME_USER_STATUS_IDLE then
        return nil
    end

    if userInfo.status > protoTypes.CGGAME_USER_STATUS_SITDOWN then
        return nil
    elseif uesrInfo.status <= protoTypes.CGGAME_USER_STATUS_SITDOWN then
        self.room:QuitTable(userInfo.FUniqueID) 
    end
end


---! @brief 前一局游戏结束，等待下一局游戏开始
---! @param proom       房间的数据信息
---！@param ptable      Table的数据信息
---！@param pusergame   玩家的游戏信息
class.AnyPlayer_GameOverWaitStart = function(self, newTimeout)
    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
        return
    end

    if not newTimeout then
        newTimeout = self:GetTimeOut()
        newTimeout = math.max(newTimeout, 6)
    end

    local mask = self:AnyPlayer_GetAllPlayerWaitMask()
    if mask == 0 and self:hasEnoughReadyPlayers() and newTimeout >= 1 then
        -- 防止有人重复进出，这样所有人都得等来等去，没办法开始
        newTimeout = 0
    elseif self.roomInfo then
        newTimeout = protoTypes.CGGAME_TIMEOUT_KEEPLINE * 2
    end

    self:SendGameWait(mask, protoTypes.CGGAME_TABLE_STATUS_WAITSTART, newTimeout)

    self.room:adjustToWaitTable(self)
end

class.AnyPlayer_WaitStartTimeout = function (self)
    if self.status ~= protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
        return
    end

    local mask = self:AnyPlayer_GetAllPlayerWaitMask()
    if mask == 0 and self:hasEnoughReadyPlayers() then
        self.waitMask = 0
        self:PlayerStartGame()
    elseif self:getPlayerCount() == 0 then
        self.status = protoTypes.CGGAME_TABLE_STATUS_IDLE
        self.room.eventTables:removeObject(self)
    end
end



---!@brief 游戏结束
class.GameOver = function (self, ready, noquit)
    local quits = {}
    self:groupAction("playingUsers", function (seatId, uid)
        local u = self.room:getUserInfo(uid)
        --- u.status 用户状态
        if (not noquit) and (not u or u.is_offline) then
            quits[uid] = seatId
        elseif u and u.status == protoTypes.CGGAME_USER_STATUS_PLAYING then
            u.status = protoTypes.CGGAME_USER_STATUS_SITDOWN
            if ready then
                u.status = protoTypes.CGGAME_USER_STATUS_READY
            end
        end
    end)
    self.playingUsers:reset()

    for uid, sid in pairs(quits) do
        local user = self.room:getUserInfo(uid)
        if not user then
            self.playerUsers:setObjectAt(sid, nil)
        else
            self.room:QuitTable(user)
        end
    end
end


class.SendRoomTableResult = function (self, allOver)
    if not self.roomInfo or not self.roomInfo.histInfo then
        return
    end

    local histInfo = self.roomInfo.histInfo
    histInfo.gameOver   = allOver

    local hp = require "TableHelper"
    local data = hp.encode(histInfo) or ""

    local lim = 64000
    while data ~= "" do
        local part = string.sub(data, 1, lim)
        self:SendDataToTable(protoTypes.CGGAME_PROTO_TYPE_ROOMDATA, protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_RESULT, part)
        data = string.sub(data, lim + 1)
    end
end

class.QuitRoomTableUsers = function (self)
    local quits = {}
    self:groupAction("playerUsers", function (seatId, uid)
        quits[uid] = seatId
    end)

    for uid, sid in pairs(quits) do
        local user = self.room:getUserInfo(uid)
        if not user then
            self.playerUsers:setObjectAt(sid, nil)
        else
            self.room:QuitTable(user, true)
        end
    end
end

---!@brief destroy this table
class.TermTable = function (self, expired)
    if not self.roomInfo then
        return
    end

    local maxDelay = protoTypes.CGGAME_ROOM_TABLE_EXPIRE_TIME 
    if expired and self.expireTime < self.openTime + maxDelay then -- protoTypes.CGGAME_ROOM_TABLE_EXPIRE_TIME then
        -- 超时
        
        local liveNum = 0
        local name
        if self.playingUsers:getCount() > 0 or self.roomInfo.histInfo then
            name = "playingUsers"
        elseif self.playerUsers:getCount() > 0 then
            name = "playerUsers"
        else
            name = nil
        end

        if name then
            self:groupAction(name, function (seatId, uid)
                local u = self.room:getUserInfo(uid)
                if not u or u.is_offline then
                else
                    liveNum = liveNum + 1
                end
            end)
        end

        if name == "playingUsers" then
            if liveNum <= 0 and self.openTime + protoTypes.CGGAME_ROOM_TABLE_EXPIRE_NO_PLAYING < os.time() then
                -- print("no playing", self.tableId, "expire at", os.time())
            else
                self.expireTime = self.expireTime + protoTypes.CGGAME_ROOM_TABLE_EXPIRE_NO_PLAYING
                -- print("playing extend time", self.tableId, self.expireTime)
                return
            end
        elseif name == "playerUsers" then
            if liveNum > 0 then
                self.expireTime = self.expireTime + 10 * 60
                -- print("player extend time", self.tableId, self.expireTime)
                return
            end
        end
    end

    -- print("term room table: %d", self.tableId)

    local debugHelper = require "DebugHelper"
    debugHelper.cclog("term room table: %d", self.tableId)

    self.room:roomTablePayBill(self, true)

    self:GameOver()
    self:QuitRoomTableUsers()
    self.room:releaseRoomTable(self)
    return true
end


---! @brief 广播消息
---! @brief 广播消息
---! @param msgType       消息的类型
---! @param seatId        座位号
---! @param uid           用户的Id号
---!  msgType = BROADCAST, subType = msgType, data = { mainType = seatId, data=uid}
class.BroadcastMessage = function (self, msgType, seatId, uid)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_BROADCAST, msgType,
    packetHelper:makeProtoData(seatId, nil, uid))
    self:sendPacketToTable(packet)
end




return GameTable

