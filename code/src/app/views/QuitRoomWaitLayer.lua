local class = class("QuitRoomWaitLayer")
class.__index = class

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"

local protoTypes = require "ProtoTypes"

function class.extend(target)
    local t = tolua.getpeer(target)
    if not t then
        t = {}
        tolua.setpeer(target, t)
    end
    setmetatable(t, class)
    return target
end

function class.create(delegate)
    cc.SpriteFrameCache:getInstance():addSpriteFrames("buttons.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("room.plist")

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

    self.delegate  = delegate -- CommonLayer
    self:setOutSideListener()
    self:resetLayer()
    self:showLayer()

    return self
end

function class:onEnter()
    Constants.startScheduler(self, self.tickFrame, 0.2)
end

function class:onExit()
    Constants.stopScheduler(self)
end

function class:tickFrame (dt)
    self:updateBottomStatus()
    self:update()
end

function class:updateMask ()
    local agent = self.delegate.agent
    local roomInfo  = agent.tableInfo.roomInfo
    local exitInfo  = roomInfo and roomInfo.exitInfo or nil
    if not exitInfo or not exitInfo.mask or not agent.selfSeatId then
        return
    end

    local bg = self.m_bg
    if exitInfo.ownerCode then
        local userInfo = agent:GetUserInfo(exitInfo.ownerCode)
        if userInfo and userInfo.FNickName then
            local text = string.format("%s 提议解散房间", userInfo.FNickName)
            bg.headLabel:setString(text)
        end
    end


    local lbls  = bg.m_status
    local icons = bg.m_icons
    local names = bg.m_names
    for seatId = 1, Constants.kMaxPlayers do
        if seatId ~= agent.selfSeatId then
            if (exitInfo.mask & (1 << seatId)) ~= 0 then
                lbls[seatId]:setString("同意")
                    :setColor(cc.c3b(0, 200, 0))
            else
                lbls[seatId]:setString("等待中")
                    :setColor(cc.c3b(93, 61, 4))
            end

            local user  = agent:GetUserAtSeat(seatId)
            if user and user.FNickName then
                names[seatId]:setString(user.FNickName)
            end

            Constants.getUserHeadSprite(icons[seatId], user)
        end
    end
end

function class:update (exitInfo)
    self:updateMask()

    if exitInfo and (not exitInfo.mask or exitInfo.mask == 0)
        and exitInfo.seatId and exitInfo.seatId > 0 and exitInfo.seatId <= Constants.kMaxPlayers then

        Constants.stopScheduler(self)

        if exitInfo.seatId == self.delegate.agent.selfSeatId then
            if (exitInfo.timeout or 0) < 0 then
                self.m_bg.myStatus:setString("您已经同意解散房间...")

            else
                self.m_bg.myStatus:setString("您已经拒绝解散房间...")

            end
        else
            if (exitInfo.timeout or 0) < 0 then
                self.m_bg.m_status[exitInfo.seatId]:setString("同意")
                                                   :setColor(cc.c3b(0, 200, 0))
            else
                self.m_bg.m_status[exitInfo.seatId]:setString("拒绝")
                                                   :setColor(cc.c3b(255, 0, 0))
            end
        end

        if self.m_bg.menu then
            self.m_bg.menu:removeFromParent()
            self.m_bg.menu = nil
        end

        self:delayedDisappear()
    end
end

function class:delayedDisappear ()
    local act = cc.Sequence:create(cc.DelayTime:create(2.0),
            cc.CallFunc:create(function ()
                self:closeLayer()
            end))
    self:runAction(act)
end

function class:updateBottomStatus ()
    local agent = self.delegate.agent
    local roomInfo  = agent.tableInfo.roomInfo
    local exitInfo  = roomInfo and roomInfo.exitInfo or nil
    if not exitInfo or not exitInfo.mask or not agent.selfSeatId then
        return
    end

    local time = (exitInfo.timeout or 0) - os.time()
    if time < 0 then
        time = 0
        self:delayedDisappear()
        self.delegate:voteExit()
    end

    local text
    local bg = self.m_bg
    if (exitInfo.mask & (1 << agent.selfSeatId)) == 0 then
        if not bg.menu then
            local menu = cc.Menu:create()
            bg.menu = menu
            menu:setPosition(0,0)
                :addTo(bg)

            local item = Constants.getMenuItem("exitroom_reject")
            item:addTo(menu)
                :setPosition(612, 138)
                :registerScriptTapHandler(function()
                    self.delegate:voteKeep()
                end)

            item = Constants.getMenuItem("exitroom_agree")
            item:addTo(menu)
                :setPosition(243, 138)
                :registerScriptTapHandler(function()
                    self.delegate:voteExit()
                end)
        end

        text = string.format("%d秒", time)
    else
        if bg.menu then
            bg.menu:removeFromParent()
            bg.menu = nil
        end

        text = string.format("您已同意，请等候其他玩家 %d秒", time)
    end
    bg.myStatus:setString(text)
end

function class:resetLayer()
    local winSize = display.size

    self.bgShadow = Constants.get9Sprite("bg_vague.png",
                    cc.size(winSize.width, winSize.height),
                    cc.p(winSize.width * 0.5 , winSize.height * 0.5),
                    self)
    self.bgShadow:setOpacity(0)

    local bg = Constants.get9Sprite("bg_dialog_simple.png",
        cc.size(855, 654),
        cc.p(winSize.width * 0.5 , winSize.height * 0.5),
        self)
    bg:setScale(0)
    self.m_bg = bg

    local bgSize = bg:getContentSize()

    local agent     = self.delegate.agent
    local tableInfo = agent.tableInfo
    local roomInfo  = tableInfo.roomInfo
    local exitInfo  = roomInfo and roomInfo.exitInfo or nil

    local text = "   有人   提议解散房间"
    if exitInfo and exitInfo.ownerCode then
        local userInfo = agent:GetUserInfo(exitInfo.ownerCode)
        if userInfo and userInfo.FNickName then
            text = string.format("%s 提议解散房间", userInfo.FNickName)
        end
    end

    local lbl = Constants.getLabel(text, Constants.kSystemBoldName, 48,cc.p(bgSize.width * 0.5, 560), bg)
    lbl:setColor(cc.c3b(93, 61, 4))
    bg.headLabel = lbl

    text = "超时后自动解散房间提前结算，已扣除元宝不予返还"
    lbl = Constants.getLabel(text, Constants.kSystemBoldName, 24,cc.p(bgSize.width * 0.5, 480), bg)
    lbl:setColor(cc.c3b(93, 61, 4))

    local idx = 0
    local gameInfo = tableInfo.gameInfo
    local seatInfo = gameInfo.seatInfo
    bg.m_status    = {}
    bg.m_icons     = {}
    bg.m_names     = {}
    for seatId = 1, Constants.kMaxPlayers do
        if seatId ~= agent.selfSeatId then
            local user  = agent:GetUserAtSeat(seatId)

            local headBg = cc.Sprite:createWithSpriteFrameName("bg_exitroom_role.png")
            headBg:addTo(bg)
                  :setPosition(cc.p(277.5 + 300 * idx, 390))

            local sten = cc.Sprite:createWithSpriteFrameName("bg_sten.png")
            local clipper = cc.ClippingNode:create()
            clipper:setStencil(sten)
            clipper:setAlphaThreshold(0.5)
                   :addTo(headBg)
                   :setScale(0.57)
                   :setPosition(60,60)

            local roleSp = cc.Sprite:createWithSpriteFrameName("icon_role0.png")
            roleSp:addTo(clipper)

            Constants.getUserHeadSprite(roleSp, user)

            bg.m_icons[seatId] = roleSp

            text = user and user.FNickName or ""
            local lbl = Constants.getLabel(text, Constants.kSystemBoldName, 30,cc.p(60, -30), headBg)
            lbl:setColor(cc.c3b(93, 61, 4))
            bg.m_names[seatId] = lbl

            text = "等待中"
            lbl = Constants.getLabel(text, Constants.kSystemBoldName, 30,cc.p(60, -66), headBg)
            lbl:setColor(cc.c3b(93, 61, 4))
            bg.m_status[seatId] = lbl

            idx = idx + 1
        end
    end

    lbl = Constants.getLabel("", Constants.kSystemBoldName, 48 ,cc.p(bgSize.width * 0.5, 138), bg)
    lbl:setColor(cc.c3b(93, 61, 4))
    bg.myStatus = lbl

    self:updateBottomStatus()
end

function class:setOutSideListener()
    local listener = cc.EventListenerTouchOneByOne:create()
    listener:setSwallowTouches(true)
    listener:setEnabled(true)

    listener:registerScriptHandler(function(touch, event)
            return true
        end, cc.Handler.EVENT_TOUCH_BEGAN)

    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listener, self)

    return true
end

function class:showLayer()
    self.m_bg:stopAllActions()
    self.m_bg:runAction(cc.EaseElasticOut:create(cc.ScaleTo:create(0.3, 1), 0.8))

    self.bgShadow:stopAllActions()
    self.bgShadow:runAction(cc.FadeTo:create(0.2, 255))
end

function class:closeLayer()
    self.m_bg:stopAllActions()
    self.m_bg:runAction(cc.Sequence:create(cc.ScaleTo:create(0.1, 0),
                                              cc.CallFunc:create(function()
                                                    self.delegate:removeQuitRoomWaitLayer()
                                                    end)))
    self.bgShadow:stopAllActions()
    self.bgShadow:runAction(cc.FadeTo:create(0.2, 0))
end

return class
