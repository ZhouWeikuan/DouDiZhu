local skynet    = skynet or require "skynet"

-- use skynet.init to determine server or client

local const         = require "Const_YunCheng"
local dbHelper      = require "DBHelper"
local tableHelper   = require "TableHelper"

local protoTypes    = require "ProtoTypes"
local YunCheng        = YunCheng or require "yuncheng"

local packetHelper  = (require "PacketHelper").create("protos/YunCheng.pb")

local baseClass     = require "GameTable"

local class = {mt = {}}
class.mt.__index = class

setmetatable(class, baseClass.mt)

class.create = function (...)
    local self = baseClass.create(...)
    setmetatable(self, class.mt)

    self.gameInfo = {}

    return self
end


class.extractRoomDetails = function(self, data)
    local info = packetHelper:decodeMsg("YunCheng.RoomDetails", data)
    if info.passCount == 16 then
        info.costCoins = 6
    else
        info.passCount = 8
        info.costCoins = 3
    end
    return info
end

class.canTermTable = function (self)
    if not self.roomInfo or not self.roomInfo.roomDetails then
        return
    end

    local gameCount = self.roomInfo.histInfo.gameCount or 0
    local passCount = self.roomInfo.roomDetails.passCount or 8
    if gameCount >= passCount then
        return true
    end
end


class.UserStatus_ProtoName = "YunCheng.UserStatus"
class.UserStatus_Fields = {
    "FUserCode", "FAgentCode", "FCounter",
    "FScore", "FWins", "FLoses", "FDraws",
    "FLastGameTime", "FSaveDate", "FSaveCount",
}

class.UpdateUserStatus = function (self, user, code, deltaScore)
    if user then
        user.FScore = (user.FScore or 0) + deltaScore
        if deltaScore > 0 then
            user.FWins = (user.FWins or 0) + 1
        else
            user.FLoses = (user.FLoses or 0) + 1
        end
    end

    if not skynet.init then
        return
    end

    local keyName = "FUserCode"
    user = self.room:remoteLoadDB(self.config.DBTableName, keyName, code)
    if user then
        user.FScore = (user.FScore or 0) + deltaScore
        self.room:remoteDeltaDB(self.config.DBTableName, keyName, code, "FScore", deltaScore)
        if deltaScore > 0 then
            user.FWins = (user.FWins or 0) + 1
            self.room:remoteDeltaDB(self.config.DBTableName, keyName, code, "FWins", 1)
        else
            user.FLoses = (user.FLoses or 0) + 1
            self.room:remoteDeltaDB(self.config.DBTableName, keyName, code, "FLoses", 1)
        end
    end

    self.room:remoteUpdateDB(self.config.DBTableName, keyName, code, 'FLastGameTime', dbHelper.timestamp())
end

class.getGiftPrice = function (self, giftName)
    if not giftName then
        return
    end
    return const.kGiftItems[giftName]
end

class.notifyVictory = function (self, user, one)
    if not skynet.init then
        return
    end

    -- disable it in test env
    do return end

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

class.canPlayerStandUp = function (self, userInfo, force)
    if self.roomInfo and self.roomInfo.histInfo then
        return force
    end
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
        one.userCode = seatInfo.userCode
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

    local code = self.playerUsers:getObjectAt(seatId)
    local packet = packetHelper:encodeMsg("YunCheng.GameInfo", gameInfo)
    self:SendGameDataToUser(code, protoTypes.CGGAME_PROTO_SUBTYPE_GAMEINFO, packet)
end

