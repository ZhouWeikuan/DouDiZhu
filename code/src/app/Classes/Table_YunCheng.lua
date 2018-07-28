local const         = require "Const_YunCheng"
local tableHelper   = require "TableHelper"

local protoTypes    = require "ProtoTypes"
local YunCheng        = YunCheng or require "yuncheng"

local packetHelper  = (require "PacketHelper").create("protos/YunCheng.pb")

local baseClass     = require "GameTable"

local class = {mt = {}}
local Table_YunCheng = class
class.mt.__index = class

setmetatable(class, baseClass.mt)

local
_____GameTable_____ = function () end

class.create = function (...)
    local self = baseClass.create(...)
    setmetatable(self, class.mt)

    self.gameInfo = {}

    return self
end

class.UserStatus_ProtoName = "YunCheng.UserStatus"
class.UserStatus_Fields = {
    "FUniqueID", "FUserCode", "FAgentCode", "FCounter",
    "FScore", "FWins", "FLoses", "FDraws",
    "FLastGameTime", "FSaveDate", "FSaveCount",
}
class.UpdateUserStatus = function (self, user, uid, deltaScore)
    if user then
        user.FScore = (user.FScore or 0) + deltaScore
        if deltaScore > 0 then
            user.FWins = (user.FWins or 0) + 1
        else
            user.FLoses = (user.FLoses or 0) + 1
        end
    end

    if not snax then
        return
    end

    local db = snax.uniqueservice("DBService")
    user = db.req.loadDB(uid)
    if user then
        user.FScore = (user.FScore or 0) + deltaScore
        if deltaScore > 0 then
            user.FWins = (user.FWins or 0) + 1
        else
            user.FLoses = (user.FLoses or 0) + 1
        end
    end

    local dbHelper = require "DBHelper"
    db.req.updateDB(user.FUniqueID, 'FLastGameTime', dbHelper.timestamp())
    db.req.updateDB(user.FUniqueID, "FScore", user.FScore)

    if deltaScore > 0 then
        db.req.updateDB(user.FUniqueID, "FWins", user.FWins)
    else
        db.req.updateDB(user.FUniqueID, "FLoses", user.FLoses)
    end
end

class.getGiftPrice = function (self, giftName)
    if not giftName then
        return
    end
    return const.kGiftItems[giftName]
end

class.notifyVictory = function (self, user, one)
    if not snax then
        return
    end

    local feed = snax.uniqueservice("FeedService")
    if not feed then
        skynet.error("failed to get unique service FeedService")
        return
    end

    local name = user and user.FNickName or ""
    local text = nil
    local score = math.abs(one.deltaScore) or 0
    if one.deltaScore > 0 then
        text = string.format("恭喜大善人 %s 打跑了两个泥腿子 获得 %d 分", name, score)
    else
        text = string.format("恭喜翻身农民打倒恶霸地主 %s, 瓜分了他 %d 分", name, score)
    end

    local chatInfo = {
        gameId      = -1,
        speekerId   = "-1",
        speakerNick = "喜讯",
        chatText    = text,
    }

    feed.post.SystemNotice(chatInfo)
end

class.checkCounter = function (self, userInfo)
    return true
end

class.canPlayerSitdown = function (self, userInfo)
    if not self:checkCounter(userInfo) then
        return
    end
    return baseClass.canPlayerSitdown(self, userInfo)
end

class.canPlayerStandUp = function (self, userInfo)
    if self.status <= const.YUNCHENG_TABLE_STATUS_WAIT_NEWGAME then
        return true
    end

    return baseClass.canPlayerStandUp(self, userInfo)
end

class.canPlayerReady = function (self, userInfo)
    if not self:checkCounter(userInfo) then
        return
    end
    return baseClass.canPlayerReady(self, userInfo)
end

