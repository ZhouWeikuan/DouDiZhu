local skynet    = skynet or require "skynet"
local crypt     = skynet.crypt or require "skynet.crypt"

local protoTypes = require "ProtoTypes"

local strHelper     = require "StringHelper"
local tabHelper     = require "TableHelper"
local packetHelper  = (require "PacketHelper").create("protos/CGGame.pb")

local NumSet        = require "NumSet"
local PriorityQueue = require "PriorityQueue"
local Queue         = require "Queue"
local SeatArray     = require "SeatArray"

---! create the class metatable
local class = {mt = {}}
class.mt.__index = class

---! create delegate object
class.create = function (delegate, authInfo, handler)
    local self = {}
    setmetatable(self, class.mt)

    self.delegate   = delegate

    self.authInfo   = authInfo

    self.selfUserCode   = nil
    self.selfSeatId     = nil

    self.allUsers    = {}

    self.handler = handler or self

    self.recv_list = Queue.create()
    self.delay_list = PriorityQueue.create(function (obj) return obj end, function (obj) return obj.timeout end, "[SENDIDX]")
    self.direct_list = Queue.create()

    return self
end

class.resetStageInfo  = function(self)
    local stageInfo = self.stageInfo or {}
    self.stageInfo  = stageInfo

    stageInfo.gameInfo      = {}
end

class.resetTableInfo  = function(self)
    self.tableInfo = {}

    self.tableInfo.standbyUsers = NumSet.create()
    self.tableInfo.playerUsers = SeatArray.create()
    self.tableInfo.playingUsers = SeatArray.create()

    self.tableInfo.gameInfo = {}
end

class.request_userinfo = function (self, code)
    if self.allUsers[code] then
        return
    end

    local list = {}
    list.FUserCode = code
    self.allUsers[code] = list

    local info = {
        FUserCode   = code,
    }
    local data = packetHelper:encodeMsg("CGGame.HallInfo", info)

    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                            protoTypes.CGGAME_PROTO_SUBTYPE_USERINFO, data)
    self:sendPacket(packet)

    packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                            protoTypes.CGGAME_PROTO_SUBTYPE_USERSTATUS, data)
    self:sendPacket(packet)
end

class.GetUserAtSeat = function (self, seatId)
    local code = self.tableInfo.playerUsers:getObjectAt(seatId)
    if code then
        local user = self:GetUserInfo(code)
        return user
    end
end

class.IsWaitingForMe = function (self, mask)
    if self.selfSeatId and (mask & (1 << self.selfSeatId)) ~= 0 then
        return true
    end
end

class.GetUserInfo = function (self, code)
    return self.allUsers[code]
end

------------------ send & recv ----------------------
class.recvPacket = function (self, packet)
    local obj = {}
    obj.timeout = skynet.time() + (self.handler == self and 0.1 or 0)
    obj.packet  = packet
    self.recv_list:pushBack(obj)
end

class.sendPacket = function (self, packet, delay)
    delay = delay or 0

    local obj = {}
    obj.timeout = skynet.time() + delay
    obj.packet  = packet

    if delay <= 0.00001 then
        self.direct_list:pushBack(obj)
        return
    end

    self.delay_list:addObject(obj)
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

    local user = self:GetUserInfo(self.selfUserCode)

    obj = self.direct_list:front()
    while obj do
        obj = self.direct_list:popFront()

        xpcall(function()
            self.delegate:command_handler(user, obj.packet)
        end,
        function(err)
            print(err)
            print(debug.traceback())
        end)

        obj = self.direct_list:front()
    end

    obj = self.delay_list:top()
    while obj and obj.timeout <= now do
        obj = self.delay_list:pop()

        xpcall(function()
            self.delegate:command_handler(user, obj.packet)
        end,
        function(err)
            print(err)
            print(debug.traceback())
        end)

        obj = self.delay_list:top()
    end
end

