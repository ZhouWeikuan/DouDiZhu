local skynet = skynet or require "skynet"

local class = {mt = {}}
local BotPlayer = class
class.mt.__index = class

local protoTypes = require("ProtoTypes")
local const = require("Const_YunCheng")
local packetHelper  = (require "PacketHelper").create("protos/YunCheng.pb")
local tableHelper   = require "TableHelper"
local debugHelper   = require "DebugHelper"

local YunCheng     = YunCheng or require "yuncheng"

class.create = function (delegate, uid, handler)
    local self = {}
    setmetatable(self, class.mt)

    self.delegate   = delegate

    self.selfUserId = uid
    self.selfSeatId = nil

    self.tableInfo   = {}
    self.allUsers    = {}
    self:resetTableInfo()
    self.gameOverInfo = {}

    self.handler = handler or self

    local Queue = require "Queue"
    self.recv_list = Queue.create()

    self.send_list = Queue.create()

    return self
end

------------------ send & recv ----------------------
class.recvPacket = function (self, packet)
    local obj = {}
    obj.timeout = skynet.time() + (self.handler == self and 0.5 or 0)
    obj.packet  = packet
    self.recv_list:pushBack(obj)
end

class.sendPacket = function (self, packet, delay)
    delay = delay or 0

    local obj = {}
    obj.timeout = skynet.time() + delay
    obj.packet  = packet

    self.send_list:pushBack(obj)
end

class.sendGiftOptions = function(self, giftName, getId)
    if not giftName or not getId then
        return
    end

    local giftInfo = {}
    giftInfo.giftName   = giftName
    giftInfo.dstSeatId  = getId
    giftInfo.srcSeatId  = self.selfSeatId

    local data  = packetHelper:encodeMsg("CGGame.GiftInfo", giftInfo)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA,
                        protoTypes.CGGAME_PROTO_SUBTYPE_GIFT, data)
    self:sendPacket(packet, 0)
end

class.sendMsgOptions = function(self, chatText, chatType)
    local user = self:GetUserInfo(self.selfUserId)
    if not user then
        return
    end
    local chatInfo = {}
    chatInfo.gameId         = const.GAMEID
    chatInfo.speekerId      = user.FUniqueID
    chatInfo.speakerNick    = user.FNickName
    chatInfo.listenerId     = string.format("%d", user.tableId or 0)
    chatInfo.chatText       = chatText
    chatInfo.chatType       = chatType or 0

    local data  = packetHelper:encodeMsg("CGGame.ChatInfo", chatInfo)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA,
                        protoTypes.CGGAME_PROTO_SUBTYPE_CHAT, data)
    self:sendPacket(packet, 0)
end

class.sendRoomOptions = function(self, subType, body, delay)
    local msg = {}
    msg.mainType    = protoTypes.CGGAME_PROTO_TYPE_ROOMDATA
    msg.subType     = subType
    msg.msgBody     = body

    local packet = packetHelper:encodeMsg("CGGame.ProtoInfo", msg)
    self:sendPacket(packet, delay)
end

class.sendTableOptions = function(self, subTypeInfo, reqSeatId, delay)
    local msg = {}
    msg.mainType    = protoTypes.CGGAME_PROTO_TYPE_GAMEDATA
    msg.subType     = subTypeInfo
    if reqSeatId then
        msg.msgBody     = tostring(reqSeatId)
    end

    local packet = packetHelper:encodeMsg("CGGame.ProtoInfo", msg)
    self:sendPacket(packet, delay)
end

class.sendRoomSeatOptions = function(self, seatId, delay)
    local msg = {}
    msg.mainType    = protoTypes.CGGAME_PROTO_TYPE_GAMEDATA
    msg.subType     = protoTypes.CGGAME_PROTO_SUBTYPE_ROOMSEAT
    msg.msgBody     = tostring(seatId)

    local packet = packetHelper:encodeMsg("CGGame.ProtoInfo", msg)
    self:sendPacket(packet, delay)
end

-- callMult must be 1 or 2
class.sendLandlordOptions = function(self, callMult, delay)
    if callMult ~= 1 and callMult ~= 2 then
        return
    end
    local callInfo = {}
    callInfo.seatId     = self.selfSeatId
    callInfo.callMult   = callMult

    local raw  = packetHelper:encodeMsg("YunCheng.CallInfo", callInfo)
    local data = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_LANDLORD, self.selfSeatId, raw)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA,
    protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, data)
    self:sendPacket(packet, delay)
end

-- callMult must be 1 or 2
class.sendMultipleOptions = function(self, callMult, delay)
    if callMult ~= 1 and callMult ~= 2 then
        return
    end

    local gameInfo = self.tableInfo.gameInfo

    local callInfo = {}
    callInfo.seatId     = self.selfSeatId
    callInfo.callMult   = callMult

    local raw  = packetHelper:encodeMsg("YunCheng.CallInfo", callInfo)
    local data = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_MULTIPLE, self.selfSeatId, raw)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA,
        protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, data)
    self:sendPacket(packet, delay)
