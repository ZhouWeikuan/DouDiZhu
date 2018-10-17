local class = class("QuitRoomConfirmLayer")
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

function class.create(delegate, hasStarted)
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

    self.delegate       = delegate -- CommonLayer
    self.m_hasStarted   = hasStarted

    self:setOutSideListener()
    self:resetLayer()
    self:showLayer()

    return self
end

function class:onEnter()
end

function class:onExit()
end

function class:cancelExit ()
    SoundApp.playEffect("sounds/main/click.mp3")

    self:closeLayer()
end

function class:confirmExit ()
    SoundApp.playEffect("sounds/main/click.mp3")

    local tableInfo = self.delegate.agent.tableInfo
    local seatInfo = tableInfo.gameInfo.seatInfo

    if seatInfo == nil then
        self.delegate:quitGame()
    end

    self:closeLayer()
end

function class:showExitScreen ()
    local bg = self.m_bg

    local text = "        游戏未开始，是否提前退出？房间创建后保留十分钟，十分钟后无人在房间则提前关闭，房间内有人则最多保留8小时。十分钟内点击房间列表加入游戏。"
    local lbTxt = Constants.getLabel(text, Constants.kSystemBoldName, 48,cc.p(427.5, 380), bg)
    lbTxt:setWidth(675)
         :setColor(cc.c3b(93, 61, 4))

    local menu = bg.menu

    local item = Constants.getMenuItem("rm_back")
    item:addTo(menu)
        :setPosition(258.5, 106)
        :registerScriptTapHandler(function()
                self:cancelExit()
            end)

    item = Constants.getMenuItem("confirm")
    item:addTo(menu)
        :setPosition(596.5, 106)
        :registerScriptTapHandler(function()
                self:confirmExit()
            end)
end

function class:showStartScreen ()
    local bg = self.m_bg

    local text = "        游戏已开始，是否提前投票退出？退出后房间关闭并统计分数，点击确定后开始投票表决。"
    local lbTxt = Constants.getLabel(text, Constants.kSystemBoldName, 48,cc.p(427.5, 380), bg)
    lbTxt:setWidth(675)
         :setColor(cc.c3b(93, 61, 4))

    local menu = bg.menu

    local item = Constants.getMenuItem("rm_back")
    item:addTo(menu)
        :setPosition(258.5, 106)
        :registerScriptTapHandler(function()
            self:cancelExit()
        end)

    item = Constants.getMenuItem("confirm")
    item:addTo(menu)
        :setPosition(596.5, 106)
        :registerScriptTapHandler(function()
            self.delegate:voteExit()
            self:removeFromParent()
        end)
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

    local menu = cc.Menu:create()
    menu:setPosition(0,0)
            :addTo(bg)

    bg.menu = menu

    if self.m_hasStarted then
        self:showStartScreen()
    else
        self:showExitScreen()
    end
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
                                                    self:removeFromParent()
                                                    end)))
    self.bgShadow:stopAllActions()
    self.bgShadow:runAction(cc.FadeTo:create(0.2, 0))
end

return class
