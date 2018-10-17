local skynet = skynet or require "skynet"

local protoTypes    = require "ProtoTypes"

local SeatArray     = require "SeatArray"
local NumSet        = require "NumSet"

local debugHelper   = require "DebugHelper"
local packetHelper  = (require "PacketHelper").create("protos/CGGame.pb")
local tabHelper     = require "TableHelper"

local class = {mt = {}}
class.mt.__index = class


---! @brief 创建GameTable对象
---! @param room      房间的信息
---! @return self     GameTable对象
class.create = function (room)
    local self = {}
    setmetatable(self, class.mt)
    --- self.room = room 房间（room）的数据
    self.room       = room

    self.config     = room.config
    --- self.tableId  桌子的Id号
    self.tableId    = room.nextTableId

    --- self.status 桌子的状态
    self.status     = protoTypes.CGGAME_TABLE_STATUS_IDLE
    --- self.timeout 本桌的超时设置
    self.timeout    = 0

    --- self.playerUsers 给用户设定座位号
    self.playerUsers = SeatArray.create()
    --- self.playingUsers 给正在游戏中的玩家设定座位号
    self.playingUsers = SeatArray.create()

    --- self.standbyUsers 旁观的用户
    self.standbyUsers = NumSet.create()

    return self
end

---! @brief 轮询列表里的元素
class.groupAction = function (self, listName, func)
    local list = self[listName]
    if list == self.standbyUsers then
        list:forEach(function (code)
            return func(-1, code)
        end)
    else
        list:forEach(func)
    end
end

---!@brief 判断是否有足够的玩家准备
---!@return true      count >= self.config.MinPlayer
---!@return false     count <  self.config.MinPlayer
class.hasEnoughReadyPlayers = function (self)
    local count = 0
    --- self.config.MaxPlayer  本桌能容纳的最大玩家数
    for i = 1,self.config.MaxPlayer do
        local code = self.playerUsers:getObjectAt(i)
        if code then
            local user = self.room:getUserInfo(code)
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
    for i = 1,self.config.MaxPlayer do
        if self.playerUsers:getObjectAt(i) ~= nil then
            count = count + 1
        end
    end
    return count
end

---! 找一个空位置
class.FindOneEmptySeat = function (self, reqSeatId)
    if reqSeatId and self:IsSeatEmpty(reqSeatId, true, false) then
        return reqSeatId
    end

    local lim = self.config.BestPlayer or self.config.MaxPlayer
    reqSeatId = self.config.SeatOrder and 1 or math.random(1, lim)
    for i = reqSeatId, lim do
        if self:IsSeatEmpty(i, true, false) then
            return i
        end
    end

    for i = reqSeatId - 1, 1, -1 do
        if self:IsSeatEmpty(i, true, false) then
            return i
        end
    end
end

---!@brief  倒计时的设置
---!@param  userInfo         用户信息
---!@return nil              退出函数
class.handlePlayerJoined = function (self, userInfo, bRefresh)
    self:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_SITDOWN, userInfo.seatId, userInfo.FUserCode)

    self:SendTableMap("playerUsers", userInfo.seatId, userInfo.FUserCode)
    self:SendTableMap("standbyUsers", userInfo.seatId, userInfo.FUserCode)

    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITCONFIRM then
        if bRefresh then
            self:SendCurrentGameToSeat(userInfo.seatId)
            self:RefreshGameWait()
        end
        return
    end

    local newTimeout = nil
    if self.status == protoTypes.CGGAME_TABLE_STATUS_IDLE then
        newTimeout = protoTypes.CGGAME_TIMEOUT_WAITREADY
        self.status = protoTypes.CGGAME_TABLE_STATUS_WAITREADY
    end

    self:AnyPlayer_GameOverWaitStart(newTimeout)
end

---! @brief  是否可以坐下
class.canPlayerSitdown = function (self, userInfo)
    if not userInfo.status or userInfo.status == protoTypes.CGGAME_USER_STATUS_IDLE
        or userInfo.status == protoTypes.CGGAME_USER_STATUS_STANDBY
        or userInfo.status == protoTypes.CGGAME_USER_STATUS_STANDUP then
        return true
    end
    return nil
end

---! @brief  判断玩家是否可以进行standup的操作
class.canPlayerStandUp = function (self, userInfo, force)
    if userInfo.status >= protoTypes.CGGAME_USER_STATUS_PLAYING then
        return nil
    end
    return true
end

---! @brief  判断玩家是否可以进行standby的操作
class.canPlayerStandBy = function (self, userInfo, force)
    if userInfo.status >= protoTypes.CGGAME_USER_STATUS_PLAYING then
        return nil
    end
    return true