end

class.sendThrowOptions = function(self, cards, delay)
    local cardInfo = {}
    cardInfo.seatId = self.selfSeatId
    cardInfo.cards  = cards

    local raw  = packetHelper:encodeMsg("YunCheng.CardInfo", cardInfo)
    local data = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_THROW, self.selfSeatId, raw)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA,
        protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, data)
    self:sendPacket(packet, delay)
end

class.tickFrame = function (self, dt)
    local now = skynet.time()

    local obj = self.recv_list:front()
    while obj and obj.timeout <= now do
        obj = self.recv_list:popFront()

        xpcall(function()
            self:handlePacket(obj.packet)
        end,
        function(err)
            print(err)
            print(debug.traceback())
        end)

        obj = self.recv_list:front()
    end

    local user = self:GetUserInfo(self.selfUserId)

    obj = self.send_list:front()
    while obj and obj.timeout <= now do
        obj = self.send_list:popFront()

        self.delegate:command_handler(user, obj.packet)

        obj = self.send_list:front()
    end
end

------------------- packet content handler --------------
class.handlePacket = function (self, packet)
    local msg = packetHelper:decodeMsg("CGGame.ProtoInfo", packet)

    if msg.mainType == protoTypes.CGGAME_PROTO_TYPE_ACL then
        self.handler:handleACL(msg.subType)
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_HEARTBEAT then
        print ("heart beating")
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_LOGIN then
        print("login", msg.msgBody)
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_JOINGAME then
        print("join game success")
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_QUITGAME then
        print("quit game")
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_NOTICE then
        self:SysChat(msg)
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_BROADCAST then
        self:handle_broadcast(msg)
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_SETUSERINFO then
        print("set userInfo and get userInfo")
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_BUYCHIP then
        self.handler:handleBuyChip(msg)
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_ROOMTEXT then
        print("room text")
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_GAMELIST then
        print("game list")
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_LOGINLIST then
        print("login list ")
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_HALLLIST then
        print("hall list ")
        local list = packetHelper:decodeMsg("CGGame.InfoList", msg.msgBody)
        list = list.server_list
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_GAMEDATA then
        self:handle_gamedata(msg)
    elseif msg.mainType == protoTypes.CGGAME_PROTO_TYPE_ROOMDATA then
        self:handle_roomdata(msg)
    else
        print ("unknown proto data ", msg.mainType, msg.subType)
    end
end

class.handle_broadcast = function (self, msg)
    local eventId = msg.subType

    msg = packetHelper:decodeMsg("CGGame.ProtoInfo", msg.msgBody)
    local seatId  = msg.mainType
    local uid     = msg.msgBody

    self:request_userinfo(uid)

    if eventId == protoTypes.CGGAME_MSG_EVENT_SITDOWN then
        self.allUsers[uid].FUniqueID = uid
        local seatstatus = protoTypes.CGGAME_USER_STATUS_SITDOWN
        self.allUsers[uid].status = seatstatus

        self.tableInfo.playerUsers:setObjectAt(seatId, uid)
        if uid == self.selfUserId then
            self.selfSeatId = seatId
        end
        self.handler:seatStatusChange(seatId, seatstatus)
    elseif eventId == protoTypes.CGGAME_MSG_EVENT_STANDUP then
        local list = self.allUsers[uid]
        list.FUniqueID = uid
        local seatstatus = protoTypes.CGGAME_USER_STATUS_STANDUP
        list.status = seatstatus
        self.handler:seatStatusChange(seatId, seatstatus)
    elseif eventId == protoTypes.CGGAME_MSG_EVENT_READY then
        local list = self.allUsers[uid]
        list.FUniqueID = uid
        local seatstatus = protoTypes.CGGAME_USER_STATUS_READY
        list.status = seatstatus
        self.handler:seatStatusChange(seatId, seatstatus)
    elseif eventId == protoTypes.CGGAME_MSG_EVENT_QUITTABLE then
        local list = self.allUsers[uid]
        local seatstatus = protoTypes.CGGAME_USER_STATUS_IDLE
        local quitSeats = {}
        if uid == self.selfUserId then
            self.tableInfo.playerUsers:forEach(function (sid, uuid)
                quitSeats[sid] = uuid
            end)
        else
            quitSeats[seatId] = uid
        end

        for sid, uuid in pairs(quitSeats) do
            self.handler:seatStatusChange(sid, seatstatus)

            self.handler:quitTableHandler(uuid, sid)
        end

        if uid == self.selfUserId then
            self.allUsers = {}
            self.allUsers[uid] = list

            self.selfSeatId = nil
            self:resetTableInfo()
        else
            self.allUsers[uid] = nil
            self.tableInfo.playerUsers:setObjectAt(seatId, nil)
        end

    elseif eventId == protoTypes.CGGAME_MSG_EVENT_BREAK then
        local list = self.allUsers[uid]
        list.FUniqueID = uid
        local seatstatus = protoTypes.CGGAME_USER_STATUS_OFFLINE
        list.status = seatstatus
        self.handler:seatStatusChange(seatId, seatstatus)
    elseif eventId == protoTypes.CGGAME_MSG_EVENT_CONTINUE then
        self.handler:seatStatusChange(seatId, protoTypes.CGGAME_USER_STATUS_SITDOWN)
        self.allUsers[uid] = nil
        self:request_userinfo(uid)
    else
        print("Unknown event ", eventId)
    end
