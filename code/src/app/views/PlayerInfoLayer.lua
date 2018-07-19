local PlayerInfoLayer = class("PlayerInfoLayer")
PlayerInfoLayer.__index = PlayerInfoLayer

local Constants = require("Constants")
local Settings  = require "Settings"
local SoundApp  = require("SoundApp")
local const = require("Const_YunCheng")
local UIHelper = require("UIHelper")

function PlayerInfoLayer.extend(target)
    local t = tolua.getpeer(target)
    if not t then
        t = {}
        tolua.setpeer(target, t)
    end
    setmetatable(t, PlayerInfoLayer)
    return target
end

function PlayerInfoLayer.create(delegate,seatId)
    cc.SpriteFrameCache:getInstance():addSpriteFrames("buttons.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("propertylayer.plist")

    local self = PlayerInfoLayer.extend(cc.Layer:create())

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

    self.delegate = delegate  -- backlayer
    self.agent = self.delegate.agent

    self.seatId = seatId
    self.viewId = self.delegate:MapSeatToView(seatId)
    self:initAll()

    return self
end

function PlayerInfoLayer:onEnter()

end

function PlayerInfoLayer:onExit()

end

function PlayerInfoLayer:getFramePos()
    local viewId = self.viewId
    local pos = cc.p(0, 0)
    if viewId < 1 or viewId > Constants.kMaxPlayers then
        return pos
    end

    local winSize = display.size

    local framePos = {
        cc.p(540, 463),
        cc.p(winSize.width - 540, 704),
        cc.p(540, 704)
    }

    pos = framePos[viewId]
    return pos
end

function PlayerInfoLayer:showPlayerHead(frameSp,user)
    local viewId = self.viewId
    local bgSize = frameSp:getContentSize()

    local bgHead, spRole = UIHelper.makeBaseHead()
    bgHead:addTo(frameSp)
          :setPosition(30, bgSize.height - 30)
          :setAnchorPoint(0, 1)

    if user then
        Constants.getUserHeadSprite(spRole, user)
    end
end

function PlayerInfoLayer:showPlayerCoin(frameSp,user)
    local viewId = self.viewId
    local bgSize = frameSp:getContentSize()

    local coinSp = Constants.getSprite("player_coin.png", cc.p(30, bgSize.height - 260), frameSp)
    coinSp:setAnchorPoint(0, 1)

    local strCoin = string.format("%d", user.FCounter or 0)
    local lbCoin = Constants.getLabel(strCoin, Constants.kSystemBoldName, 35, cc.p(136, 30), coinSp)
    lbCoin:setColor(cc.c3b(0xfb,0xce,0x32))
end

function PlayerInfoLayer:showPlayerInfo(frameSp,user)
    local viewId = self.viewId
    local bgSize = frameSp:getContentSize()
    local inforSp = Constants.getSprite("player_information.png", cc.p(bgSize.width - 30, bgSize.height - 30), frameSp)
    inforSp:setAnchorPoint(1,1)

    local name = user.FNickName or ""
    local namelbl = Constants.getLabel(name, Constants.kSystemBoldName, 35, cc.p(145, 250), inforSp)
    namelbl:setAnchorPoint(0,0.5)

    local rank = const.findLevelRank(user.FScore or 0)
    local rankName = const.findLevelName(rank)
    local strLv = string.format("Lv.%d %s", rank, rankName)
    local levellbl = Constants.getLabel(strLv, Constants.kSystemBoldName, 35, cc.p(145, 180), inforSp)
    levellbl:setAnchorPoint(0,0.5)

    local winPerct = 100
    local winCount = user.FWins or 0
    local loseCount = user.FLoses or 0
    if winCount > 0 or loseCount > 0 then
        winPerct = math.floor(winCount * 100 / (winCount + loseCount))
    end

    local strWinPerct = string.format("%d%%", winPerct)
    local winlbl = Constants.getLabel(strWinPerct, Constants.kSystemBoldName, 30, cc.p(145, 110), inforSp)
    winlbl:setAnchorPoint(0,0)

    local strWinLose = string.format("(%d胜 %d败)", winCount, loseCount)
    local winLoselbl = Constants.getLabel(strWinLose, Constants.kSystemBoldName, 30, cc.p(145, 110), inforSp)
    winLoselbl:setAnchorPoint(0,1)

    local strScore = string.format("%d", (user.FScore or 0))
    if rank == 1 and user.FScore < const.levelScores[1] then
        strScore = string.format("(%d/%d)", (user.FScore or 0), const.levelScores[1])
    elseif rank >= #const.levelScores then
        strScore = "(MAX)"
    else
        strScore = string.format("(%d/%d)", (user.FScore or 0) - const.levelScores[rank], const.levelScores[rank + 1] - const.levelScores[rank])
    end

    local scoreLb = Constants.getLabel(strScore, Constants.kSystemBoldName, 35, cc.p(145, 40), inforSp)
    scoreLb:setAnchorPoint(0,0.5)
end

function PlayerInfoLayer:showGiftInfo(frameSp,user)
    local viewId = self.viewId
    if viewId ~= 1 then
        local bgSize = frameSp:getContentSize()
        local rodSp = Constants.getSprite("player_rod.png", cc.p(bgSize.width * 0.5, 200), frameSp)

        local giftMenu = cc.Menu:create()
        giftMenu:addTo(frameSp)
                :setPosition(0, 0)

        local gifts = {"egg", "water", "flower","kiss"}
        for i, name in ipairs(gifts) do
            local giftName = name
            local giftCoin = const.kGiftItems[name]
            local item = Constants.getMenuItem("gift")
            item:registerScriptTapHandler(function()
                    self:doGift(giftName, self.seatId)
                end)
            item:addTo(giftMenu)
                :setPosition( 100 + (i-1)*170, 100)

            local giftSp = Constants.getSprite(string.format("gift_%s.png", giftName), cc.p(70, 93), item)
            giftSp:setScale(1.5)

            if i == 2 then
                giftSp:setScale(1.3)
            end

            local lbl = Constants.getLabel("限免",
                                            Constants.kBoldFontName,
                                            25,
                                            cc.p(70, 31),
                                            item)
            lbl:setAnchorPoint(cc.p(0.5, 0.5))
               :setColor(cc.c3b(0xfb,0xce,0x32))
        end
    end
end

function PlayerInfoLayer:getSprite()
    local viewId = self.viewId
    local user = self.agent:GetUserAtSeat(self.seatId)

    local frameSp = ccui.Scale9Sprite:createWithSpriteFrameName("player_frame.png")
    if viewId == 1 then
        frameSp:setContentSize(710, 355)
    else
        frameSp:setContentSize(710, 545)
    end

    self:showPlayerCoin(frameSp,user)
    self:showPlayerHead(frameSp,user)
    self:showPlayerInfo(frameSp,user)
    self:showGiftInfo(frameSp,user)

    return frameSp
end

function PlayerInfoLayer:initAll()
    local size      = display.size

    local icon_frameSp = self:getSprite()
    local pos = self:getFramePos()
    icon_frameSp:addTo(self)
                :setPosition(pos)

    local rect = icon_frameSp:getBoundingBox()
    local startPos = UIHelper.getPlayerPosByViewId(self.viewId)

    local anchX = (startPos.x - cc.rectGetMinX(rect)) / rect.width
    local anchY = (startPos.y - cc.rectGetMinY(rect)) / rect.height

    icon_frameSp:setAnchorPoint(anchX, anchY)
                :setPosition(startPos)

    icon_frameSp:setScale(0)
                :runAction(cc.EaseElasticOut:create(cc.ScaleTo:create(0.3, 1), 0.8))

    self.frame = icon_frameSp

    local listener = cc.EventListenerTouchOneByOne:create()
    listener:setSwallowTouches(true)

    listener:registerScriptHandler(function(touch, event)
        return true
        end,cc.Handler.EVENT_TOUCH_BEGAN )

    listener:registerScriptHandler(function(touch, event)

        end,cc.Handler.EVENT_TOUCH_MOVED )

    listener:registerScriptHandler(function(touch, event)
        local pos = touch:getLocation()
        local rect = self.frame:getBoundingBox()

        if (not cc.rectContainsPoint(rect, pos))
            and icon_frameSp:getNumberOfRunningActions() == 0 then
                self:closeLayer()
        end

        end,cc.Handler.EVENT_TOUCH_ENDED )

    listener:registerScriptHandler(function(touch, event)
        end,cc.Handler.EVENT_TOUCH_CANCELLED )
    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listener, self)

    return true
end

function PlayerInfoLayer:doGift(giftName, getId)
    SoundApp.playEffect("sounds/main/click.mp3")
    self.agent:sendGiftOptions(giftName, getId)

    self.delegate.m_playerInfoLayer = nil
    self:removeFromParent()
end

function PlayerInfoLayer:closeLayer()
    SoundApp.playEffect("sounds/main/click.mp3")
    self.frame:runAction(cc.Sequence:create(cc.ScaleTo:create(0.1, 0),
                                                  cc.CallFunc:create(function()
                                                        self.delegate.m_playerInfoLayer = nil
                                                        self:removeFromParent()
                                                        end)))
end

return PlayerInfoLayer
