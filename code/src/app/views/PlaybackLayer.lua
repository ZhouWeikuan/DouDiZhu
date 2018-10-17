local class = class("PlaybackLayer")
class.__index = class

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"

local packetHelper  = require "PacketHelper"
local UIHelper      = require "UIHelper"

local protoTypes    = require "ProtoTypes"
local const         = require "Const_YunCheng"
local YunCheng      = YunCheng or require "yuncheng"

local kPlayback_Z_Head       = 1
local kPlayback_Z_HandCards  = 2
local kPlayback_Z_ThrowCards = 3
local kPlayback_Z_TopInf     = 4
local kPlayback_Z_Anim       = 5
local kPlayback_Z_Score      = 10
local kPlayback_Z_Btn        = 0

function class.extend(target)
    local t = tolua.getpeer(target)
    if not t then
        t = {}
        tolua.setpeer(target, t)
    end
    setmetatable(t, class)
    return target
end

function class.create(selfSeatId, gameInfo)
    cc.SpriteFrameCache:getInstance():addSpriteFrames("replaylayer.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("comlayer.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("card_big.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("card_small.plist")

    local self = class.extend(cc.Layer:create())
    if nil ~= self then
        local function onNodeEvent(event)
            if "enter" == event then
                self:onEnter()
            elseif "exit" == event then
                self:onExit()
            end
        end
        self:registerScriptHandler(onNodeEvent)
    end

    UIHelper.createSceneBg(self)

    self.selfSeatId = selfSeatId
    self.gameInfo   = gameInfo

    self.m_userdata = YunCheng.new(gameInfo.same3Bomb)

    self.m_throwIdx = 1
    self.m_spHandcards = {{}, {}, {}}
    self.m_spThrows = {{}, {}, {}}
    self.m_lbMult = {}
    self.m_multiple = {1,1,1}

    self:initUI()
    self:initHeads()
    self:pickUp()

    local ClockLayer    = require "ClockLayer"
    self.clockLayer     = ClockLayer.create(self)
    self.clockLayer:addTo(self, kPlayback_Z_TopInf)

    return self
end

function class:onEnter()
    Constants.startScheduler(self, self.tickFrame, 1)
end

function class:onExit()
    Constants.stopScheduler(self)
end

function class:tickFrame (dt)
    self:throwCards()
end

function class:getHeadPos(viewId)
    local winSize = display.size
    local posHead = {
        cc.p(150, 450),
        cc.p(winSize.width - 150, winSize.height - 150),
        cc.p(150, winSize.height - 150)
    }

    return posHead[viewId]
end

function class:initHeads()
    for seatId = 1, Constants.kMaxPlayers do
        local viewId = self:MapSeatToView(seatId)
        local pos = self:getHeadPos(viewId)

        local seatInfo = self.gameInfo.seatInfo[seatId]
        if seatInfo then
            local headBg = Constants.getSprite("bg_role.png", cc.p(350,80), self)
            headBg:setLocalZOrder(kPlayback_Z_Head)
                  :setPosition(pos)
                  :setScale(0.77)

            local bgSize = headBg:getContentSize()

            local sten = cc.Sprite:createWithSpriteFrameName("bg_sten.png")
            local clipper = cc.ClippingNode:create()
            clipper:setStencil(sten)
            clipper:setAlphaThreshold(0.5)
                   :addTo(headBg)
                   :setPosition(bgSize.width * 0.5, bgSize.height * 0.5)

            local roleSp = Constants.getSprite("icon_role0.png", cc.p(0,0), clipper)

            local userInfo = {
                FAvatarUrl  = seatInfo.AvatarUrl,
                FUserCode   = seatInfo.userCode,
                FAvatarID   = seatInfo.AvatarID
            }
            Constants.getUserHeadSprite(roleSp, userInfo)

            local lbName = cc.Label:createWithSystemFont(seatInfo.name, Constants.kBoldFontNamePF, 48)
            lbName:addTo(headBg)
                  :setAnchorPoint(cc.p(0.5, 1.0))
                  :setPosition(cc.p(bgSize.width * 0.5, 0))
                  :enableOutline(cc.WHITE, 0.3)

            local lblMult = cc.Label:createWithSystemFont("1倍", fontNameT, 48)
            headBg:addChild(lblMult)
            lblMult:setAnchorPoint(0.5, 1.0)
            lblMult:setPosition(cc.p(bgSize.width * 0.5, bgSize.height * 1.3))
            lblMult:enableOutline(cc.WHITE, 0.3)
            self.m_lbMult[viewId] = lblMult
        end
    end
end

function class:initUI()
    local winSize = display.size

    local bgBtn = Constants.get9Sprite("bg_rp_btn.png", cc.size(806,126),
                                        cc.p(winSize.width * 0.5, winSize.height * 0.35), self)
    self:reorderChild(bgBtn, kPlayback_Z_Btn)

    local btnDefs = {
        {"rp_back",  "clickBack",   cc.p(140, 63)},
        {"rp_play",  "clickPlay",   cc.p(403,  63)},
        {"rp_pause", "clickPause",  cc.p(666,  63)}
    }

    local menu = cc.Menu:create()
    menu:addTo(bgBtn)
        :setPosition(0,0)

    for _,one in ipairs(btnDefs) do
        local item = Constants.getMenuItem(one[1])
        item:registerScriptTapHandler(function() self[one[2]](self) end)
        item:addTo(menu)
            :setPosition(one[3])
    end
end

function class:clickBack()
    SoundApp.playEffect("sounds/main/click.mp3")
    cc.Director:getInstance():popScene()
end

function class:clickPlay()
    if not self.m_throwOver then
        SoundApp.playEffect("sounds/main/click.mp3")

        self:throwCards()

        Constants.stopScheduler(self)
        Constants.startScheduler(self, self.tickFrame, 1)
    end
end

function class:clickPause()
    SoundApp.playEffect("sounds/main/click.mp3")

    Constants.stopScheduler(self)
end

function class:MapSeatToView (seatId)
    local num = Constants.kMaxPlayers

    local viewId = Constants.kCenterViewId + (seatId - self.selfSeatId)
    if viewId > num then
        viewId = viewId - num
    elseif viewId < 1 then
        viewId = viewId + num
    end

    return viewId
end

function class:addOneHand(handCards, seatId)
    local viewId = self:MapSeatToView(seatId)

    local masterSeatId = self.gameInfo.masterSeatId
    local isMaster = masterSeatId and (masterSeatId == seatId)

    for _,card in ipairs(handCards) do
        local cardSp = UIHelper.getCardSprite(card, cc.p(0,0), self, kPlayback_Z_HandCards, isMaster)
        if viewId > 1 then
            cardSp:setScale(0.4)
        end

        cardSp.card = card

        table.insert(self.m_spHandcards[seatId], cardSp)

        if not self.m_cardSize then
            self.m_cardSize = cardSp:getContentSize()
        end
    end
end

function class:pickUp()
    for seatId = 1, Constants.kMaxPlayers do
        local seatInfo = self.gameInfo.seatInfo[seatId]
        if seatInfo then
            self:addOneHand(seatInfo.handCards, seatId)
        end
    end

    self:placeHandCards()
end

function class:placeHandCards(seatId)
    local fromSid, toSid

    if seatId then
        fromSid = seatId
        toSid = seatId
    else
        fromSid = 1
        toSid = Constants.kMaxPlayers
    end

    local winSize = display.size

    for sid = fromSid, toSid do
        local viewId = self:MapSeatToView(sid)
        local spTbl = self.m_spHandcards[sid]
        local count = #spTbl
        local maxCol = 7

        for k,v in ipairs(spTbl) do
            local pos = cc.p(0,0)
            if viewId == 1 then
                pos = UIHelper.getCardsPos(k-1, count)
            else
                pos = self:getHandCardsPos(viewId, k-1, count)
            end
            v:setPosition(pos)
        end
    end
end

function class:getHandCardsPos(viewId, i, count)
    local winSize = display.size

    local pos = cc.p(winSize.width * 0.03, winSize.height * 0.67)
    local dir = 1
    local idx = i
    if viewId == 2 then
        pos.x = winSize.width * 0.97
        dir = -1
        idx = count-1 - i
    end

    local space = 33

    pos.x = pos.x + space * idx * dir

    return pos
end

function class:subHandCards(seatId, cards)
    for _,card in ipairs(cards) do
        for i = #self.m_spHandcards[seatId], 1, -1 do
            local spCard = self.m_spHandcards[seatId][i]
            if spCard.card == card then
                spCard:removeFromParent()
                table.remove(self.m_spHandcards[seatId], i)
                break
            end
        end
    end

    self:placeHandCards(seatId)
end

function class:initTopInfo()
    local winSize = display.size

    -- 底牌
    local bottomCards = self.gameInfo.bottomCards
    if bottomCards and #bottomCards >= 3 then
        local ndCards = display.newNode()
        self:addChild(ndCards)

        local width = 0
        for k, v in pairs(bottomCards) do
            local cardSp = Constants.getSprite(string.format("cards%02d.png", v),
                            cc.p(width, 0), ndCards)
            cardSp:setAnchorPoint(0, 1)

            width = width + cardSp:getContentSize().width
        end

        ndCards:setPosition(winSize.width * 0.5 - width * 0.5, winSize.height)
    end
end

function class:showCurCursor(seatId)
    self.clockLayer:repaintSeatClock(seatId)
end

function class:throwCards()
    local histOperations = self.gameInfo.histOperations
    local curObj = histOperations[self.m_throwIdx]
    if curObj == nil then
        self.m_throwOver = true
        self:showGameOver()
        return
    end

    local cardInfo = curObj.info
    local seatId = cardInfo.seatId
    local viewId = self:MapSeatToView(seatId)
    local throws = cardInfo.cards

    self:showCurCursor(seatId)

    if not throws then
        self:procAction(curObj)
        self.m_throwIdx = self.m_throwIdx + 1
        return
    end

    for k,v in ipairs(self.m_spThrows[seatId]) do
        v:removeFromParent()
    end
    self.m_spThrows[seatId] = {}

    local winSize = display.size

    if throws[1] == -1 then
        UIHelper.showTalkBubble(viewId, "buchu", 2, self, kPlayback_Z_ThrowCards, true)

        local num = math.random(1, 4)
        local sexStr = self:getSexStr(seatId)
        local strSound = string.format("buyao%d.mp3", num)
        SoundApp.playEffect(sexStr .. strSound)
    else
        local playerOutCardPos = {
            cc.p(winSize.width * 0.50, winSize.height * 0.56),
            cc.p(winSize.width * 0.65, winSize.height * 0.77),
            cc.p(winSize.width * 0.35, winSize.height * 0.77),
        }

        local playerCardPos = {
            cc.p(winSize.width * 0.5, winSize.height * 0.13),
            cc.p(winSize.width * 0.895, winSize.height * 0.66),
            cc.p(winSize.width * 0.105, winSize.height * 0.66)
        }

        local masterSeatId = self.gameInfo.masterSeatId
        local isMaster = masterSeatId and (masterSeatId == seatId)

        local i = -math.floor(#throws/2)
        local s =  0.7
        local cardSpace = UIHelper.getCardsSpacing(#throws) * (s - 0.2)
        for k, v in pairs(throws) do
            local sp = UIHelper.getCardSprite(v, playerCardPos[viewId], self, kPlayback_Z_ThrowCards, isMaster)

            if viewId == 1 then
                sp:runAction(cc.Spawn:create(
                    cc.MoveTo:create(0.1, cc.p(playerOutCardPos[viewId].x+i*cardSpace,playerOutCardPos[viewId].y)),
                    cc.ScaleBy:create(0.1, s)
                    ))
            else
                cardSpace = 53
                sp:setScale(0)
                  :runAction(cc.Spawn:create(
                        cc.MoveTo:create(0.1, cc.p(playerOutCardPos[viewId].x+i*cardSpace,playerOutCardPos[viewId].y)),
                        cc.ScaleTo:create(0.1, 0.6)
                        ))
            end

            table.insert(self.m_spThrows[viewId], sp)
            i = i + 1
        end

        -- 从手牌中去除
        self:subHandCards(seatId, throws)

        self:doEffect(throws, seatId)
        self.m_winSeatId = seatId
    end

    self.m_throwIdx = self.m_throwIdx + 1
end

function class:playSoundDelay(str, t)
    self:runAction(cc.Sequence:create(cc.DelayTime:create(t),
                                     cc.CallFunc:create(function() SoundApp.playEffect(str) end)
                                     ))
end

function class:getSexStr(seatId)
    local seatInfo = self.gameInfo.seatInfo[seatId]
    local avatarID = seatInfo.AvatarID or 1

    local sexStr = string.format("sounds/%s/", UIHelper.getUserGender(avatarID))

    return sexStr
end

function class:doEffect(cards, seatId)
    self:playSoundDelay("sounds/main/givecard.mp3", 0.3)
    local node = self.m_userdata:getNodeType(cards)
    local sexStr = self:getSexStr(seatId)

    if self.m_winSeatId and self.m_winSeatId ~= seatId then
        local xr = math.random(1, 10)
        if xr < 4 then
            if (not const.isRocket(node)) and (not const.isBomb(node)) then
                local str = string.format("dani%d.mp3",xr)
                str = sexStr .. str
                self:playSoundDelay(str, 0.3)
                return
            end
        end
    end

    local resTbl = UIHelper.parseCardType(node, sexStr)

    if resTbl.anim then
        UIHelper.doAnimation(resTbl.anim, self)
    end

    for _,sound in ipairs(resTbl.sound) do
        self:playSoundDelay(sound, 0.3)
    end
end

function class:procAction(actionInfo)
    if actionInfo.action == const.YUNCHENG_GAMETRACE_LANDLORD then
        self:procLandlord(actionInfo.info.seatId, actionInfo.info.callMult)

    elseif actionInfo.action == const.YUNCHENG_GAMETRACE_MULTIPLE then
        self:procMultiple(actionInfo.info.seatId, actionInfo.info.callMult)

    elseif actionInfo.action == const.YUNCHENG_GAMETRACE_BOMBMULT then
        local bombCnt = actionInfo.info.callMult
        self:repaintBombMult(bombCnt)
    end
end

function class:repaintAllMultiple(bombCnt)
    bombCnt = bombCnt or 0
    for viewId = 1, Constants.kMaxPlayers do
        self.m_lbMult[viewId]:setString(string.format("%d倍", self.m_multiple[viewId] * (1 << bombCnt)))
    end
end

function class:repaintPlayerMult()
    self:repaintAllMultiple()
end

function class:repaintBombMult(bombCnt)
    self:repaintAllMultiple(bombCnt)
end

function class:procMultiple(seatId, callMult)
    callMult = callMult ~= 2 and 1 or 2
    local viewId = self:MapSeatToView(seatId)
    self.m_multiple[viewId] = self.m_multiple[viewId] * callMult

    local masterSeatId = self.gameInfo.masterSeatId
    if masterSeatId then
        local nextId = const.deltaSeat(masterSeatId, 1)
        local prevId = const.deltaSeat(masterSeatId, -1)
        local nextViewId = self:MapSeatToView(nextId)
        local prevViewId = self:MapSeatToView(prevId)
        if seatId == masterSeatId then
            if callMult > 1 then
                if self.m_multiple[nextViewId] > 1 then
                    self.m_multiple[nextViewId] = self.m_multiple[nextViewId] * 2
                end
                if self.m_multiple[prevViewId] > 1 then
                    self.m_multiple[prevViewId] = self.m_multiple[prevViewId] * 2
                end

                UIHelper.showTalkBubble(viewId, "huiti", 2, self, kPlayback_Z_ThrowCards, true)
            end
        else
            if callMult > 1 then
                local partnerViewId = (seatId == nextId) and prevViewId or nextViewId

                if self.m_multiple[partnerViewId] > 1 then
                    UIHelper.showTalkBubble(viewId, "genti", 2, self, kPlayback_Z_ThrowCards, true)
                else
                    UIHelper.showTalkBubble(viewId, "ti", 2, self, kPlayback_Z_ThrowCards, true)
                end
            end
        end

        local masterViewId = self:MapSeatToView(masterSeatId)
        self.m_multiple[masterViewId] = self.m_multiple[nextViewId] + self.m_multiple[prevViewId]

        if callMult < 2 then
            UIHelper.showTalkBubble(viewId, "buti", 2, self, kPlayback_Z_ThrowCards, true)
        end
    end

    local sexStr = self:getSexStr(seatId)
    local str = nil
    if callMult > 1 then
        str = sexStr .. "jiabei1.mp3"
    else
        str = sexStr .. "jiabei0.mp3"
    end
    SoundApp.playEffect(str)

    self:repaintPlayerMult()
end

function class:procLandlord(seatId, callMult)
    local viewId = self:MapSeatToView(seatId)

    local winSize = display.size

    if callMult < 2 then
        UIHelper.showTalkBubble(viewId, "bujiao", 2, self, kPlayback_Z_ThrowCards, true)

        local sexStr = self:getSexStr(seatId)
        local str = sexStr .. "noorder.mp3"
        SoundApp.playEffect(str)
    else
        self.gameInfo.masterSeatId = seatId
        local playerOutCardPos = {
            cc.p(winSize.width * 0.50, winSize.height * 0.56),
            cc.p(winSize.width * 0.65, winSize.height * 0.77),
            cc.p(winSize.width * 0.35, winSize.height * 0.77),
        }
        local spDiZhu = Constants.getSprite("dizhu.png", playerOutCardPos[viewId], self)
        spDiZhu:setScale(0.1)
               :runAction(cc.Sequence:create(cc.ScaleTo:create(0.2, 1),
                                                cc.DelayTime:create(0.5),
                                                cc.ScaleTo:create(0.3, 0.3),
                                                cc.CallFunc:create(function()
                                                    spDiZhu:removeFromParent()
                                                end)))

        local pos = self:getHeadPos(viewId)
        pos.x = (viewId == 2) and pos.x + 56 or pos.x - 56
        pos.y = pos.y + 44
        local master = self.m_dizhuMark
        if not master then
            local master = Constants.getSprite("info_host.png", pos, self)
            master:setScale(0.1)
                  :setLocalZOrder(kPlayback_Z_Head)
            self.m_dizhuMark = master
            local act = cc.Sequence:create(cc.ScaleTo:create(0.2, 1.5),
                                cc.ScaleTo:create(0.2, 1.0))
            master:runAction(act)
        end

        local viewId = self:MapSeatToView(seatId)
        self.m_multiple[viewId] = 2
        self:repaintPlayerMult()

        local sexStr = self:getSexStr(seatId)
        local str = sexStr .. "order.mp3"
        SoundApp.playEffect(str)

        UIHelper.showTalkBubble(viewId, "jiaodizhu", 2, self, kPlayback_Z_ThrowCards, true)

        self:initTopInfo()
        self:repaintMasterHandCards()
    end
end

function class:repaintMasterHandCards()
    local masterSeatId = self.gameInfo.masterSeatId
    if not masterSeatId then return end

    for _,sp in ipairs(self.m_spHandcards[masterSeatId]) do
        sp:removeFromParent()
    end
    self.m_spHandcards[masterSeatId] = {}

    local seatInfo = self.gameInfo.seatInfo[masterSeatId]
    local bottomCards = self.gameInfo.bottomCards

    local handCards = {}
    for _, card in ipairs(seatInfo.handCards) do
        table.insert(handCards, card)
    end
    for _, card in ipairs(bottomCards) do
        table.insert(handCards, card)
    end

    handCards = self.m_userdata:sortMyCards(handCards)

    self:addOneHand(handCards, masterSeatId)
    self:placeHandCards()
end

function class:showGameOver()
    Constants.stopScheduler(self)

    if self.m_cursor then
        self.m_cursor:removeFromParent()
        self.m_cursor = nil
    end

    for seatId = 1, Constants.kMaxPlayers do
        local seatInfo = self.gameInfo.seatInfo[seatId]
        local viewId = self:MapSeatToView(seatId)
        local pos = self:getHeadPos(viewId)

        local bgScore = Constants.get9Sprite("bg_score.png", cc.size(120,60),
                                        cc.p(pos.x, pos.y -125), self)
        bgScore:setAnchorPoint(0.5, 1.0)
               :setLocalZOrder(kPlayback_Z_Score)

        local strScore = string.format("%+d", seatInfo.deltaScore)

        local lbScore = Constants.getLabel(strScore, Constants.kBoldFontNamePF, 44, cc.p(0,0), bgScore)
        local bgSize = cc.size(math.max(120, lbScore:getContentSize().width+40), 60)
        bgScore:setContentSize(bgSize)
        lbScore:setPosition(bgSize.width * 0.5, bgSize.height * 0.5)
    end
end

return class