end

class.handle_gamedata = function(self,msg)
    local typeId = msg.subType
    if typeId == protoTypes.CGGAME_PROTO_SUBTYPE_SITDOWN then
        print("sit down")
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_READY then
        print("ready")
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_STANDUP then
        print("stand up")
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_QUITTABLE then
        print("quit table")
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_CHANGETABLE then
        self.handler:changeTableHandler()
        print("change table")
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_WAITUSER then
        local wait = packetHelper:decodeMsg("CGGame.WaitUserInfo", msg.msgBody)
        self:GameWait(wait)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_USERINFO then
        local info = packetHelper:decodeMsg("CGGame.UserInfo", msg.msgBody)
        self:UpdateUserInfo(info, typeId)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_USERSTATUS then
        local info = packetHelper:decodeMsg("YunCheng.UserStatus", msg.msgBody)
        self:UpdateUserInfo(info, typeId)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_GAMEINFO then
        self:GameInfo(msg)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE then
        self:GameTrace(msg)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_GAMEOVER then
        local gameoverinfo = packetHelper:decodeMsg("YunCheng.GameOver", msg.msgBody)
        self:UpdateGameOverData(gameoverinfo)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_TABLEMAP then
        self:TableMap(msg)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_CHAT then
        self:GameChat(msg)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_GIFT then
        self:GameGift(msg)
    else
        print("Unkown game data ".. typeId)
    end
end

class.handle_roomdata = function (self, msg)
    local hp = require "TableHelper"

    local typeId = msg.subType
    if typeId == protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_INFO then
        self.m_thisResult = ""

        local roomInfo = packetHelper:decodeMsg("CGGame.RoomInfo", msg.msgBody)
        roomInfo = hp.copyTable(roomInfo)

        local roomDetails = packetHelper:decodeMsg("YunCheng.RoomDetails", roomInfo.roomDetails)
        roomInfo.passCount = roomDetails.passCount

        self.tableInfo.roomInfo = roomInfo
        roomInfo.roomDetails = roomDetails
        self.handler:handleRoomInfo(roomInfo, roomDetails)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_RELEASE then
        local exitInfo = packetHelper:decodeMsg("CGGame.ExitInfo", msg.msgBody)
        exitInfo = hp.copyTable(exitInfo)

        if exitInfo.ownerId == "" then
            self.tableInfo.roomInfo.exitInfo = nil
        else
            self.tableInfo.roomInfo.exitInfo = exitInfo
        end

        if exitInfo.timeout and exitInfo.timeout > 0 then
            exitInfo.timeout = exitInfo.timeout + os.time()
        end

        self.handler:handleRoomRelease(exitInfo)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_RESULT then
        self.m_thisResult = (self.m_thisResult or "") .. msg.msgBody

        local hp = require "TableHelper"
        local curRoomResult = hp.decode(self.m_thisResult)
        if curRoomResult then
            self.handler:handleRoomResult(self.m_thisResult, self.selfSeatId)
            self.m_thisResult = ""
        end
    end
end

class.SysChat = function (self, msg)
    local rawChat = packetHelper:decodeMsg("CGGame.ChatInfo", msg.msgBody)
    local chatInfo = {}
    for k, v in pairs(rawChat) do
        chatInfo[k] = v
    end

    self.handler:recvNotice(chatInfo)
end

---------------------data handler-----------------------
class.GameGift = function (self, msg)
    local rawGift = packetHelper:decodeMsg("CGGame.GiftInfo", msg.msgBody)
    local giftInfo = {}
    for k, v in pairs(rawGift) do
        giftInfo[k] = v
    end
    giftInfo.coinCost = math.tointeger(giftInfo.coinCost) or 0

    local user = self:GetUserAtSeat(giftInfo.srcSeatId)
    if user then
        user.FCounter = (user.FCounter or 0) - giftInfo.coinCost
        self.handler:RepaintPlayerInfo(giftInfo.srcSeatId)
        self.handler:UpdateUserStatus(user)
    end

    self.handler:recvGift(giftInfo)
end

class.GameChat = function (self, msg)
    local rawChat = packetHelper:decodeMsg("CGGame.ChatInfo", msg.msgBody)
    local chatInfo = {}

    for k, v in pairs(rawChat) do
        chatInfo[k] = v
    end
    chatInfo.listenerId = math.tointeger(chatInfo.listenerId) or 0

    self.handler:recvMsg(chatInfo)
end

