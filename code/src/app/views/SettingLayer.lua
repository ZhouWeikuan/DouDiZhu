local class = class("SettingLayer")
class.__index = class

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"

function class.extend(target)
    local t = tolua.getpeer(target)
    if not t then
        t = {}
        tolua.setpeer(target, t)
    end
    setmetatable(t, class)
    return target
end

function class.create()
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
    cc.SpriteFrameCache:getInstance():addSpriteFrames("propertylayer.plist")

    self:initBg()
    self:initLayer()
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
    end, cc.Handler.EVENT_TOUCH_BEGAN )

    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listenner, self)
end

function class:onExit()
end

function class:initBg()
    -- bg
    local winSize = display.size
    self.bgShadow = Constants.get9Sprite("bg_vague.png", winSize, cc.p(winSize.width * 0.5, winSize.height * 0.5), self)
    self.bgShadow:setOpacity(0)

    local bg = Constants.get9Sprite("bg_dialog_simple.png", cc.size(855, 654),
                                        cc.p(winSize.width * 0.5, winSize.height * 0.5), self)
    self.m_bg = bg

    local bgSize = bg:getContentSize()

    -- txt
    local lb = Constants.getLabel("声音设置", Constants.kSystemBoldName, 72,cc.p(bgSize.width * 0.5, 536), bg)
    lb:setColor(cc.c3b(93, 61, 4))

    lb = Constants.getLabel("音乐", Constants.kSystemBoldName, 48,cc.p(120, 420), bg)
    lb:setColor(cc.c3b(93, 61, 4))

    lb = Constants.getLabel("音效", Constants.kSystemBoldName, 48,cc.p(120, 290), bg)
    lb:setColor(cc.c3b(93, 61, 4))

    -- button
    local menu = cc.Menu:create()
    menu:setPosition(0,0)
            :addTo(bg)

    local item = Constants.getMenuItem("confirm")
    item:addTo(menu)
        :setPosition(bgSize.width * 0.5, 135)
        :registerScriptTapHandler(function()
            SoundApp.playEffect("sounds/main/click.mp3")
            self:closeLayer()
        end)
end

function class:initLayer()
    self:initMusicSlider()
    self:initSoundSlider()

    self:updateBtn()
end

function class:initMusicSlider()
    local function sliderEvent(sender, eventType)
        if eventType == ccui.SliderEventType.percentChanged then
            local vol = sender:getPercent() / 100
            SoundApp.setMusicVolume(vol)
        end
    end

    local vol = SoundApp.getMusicVolume()

    local slider = ccui.Slider:create()
    slider:setTouchEnabled(true)
    slider:loadBarTexture("set_sliderTrack.png", 1)
    slider:loadSlidBallTextures("set_slidball_normal.png", "set_slidball_hover.png", "", 1)
    slider:loadProgressBarTexture("set_sliderPrgrs.png", 1)
    slider:setPosition(cc.p(self.m_bg:getContentSize().width * 0.5, 420))
    slider:setPercent(vol * 100)
    self.m_bg:addChild(slider)
    slider:addEventListener(sliderEvent)

    self.m_musicSlider = slider
end

function class:initSoundSlider()
    local function sliderEvent(sender, eventType)
        if eventType == ccui.SliderEventType.percentChanged then
            local vol = sender:getPercent() / 100
            SoundApp.setEffectsVolume(vol)
        end
    end

    local vol = SoundApp.getEffectsVolume()

    local slider = ccui.Slider:create()
    slider:setTouchEnabled(true)
    slider:loadBarTexture("set_sliderTrack.png", 1)
    slider:loadSlidBallTextures("set_slidball_normal.png", "set_slidball_hover.png", "", 1)
    slider:loadProgressBarTexture("set_sliderPrgrs.png", 1)
    slider:setPosition(cc.p(self.m_bg:getContentSize().width * 0.5, 290))
    slider:setPercent(vol * 100)
    self.m_bg:addChild(slider)
    slider:addEventListener(sliderEvent)

    self.m_soundSlider = slider
end

function class:updateBtn()
    if not self.m_menu then
        self.m_menu = cc.Menu:create()
        self.m_menu:setPosition(0,0)
                   :addTo(self.m_bg)
    end

    self.m_menu:removeAllChildren()

    local item
    -- music
    if Settings.isMusicOn() then
        item = Constants.getMenuItem("music")
        self.m_musicSlider:setEnabled(true)
    else
        item = Constants.getMenuItem("music", false, "icon_off_normal.png", "icon_off_hover.png")
        self.m_musicSlider:setEnabled(false)
    end

    item:registerScriptTapHandler(function() self:toggleMusic() end)
    item:addTo(self.m_menu)
    item:setPosition(740, 420)

    -- sound effect
    if Settings.isSoundOn() then
        item = Constants.getMenuItem("sound")
        self.m_soundSlider:setEnabled(true)
    else
        item = Constants.getMenuItem("sound", false, "icon_off_normal.png", "icon_off_hover.png")
        self.m_soundSlider:setEnabled(false)
    end

    item:registerScriptTapHandler(function() self:toggleSound() end)
    item:addTo(self.m_menu)
    item:setPosition(740, 290)
end

function class:toggleMusic()
    SoundApp.playEffect("sounds/main/click.mp3")

    Settings.setMusicOn(not Settings.isMusicOn())
    SoundApp.playBackMusic("music/Welcome.mp3")
    self:updateBtn()
end

function class:toggleSound()
    SoundApp.playEffect("sounds/main/click.mp3")

    Settings.setSoundOn(not Settings.isSoundOn())
    self:updateBtn()
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
    if self.m_bg and self.m_bg:getNumberOfRunningActions() == 0 then
        self.m_bg:runAction(cc.Sequence:create(cc.ScaleTo:create(0.1, 0),
                                               cc.CallFunc:create(function()
                                                    self:removeFromParent()
                                                end)))
    end
end

return class
