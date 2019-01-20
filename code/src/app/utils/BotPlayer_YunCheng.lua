local skynet        = skynet or require "skynet"

local protoTypes    = require "ProtoTypes"
local const         = require "Const_YunCheng"

local packetHelper  = (require "PacketHelper").create("protos/YunCheng.pb")
local tabHelper     = require "TableHelper"
local debugHelper   = require "DebugHelper"

local YunCheng     = YunCheng or require "yuncheng"

local baseClass = require "BotPlayer_Base"

---! class define
local class = {mt = {}}
class.mt.__index = class

setmetatable(class, baseClass.mt)

---! create object
class.create = function (delegate, authInfo, handler)
    local self = baseClass.create(delegate, authInfo, handler)
    setmetatable(self, class.mt)

    self:resetTableInfo()

    self.const = const
    self.gameOverInfo = {}

    return self
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
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME,
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
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME,
                        protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, data)
    self:sendPacket(packet, delay)
end

---! send throw cards
class.sendThrowOptions = function(self, cards, delay)
    local cardInfo = {}
    cardInfo.seatId = self.selfSeatId
    cardInfo.cards  = cards

    local raw  = packetHelper:encodeMsg("YunCheng.CardInfo", cardInfo)
    local data = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_THROW, self.selfSeatId, raw)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME,
                        protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, data)
    self:sendPacket(packet, delay)
end

------------------------------------------------------------------------------------------

class.handle_hall = function (self, args)
    if args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_MYSTATUS then
        local info = packetHelper:decodeMsg("YunCheng.UserStatus", args.msgBody)

    elseif args.subType == protoTypes.CGGAME_PROTO_SUBTYPE_USERSTATUS then
        local info = packetHelper:decodeMsg("YunCheng.UserStatus", args.msgBody)
        self:UpdateUserInfo(info, args.subType)

    else
        baseClass.handle_hall(self, args)
    end
end

class.handle_room = function (self, args)
    local typeId = args.subType
    if typeId == protoTypes.CGGAME_PROTO_SUBTYPE_INFO then
        local roomInfo = packetHelper:decodeMsg("CGGame.RoomInfo", args.msgBody)
        roomInfo = tabHelper.cloneTable(roomInfo)

        local roomDetails = packetHelper:decodeMsg("YunCheng.RoomDetails", roomInfo.roomDetails)
        roomInfo.passCount = roomDetails.passCount

        self.tableInfo.roomInfo = roomInfo
        roomInfo.roomDetails = roomDetails
        self.handler:handleRoomInfo(roomInfo, roomDetails)
    else
        baseClass.handle_room(self, args)
    end
end


---! 处理游戏协议
class.handle_game = function (self, args)
    local typeId = args.subType
    if typeId == protoTypes.CGGAME_PROTO_SUBTYPE_GAMEOVER then
        local gameoverinfo = packetHelper:decodeMsg("YunCheng.GameOver", args.msgBody)
        self:UpdateGameOverData(gameoverinfo)
    else
        baseClass.handle_game(self, args)
    end
end