class.TableMap = function (self, msg)
    local map = packetHelper:decodeMsg("CGGame.TableMapInfo", msg.msgBody)

    local seatArr = map.field and self.tableInfo[map.field] or nil
    if not seatArr then
        return
    end

    seatArr:reset()

    for i=1,#map.uid do
        local u = map.uid[i]
        local s = map.seatId[i]
        seatArr:setObjectAt(s, u)

        self:request_userinfo(u)

        if self.selfSeatId == nil and u == self.selfUserId then
            self.selfSeatId = s
        end
    end

    if map.field == "playerUsers" then
        self.handler:TableMapHandler()
    else
        -- playing users
        self.tableInfo.playingUsers:forEach(function (sid, uid)
            local list = self.allUsers[uid]
            if list and list.status == protoTypes.CGGAME_USER_STATUS_READY then
                list.status = protoTypes.CGGAME_USER_STATUS_PLAYING
            end
        end)
    end

    self.isJumped = nil
end

class.GameInfo = function (self, msg)
    --- update game info
    local info = packetHelper:decodeMsg("YunCheng.GameInfo", msg.msgBody)
    packetHelper:extractMsg(info)

    local gameInfo = tableHelper.copyTable(info)
    self.tableInfo.gameInfo = gameInfo

    gameInfo.masterSeatId = gameInfo.masterSeatId or 0
    gameInfo.curSeatId  = gameInfo.curSeatId or 0
    gameInfo.bottomScore   = gameInfo.bottomScore or 0
    gameInfo.bombCount   = gameInfo.bombCount or 0
    gameInfo.bombMax    = gameInfo.bombMax or 0
    gameInfo.same3Bomb  = gameInfo.same3Bomb or 0
    gameInfo.histCards = gameInfo.histCards or {}
    gameInfo.bottomCards = gameInfo.bottomCards or {}
    gameInfo.showBottoms = gameInfo.showBottoms or nil
    if gameInfo.winCards then
        local sid = gameInfo.winCards.seatId or 0
        if sid == 0 then
            gameInfo.winCards = nil
        end
    end

    local userdata      = YunCheng.new(gameInfo.same3Bomb)
    gameInfo.userdata   = userdata

    for k, seatInfo in pairs(gameInfo.seatInfo) do
        seatInfo.uid = seatInfo.uid or 0
        seatInfo.seatId = seatInfo.seatId or 0
        seatInfo.multiple = seatInfo.multiple or 0
        seatInfo.handCards = seatInfo.handCards or {}
        seatInfo.throwCards = seatInfo.throwCards or {}
        seatInfo.scoreCard = seatInfo.scoreCard or 0

        userdata:setHandCards(seatInfo.seatId, seatInfo.handCards)
    end

    for _, cardInfo in ipairs(gameInfo.histCards) do
        userdata:addHistCards(cardInfo.cards)
    end

    self.handler:gameInfoHandler()

    self.m_thisResult = ""
end