class.SendGameInfo = function (self, seatId)
    local info = self.gameInfo

    local gameInfo = {}
    gameInfo.masterSeatId       = info.masterSeatId
    gameInfo.curSeatId          = info.curSeatId
    gameInfo.bottomScore        = info.bottomScore
    gameInfo.bombCount          = info.bombCount
    gameInfo.bombMax            = info.bombMax
    gameInfo.same3Bomb          = info.same3Bomb
    gameInfo.bottomCards        = info.bottomCards
    gameInfo.showBottoms        = info.showBottoms

    gameInfo.histCards          = info.histCards
    gameInfo.winCards           = info.winCards
    gameInfo.seatInfo           = {}
    for k, seatInfo in pairs(info.seatInfo) do
        local one = {}
        one.uid     = seatInfo.uid
        one.seatId  = seatInfo.seatId
        one.multiple = seatInfo.multiple
        one.throwCards  = seatInfo.throwCards
        one.scoreCard   = seatInfo.scoreCard

        one.handCards = {}
        for i, card in ipairs(seatInfo.handCards) do
            if seatInfo.seatId == seatId then
                one.handCards[i] = card
            else
                one.handCards[i] = const.YUNCHENG_CARD_BACKGROUND
            end
        end
        gameInfo.seatInfo[k] = one
    end

    local uid = self.playerUsers:getObjectAt(seatId)
    local packet = packetHelper:encodeMsg("YunCheng.GameInfo", gameInfo)
    self:SendGameDataToUser(uid, protoTypes.CGGAME_PROTO_SUBTYPE_GAMEINFO, packet)
end

class.gameStart = function (self)
    local info  = self.gameInfo or {}
    self.gameInfo       = info

    info.timeoutList    = {}
    info.bottomCards = {}

    info.masterSeatId   = 0
    info.curSeatId      = 0

    info.same3Bomb      = 0

    info.bombMax        = 0
    info.bottomScore    = 1

    info.bombCount      = 0
    info.bottomCards    = nil
    info.showBottoms    = nil

    info.winCards       = nil
    info.seatInfo       = {}
    info.histCards      = {}

    info.userdata    = YunCheng.new(info.same3Bomb);

    -- print (string.format("tableId %d", self.tableId))
    self:groupAction("playingUsers", function (sid, uid)
        -- print (string.format("seatId =  %d, uid = %s", sid, uid))

        local seatInfo = {}
        seatInfo.seatId = sid
        seatInfo.uid    = uid

        seatInfo.multiple = 1

        seatInfo.handCards  = {}
        seatInfo.throwCards = {}

        seatInfo.canCall    = true
        seatInfo.outTimes   = 0
        seatInfo.scoreCard  = 0

        info.seatInfo[sid] = seatInfo
    end)

    self:SendCurrentGameToTable()

    self:dispatchCards()
end

class.yunchengGameOver = function (self)
    local gameInfo = self.gameInfo
    local userdata = gameInfo.userdata

    local gameOver = {
        sites = {{},{},{}},
        resType = 0,
    }
    local otherTimes = 0
    self:groupAction("playingUsers", function (seatId, uid)
        local seatInfo = gameInfo.seatInfo[seatId]
        if seatId ~= gameInfo.curSeatId then
            otherTimes = otherTimes + seatInfo.outTimes
        end
    end)
    if (gameInfo.masterSeatId == gameInfo.curSeatId and otherTimes == 0)
        or (gameInfo.masterSeatId ~= gameInfo.curSeatId and otherTimes == 1) then
        gameOver.resType = 1
        gameInfo.bombCount = gameInfo.bombCount + 1
    end

    local score = gameInfo.bottomScore * (1 << gameInfo.bombCount)
    local masterUser = nil
    local scores = {}
    self:groupAction("playingUsers", function (seatId, uid)
        local seatInfo = gameInfo.seatInfo[seatId]

        local one = gameOver.sites[seatId]
        one.seatId = seatId
        if gameInfo.masterSeatId == gameInfo.curSeatId then
            if seatId == gameInfo.masterSeatId then
                one.deltaScore = score * seatInfo.multiple
            else
                one.deltaScore = -score * seatInfo.multiple
            end
        else -- 地主失败
            if seatId == gameInfo.masterSeatId then
                one.deltaScore = -score * seatInfo.multiple
            else
                one.deltaScore = score * seatInfo.multiple
            end
        end

        one.handCards = seatInfo.handCards

        local userInfo = self.room:getUserInfo(uid)
        if one then
            self:UpdateUserStatus(userInfo, uid, one.deltaScore or 0)
        end

        if seatId == gameInfo.masterSeatId and math.abs(one.deltaScore) >= 10 then
            masterUser = userInfo
            self:notifyVictory(masterUser, one)
        end
    end)

    local packet = packetHelper:encodeMsg("YunCheng.GameOver", gameOver)
    self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_GAMEOVER, packet)

    baseClass.GameOver(self)

    self:SendGameWait(0, const.YUNCHENG_TABLE_STATUS_WAIT_NEWGAME, const.YUNCHENG_TIMEOUT_WAIT_NEWGAME)