end

---! @brief 判断玩家是否可以进入准备状态
class.canPlayerReady = function (self, userInfo)
    if userInfo.status == protoTypes.CGGAME_USER_STATUS_SITDOWN then
        return true
    end
end

---! @brief 玩家操作standup
class.handlePlayerStandUp = function (self, userInfo)
    self:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_STANDUP, userInfo.seatId, userInfo.FUserCode)

    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
        return
    end

    self:AnyPlayer_GameOverWaitStart()
end

---! @brief 玩家操作standby
class.handlePlayerStandBy = function (self, userInfo)
    self:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_STANDBY, userInfo.seatId, userInfo.FUserCode)

    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
        return
    end

    self:AnyPlayer_GameOverWaitStart()
end

---! @brief 玩家操作ready
class.handlePlayerReady = function (self, userInfo)
    self:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_READY, userInfo.seatId, userInfo.FUserCode)

    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
        return
    end

    self:AnyPlayer_GameOverWaitStart()
end

---! @brief 玩家操作退出Table
class.handlePlayerQuitTable = function (self, userInfo)
    self:BroadcastMessage(protoTypes.CGGAME_MSG_EVENT_QUITTABLE, userInfo.seatId, userInfo.FUserCode)

    local info = {
        roomId  = protoTypes.CGGAME_MSG_EVENT_QUITTABLE,
        seatId  = userInfo.seatId,
        userCode = userInfo.FUserCode,
    }
    local packet = packetHelper:encodeMsg("CGGame.SeatInfo", info)
    packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME,
                protoTypes.CGGAME_PROTO_SUBTYPE_BROADCAST, packet)
    self:sendPacketToUser(packet, userInfo.FUserCode)

    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
        return
    end

    if self.config.MinPlayer == self.config.MaxPlayer
            and self.tableId < protoTypes.CGGAME_ROOM_TABLE_MINID
            and userInfo.seatId > 0 then
        -- 不可随意退出的桌子
        self.gameInfo = {}
    end

    self:AnyPlayer_GameOverWaitStart()
end

---! @brief 广播消息
---! @param msgType       消息的类型
---! @param seatId        座位号
---! @param code          用户的userCode号
class.BroadcastMessage = function (self, msgType, seatId, code)
    local info = {
        roomId  = msgType,
        seatId  = seatId,
        userCode = code,
    }
    local packet = packetHelper:encodeMsg("CGGame.SeatInfo", info)
    packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME,
                protoTypes.CGGAME_PROTO_SUBTYPE_BROADCAST, packet)
    self:sendPacketToTable(packet)
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

---!@brief  处理游戏桌子的数据
class.handleGameData = function (self, userInfo, gameType, data)
    print ("Unknown game data, subType = ", userInfo, gameType, data)
end

---!@brief 超时操作
class.timeoutHandler = function (self)
    if self.status == protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
        self:ClearWaitUser()
        self:AnyPlayer_WaitStartTimeout()
    else
        print("unknown status ", self.status)
        self.room.eventTables:removeObject(self)
    end
end

---! @brief 发送游戏数据到用户
---! @param code        userCode
---! @param subType     数据类型
---! @param data        数据内容
class.SendGameDataToUser = function (self, code, subType, data)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME, subType, data);
    self:sendPacketToUser(packet, code)
end

---! @brief 发送游戏数据到Table
---! @param subType       数据的类型
---! @param data          数据的内容
class.SendGameDataToTable = function (self, subType, data)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME, subType, data);
    self:sendPacketToTable(packet)
end

---! @brief 发送数据到Table
class.sendPacketToTable = function (self, packet)
    self:groupAction("playerUsers", function (seatId, code)
        self:sendPacketToUser(packet, code)
    end)
    self:groupAction("standbyUsers", function (seatId, code)
        self:sendPacketToUser(packet, code)
    end)
end

---! @brief 发送数据到用户
class.sendPacketToUser = function (self, packet, code)
    self.room:sendPacketToUser(packet, code)
end

---! 发送acl信息给整个桌子的用户
class.SendACLToTable = function(self, aclType)
    local aclInfo = {
        aclType = aclType,
    }
    local data = packetHelper:encodeMsg("CGGame.AclInfo", aclInfo)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                        protoTypes.CGGAME_PROTO_SUBTYPE_ACL, data)
    self:sendPacketToTable(packet)
end

---! 获得超时时间
class.GetTimeOut = function (self)
    local to = self.timeout - skynet.time()
    return to
end