class.GameTrace = function (self, msg)
    local info = packetHelper:decodeMsg("CGGame.ProtoInfo", msg.msgBody)
    if info.mainType == const.YUNCHENG_GAMETRACE_PICKUP then
        local cardInfo = packetHelper:decodeMsg("YunCheng.CardInfo", info.msgBody)
        local gameInfo = self.tableInfo.gameInfo
        local userdata = gameInfo.userdata
        userdata:setHandCards(cardInfo.seatId, cardInfo.cards)

        for sid=1, const.YUNCHENG_MAX_PLAYER_NUM do
            local seatInfo = gameInfo.seatInfo[sid]
            seatInfo.handCards = {}
            for k, card in pairs(cardInfo.cards) do
                if sid == cardInfo.seatId then
                    seatInfo.handCards[k] = card
                else
                    seatInfo.handCards[k] = const.YUNCHENG_CARD_BACKGROUND
                end
            end
            if sid == cardInfo.seatId then
                self:CalcPowerValue(seatInfo.handCards)
                self.handler:repaintCardsBySeatId(sid, seatInfo, 1, 1)
            else
                self.handler:repaintCardsBySeatId(sid, seatInfo)
            end
        end

    elseif info.mainType == const.YUNCHENG_GAMETRACE_LANDLORD then
        local callInfo = packetHelper:decodeMsg("YunCheng.CallInfo", info.msgBody)
        if callInfo.callMult > 1 then
            self.handler:callLandLord(callInfo.seatId, 1)
            local gameInfo = self.tableInfo.gameInfo
            gameInfo.masterSeatId = callInfo.seatId
            local seatInfo = gameInfo.seatInfo[gameInfo.masterSeatId]
            seatInfo.multiple = 2
            self.handler:ShowMultiple(callInfo.seatId, callInfo.callMult, true)
            self.handler:repaintMaster()
        else
            self.handler:callLandLord(callInfo.seatId, 2)
        end
        -- self.handler:repaintMaster()
    elseif info.mainType == const.YUNCHENG_GAMETRACE_REFRESH then
        local cardInfo = packetHelper:decodeMsg("YunCheng.CardInfo", info.msgBody)
        local gameInfo = self.tableInfo.gameInfo
        local seatInfo = gameInfo.seatInfo[cardInfo.seatId]
        seatInfo.handCards = tableHelper.copyArray(cardInfo.cards)

        local userdata = gameInfo.userdata
        userdata:setHandCards(cardInfo.seatId, seatInfo.handCards)

        self.handler:repaintCardsBySeatId(cardInfo.seatId, seatInfo)
        self.handler:SayLeftCard(cardInfo.seatId, seatInfo.handCards)

    elseif info.mainType == const.YUNCHENG_GAMETRACE_MULTIPLE then
        local callInfo = packetHelper:decodeMsg("YunCheng.CallInfo", info.msgBody)
        local gameInfo = self.tableInfo.gameInfo
        local seatInfo = gameInfo.seatInfo[callInfo.seatId]
        callInfo.callMult = callInfo.callMult ~= 2 and 1 or 2
        seatInfo.multiple = seatInfo.multiple * callInfo.callMult

        local nextId = const.deltaSeat(gameInfo.masterSeatId, 1)
        local prevId = const.deltaSeat(gameInfo.masterSeatId, -1)
        local nextInfo = gameInfo.seatInfo[nextId]
        local prevInfo = gameInfo.seatInfo[prevId]
        if callInfo.seatId == gameInfo.masterSeatId then
            if callInfo.callMult > 1 then
                nextInfo.multiple = nextInfo.multiple > 1 and nextInfo.multiple * 2 or nextInfo.multiple
                prevInfo.multiple = prevInfo.multiple > 1 and prevInfo.multiple * 2 or prevInfo.multiple

                self.handler:showTalkBubble(callInfo.seatId, "huiti")
            end
        else
            if callInfo.callMult > 1 then
                local partnerId = (callInfo.seatId == nextId) and prevId or nextId
                local partnerInfo = gameInfo.seatInfo[partnerId]
                if partnerInfo.multiple > 1 then
                    self.handler:showTalkBubble(callInfo.seatId, "genti")
                else
                    self.handler:showTalkBubble(callInfo.seatId, "ti")
                end
            end
        end

        local masterInfo = gameInfo.seatInfo[gameInfo.masterSeatId]
        masterInfo.multiple = nextInfo.multiple + prevInfo.multiple

        if callInfo.callMult > 1 then
            self.handler:ShowMultiple(callInfo.seatId, callInfo.callMult)
        else
            self.handler:ShowMultiple(callInfo.seatId, -1)
            self.handler:showTalkBubble(callInfo.seatId, "buti")
        end

    elseif info.mainType == const.YUNCHENG_GAMETRACE_THROW then
        local cardInfo = packetHelper:decodeMsg("YunCheng.CardInfo", info.msgBody)
        local gameInfo = self.tableInfo.gameInfo
        local userdata = gameInfo.userdata
        if #cardInfo.cards > 0 and cardInfo.cards[1] >= 0 then
            userdata:addHistCards(cardInfo.cards);
            self.handler:outCardsAction(cardInfo.cards, cardInfo.seatId)
            gameInfo.winCards = tableHelper.copyTable(cardInfo)
        else
            self.handler:cleanLastCards(cardInfo.seatId)
        end
    elseif info.mainType == const.YUNCHENG_GAMETRACE_SHOWBOTTOM then
        local cardInfo = packetHelper:decodeMsg("YunCheng.CardInfo", info.msgBody)
        local gameInfo = self.tableInfo.gameInfo
        gameInfo.showBottoms = true
        gameInfo.masterSeatId = cardInfo.seatId
        gameInfo.bottomCards = {}
        for k, v in pairs(cardInfo.cards) do
            gameInfo.bottomCards[k] = v
        end
        self.handler:repaintBottomCards(gameInfo.bottomCards)
        -- self.handler:repaintMaster()
    elseif info.mainType == const.YUNCHENG_GAMETRACE_BOMBMULT then
        local callInfo = packetHelper:decodeMsg("YunCheng.CallInfo", info.msgBody)
        local gameInfo = self.tableInfo.gameInfo
        gameInfo.bombCount = callInfo.callMult
        self.handler:repaintBottomMult(callInfo.seatId)
    else
        print("unknown game trace ", info.mainType)
    end
end

class.GameWait = function (self, waitInfo)
    self.tableInfo.status   = waitInfo.tableStatus
    self.tableInfo.waitMask = waitInfo.waitMask
    self.tableInfo.timeout  = waitInfo.timeout

    xpcall(function ()
        self.handler:GameWaitHandler(waitInfo.waitMask, waitInfo.tableStatus, waitInfo.timeout)
    end,
    function (err)
        print (err)
        print (debug.traceback())
    end)
end