end

class.handleGameData = function (self, userInfo, data)
    if not userInfo.seatId then
        return
    end
    if data.subType == protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE then
        local traceInfo = packetHelper:decodeMsg("CGGame.ProtoInfo", data.msgBody)
        self:yunchengGameTrace(userInfo.seatId, traceInfo)
    else
        baseClass.handleGameData(self, userInfo, data)
    end
end

class.timeoutHandler = function (self)
    if not self:yunchengTimeout() then
        baseClass.timeoutHandler(self)
    end
end

class.yunchengTimeout = function (self)
    local info = self.gameInfo
    if self.status == const.YUNCHENG_TABLE_STATUS_WAIT_PICKUP then
        self:landlordStart()

    elseif self.status == const.YUNCHENG_TABLE_STATUS_WAIT_THROW then
        if self:yunchengCheckFlower() then
        else
            info.timeoutList[info.curSeatId or 0] = true
            self:yunchengAutoThrow()
        end

    elseif self.status == const.YUNCHENG_TABLE_STATUS_WAIT_MULTIPLE then
        self:groupAction("playingUsers", function (seatId, uid)
            if self:IsWaitSeat(seatId) then
                info.timeoutList[seatId] = true
            end
        end)
        self.waitMask = 0
        self:yunchengRequestMultiple()

    elseif self.status == const.YUNCHENG_TABLE_STATUS_WAIT_LANDLORD then
        info.timeoutList[info.curSeatId or 0] = true
        local callInfo = {}
        callInfo.seatId = info.curSeatId
        callInfo.callMult = 1
        self:yunchengRequestLandlord(callInfo)

    elseif self.status == const.YUNCHENG_TABLE_STATUS_WAIT_GAMEOVER then
        self:yunchengGameOver()

    elseif self.status == const.YUNCHENG_TABLE_STATUS_WAIT_NEWGAME then
        self.status = protoTypes.CGGAME_TABLE_STATUS_WAITSTART
        baseClass.AnyPlayer_GameOverWaitStart(self, protoTypes.CGGAME_TIMEOUT_WAITSTART)

    else
        return nil
    end

    return true
end


---! GAME_DATA, GAME_TRACE, TRACE_BET, seatId, msgBody
---! traceInfo is TRACE_BET, seatId, msgBody
class.yunchengGameTrace = function (self, seatId, traceInfo)
    local info = self.gameInfo
    if self.status <= protoTypes.CGGAME_TABLE_STATUS_WAITSTART or not self:IsWaitSeat(seatId) then
        return
    end

    if traceInfo.mainType == const.YUNCHENG_GAMETRACE_THROW then
        local cardInfo = packetHelper:decodeMsg("YunCheng.CardInfo", traceInfo.msgBody)
        self:yunchengRequestThrow(cardInfo)

    elseif traceInfo.mainType == const.YUNCHENG_GAMETRACE_MULTIPLE then
        local callInfo = packetHelper:decodeMsg("YunCheng.CallInfo", traceInfo.msgBody)
        self:yunchengRequestMultiple(callInfo)

    elseif traceInfo.mainType == const.YUNCHENG_GAMETRACE_LANDLORD then
        local callInfo = packetHelper:decodeMsg("YunCheng.CallInfo", traceInfo.msgBody)
        self:yunchengRequestLandlord(callInfo)

    else
        local debugHelper = require "DebugHelper"
        debugHelper.cclog("unkown yuncheng trace type: %d", traceInfo.mainType)
    end

    info.timeoutList[seatId] = nil
end

local
_____Table_YunCheng_____ = function () end

