local class = class("ClockLayer")
class.__index = class

local Constants = require "Constants"
local SoundApp = require "SoundApp"
local Settings = require "Settings"
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

    return self
end

function class:onEnter()
    Constants.startScheduler(self, self.tickFrame, 0.3)
end

function class:onExit()
    Constants.stopScheduler(self)
end

function class:tickFrame (dt)
    self:updateClockTimeout()
    self:updateCounterListTimeout()
end

function class:initClock()
    local spClock = cc.Sprite:createWithSpriteFrameName("clock_panel.png")
    self:addChild(spClock, Constants.kLayerBack)

    local winSize = display.size
    spClock:setPosition(winSize.width * 0.5, 824)

    local arrowRot = {90, 0, 180}
    local clockSize = spClock:getContentSize()

    spClock.spPointers = {}
    for viewId, angle in ipairs(arrowRot) do
        local arrow = cc.Sprite:createWithSpriteFrameName("clock_pointer.png")
        arrow:addTo(spClock, -1)
            :setPosition(49, 55)
            :setAnchorPoint(cc.p(-0.2, 0.5))
            :setRotation(angle)
            :setVisible(false)
        spClock.spPointers[viewId] = arrow
    end

    local lbl = Constants.getLabel("0", Constants.kBoldFontNamePF, 42,
                    cc.p(clockSize.width * 0.5, clockSize.height * 0.58), spClock)
    lbl:enableOutline(cc.c4b(0x00, 0x36, 0x71, 255), 5)
    spClock.lblTimeout = lbl

    return spClock
end

function class:resetCounterListTimeout (timeout)
    local list = {10, 5, 2}
    self.m_counter_list_timeout = {}
    for _, num in pairs(list) do
        if timeout > num then
            local value = skynet.time() + timeout - num
            if num == 2 then
                self.m_counter_list_timeout[value] = "sounds/main/timeup.mp3"
            else
                self.m_counter_list_timeout[value] = "sounds/main/remind.mp3"
            end
        end
    end
end

function class:updateCounterListTimeout ()
    if not self.m_counter_list_timeout then
        return
    end

    local now = skynet.time()
    local removed = {}

    for k, v in pairs(self.m_counter_list_timeout) do
        if now >= k then
            SoundApp.playEffect(v)
            removed[k] = true
        end
    end

    for k, v in pairs(removed) do
        self.m_counter_list_timeout[k] = nil
    end
end

function class:updateClockTimeout()
    if not self.m_spClock then
        return
    end

    local timeout = math.floor(self.m_timeout - skynet.time())
    if timeout < 0 then timeout = 0 end

    local str = string.format("%d", timeout)
    if str ~= self.m_spClock.lblTimeout:getString() then
        self.m_spClock.lblTimeout:stopAllActions()
        self.m_spClock.lblTimeout:setScale(1.0)
        self.m_spClock.lblTimeout:setString(str)

        if timeout < 6 then
            self.m_spClock.lblTimeout:setScale(2.0)
            self.m_spClock.lblTimeout:runAction(cc.ScaleTo:create(0.5, 1.0))
        end
    end
end

function class:repaintClock(mask, timeout)
    if mask and mask > 0 then
        if self.m_spClock then
            self.m_spClock:setVisible(true)
        end
        self:resetCounterListTimeout(timeout)
    else
        if self.m_spClock then
            self.m_spClock:setVisible(false)
        end
        self.m_counter_list_timeout = nil
    end

    local spClock = self.m_spClock
    if not spClock then
        spClock = self:initClock()
        self.m_spClock = spClock
    else
        spClock:setVisible(true)
    end

    local pointers = spClock.spPointers
    for viewId=1,Constants.kMaxPlayers do
        pointers[viewId]:setVisible(false)
    end

    local seats = self.delegate:Mask2Seat(mask)
    for _, seatId in pairs(seats) do
        local viewId = self.delegate:MapSeatToView(seatId)
        pointers[viewId]:setVisible(true)
    end

    self.m_timeout = skynet.time() + timeout
    self:updateClockTimeout()
end

function class:repaintSeatClock(seatId)
    if seatId and seatId > 0 then
        if self.m_spClock then
            self.m_spClock:setVisible(true)
        end
    else
        if self.m_spClock then
            self.m_spClock:setVisible(false)
        end
        self.m_counter_list_timeout = nil
    end

    local spClock = self.m_spClock
    if not spClock then
        spClock = self:initClock()
        self.m_spClock = spClock
    else
        spClock:setVisible(true)
    end

    local pointers = spClock.spPointers
    for viewId=1,Constants.kMaxPlayers do
        pointers[viewId]:setVisible(false)
    end

    local viewId = self.delegate:MapSeatToView(seatId)
    pointers[viewId]:setVisible(true)

    self.m_timeout = 0
    self.m_spClock.lblTimeout:setVisible(false)
end

return class