---! @brief Table中的座位的状态的显示
class.SendTableMap = function (self, fieldName, seatId, userCode)
    local map = {
        field       = fieldName,
        userCode    = {},
        seatId      = {},
    }
    self:groupAction(fieldName, function (sid, code)
        table.insert(map.userCode, code)
        table.insert(map.seatId, sid)
    end)

    local myCode = self.playerUsers:getObjectAt(seatId)
    if not myCode and not self.standbyUsers:hasObject(userCode) then
        return
    end
    myCode = myCode or userCode
    local packet = packetHelper:encodeMsg("CGGame.TableMapInfo", map)
    self:SendGameDataToUser(myCode, protoTypes.CGGAME_PROTO_SUBTYPE_TABLEMAP, packet)
end

---! 交换座位
class.SwapSeats = function (self)
    local lim = self.config.MaxPlayer
    for i=1,lim do
        local j = math.random(1, lim)
        if i ~= j then
            local temp = self.playerUsers:getObjectAt(i)
            local code = self.playerUsers:getObjectAt(j)
            self.playerUsers:setObjectAt(i, code)
            self.playerUsers:setObjectAt(j, temp)
        end
    end

    for i=1,lim do
        local code = self.playerUsers:getObjectAt(i)
        if code then
            local user = self.room:getUserInfo(code)
            if user then
                user.seatId = i
            end
            self:SendTableMap("playerUsers", i, code)
        end
    end
end

class.SendGameInfo = function (self, seatId)
    print ("you must derive SendGameInfo for each game")
end

---! @brief 发送等待进入游戏
---！@param mask 等待时的Mask
---！@param newstatus Table的状态消息
---！@param newTimeout   用户在游戏中的超时设置
class.SendGameWait = function(self, mask, newStatus, newTimeout)
    self.status = newStatus
    self.room:updateTableTimeout(self, newTimeout)
    self.waitMask = mask

    local wait = {
        tableStatus = newStatus,
        timeout     = math.ceil(newTimeout),
        waitMask    = mask,
    }

    local data = packetHelper:encodeMsg("CGGame.WaitUserInfo", wait)
    self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_WAITUSER, data)
end

---! 刷新用户等待
class.RefreshGameWait = function (self)
    local status    = self.status
    local timeout   = self:GetTimeOut()
    local waitmask  = self.waitMask

    self:SendGameWait(waitmask, status, timeout)
end

---! @brief 等待用户
class.IsWaitSeat = function (self, seatId)
    local mask = (1 << seatId)
    if (self.waitMask & mask) ~= 0 then
        return true
    end
end

---! 判断座位是否为空
class.IsSeatEmpty = function (self, seatId, checkPlayerUser, checkPlayingUser)
    if (checkPlayerUser and self.playerUsers:getObjectAt(seatId) ~= nil)
            or (checkPlayingUser and self.playingUsers:getObjectAt(seatId) ~= nil) then
        return
    end

    return true
end

---! 获取等候的座位
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
class.ClearWaitUser = function(self)
    local readyCount = 0
    local quits = {}
    self:groupAction("playerUsers", function (seatId, code)
        local user = self.room:getUserInfo(code)
        if not user then
            quits[code] = seatId
            return
        end
        if (user.is_offline and self.roomInfo == nil)
                or (user.tableId ~= self.tableId or user.seatId ~= seatId)
                or (user.status == protoTypes.CGGAME_USER_STATUS_SITDOWN) then
            quits[code] = seatId
        elseif user.status == protoTypes.CGGAME_USER_STATUS_PLAYING then
            user.status = protoTypes.CGGAME_USER_STATUS_READY
            readyCount = readyCount + 1
        elseif user.status == protoTypes.CGGAME_USER_STATUS_READY then
            readyCount = readyCount + 1
        elseif user.status == protoTypes.CGGAME_USER_STATUS_STANDUP
            or user.status == protoTypes.CGGAME_USER_STATUS_STANDBY then
        else
            print("uncleared user status ", user.status)
        end
    end)

    for code, sid in pairs(quits) do
        local user = self.room:getUserInfo(code)
        if not user or user.tableId ~= self.tableId or user.seatId ~= sid then
            self.playerUsers:setObjectAt(sid, nil)
        else
            self.room:QuitTable(user)
        end
    end
end

---! @brief 发送当前游戏消息
class.SendCurrentGameToSeat = function(self, seatId, code)
    self:SendTableMap("playingUsers", seatId, code)
    self:SendGameInfo(seatId)
end