class.UpdateGameOverData = function(self,info)
    info.resType = info.resType or 0
    local sites = {}
    local gameInfo = self.tableInfo.gameInfo
    for k, v in pairs(info.sites) do
        v.deltaChips = v.deltaChips or 0
        v.deltaScore = v.deltaScore or 0
        v.seatId = k or 0

        local seatInfo = gameInfo.seatInfo[k]
        seatInfo.handCards = v.handCards or {}

        sites[k] = v

        local user = self:GetUserAtSeat(k)
        if user and not self.tableInfo.roomInfo then
            user.FCounter = (user.FCounter or 0) + v.deltaChips
            user.FScore   = (user.FScore or 0) + v.deltaScore
            if v.deltaScore > 0 then
                user.FWins = (user.FWins or 0) + 1
            else
                user.FLoses = (user.FLoses or 0) + 1
            end
        end
    end
    self.gameOverInfo.sites = sites
    self.gameOverInfo.resType = info.resType
    if info.resType == 1 then
        gameInfo.bombCount = gameInfo.bombCount + 1
        self.handler:repaintBottomMult()
    end

    self.handler:GameOverHandler()
end

class.UpdateUserInfo = function (self, info, typeId)
    local list = self.allUsers[info.FUniqueID] or {}
    for k, v in pairs(info) do
        list[k] = v
    end
    list.FCounter = list.FCounter or 0
    list.FAvatarID = list.FAvatarID or 0
    self.allUsers[info.FUniqueID] = list

    if typeId == protoTypes.CGGAME_PROTO_SUBTYPE_USERSTATUS then
        self.handler:UpdateUserStatus(list)
    end

    local seatUsers = self.tableInfo.playerUsers
    seatUsers:forEach(function (seatId, uid)
        if uid == info.FUniqueID then
            local status = self.allUsers[uid].status
            self.handler:RepaintPlayerInfo(seatId, status)
            return true
        end
    end)
end

------------ lua proc ------------------
class.remove_all_long_func = function (self)
    local luaproc = luaproc or require "luaproc"

    self.wait_long_funcs = self.wait_long_funcs or {}
    local item = self.wait_long_funcs[1]
    while item do
        table.remove(self.wait_long_funcs, 1)
        luaproc.delchannel(item.name)

        item = self.wait_long_funcs[1]
    end
end

class.check_long_func = function (self)
    local luaproc = luaproc or require "luaproc"
    local argsHelper = require "TableHelper"

    self.wait_long_funcs = self.wait_long_funcs or {}
    local item = self.wait_long_funcs[1]
    if not item then
        return
    end

    local s, m = luaproc.receive(item.name, true)
    if s then
        local data = argsHelper.decode(s)
        coroutine.resume(item.co_func, data)

        s, m = luaproc.delchannel(item.name)
        if not s then
            print("delchannel failed", m)
        end

        table.remove(self.wait_long_funcs, 1)
    end
end

class.genFuncBody = function (self, light, funcName, name, data)
    -- copy from TableHelper
    -- android 里不支持 [[ ]] 这种字符串块
    local lines = {
    '   local table     = require "table" ',
    '   local string    = require "string" ',
    '   local class     = {} ',
    '',
    '   class.table_ser = function (tablevalue, tablekey, mark, assign) ',
    '       mark[tablevalue] = tablekey ',
    '       local container = {} ',
    '       for k, v in pairs(tablevalue) do ',
    '           local keystr = nil ',
    '           if type(k) == "string" then ',
    '               keystr = string.format("[\"%s\"]", k) ',
    '           elseif type(k) == "number" then ',
    '               keystr = string.format("[%d]", k) ',
    '           end ',
    '',
    '           local valuestr = nil ',
    '           if type(v) == "string" then ',
    '               valuestr = string.format("\"%s\"", tostring(v)) ',
    '           elseif type(v) == "number" or type(v) == "boolean" then ',
    '               valuestr = tostring(v) ',
    '           elseif type(v) == "table" then ',
    '               local fullkey = string.format("%s%s", tablekey, keystr) ',
    '               if mark[v] then table.insert(assign, string.format("%s=%s", fullkey, mark[v])) ',
    '               else valuestr = class.table_ser(v, fullkey, mark, assign) ',
    '               end ',
    '           end ',
    ' ',
    '           if keystr and valuestr then ',
    '               local keyvaluestr = string.format("%s=%s", keystr, valuestr) ',
    '               table.insert(container, keyvaluestr) ',
    '           end ',
    '       end ',
    '       return string.format("{%s}", table.concat(container, ",")) ',
    '   end ',
    ' ',
    '   class.encode = function (var) ',
    '       assert(type(var)=="table") ',
    '       local mark = {} ',
    '       local assign = {} ',
    '       local data = class.table_ser(var, "data", mark, assign) ',
    '       local data = string.format("local data=%s %s; return data", data, table.concat(assign, ";")) ',
    '       return data ',
    '   end ',
    ' ',
    '   class.decode = function (data) ',
    '       local func = load(data) ',
    '       return func() ',
    '   end ',
    }

    local funcBody = "\n"
    funcBody = funcBody .. 'local luaproc = require "luaproc"\n'
    funcBody = funcBody .. string.format('local name    = "%s"\n', name)
    funcBody = funcBody .. string.format('local data    = \'%s\' \n', data)
    funcBody = funcBody .. string.format('local data    = class.decode(data)\n')
    funcBody = funcBody .. string.format('local mv = %s(%d, table.unpack(data))\n', funcName, light)
    funcBody = funcBody .. string.format('local mv = class.encode(mv)\n')
    funcBody = funcBody .. string.format('local s, m = luaproc.send(name, mv)\n')
    funcBody = funcBody .. string.format('if not s then\n')
    funcBody = funcBody .. string.format('    print("send failed ", m)\n')
    funcBody = funcBody .. string.format('end\n')

    funcBody = table.concat(lines, "\n") .. funcBody

    return funcBody