class.dispatchCards = function (self)
    local playRule = 0

    local tableCards = {}
    local maxCardValue = (playRule >= 1) and 55 or 54
    local index = 0
    for i=1,maxCardValue do
        index = index + 1
        tableCards[index] = i
    end

    maxCardValue = #tableCards
    for i=1,maxCardValue do
        local t = math.random(1, maxCardValue)
        tableCards[i], tableCards[t] = tableCards[t], tableCards[i]
    end

    local info = self.gameInfo
    local userdata  = info.userdata
    local s = index
    local playerCardNum = const.YUNCHENG_PLAYER_CARD_NUM
    self:groupAction("playingUsers", function (sid, uid)
        local cards = {}
        for i = 1, playerCardNum do
            cards[i] = tableCards[s]

            s = s - 1
        end

        cards = userdata:sortMyCards(cards)
        userdata:setHandCards(sid, cards)

        local list = info.seatInfo[sid]
        list.handCards = cards

        local cardInfo = {}
        cardInfo.seatId = sid
        cardInfo.cards = cards

        local data   = packetHelper:encodeMsg("YunCheng.CardInfo", cardInfo)
        local packet = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_PICKUP, sid, data)
        self:SendGameDataToUser(uid, protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)
    end)

    local bottomNum = 3 + playRule
    if s ~= bottomNum then
        self:SendACLToTable(const.YUNCHENG_ACL_STATUS_RESTART_NO_MASTER)

        baseClass.GameOver(self, true)

        self:SendGameWait(0, const.YUNCHENG_TABLE_STATUS_WAIT_NEWGAME, const.YUNCHENG_TIMEOUT_WAIT_NEWGAME)
        return
    end

    info.bottomCards = {}
    for i=1,s do
        info.bottomCards[i] = tableCards[i]
    end
    info.showBottoms = nil

    local mask = self:GetAllPlayingUserMask()
    self:SendGameWait(mask, const.YUNCHENG_TABLE_STATUS_WAIT_PICKUP, const.YUNCHENG_TIMEOUT_WAIT_PICKUP)
end

class.landlordStart = function (self)
    local seatId    = math.random(1, const.YUNCHENG_MAX_PLAYER_NUM)
    local info = self.gameInfo
    info.curSeatId      = seatId
    info.masterSeatId   = nil

    local mask = 1 << seatId
    self:SendGameWait(mask, const.YUNCHENG_TABLE_STATUS_WAIT_LANDLORD, const.YUNCHENG_TIMEOUT_WAIT_LANDLORD)
end

class.landlordNext = function (self)
    local gameInfo = self.gameInfo
    local seatInfo = gameInfo.seatInfo[gameInfo.curSeatId]
    seatInfo.canCall = nil

    local seatId = gameInfo.curSeatId
    local count = 0
    repeat
        seatId      = self:GetNextPlayer(seatId)
        seatInfo    = gameInfo.seatInfo[seatId]
        count = count + 1
    until seatInfo.canCall or count >= const.YUNCHENG_MAX_PLAYER_NUM

    if not seatInfo.canCall then
        self:SendACLToTable(const.YUNCHENG_ACL_STATUS_RESTART_NO_MASTER)

        baseClass.GameOver(self, true)

        self:SendGameWait(0, const.YUNCHENG_TABLE_STATUS_WAIT_NEWGAME, const.YUNCHENG_TIMEOUT_WAIT_NEWGAME)
        return
    end

    gameInfo.curSeatId = seatId
    local mask = 1 << seatId

    local timeout = const.YUNCHENG_TIMEOUT_WAIT_LANDLORD
    if gameInfo.timeoutList[seatId] then
        timeout = const.YUNCHENG_TIMEOUT_WAIT_OFFLINE
    end
    self:SendGameWait(mask, const.YUNCHENG_TABLE_STATUS_WAIT_LANDLORD, timeout)
end