---! @brief 发送当前游戏消息给用户
class.SendCurrentGameToTable = function (self)
    self:groupAction("playerUsers", function (seatId, code)
        self:SendCurrentGameToSeat(seatId, code)
    end)
    self:groupAction("standbyUsers", function (seatId, code)
        self:SendCurrentGameToSeat(seatId, code)
    end)
end

---! 等候游戏确认开始
class.WaitForConfirm = function (self)
    if self.status ~= protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
        return
    end

    local mask = 0
    for i=1, self.config.MaxPlayer do
        local code = self.playerUsers:getObjectAt(i)
        if code then
            local u = self.room:getUserInfo(code)
            if u and u.status == protoTypes.CGGAME_USER_STATUS_READY then
                mask = (1<<i)
                break
            end
        end
    end

    local timeout = self.config.RoomTimeOut or protoTypes.CGGAME_TIMEOUT_KEEPLINE * 2
    self:SendGameWait(mask, protoTypes.CGGAME_TABLE_STATUS_WAITCONFIRM, timeout)

    self.room:adjustToWaitTable(self)
end

---! @brief 玩家开始游戏
class.PlayerStartGame = function (self)
    if self.status ~= protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
        return
    end

    if self.roomInfo and self.config.ConfirmReady and not self.roomInfo.histInfo then
        self:WaitForConfirm()
        return
    end

    self:CheckGameStart()
end

---! 准备完毕，看游戏是否可以开始
class.CheckGameStart = function (self)
    if self.status ~= protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
        return
    end

    if self.roomInfo and self.roomInfo.histInfo and self.roomInfo.histInfo.gameOver then
        skynet.error("Can't start released table", self.tableId)
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
        local code = self.playingUsers:getObjectAt(i)
        if code then
            mask = mask | (1<<i)
        end
    end

    return mask
end

---! @brief 将已准备的玩家放入索引的范围
class.RefreshPlayingUsers = function(self)
    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
        return nil
    end

    local oldUsers = {}
    local count = 0
    self.playingUsers:clear()
    self:groupAction("playerUsers", function(seatId, code)
        local user = self.room:getUserInfo(code)
        if user and user.status == protoTypes.CGGAME_USER_STATUS_READY then
            user.status = protoTypes.CGGAME_USER_STATUS_PLAYING
            self.playingUsers:setObjectAt(seatId, code)

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
end

---! @brief 查看相邻玩家的ID号
class.AnyPlayer_GetNextPlayerID = function(self, seatId, step)
    local nextSeatId = self:GetNextPlayer(seatId, step)
    if nextSeatId then
        local nextUserId = self.playingUsers:getObjectAt(nextSeatId)
        return nextUserId
    end
    return nil
end

---! @brief 获取下一个玩家的索引号
class.AnyPlayer_GetNextPlayerSite = function(self, seatId, step)
    local nextSeatId = self:GetNextPlayer(seatId, step)
    return nextSeatId
end

---! @brief 所有玩家等待mask
---! @return mask    返回mask
class.AnyPlayer_GetAllPlayerWaitMask = function (self)
    local mask = 0
    for i=1, self.config.MaxPlayer do
        local code = self.playerUsers:getObjectAt(i)
        if code then
            local u = self.room:getUserInfo(code)
            if u and u.status == protoTypes.CGGAME_USER_STATUS_SITDOWN then
                if not self.roomInfo and self.config.AutoReady then
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
class.AnyPlayer_SetPlayerForceQuit = function(self, userInfo)
    if self.status == protoTypes.CGGAME_TABLE_STATUS_IDLE then
        userInfo.tableId = nil
    end

    if userInfo.status == protoTypes.CGGAME_USER_STATUS_IDLE
            or userInfo.status > protoTypes.CGGAME_USER_STATUS_SITDOWN then
        return
    elseif uesrInfo.status <= protoTypes.CGGAME_USER_STATUS_SITDOWN then
        self.room:QuitTable(userInfo)
    end
end

---! @brief 前一局游戏结束，等待下一局游戏开始
class.AnyPlayer_GameOverWaitStart = function(self, newTimeout)
    if self.status > protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
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
        newTimeout = self.config.RoomTimeOut or protoTypes.CGGAME_TIMEOUT_KEEPLINE * 2
    end

    self:SendGameWait(mask, protoTypes.CGGAME_TABLE_STATUS_WAITREADY, newTimeout)
    self.room:adjustToWaitTable(self)
end

---! 等候开始，已经超时了
class.AnyPlayer_WaitStartTimeout = function (self)
    if self.status ~= protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
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

---! @brief 游戏结束
class.GameOver = function (self, ready, noquit)
    local quits = {}
    self:groupAction("playingUsers", function (seatId, code)
        local u = self.room:getUserInfo(code)
        --- u.status 用户状态
        if (not noquit) and (not u or u.is_offline) then
            quits[code] = seatId
        elseif u and u.status == protoTypes.CGGAME_USER_STATUS_PLAYING then
            u.status = protoTypes.CGGAME_USER_STATUS_SITDOWN
            if ready then
                u.status = protoTypes.CGGAME_USER_STATUS_READY
            end
        end
    end)
    self.playingUsers:reset()

    for code, sid in pairs(quits) do
        local user = self.room:getUserInfo(code)
        if not user then
            self.playerUsers:setObjectAt(sid, nil)
        else
            self.room:QuitTable(user)
        end
    end
end

---! 房卡场用户的退出
class.QuitRoomTableUsers = function (self)
    local quits = {}
    self:groupAction("playerUsers", function (seatId, code)
        quits[code] = seatId
    end)

    for code, sid in pairs(quits) do
        local user = self.room:getUserInfo(code)
        if not user then
            self.playerUsers:setObjectAt(sid, nil)
        else
            self.room:QuitTable(user, true)
        end
    end
end

----! 发送房卡数据
class.sendMultiRoomData = function (self, code, subType, data)
    local lim = 60000
    local arr = {}
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_ROOM, subType, data)
    while packet ~= "" do
        local part = string.sub(packet, 1, lim)
        table.insert(arr, part)
        packet = string.sub(packet, lim + 1)
    end

    local num = #arr
    for idx, part in ipairs(arr) do
        local info = {
            curIndex = idx,
            maxIndex = num,
            msgBody  = part,
        }
        data = packetHelper:encodeMsg("CGGame.MultiBody", info)
        packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_BASIC,
                        protoTypes.CGGAME_PROTO_SUBTYPE_MULTIPLE, data)
        if code then
            self:sendPacketToUser(packet, code)
        else
            self:sendPacketToTable(packet)
        end
    end
