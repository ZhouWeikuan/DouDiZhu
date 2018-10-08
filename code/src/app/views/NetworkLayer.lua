local class = class("NetworkLayer")
class.__index = class

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"
local protoTypes= require "ProtoTypes"

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

    cc.SpriteFrameCache:getInstance():addSpriteFrames("buttons.plist")

    self.delegate = delegate
    if delegate.m_netLoadingLayer then
        return nil
    end
    delegate.m_netLoadingLayer = self
    delegate:addChild(self, Constants.kLayerNetLoading)

    self:initLayer()
    self:showLayer()

    return self
end

function class:onEnter()
    local listenner = cc.EventListenerTouchOneByOne:create()
    listenner:setSwallowTouches(true)
    listenner:registerScriptHandler(function(touch, event)
        return true
    end,cc.Handler.EVENT_TOUCH_BEGAN)
    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listenner, self)
end

function class:onExit()
end

function class:initLayer()
    -- bg
    local winSize = display.size
    self.bgShadow = Constants.get9Sprite("bg_vague.png", winSize, cc.p(winSize.width * 0.5, winSize.height * 0.5), self)
    self.bgShadow:setOpacity(0)

    local bg = Constants.getSprite("bg_dialog_simple.png", cc.p(winSize.width * 0.5, winSize.height * 0.5), self)
    bg:setRotation(90)
    self.m_bg = bg
    local bgSize = bg:getContentSize()

    -- text
    local lbTxt = Constants.getLabel("返回游戏...", Constants.kSystemBoldName, 50,
                                    cc.p(bgSize.width * 0.5, bgSize.height * 0.5), bg)
    lbTxt:setColor(cc.c3b(93, 61, 4))
         :setAnchorPoint(0.3, 0.5)
         :setRotation(-90)

    -- loading
    local spLoading = Constants.getSprite("net_loading.png", cc.p(bgSize.width * 0.5, 130), bg)
    spLoading:runAction(cc.RepeatForever:create(cc.RotateBy:create(1.0, 120)))
end

function class:showLayer()
    if not self.m_bg then
        return
    end

    local act = cc.Sequence:create(cc.FadeTo:create(0.3, 255),
                                   cc.DelayTime:create(3),
                                   cc.FadeTo:create(0.1, 0))
    self.bgShadow:runAction(act)

    act = cc.Sequence:create(cc.EaseElasticOut:create(cc.ScaleTo:create(0.3, 1), 0.8),
                                   cc.DelayTime:create(2.8),
                                   cc.ScaleTo:create(0.1, 0),
                                   cc.CallFunc:create(function()
                                        self:hideLayer()
                                    end))
    self.m_bg:setScale(0)
             :runAction(act)
end

function class:hideLayer()
    self.delegate.m_netLoadingLayer = nil

    self:removeFromParent()
end

return class
