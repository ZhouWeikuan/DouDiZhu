local class = class("MsgBox")
class.__index = class

local Constants = require("Constants")
local SoundApp = require("SoundApp")
local Settings = require("Settings")
local protoTypes = require("ProtoTypes")

function class.extend(target)
    local t = tolua.getpeer(target)
    if not t then
        t = {}
        tolua.setpeer(target, t)
    end
    setmetatable(t, class)
    return target
end

function class.create(strMsg)
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

    cc.SpriteFrameCache:getInstance():addSpriteFrames("buttons.plist")

    self:initLayer(strMsg)
    self:showLayer()

    return self
end

function class:onEnter()
    local listenner = cc.EventListenerTouchOneByOne:create()
    listenner:setSwallowTouches(true)
    listenner:registerScriptHandler(function(touch, event)
        if self.m_bg then
            local rect = self.m_bg:getBoundingBox()
            local pos = self:convertToNodeSpace(touch:getLocation())
            if cc.rectContainsPoint(rect, pos) then
            else
                self:closeLayer()
            end
        end
        return true
    end,cc.Handler.EVENT_TOUCH_BEGAN)
    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listenner, self)
end

function class:onExit()
end

function class:initLayer(strMsg)
    -- bg
    local winSize = display.size
    self.bgShadow = Constants.get9Sprite("bg_vague.png", winSize, cc.p(winSize.width * 0.5, winSize.height * 0.5), self)
    self.bgShadow:setOpacity(0)

    local bg = Constants.get9Sprite("bg_dialog_simple.png", cc.size(855, 654),
                                        cc.p(winSize.width * 0.5, winSize.height * 0.5), self)
    self.m_bg = bg
    local bgSize = bg:getContentSize()

    -- button
    local menu = cc.Menu:create()
    menu:setPosition(0,0)
            :addTo(bg)

    local item = Constants.getMenuItem("confirm")
    item:addTo(menu)
        :setPosition(bgSize.width * 0.5, 106)
        :registerScriptTapHandler(function()
            self:closeLayer()
        end)

    -- text
    local lbTxt = Constants.getLabel("提示", Constants.kSystemBoldName, 72,cc.p(bgSize.width * 0.5, 530), bg)
    lbTxt:setColor(cc.c3b(93, 61, 4))

    lbTxt = Constants.getLabel(strMsg, Constants.kSystemBoldName, 48,cc.p(bgSize.width * 0.5, 380), bg)
    lbTxt:setColor(cc.c3b(93, 61, 4))
    if lbTxt:getContentSize().width > 675 then
        lbTxt:setWidth(675)
    end
end

function class:showLayer()
    if not self.m_bg then
        return
    end

    self.bgShadow:runAction(cc.FadeTo:create(0.2, 255))

    self.m_bg:setScale(0)
             :runAction(cc.EaseElasticOut:create(cc.ScaleTo:create(0.3, 1), 0.8))
end

function class:closeLayer()
    SoundApp.playEffect("sounds/main/click.mp3")

    if self.m_bg and self.m_bg:getNumberOfRunningActions() == 0 then
        self.m_bg:runAction(cc.Sequence:create(cc.ScaleTo:create(0.1, 0),
                                               cc.CallFunc:create(function()
                                                    self:removeFromParent()
                                                end)))
    end
end

return class