class.yunchengRequestMultiple = function (self, callInfo)
    local gameInfo = self.gameInfo
    if self.status ~= const.YUNCHENG_TABLE_STATUS_WAIT_MULTIPLE then
        -- print ("illegal status for multiple ", self.status)
        return
    end

    if not callInfo then
        callInfo = {}
        callInfo.seatId = gameInfo.curSeatId
        callInfo.callMult = 1
    end

    if callInfo and callInfo.seatId and callInfo.callMult then
        self.waitMask = self.waitMask & ~(1 << callInfo.seatId)

        local seatInfo = gameInfo.seatInfo[callInfo.seatId]
        if callInfo.callMult ~= 1 then
            callInfo.callMult = 2
        end
        seatInfo.canCall = nil

        seatInfo.multiple = seatInfo.multiple * callInfo.callMult

        local nextId = const.deltaSeat(gameInfo.masterSeatId, 1)
        local prevId = const.deltaSeat(gameInfo.masterSeatId, -1)
        local nextInfo = gameInfo.seatInfo[nextId]
        local prevInfo = gameInfo.seatInfo[prevId]
        if callInfo.seatId == gameInfo.masterSeatId then
            if callInfo.callMult > 1 then
                nextInfo.multiple = nextInfo.multiple > 1 and nextInfo.multiple * 2 or nextInfo.multiple
                prevInfo.multiple = prevInfo.multiple > 1 and prevInfo.multiple * 2 or prevInfo.multiple
            end
        end

        local masterInfo = gameInfo.seatInfo[gameInfo.masterSeatId]
        masterInfo.multiple = nextInfo.multiple + prevInfo.multiple

        local data = packetHelper:encodeMsg("YunCheng.CallInfo", callInfo)
        local packet = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_MULTIPLE, callInfo.seatId, data)
        self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)

        if callInfo.seatId == gameInfo.masterSeatId then
            self:enterThrowStage()
            return
        end

        local otherId = (callInfo.seatId == nextId and prevId or nextId)
        local otherInfo = gameInfo.seatInfo[otherId]
        if callInfo.callMult == 1 then
            if otherInfo.canCall then
                self:enterMultipleStage(otherId)
                return
            end
        else
            if otherInfo.multiple == 1 then
                self:enterMultipleStage(otherId)
                return
            end
        end

        if nextInfo.multiple > 1 or prevInfo.multiple > 1 then
            self:enterMultipleStage(gameInfo.masterSeatId)
        else
            self:enterThrowStage()
        end
    end
end

class.yunchengPostLandlord = function (self)
    local gameInfo = self.gameInfo
    -- 底牌加上
    local seatInfo = gameInfo.seatInfo[gameInfo.masterSeatId]
    local cards = seatInfo.handCards
    for _, v in ipairs(gameInfo.bottomCards) do
        table.insert(cards, v)
    end
    gameInfo.showBottoms = true

    local userdata = gameInfo.userdata
    cards = userdata:sortMyCards(cards)

    seatInfo.handCards = cards
    self:refreshUserCards(gameInfo.masterSeatId)

    local cardInfo = {
        seatId = gameInfo.masterSeatId,
        cards  = gameInfo.bottomCards,
    }
    local data   = packetHelper:encodeMsg("YunCheng.CardInfo", cardInfo)
    local packet = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_SHOWBOTTOM, gameInfo.masterSeatId, data)
    self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)

    -- 踢，跟踢，回踢
    local nextId = const.deltaSeat(gameInfo.masterSeatId, 1)
    local nextInfo = gameInfo.seatInfo[nextId]

    local prevId = const.deltaSeat(gameInfo.masterSeatId, -1)
    local prevInfo = gameInfo.seatInfo[prevId]

    if nextInfo.canCall then
        self:enterMultipleStage(nextId)
    elseif prevInfo.canCall then
        self:enterMultipleStage(prevId)
    else
        self:enterThrowStage()
    end
end

class.yunchengRequestLandlord = function (self, callInfo)
    if self.status ~= const.YUNCHENG_TABLE_STATUS_WAIT_LANDLORD then
        return
    end

    local gameInfo = self.gameInfo
    if callInfo.seatId ~= gameInfo.curSeatId then
        return
    end

    local seatInfo = gameInfo.seatInfo[callInfo.seatId]
    local userdata = gameInfo.userdata
    if userdata:bigEnough(seatInfo.handCards) then
        callInfo.callMult = 2
    end

    if not callInfo.callMult or callInfo.callMult == 1 then
        callInfo.callMult = 1
        seatInfo.canCall = nil
        local data      = packetHelper:encodeMsg("YunCheng.CallInfo", callInfo)
        local packet    = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_LANDLORD, nil, data)
        self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)

        self:landlordNext()
        return
    end

    if gameInfo.masterSeatId then
        return; -- 禁止重复叫地主
    end
    callInfo.callMult = 2
    seatInfo.multiple = 2
    gameInfo.masterSeatId = callInfo.seatId

    local data      = packetHelper:encodeMsg("YunCheng.CallInfo", callInfo)
    local packet    = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_LANDLORD, nil, data)
    self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)

    self:yunchengPostLandlord()