--------------------------- send packet options -------------------------
class.sendAuthOptions = function (self, authType)
    local info = self.authInfo
    if authType == protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME then
        local packet = nil
        if strHelper.isNullKey(info.playerId) or strHelper.isNullKey(info.password)
            or strHelper.isNullKey(info.challenge) or strHelper.isNullKey(info.secret) then
            -- print("ask for new auth")
            packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_AUTH, authType, nil)
        else
            info.authIndex = info.authIndex or 0
            -- print("try old auth", info.authIndex, info.playerId, "challenge:", crypt.hexencode(info.challenge), "secret:", crypt.hexencode(info.secret))

            local ret = {}
            ret.playerId    = info.playerId
            ret.authIndex   = math.floor(info.authIndex + 0.01)
            local data  = ret.playerId .. ";" .. ret.authIndex

            ret.password    = crypt.desencode(info.secret, info.password)
            ret.etoken      = crypt.desencode(info.secret, "token code")
            ret.hmac        = crypt.hmac64(crypt.hashkey(info.challenge .. data), info.secret)
            data   = packetHelper:encodeMsg("CGGame.AuthInfo", ret)

            packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_AUTH, authType, data)
        end
        self:sendPacket(packet)
    elseif authType == protoTypes.CGGAME_PROTO_SUBTYPE_CLIENTKEY then
        info.clientkey = crypt.randomkey()
        local ret = {}
        ret.clientkey = crypt.dhexchange(info.clientkey)
        -- print("send client key", crypt.hexencode(info.clientkey), "dhexchange", crypt.hexencode(ret.clientkey))
        local data = packetHelper:encodeMsg("CGGame.AuthInfo", ret)
        local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_AUTH, authType, data)
        self:sendPacket(packet)
    elseif authType == protoTypes.CGGAME_PROTO_SUBTYPE_CHALLENGE
        or authType == protoTypes.CGGAME_PROTO_SUBTYPE_SERVERKEY
        or authType == protoTypes.CGGAME_PROTO_SUBTYPE_RESUME_OK then
        -- print("Cannot send authType", authType, "from client")
    else
        print("Unknown authType ", authType, "from client")
    end
end

class.sendGiftOptions = function(self, giftName, getId)
    if not giftName or not getId then
        return
    end

    local giftInfo = {}
    giftInfo.giftName   = giftName
    giftInfo.dstSeatId  = getId
    giftInfo.srcSeatId  = self.selfSeatId

    local data      = packetHelper:encodeMsg("CGGame.GiftInfo", giftInfo)
    local packet    = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME,
                            protoTypes.CGGAME_PROTO_SUBTYPE_GIFT, data)
    self:sendPacket(packet)
end

class.sendMsgOptions = function(self, chatText, chatType)
    local user = self:GetUserInfo(self.selfUserCode)
    if not user then
        return
    end
    local chatInfo = {}
    chatInfo.gameId         = self.const.GAMEID
    chatInfo.speekerCode    = user.FUserCode
    chatInfo.speakerNick    = user.FNickName
    chatInfo.listenerId     = user.tableId or 0
    chatInfo.chatText       = chatText
    chatInfo.chatType       = chatType or 0

    local data      = packetHelper:encodeMsg("CGGame.ChatInfo", chatInfo)
    local packet    = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                            protoTypes.CGGAME_PROTO_SUBTYPE_CHAT, data)
    self:sendPacket(packet)
end

class.sendRoomOptions = function(self, subType, data, delay)
    local packet    = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_ROOM,
                            subType, data)
    self:sendPacket(packet, delay)
end

class.sendTableOptions = function(self, subType, tableId, seatId, delay)
    local info = {
        roomId = tableId,
        seatId = seatId,
    }
    local data      = packetHelper:encodeMsg("CGGame.SeatInfo", info)

    local packet    = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME,
                            subType, data)
    self:sendPacket(packet, delay)
end

class.sendSitDownOptions = function(self, tableId, seatId, delay)
    local info = {
        roomId = tableId,
        seatId = seatId,
    }
    local data      = packetHelper:encodeMsg("CGGame.SeatInfo", info)

    local packet    = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME,
                            protoTypes.CGGAME_PROTO_SUBTYPE_SITDOWN, data)
    self:sendPacket(packet, delay)
end