class.addStartToHist = function (self)
    local roomInfo = self.roomInfo
    if not roomInfo then
        return
    end

    local histInfo = roomInfo.histInfo
    if not histInfo then
        histInfo = {}
        roomInfo.histInfo = histInfo

        histInfo.roomId     = roomInfo.FRoomID
        histInfo.passCount  = roomInfo.roomDetails.passCount or 8
        histInfo.openTime   = self.openTime
        histInfo.ownerCode  = roomInfo.FOwnerCode
        histInfo.ownerName  = roomInfo.FOwnerName
        histInfo.gameOver   = nil

        histInfo.seatScore  = {}

        for seatId = 1, const.YUNCHENG_MAX_PLAYER_NUM do
            local code = self.playingUsers:getObjectAt(seatId)
            local userInfo = self.room:getUserInfo(code)

            local one = {}
            one.name  = userInfo and userInfo.FNickName or ""
            one.score = 0
            one.winCount  = 0
            one.loseCount = 0

            histInfo.seatScore[seatId] = one
        end
    end

    histInfo.gameInfo   = {}
    local thisInfo = histInfo.gameInfo
    local gameInfo = self.gameInfo

    histInfo.gameCount  = (histInfo.gameCount or 0) + 1
    thisInfo.gameIndex  = histInfo.gameCount

    thisInfo.startTime  = os.time()

    thisInfo.masterSeatId   = gameInfo.masterSeatId
    thisInfo.bottomScore    = gameInfo.bottomScore
    thisInfo.bombCount      = gameInfo.bombCount
    thisInfo.bombMax        = gameInfo.bombMax
    thisInfo.same3Bomb      = gameInfo.same3Bomb
    thisInfo.bottomCards    = {}

    thisInfo.histOperations = {}

    thisInfo.seatInfo = {}
    for seatId, seatInfo in pairs(gameInfo.seatInfo) do
        local one = {}
        one.userCode    = seatInfo.userCode
        one.seatId      = seatId

        local userInfo  = self.room:getUserInfo(one.userCode)
        one.name        = userInfo and userInfo.FNickName or ""
        one.AvatarID    = userInfo and userInfo.FAvatarID
        one.AvatarUrl   = userInfo and userInfo.FAvatarUrl
        one.deltaScore  = 0
        one.multiple    = seatInfo.multiple
        one.handCards   = {}

        thisInfo.seatInfo[seatId] = one
    end
end

class.addHandCardsToHist = function (self, seatId, cards)
    if not self.roomInfo then
        return
    end

    local thisInfo = self.roomInfo.histInfo.gameInfo
    local seatInfo = thisInfo.seatInfo[seatId]

    for i, v in ipairs(cards) do
        seatInfo.handCards[i] = v
    end
end

--- Landlord: 叫或者不叫, masterSeatId
--- Multiple: 1, 2 只修改seatInfo[seatId].multiple
--- Throw:  {-1}, 或者{cards},
--- BombMult: 修改bombCount
class.addActionToHist = function (self, action, info)
    if not self.roomInfo then
        return
    end

    local thisInfo = self.roomInfo.histInfo.gameInfo
    local one = {action = action, info = info}

    table.insert(thisInfo.histOperations, one)
end

class.addResultScoreToHist = function (self, scores, resType)
    if not self.roomInfo then
        return
    end

    local histInfo = self.roomInfo.histInfo
    local thisInfo = histInfo.gameInfo
    thisInfo.bottomCards    = self.gameInfo.bottomCards
    thisInfo.resType        = resType

    for seatId, score in pairs(scores) do
        thisInfo.seatInfo[seatId].deltaScore = thisInfo.seatInfo[seatId].deltaScore + score

        local one = histInfo.seatScore[seatId]
        one.score = one.score + score
        if score > 0 then
            one.winCount    = (one.winCount or 0) + 1
        else
            one.loseCount   = (one.loseCount or 0) + 1
        end
    end
end