end

class.enterMultipleStage = function (self, seatId)
    local mask = 1 << seatId
    self:SendGameWait(mask, const.YUNCHENG_TABLE_STATUS_WAIT_MULTIPLE, const.YUNCHENG_TIMEOUT_WAIT_MULTIPLE)
end

class.enterThrowStage = function (self)
    local gameInfo = self.gameInfo

    self.waitMask = 0
    gameInfo.winCards    = nil
    self:turnToNextSeat()
end

class.yunchengCheckFlower = function (self)
    local gameInfo  = self.gameInfo
    local seatInfo  = gameInfo.seatInfo[gameInfo.curSeatId]
    local card = seatInfo.handCards[1] or nil

    if gameInfo.winCards == nil and #seatInfo.handCards == 1 and card == const.YUNCHENG_CARD_FLOWER then
        local seatId = self:GetNextPlayer(gameInfo.curSeatId)
        local cardInfo = {
            seatId = seatId,
            cards = {const.YUNCHENG_CARD_BACKGROUND}
        }
        local data   = packetHelper:encodeMsg("YunCheng.CardInfo", cardInfo)
        local packet = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_THROW, seatId, data)
        self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)

        self:turnToNextSeat(gameInfo.curSeatId)
        return true
    end
    return false
end

class.yunchengAutoThrow = function (self)
    local gameInfo  = self.gameInfo
    local curSeatId = gameInfo.curSeatId

    local cardInfo = {}
    cardInfo.seatId = gameInfo.curSeatId
    if gameInfo.winCards ~= nil then
        -- 超时不要
        cardInfo.cards  = {-1}
        self:yunchengRequestThrow(cardInfo)
        return
    end

    local userdata = gameInfo.userdata
    userdata:updateSeats(gameInfo.masterSeatId, gameInfo.curSeatId)

    local seatInfo = gameInfo.seatInfo[gameInfo.curSeatId]
    cardInfo.cards = userdata:robotFirstPlay()

    local ok, cards = const.getSelCards(seatInfo.handCards, const.getCardItSelf,  cardInfo.cards, const.getCardItSelf)
    if not ok then
        print ("can't find selected cards in first play")
    end

    cardInfo.cards = cards

    self:yunchengRequestThrow(cardInfo)
end