end

--- Must be called in coroutine!!!!
class.run_long_func = function (self, funcName, ...)
    local gameInfo = self.tableInfo.gameInfo
    local userdata = gameInfo.userdata

    local res = {}
    if self.handler.is_offline or self.handler ~= self then
        -- we must async exec long run func for me and local AIs
        local light = userdata:getLight()

        local luaproc = luaproc or require "luaproc"

        if luaproc.getnumworkers() < 2 then
            luaproc.setnumworkers(2)
        end

        local co   = coroutine.running()
        local name = tostring(co)

        local s, m = luaproc.newchannel(name)
        if not s then
            print("luaproc new channel failed: ", m)
            return res
        end

        self.wait_long_funcs = self.wait_long_funcs or {}
        table.insert(self.wait_long_funcs, {
                name = name,
                co_func = co,
            })

        local args = table.pack(...)
        local argsHelper = require "TableHelper"
        local data = argsHelper.encode(args)

        local funcBody = self:genFuncBody(light, funcName, name, data)


        s, m = luaproc.newproc(funcBody)
        if not s then
            print("luaproc start failed", tostring(m))
            table.remove(self.wait_long_funcs)
            return res
        end

        res = coroutine.yield()
    else
        -- remote AIs, no need to async
        res = userdata[funcName](userdata, ...)
    end
    return res
end

----------------UI & AI handlers -----------------------
class.handleRoomInfo = function (self, roomInfo, roomDetails)
end

class.handleRoomRelease = function (self, exitInfo)
end

class.handleRoomResult = function (self, msg, seatId)
end

class.handleACL =  function (self, aclType)
    if aclType == const.YUNCHENG_ACL_STATUS_RESTART_NO_MASTER then
    elseif aclType == const.YUNCHENG_ACL_STATUS_NO_SELECT_CARDS then
    elseif aclType == const.YUNCHENG_ACL_STATUS_NOT_VALID_TYPE then
    elseif aclType == const.YUNCHENG_ACL_STATUS_NOT_SAME_TYPE then
    elseif aclType == const.YUNCHENG_ACL_STATUS_NOT_BIGGER then
    elseif aclType == const.YUNCHENG_ACL_STATUS_NO_BIG_CARDS then
    elseif aclType == const.YUNCHENG_ACL_STATUS_NO_YOUR_CARDS then
    elseif aclType == protoTypes.CGGAME_ACL_STATUS_COUNTER_LACK then
    elseif aclType == protoTypes.CGGAME_ACL_STATUS_INVALID_INFO then
    else
        print ("unknown acl type = ", aclType)
    end
end

class.GameOverHandler = function (self)
    if self.handler.is_offline then
        return
    end
    local cnt = self.tableInfo.playerUsers:getCount()
    if cnt >= 3 and math.random() < 0.20 then
        self:sendTableOptions(protoTypes.CGGAME_PROTO_SUBTYPE_CHANGETABLE, math.random(1, 2), math.random(2, 4))
        self.isJumped = true
    end
end

class.GameWaitHandler = function (self, mask, status, timeout)
    if self:IsWaitingForMe(mask) then
        local gameInfo = self.tableInfo.gameInfo

        if status == protoTypes.CGGAME_TABLE_STATUS_IDLE then
        elseif status == protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
            local cnt = self.tableInfo.playerUsers:getCount()
            if not self.handler.is_offline and cnt <= 1 and not self.isJumped then
                self:sendTableOptions(protoTypes.CGGAME_PROTO_SUBTYPE_CHANGETABLE, math.random(1, 2), math.random(2, 4))
                self.isJumped = true
            elseif not self.isJumped then
                local msg = {
                    mainType    = protoTypes.CGGAME_PROTO_TYPE_GAMEDATA,
                    subType     = protoTypes.CGGAME_PROTO_SUBTYPE_READY,
                    msgBody     = nil
                }

                local packet = packetHelper:encodeMsg("CGGame.ProtoInfo", msg)
                self:sendPacket(packet, math.random(1, 3))
            end
        elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_PICKUP then
            local seatInfo = gameInfo.seatInfo[self.selfSeatId]
            local userdata = gameInfo.userdata

        elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_LANDLORD then
            local seatInfo = gameInfo.seatInfo[self.selfSeatId]
            local userdata = gameInfo.userdata

            local winPoss = userdata:getWinPossible(seatInfo.handCards)
            local mult = 1
            if userdata:bigEnough(seatInfo.handCards) or
                (gameInfo.masterSeatId == 0 and winPoss >= 0.3)
                or (gameInfo.masterSeatId ~= 0 and winPoss >= 0.6) then
                mult = 2
            end
            self:sendLandlordOptions(mult, 1)
        elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_MULTIPLE then
            local seatInfo = gameInfo.seatInfo[self.selfSeatId]
            local userdata = gameInfo.userdata

            local winPoss = userdata:getWinPossible(seatInfo.handCards)
            if winPoss < 0.6 then
                self:sendMultipleOptions(1)
            else
                self:sendMultipleOptions(2)
            end
        elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_THROW then
            self:AutoThrow()

        elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_GAMEOVER then
            print ("bot wait for me to game over")
        elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_NEWGAME then
            print ("bot wait for me to new game")
        else
            print ("bot wait for me to do evil".. status)
        end
    end