class.gameStart = function (self)
    local roomDetails = self.roomInfo and self.roomInfo.roomDetails or {}

    local info  = self.gameInfo or {}
    self.gameInfo       = info

    info.timeoutList    = {}
    info.bottomCards = {}

    info.masterSeatId   = 0
    info.curSeatId      = 0

    roomDetails.playRule = roomDetails.playRule or 0
    if roomDetails.playRule == 2 then
        info.same3Bomb      = 1
    elseif roomDetails.playRule ==1 then
        info.same3Bomb      = roomDetails.same3Bomb or 0
    else
        info.same3Bomb      = 0
    end

    -- test
    if not skynet.init then
        roomDetails.playRule = 2
        info.same3Bomb = 1
    end

    info.bombMax        = roomDetails.bombMax or 0
    info.bottomScore    = roomDetails.bottomScore or 1

    info.bombCount      = 0
    info.bottomCards    = nil
    info.showBottoms    = nil

    info.winCards       = nil
    info.seatInfo       = {}
    info.histCards      = {}

    info.userdata    = YunCheng.new(info.same3Bomb);

    -- print (string.format("tableId %d", self.tableId))
    self:groupAction("playingUsers", function (sid, code)
        -- print (string.format("seatId =  %d, uid = %s", sid, uid))

        local seatInfo = {}
        seatInfo.seatId = sid
        seatInfo.userCode = code

        seatInfo.multiple = 1

        seatInfo.handCards  = {}
        seatInfo.throwCards = {}

        seatInfo.canCall    = true
        seatInfo.outTimes   = 0
        seatInfo.scoreCard  = 0
        if self.roomInfo and self.roomInfo.histInfo and self.roomInfo.histInfo.seatScore then
            local tmp = self.roomInfo.histInfo.seatScore[sid] or {}
            seatInfo.scoreCard = tmp.score or 0
        end

        info.seatInfo[sid] = seatInfo
    end)

    self:addStartToHist()
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
    self:groupAction("playingUsers", function (seatId, code)
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
    self:groupAction("playingUsers", function (seatId, code)
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

        local userInfo = self.room:getUserInfo(code)
        if one then
            if self.roomInfo then
                scores[seatId] = one.deltaScore or 0
            end
            self:UpdateUserStatus(userInfo, code, one.deltaScore or 0)
        end

        if seatId == gameInfo.masterSeatId and math.abs(one.deltaScore) >= 10 then
            masterUser = userInfo
            self:notifyVictory(masterUser, one)
        end
    end)

    local packet = packetHelper:encodeMsg("YunCheng.GameOver", gameOver)
    self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_GAMEOVER, packet)

    if self.roomInfo ~= nil then
        self:addResultScoreToHist(scores, gameOver.resType)
        self.room:roomTablePayBill(self)
        if self:canTermTable() then
            self:SendRoomTableResult(true)
            if baseClass.TermTable(self) then
                return
            end
        else
            self:SendRoomTableResult()
            baseClass.GameOver(self, false, true)
        end
    else
        baseClass.GameOver(self)
    end

    self:SendGameWait(0, const.YUNCHENG_TABLE_STATUS_WAIT_NEWGAME, const.YUNCHENG_TIMEOUT_WAIT_NEWGAME)
end

class.handleGameData = function (self, userInfo, gameType, data)
    if not userInfo.seatId then
        return
    end
    if gameType == protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE then
        local traceInfo = packetHelper:decodeMsg("CGGame.ProtoInfo", data)
        self:yunchengGameTrace(userInfo.seatId, traceInfo)
    else
        baseClass.handleGameData(self, userInfo, gameType, data)
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
        elseif not self.roomInfo then
            info.timeoutList[info.curSeatId or 0] = true
            self:yunchengAutoThrow()
        end

    elseif self.status == const.YUNCHENG_TABLE_STATUS_WAIT_MULTIPLE then
        if not self.roomInfo then
            self:groupAction("playingUsers", function (seatId, code)
                if self:IsWaitSeat(seatId) then
                    info.timeoutList[seatId] = true
                end
            end)
            self.waitMask = 0
            self:yunchengRequestMultiple()
        end

    elseif self.status == const.YUNCHENG_TABLE_STATUS_WAIT_LANDLORD then
        if not self.roomInfo then
            info.timeoutList[info.curSeatId or 0] = true
            local callInfo = {}
            callInfo.seatId = info.curSeatId
            callInfo.callMult = 1
            self:yunchengRequestLandlord(callInfo)
        end

    elseif self.status == const.YUNCHENG_TABLE_STATUS_WAIT_GAMEOVER then
        self:yunchengGameOver()

    elseif self.status == const.YUNCHENG_TABLE_STATUS_WAIT_NEWGAME then
        self.status = protoTypes.CGGAME_TABLE_STATUS_WAITREADY
        baseClass.AnyPlayer_GameOverWaitStart(self, protoTypes.CGGAME_TIMEOUT_WAITREADY)

    else
        return nil
    end

    return true
end