end

---! 发送房卡场一局结果
class.SendRoomTableResult = function (self, allOver)
    if not self.roomInfo or not self.roomInfo.histInfo then
        return
    end

    local histInfo = self.roomInfo.histInfo
    local newResult = not histInfo.gameOver
    histInfo.gameOver   = allOver

    local data = tabHelper.encode(histInfo) or ""
    self:sendMultiRoomData(nil, protoTypes.CGGAME_PROTO_SUBTYPE_RESULT, data)

    local allHistInfo = self.roomInfo.allHistInfo
    if allHistInfo then
        local gameInfos = allHistInfo.gameInfo
        allHistInfo = tabHelper.cloneTable(histInfo)
        allHistInfo.gameInfo = gameInfos
        self.roomInfo.allHistInfo = allHistInfo
        if newResult then
            table.insert(allHistInfo.gameInfo, histInfo.gameInfo)
        end

        local tmp = {}
        for k, v in pairs(self.roomInfo) do
            tmp[k] = v
        end
        tmp.histInfo = nil
        tmp.allHistInfo = nil
        tmp.packDetails = nil
        allHistInfo.roomInfo = tmp
    end
end

---! 发送房卡场全部结果
class.SendRoomTableResultAll = function (self, code)
    if not self.roomInfo or not self.roomInfo.allHistInfo then
        return
    end

    local allHistInfo = self.roomInfo.allHistInfo
    if allHistInfo then
        local data = tabHelper.encode(allHistInfo) or ""
        self:sendMultiRoomData(code, protoTypes.CGGAME_PROTO_SUBTYPE_RESULT_ALL, data)
    end
end

---! 刷新过期时间
class.refreshTableExpire = function (self)
    if not self.roomInfo then
        return true
    end

    local maxDelay = protoTypes.CGGAME_ROOM_TABLE_EXPIRE_TIME
    if expired and self.expireTime < self.openTime + maxDelay then
        --- 超时

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
            self:groupAction(name, function (seatId, code)
                local u = self.room:getUserInfo(code)
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
                return true
            end
        elseif name == "playerUsers" then
            if liveNum > 0 then
                self.expireTime = self.expireTime + 10 * 60
                -- print("player extend time", self.tableId, self.expireTime)
                return true
            end
        end
    end
end

---! @brief destroy this table
class.TermTable = function (self, expired)
    if self:refreshTableExpire() then
        return
    end

    -- print("term room table: %d", self.tableId)
    debugHelper.cclog("term room table: %d", self.tableId)

    self.room:roomTablePayBill(self, true)

    self:GameOver()
    self:QuitRoomTableUsers()
    self.room:releaseRoomTable(self)
    return true
end

return class