class.UpdateUserInfo = function (self, info, typeId)
    baseClass.UpdateUserInfo(self, info, typeId)

    local seatUsers = self.tableInfo.playerUsers
    seatUsers:forEach(function (seatId, code)
        if code == info.FUserCode then
            local status = self.allUsers[code].status
            self.handler:RepaintPlayerInfo(seatId, status)
            return true
        end
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
        if user then
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

class.GameInfo = function (self, data)
    --- update game info
    local info = packetHelper:decodeMsg("YunCheng.GameInfo", data)
    packetHelper:extractMsg(info)

    local gameInfo = tabHelper.cloneTable(info)
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
        seatInfo.userCode = seatInfo.userCode or 0
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

class.GameTrace = function (self, data)
    local info = packetHelper:decodeMsg("CGGame.ProtoInfo", data)
    local gameInfo = self.tableInfo.gameInfo
    local userdata = gameInfo.userdata
    if info.mainType == const.YUNCHENG_GAMETRACE_PICKUP then
        local cardInfo = packetHelper:decodeMsg("YunCheng.CardInfo", info.msgBody)
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
        local seatInfo = gameInfo.seatInfo[cardInfo.seatId]
        seatInfo.handCards = tabHelper.cloneArray(cardInfo.cards)
        userdata:setHandCards(cardInfo.seatId, seatInfo.handCards)

        self.handler:repaintCardsBySeatId(cardInfo.seatId, seatInfo)
        self.handler:SayLeftCard(cardInfo.seatId, seatInfo.handCards)

    elseif info.mainType == const.YUNCHENG_GAMETRACE_MULTIPLE then
        local callInfo = packetHelper:decodeMsg("YunCheng.CallInfo", info.msgBody)
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
        if #cardInfo.cards > 0 and cardInfo.cards[1] >= 0 then
            userdata:addHistCards(cardInfo.cards);
            self.handler:outCardsAction(cardInfo.cards, cardInfo.seatId)
            gameInfo.winCards = tabHelper.cloneTable(cardInfo)
        else
            self.handler:cleanLastCards(cardInfo.seatId)
        end

    elseif info.mainType == const.YUNCHENG_GAMETRACE_SHOWBOTTOM then
        local cardInfo = packetHelper:decodeMsg("YunCheng.CardInfo", info.msgBody)
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
        gameInfo.bombCount = callInfo.callMult
        self.handler:repaintBottomMult(callInfo.seatId)
    else
        print("unknown game trace ", info.mainType)
    end
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
class.handleACL =  function (self, aclInfo)
    if aclInfo.aclType == const.YUNCHENG_ACL_STATUS_RESTART_NO_MASTER then
    elseif aclInfo.aclType == const.YUNCHENG_ACL_STATUS_NO_SELECT_CARDS then
    elseif aclInfo.aclType == const.YUNCHENG_ACL_STATUS_NOT_VALID_TYPE then
    elseif aclInfo.aclType == const.YUNCHENG_ACL_STATUS_NOT_SAME_TYPE then
    elseif aclInfo.aclType == const.YUNCHENG_ACL_STATUS_NOT_BIGGER then
    elseif aclInfo.aclType == const.YUNCHENG_ACL_STATUS_NO_BIG_CARDS then
    elseif aclInfo.aclType == const.YUNCHENG_ACL_STATUS_NO_YOUR_CARDS then
    else
        baseClass.handleACL(self, aclInfo)
    end
end

class.GameOverHandler = function (self)
    if self.handler.is_offline then
        return
    end
    local cnt = self.tableInfo.playerUsers:getCount()
    if cnt >= 3 and math.random() < 0.20 then
        self:sendTableOptions(protoTypes.CGGAME_PROTO_SUBTYPE_CHANGETABLE, nil, nil, math.random(2, 4))
        self.isJumped = true
    end
end

class.GameWaitHandler = function (self, mask, status, timeout)
    if not self:IsWaitingForMe(mask) then
        return
    end

    local gameInfo = self.tableInfo.gameInfo

    if status == protoTypes.CGGAME_TABLE_STATUS_IDLE then
    elseif status == protoTypes.CGGAME_TABLE_STATUS_WAITREADY then
        local cnt = self.tableInfo.playerUsers:getCount()
        if not self.handler.is_offline and cnt <= 1 and not self.isJumped then
            self:sendTableOptions(protoTypes.CGGAME_PROTO_SUBTYPE_CHANGETABLE, nil, nil, math.random(2, 4))
            self.isJumped = true
        elseif not self.isJumped then
            local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_GAME,
                                protoTypes.CGGAME_PROTO_SUBTYPE_READY, nil)
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
        print ("bot wait for me to do evil", status)
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



return class