--------------------------- packet content handler ----------------------
class.handlePacket = function (self, packet)
    local args = packetHelper:decodeMsg("CGGame.ProtoInfo", packet)
    if args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_BASIC then
        self:handle_basic(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_AUTH then
        self:handle_auth(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_HALL then
        self:handle_hall(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_CLUB then
        self:handle_club(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_ROOM then
        self:handle_room(args)
    elseif args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_GAME then
        self:handle_game(args)
    else
        print("uknown main type", args.mainType, args.subType, args.msgBody)
    end
end

class.handle_basic = function (self, args)
	if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_HEARTBEAT then
        local info = packetHelper:decodeMsg("CGGame.HeartBeat", args.msgBody)
        if info.fromType == protoTypes.CGGAME_PROTO_HEARTBEAT_CLIENT then
            local now = skynet.time()
            info.timestamp = info.timestamp or now
            self.authInfo.speed_diff = (now - info.timestamp) * 0.5
            -- print("client speed diff is ", now, info.timestamp, self.authInfo.speed_diff)

        elseif info.fromType == protoTypes.CGGAME_PROTO_HEARTBEAT_SERVER then
            local packet = packetHelper:makeProtoData(args.mainType, args.subType, args.msgBody)
            self:sendPacket(packet)
            -- print("server heartbeat")

        else
            print("unknown heart beat fromType", info.fromType, " timestamp: ", info.timestamp)
        end

    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_AGENTLIST then
        local p = packetHelper:decodeMsg("CGGame.AgentList", args.msgBody)

        local list = {}
        for k, v in ipairs(p.agents or {}) do
            table.insert(list, string.format("%s:%d", v.addr, v.port))
        end
        local str = table.concat(list, ",")
        -- print("agent list is", str)

        local AuthUtils = require "AuthUtils"
        if AuthUtils then
            AuthUtils.setItem(AuthUtils.keyAgentList, str)
        end

    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_NOTICE then
        self:SysNotice(args.msgBody)

    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ACL then
        local aclInfo = packetHelper:decodeMsg("CGGame.AclInfo", args.msgBody)
        self.handler:handleACL(aclInfo)

    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_MULTIPLE then
        self.multiInfo = self.multiInfo or {}
        local info = packetHelper:decodeMsg("CGGame.MultiBody", args.msgBody)
        self.multiInfo[info.curIndex] = info.msgBody
        if info.curIndex == info.maxIndex then
            local data = table.concat(self.multiInfo, "")
            self.multiInfo = nil
            self:handlePacket(data)
        end

    else
        print("unhandled basic", args.mainType, args.subType, args.msgBody)
    end
end

class.SysNotice = function (self, data)
    local noteInfo = packetHelper:decodeMsg("CGGame.NoticeInfo", data)
    self.handler:recvNotice(noteInfo)
end

class.handle_auth = function (self, args)
    local info = packetHelper:decodeMsg("CGGame.AuthInfo", args.msgBody)
    if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_CHALLENGE then
        self.authInfo.authIndex = 0
        self.authInfo.challenge = info.challenge
        -- print("get challenge", crypt.hexencode(info.challenge))
        self:sendAuthOptions(protoTypes.CGGAME_PROTO_SUBTYPE_CLIENTKEY)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_SERVERKEY then
        -- print("get serverkey", crypt.hexencode(info.serverkey))
        self.authInfo.serverkey = info.serverkey
        self.authInfo.secret = crypt.dhsecret(info.serverkey, self.authInfo.clientkey)
        -- print("get secret", crypt.hexencode(self.authInfo.secret))
        self:sendAuthOptions(protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME)
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_RESUME_OK then
        local AuthUtils = require "AuthUtils"
        self.authInfo.authIndex = (self.authInfo.authIndex or 0) + 1
        AuthUtils.setItem(AuthUtils.keyAuthIndex, self.authInfo.authIndex)
        AuthUtils.setItem(AuthUtils.base64AuthChallenge, crypt.base64encode(self.authInfo.challenge))
        AuthUtils.setItem(AuthUtils.base64AuthSecret, crypt.base64encode(self.authInfo.secret))
        self.delegate.authOK = true
        if self.delegate.postAuthAction then
            self.delegate:postAuthAction()
        end
    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME
        or args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_CLIENTKEY then
        print("Client should not receive auth:", args.mainType, args.subType, args.msgBody)
    else
        print("Unknown auth", args.mainType, args.subType, args.msgBody)
    end
end

class.handle_hall = function (self, args)
    local typeId = args.subType
    if typeId == protoTypes.CGGAME_PROTO_SUBTYPE_HALLJOIN then
        self:handleUserJoined(args.msgBody)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_MYINFO then
        print("got my info")
        local info = packetHelper:decodeMsg("CGGame.UserInfo", args.msgBody)

    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_USERINFO then
        local info = packetHelper:decodeMsg("CGGame.UserInfo", args.msgBody)
        self:UpdateUserInfo(info, typeId)

    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_BONUS then
        skynet.error("get hall bonus")
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_QUIT then
        skynet.error("quit the server", args.mainType, args.subType, args.msgBody)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_CHAT then
        self:GameChat(args.msgBody)
    else
        skynet.error("unhandled hall", args.mainType, args.subType, args.msgBody)
    end
end

class.handle_club = function (self, args)
    skynet.error("unhandled club", args.mainType, args.subType, args.msgBody)
end

class.handle_room = function (self, args)
    local typeId = args.subType
    if typeId == protoTypes.CGGAME_PROTO_SUBTYPE_RELEASE then
        local exitInfo = packetHelper:decodeMsg("CGGame.ExitInfo", args.msgBody)
        exitInfo = tabHelper.cloneTable(exitInfo)

        if strHelper.isNullKey(exitInfo.ownerCode) then
            self.tableInfo.roomInfo.exitInfo = nil
        else
            self.tableInfo.roomInfo.exitInfo = exitInfo
        end

        if exitInfo.timeout and exitInfo.timeout > 0 then
            exitInfo.timeout = exitInfo.timeout + os.time()
        end

        self.handler:handleRoomRelease(exitInfo)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_RESULT then
        self.handler:handleRoomResult(args.msgBody, self.selfSeatId)
    else
        skynet.error("unhandled room", args.mainType, args.subType, args.msgBody)
    end
end

class.handle_broadcast = function (self, data)
    local seatInfo = packetHelper:decodeMsg("CGGame.SeatInfo", data)
    local eventId = seatInfo.roomId
    local seatId  = seatInfo.seatId
    local code    = seatInfo.userCode

    self:request_userinfo(code)

    local list = self.allUsers[code]
    list.FUserCode = code
    if eventId == protoTypes.CGGAME_MSG_EVENT_SITDOWN then
        local seatstatus = protoTypes.CGGAME_USER_STATUS_SITDOWN
        list.status = seatstatus

        self.tableInfo.playerUsers:setObjectAt(seatId, code)
        if code == self.selfUserCode then
            self.selfSeatId = seatId
        end
        self.handler:seatStatusChange(seatId, seatstatus)

    elseif eventId == protoTypes.CGGAME_MSG_EVENT_STANDBY then
        local seatstatus = protoTypes.CGGAME_USER_STATUS_STANDBY
        list.status = seatstatus
        if code == self.selfUserCode then
            self.selfSeatId = -1
        end
        self.handler:seatStatusChange(seatId, seatstatus)

    elseif eventId == protoTypes.CGGAME_MSG_EVENT_STANDUP then
        local seatstatus = protoTypes.CGGAME_USER_STATUS_STANDUP
        list.status = seatstatus
        self.handler:seatStatusChange(seatId, seatstatus)

    elseif eventId == protoTypes.CGGAME_MSG_EVENT_READY then
        local seatstatus = protoTypes.CGGAME_USER_STATUS_READY
        list.status = seatstatus
        self.handler:seatStatusChange(seatId, seatstatus)

    elseif eventId == protoTypes.CGGAME_MSG_EVENT_QUITTABLE then
        local seatstatus = protoTypes.CGGAME_USER_STATUS_IDLE
        local quitSeats = {}
        if code == self.selfUserCode then
            self.tableInfo.playerUsers:forEach(function (sid, cd)
                quitSeats[sid] = cd
            end)
        else
            quitSeats[seatId] = code
        end

        for sid, cd in pairs(quitSeats) do
            self.handler:seatStatusChange(sid, seatstatus)
            self.handler:quitTableHandler(cd, sid)
        end

        if code == self.selfUserCode then
            self.allUsers = {}
            self.allUsers[code] = list

            self.selfSeatId = nil
            self:resetTableInfo()
        else
            self.allUsers[code] = nil
            self.tableInfo.playerUsers:setObjectAt(seatId, nil)
        end

    elseif eventId == protoTypes.CGGAME_MSG_EVENT_BREAK then
        local seatstatus = protoTypes.CGGAME_USER_STATUS_OFFLINE
        list.status = seatstatus
        self.handler:seatStatusChange(seatId, seatstatus)

    elseif eventId == protoTypes.CGGAME_MSG_EVENT_CONTINUE then
        self.handler:seatStatusChange(seatId, protoTypes.CGGAME_USER_STATUS_SITDOWN)
        self.allUsers[code] = nil
        self:request_userinfo(code)

    else
        print("Unknown event ", eventId)
    end
end

---! 处理游戏相关协议
class.handle_game = function (self, args)
    local typeId = args.subType
    local data = args.msgBody
    if typeId == protoTypes.CGGAME_PROTO_SUBTYPE_GAMEJOIN then
        self:handleUserJoined(data)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_BROADCAST then
        self:handle_broadcast(data)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_WAITUSER then
        local wait = packetHelper:decodeMsg("CGGame.WaitUserInfo", data)
        self:GameWait(wait)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_GAMEINFO then
        self:GameInfo(data)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE then
        self:GameTrace(data)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_TABLEMAP then
        self:TableMap(data)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_GIFT then
        self:GameGift(data)
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_SITDOWN then
        print("sit down")
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_READY then
        print("ready")
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_CONFIRM then
        print("game confirm")
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_STANDBY then
        print("stand by")
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_STANDUP then
        print("stand up")
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_QUITTABLE then
        print("quit table")
    elseif typeId == protoTypes.CGGAME_PROTO_SUBTYPE_CHANGETABLE then
        print("change table")
    else
        print("Unkown game data ".. typeId)
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

class.TableMap = function (self, data)
    local map = packetHelper:decodeMsg("CGGame.TableMapInfo", data)

    local seatArr = map.field and self.tableInfo[map.field] or nil
    if not seatArr then
        return
    end

    seatArr:reset()

    for i = 1,#map.userCode do
        local u = map.userCode[i]
        local s = map.seatId[i]
        if seatArr.setObjectAt then
            seatArr:setObjectAt(s, u)
        else
            seatArr:addObject(u)
        end

        self:request_userinfo(u)
        if self.selfSeatId == nil and u == self.selfUserCode then
            self.selfSeatId = s
        end
    end

    if map.field == "playerUsers" then
        self.handler:TableMapHandler()
    elseif map.field == "standbyUsers" then
        self.handler:StandByHandler()
    else
        -- playing users
        self.tableInfo.playingUsers:forEach(function (sid, code)
            local list = self.allUsers[code]
            if list and list.status == protoTypes.CGGAME_USER_STATUS_READY then
                list.status = protoTypes.CGGAME_USER_STATUS_PLAYING
            end
        end)
    end

    self.isJumped = nil
end

class.GameGift = function (self, data)
    local rawGift = packetHelper:decodeMsg("CGGame.GiftInfo", data)
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

class.GameChat = function (self, data)
    local rawChat = packetHelper:decodeMsg("CGGame.ChatInfo", data)
    local chatInfo = {}

    for k, v in pairs(rawChat) do
        chatInfo[k] = v
    end
    chatInfo.listenerId = math.tointeger(chatInfo.listenerId) or 0

    self.handler:recvMsg(chatInfo)
end

class.UpdateUserInfo = function (self, info, typeId)
    local list = self.allUsers[info.FUserCode] or {}
    for k, v in pairs(info) do
        list[k] = v
    end
    list.FCounter = list.FCounter or 0
    list.FAvatarID = list.FAvatarID or 0
    self.allUsers[info.FUserCode] = list

    if typeId == protoTypes.CGGAME_PROTO_SUBTYPE_USERSTATUS then
        self.handler:UpdateUserStatus(list)
    end
end
---------------------------- handler's handle function ------------------
class.switchScene = function (self)
    if skynet.init then
        return
    end
    local app = cc.exports.appInstance
    local view = app:createView("LineScene")
    view:showWithScene()
end

class.handleUserJoined = function (self, data)
    local hallInfo = packetHelper:decodeMsg("CGGame.HallInfo", data)
    self.selfUserCode   = hallInfo.FUserCode
    self:request_userinfo(self.selfUserCode)

    print("got userCode", hallInfo.FUserCode)
    local AuthUtils = require "AuthUtils"
    if AuthUtils then
        AuthUtils.setItem(AuthUtils.keyUserCode, hallInfo.FUserCode)
    end
    self.authInfo.userCode = hallInfo.FUserCode
    if self.delegate.postJoinAction then
        self.delegate:postJoinAction()
    end
end

class.handleACL = function (self, aclInfo)
    print("ACL type:", aclInfo.aclType, "msg:", aclInfo.aclMsg)
    if aclInfo.aclType == protoTypes.CGGAME_ACL_STATUS_SERVER_BUSY then
        self:switchScene()
    end
end

---! 处理room信息的handler
class.handleRoomInfo = function (self, roomInfo, roomDetails)
end

class.handleRoomRelease = function (self, exitInfo)
end

class.handleRoomResult = function (self, msg, seatId)
end

class.recvGift = function (self, giftInfo)
end

class.recvMsg = function (self, chatInfo)
end

class.recvNotice = function(self, noteInfo)
    -- NoticeInfo
    print("Notice type:", noteInfo.noticeType, "text:", noteInfo.noticeText)
end

class.TableMapHandler = function (self)
end

class.StandByHandler = function (self)
end

class.gameInfoHandler = function (self)
end

class.gameTraceHandler = function (self)
end

class.quitTableHandler = function(self, code, seatId)
end

class.seatStatusChange = function (self, seatId, status)
end

class.RepaintPlayerInfo = function (self, seatId, newStatus)
end

class.UpdateUserStatus = function (self, user)
end


return class