end

class.AutoThrow = function (self)
    local co = coroutine.create(function()
        self:do_AutoThrow()
        end)
    coroutine.resume(co)
end

class.do_AutoThrow = function (self)
    local gameInfo = self.tableInfo.gameInfo
    if gameInfo.winCards and gameInfo.winCards.seatId == self.selfSeatId then
        gameInfo.winCards = nil
    end

    local cards = nil
    local seatInfo = gameInfo.seatInfo[self.selfSeatId]
    local userdata = gameInfo.userdata
    userdata:updateSeats(gameInfo.masterSeatId, self.selfSeatId)

    local winCards  = gameInfo.winCards
    if not winCards then
        cards = self:run_long_func("robotFirstPlay")
        if #cards <= 0 then
            print("no cards for direct play?")
        end
    else
        cards = self:run_long_func("robotFollowCards", winCards.seatId, winCards.cards)
    end

    if #cards > 0 then
        local ok, selected = const.getSelCards(seatInfo.handCards, const.getCardItSelf, cards, const.getCardItSelf)
        if not ok then
            print("cards cannot be selected")
            debugHelper.printDeepTable(seatInfo.handCards)
            print("cards to ----- ")
            debugHelper.printDeepTable(cards)
        end
        cards = selected
    else
        cards[1] = -1
    end

    self:sendThrowOptions(cards, 0.8)
end

class.CalcPowerValue = function (self, cards)
    local co = coroutine.create(function()
        self:run_long_func("calcPowerValue", cards)
    end)
    coroutine.resume(co)
end

class.repaintMaster = function (self)
end

class.recvGift = function (self, giftInfo)
end

class.recvMsg = function (self, chatInfo)
end

class.recvNotice = function(self, chatInfo)
end

class.TableMapHandler = function (self)
end

class.gameInfoHandler = function (self)
end

class.gameTraceHandler = function (self)
end

class.changeTableHandler = function(self)
end

class.quitTableHandler = function(self, uid, seatId)
end

class.seatStatusChange = function (self, seatId, status)
end

class.RepaintPlayerInfo = function (self, seatId, newStatus)
end

class.UpdateUserStatus = function (self, user)
end

class.handleBuyChip = function (self, msg)
end

class.repaintCardsBySeatId = function(self, seatId, seatInfo)
end

class.repaintBottomMult = function(self)
end

class.outCardsAction = function(self, cards, seatId)
end

class.cleanLastCards = function(self, seatId)
end

class.repaintBottomCards = function(self, bottomCards)
end

class.callLandLord = function(self, seatId)
end

class.ShowMultiple = function(self, seatId, callMult)
end

class.showTalkBubble = function(self, seatId, strType)
end

class.SayLeftCard = function(self, seatId, cards)
end

----------------------help handlers-------------------------------------
class.resetTableInfo  = function(self)
    self.tableInfo = {}

    local SeatArray = require "SeatArray"
    self.tableInfo.playerUsers = SeatArray:create()
    self.tableInfo.playingUsers = SeatArray:create()

    self.tableInfo.gameInfo = {}
end

class.request_userinfo = function (self, uid)
    if self.allUsers[uid] then
        return
    end
    local list = {}
    list.FUniqueID = uid

    self.allUsers[uid] = list
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA,
                            protoTypes.CGGAME_PROTO_SUBTYPE_USERINFO, uid)
    self:sendPacket(packet)

    packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_GAMEDATA,
                            protoTypes.CGGAME_PROTO_SUBTYPE_USERSTATUS, uid)
    self:sendPacket(packet)
end

class.GetUserAtSeat = function (self, seatId)
    local uid = self.tableInfo.playerUsers:getObjectAt(seatId)
    if uid then
        return self:GetUserInfo(uid)
    end
end

class.IsWaitingForMe = function (self, mask)
    if self.selfSeatId and  (mask & (1 << self.selfSeatId)) ~= 0 then
        return true
    end
end

class.GetUserInfo = function (self, uid)
    return self.allUsers[uid]
end

return class