---! GAME_DATA, GAME_TRACE, TRACE_BET, seatId, msgBody
---! traceInfo is TRACE_BET, seatId, msgBody
class.yunchengGameTrace = function (self, seatId, traceInfo)
    local info = self.gameInfo
    if self.status <= protoTypes.CGGAME_TABLE_STATUS_WAITREADY or not self:IsWaitSeat(seatId) then
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
    local roomDetails = self.roomInfo and self.roomInfo.roomDetails or {}
    local playRule = roomDetails.playRule or 0

    -- test
    if not skynet.init then
        playRule = 2
    end

    local tableCards = {}
    local maxCardValue = (playRule >= 1) and 55 or 54
    local index = 0
    for i=1,maxCardValue do
        if (i == 3 or i == 42) and playRule == 2 then
        else
            index = index + 1
            tableCards[index] = i
        end
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
    if playRule == 2 then
        playerCardNum = playerCardNum - 1
    end
    self:groupAction("playingUsers", function (sid, code)
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
        self:SendGameDataToUser(code, protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)

        self:addHandCardsToHist(sid, cards)
    end)

    local bottomNum = 3 + playRule
    if s ~= bottomNum then
        self:SendACLToTable(const.YUNCHENG_ACL_STATUS_RESTART_NO_MASTER)

        if self.roomInfo then
            local histInfo = self.roomInfo.histInfo
            histInfo.gameCount = histInfo.gameCount - 1
            baseClass.GameOver(self, true, true)
        else
            baseClass.GameOver(self, true)
        end

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

        if self.roomInfo then
            local histInfo = self.roomInfo.histInfo
            histInfo.gameCount = histInfo.gameCount - 1
            baseClass.GameOver(self, true, true)
        else
            baseClass.GameOver(self, true)
        end

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
        if not seatInfo then
            return
        end
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

        self:addActionToHist(const.YUNCHENG_GAMETRACE_MULTIPLE, callInfo)

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

        self:addActionToHist(const.YUNCHENG_GAMETRACE_LANDLORD, callInfo)

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

    self:addActionToHist(const.YUNCHENG_GAMETRACE_LANDLORD, callInfo)

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
        local code = self.playingUsers:getObjectAt(gameInfo.curSeatId)
        self.room:SendACLToUser(const.YUNCHENG_ACL_STATUS_NO_SELECT_CARDS, code)
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

        self:addActionToHist(const.YUNCHENG_GAMETRACE_THROW, cardInfo)

        self:turnToNextSeat(gameInfo.curSeatId)
        return
    end

    local testCards = tableHelper.cloneArray(seatInfo.handCards)
    local ok = const.removeSubset(testCards, cardInfo.cards)
    if not ok then
        local code = self.playingUsers:getObjectAt(gameInfo.curSeatId)
        self.room:SendACLToUser(const.YUNCHENG_ACL_STATUS_NO_YOUR_CARDS, code)
        return
    end

    local userdata  = gameInfo.userdata
    userdata:updateSeats(gameInfo.masterSeatId, gameInfo.curSeatId)

    local prevCards = gameInfo.winCards and gameInfo.winCards.cards or nil
    local retCode, sorted = userdata:canPlayCards(cardInfo.cards, prevCards)
    if retCode ~= 0  then
        local code = self.playingUsers:getObjectAt(gameInfo.curSeatId)
        self.room:SendACLToUser(retCode, code)
        return
    end

    cardInfo.cards = sorted
    gameInfo.winCards = tableHelper.cloneTable(cardInfo)
    seatInfo.outTimes = seatInfo.outTimes + 1

    local data   = packetHelper:encodeMsg("YunCheng.CardInfo", cardInfo)
    local packet = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_THROW, gameInfo.curSeatId, data)
    self:SendGameDataToTable(protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)

    self:addActionToHist(const.YUNCHENG_GAMETRACE_THROW, gameInfo.winCards)

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

        self:addActionToHist(const.YUNCHENG_GAMETRACE_BOMBMULT, callInfo)
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

    self:groupAction("playingUsers", function (sid, code)
        if sid ~= seatId then
            cardInfo.cards = backCards
        else
            cardInfo.cards = seatInfo.handCards
        end
        local data      = packetHelper:encodeMsg("YunCheng.CardInfo", cardInfo)
        local packet    = packetHelper:makeProtoData(const.YUNCHENG_GAMETRACE_REFRESH, seatId, data)
        self:SendGameDataToUser(code, protoTypes.CGGAME_PROTO_SUBTYPE_GAMETRACE, packet)
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

return class