class.yunchengRequestThrow = function (self, cardInfo)
    if self.status ~= const.YUNCHENG_TABLE_STATUS_WAIT_THROW then
        return
    end

    local gameInfo  = self.gameInfo
    if gameInfo.curSeatId ~= cardInfo.seatId then
        return
    end

    if not cardInfo.cards or #cardInfo.cards == 0 then
        local uid = self.playingUsers:getObjectAt(gameInfo.curSeatId)
        self.room:SendACLToUser(const.YUNCHENG_ACL_STATUS_NO_SELECT_CARDS, uid)
        return
    end

    local seatInfo  = gameInfo.seatInfo[cardInfo.seatId]
    if cardInfo.cards[1] < 0 then
        if not gameInfo.winCards then
            return
        end

        seatInfo.throwCards = {}

        -- 告诉客户端 某方 pass
        local data   = packetHelper:encodeMsg("YunCheng.CardInfo", cardInfo)
        local packet = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_THROW, gameInfo.curSeatId, data)
        self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)

        self:turnToNextSeat(gameInfo.curSeatId)
        return
    end

    local testCards = tableHelper.copyArray(seatInfo.handCards)
    local ok = const.removeSubset(testCards, cardInfo.cards)
    if not ok then
        local uid = self.playingUsers:getObjectAt(gameInfo.curSeatId)
        self.room:SendACLToUser(const.YUNCHENG_ACL_STATUS_NO_YOUR_CARDS, uid)
        return
    end

    local userdata  = gameInfo.userdata
    userdata:updateSeats(gameInfo.masterSeatId, gameInfo.curSeatId)
    local prevCards = gameInfo.winCards and gameInfo.winCards.cards or nil
    local retCode, sorted = userdata:canPlayCards(cardInfo.cards, prevCards)
    if retCode ~= 0  then
        local uid = self.playingUsers:getObjectAt(gameInfo.curSeatId)
        self.room:SendACLToUser(retCode, uid)
        return
    end

    cardInfo.cards = sorted
    gameInfo.winCards = tableHelper.copyTable(cardInfo)
    seatInfo.outTimes = seatInfo.outTimes + 1

    local data   = packetHelper:encodeMsg("YunCheng.CardInfo", cardInfo)
    local packet = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_THROW, gameInfo.curSeatId, data)
    self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)

    seatInfo.throwCards = cardInfo.cards

    table.insert(gameInfo.histCards, cardInfo)
    userdata:addHistCards(cardInfo.cards)

    seatInfo.handCards = testCards
    self:refreshUserCards(gameInfo.curSeatId)

    -- handle bombs
    local node = userdata:getNodeType(cardInfo.cards)
    if const.isRocket(node) or const.isBomb(node) then
        gameInfo.bombCount = gameInfo.bombCount + 1
        if gameInfo.bombMax > 0 and gameInfo.bombCount > gameInfo.bombMax then
            gameInfo.bombCount = gameInfo.bombMax
        end
        local callInfo = {
            callMult = gameInfo.bombCount,
            seatId   = cardInfo.seatId,
        }
        local data   = packetHelper:encodeMsg("YunCheng.CallInfo", callInfo)
        local packet = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_BOMBMULT, cardInfo.seatId, data)
        self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)
    end

    -- test game over
    if #testCards == 0 then
        self:SendGameWait(0, const.YUNCHENG_TABLE_STATUS_WAIT_GAMEOVER, const.YUNCHENG_TIMEOUT_WAIT_GAMEOVER)
        return
    end

    -- turn to next seat
    self:turnToNextSeat(gameInfo.curSeatId)
end

class.refreshUserCards = function (self, seatId)
    local gameInfo = self.gameInfo
    local seatInfo = gameInfo.seatInfo[seatId]

    local cardInfo = {}
    cardInfo.seatId = seatId
    cardInfo.cards  = seatInfo.handCards

    local userdata  = gameInfo.userdata
    userdata:setHandCards(seatId, seatInfo.handCards)

    local backCards = {}
    for i, v in ipairs(seatInfo.handCards) do
        backCards[i] = v
    end

    self:groupAction("playingUsers", function (sid, uid)
        if sid ~= seatId then
            cardInfo.cards = backCards
        else
            cardInfo.cards = seatInfo.handCards
        end
        local data      = packetHelper:encodeMsg("YunCheng.CardInfo", cardInfo)
        local packet    = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_REFRESH, seatId, data)
        self:SendGameDataToUser(uid, protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)
    end)
end

class.turnToNextSeat = function (self, seatId)
    local gameInfo = self.gameInfo
    if not seatId then
        gameInfo.curSeatId = gameInfo.masterSeatId
    else
        gameInfo.curSeatId = self:GetNextPlayer(gameInfo.curSeatId)
    end

    local oldCards = gameInfo.winCards
    if oldCards and oldCards.seatId == gameInfo.curSeatId then
        gameInfo.winCards = nil
    end

    local onlyFlower = nil
    if gameInfo.winCards == nil then
        local seatInfo = gameInfo.seatInfo[gameInfo.curSeatId]
        local card = seatInfo.handCards[1] or nil
        if #seatInfo.handCards == 1 and card == const.YUNCHENG_CARD_FLOWER then
            onlyFlower = true
        end
    end

    local mask   = 1 << gameInfo.curSeatId
    local timeout = const.YUNCHENG_TIMEOUT_WAIT_THROW
    if onlyFlower or gameInfo.timeoutList[gameInfo.curSeatId] then
        timeout = const.YUNCHENG_TIMEOUT_WAIT_OFFLINE
    end
    self:SendGameWait(mask, const.YUNCHENG_TABLE_STATUS_WAIT_THROW, timeout)
end

return Table_YunCheng

