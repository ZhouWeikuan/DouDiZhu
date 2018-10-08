local class = class("AboutLayer")
class.__index = class

local Constants = require "Constants"
local SoundApp  = require "SoundApp"

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

    local bg = Constants.get9Sprite("bg_dialog_frame.png", cc.size(1314, 974),
                                        cc.p(winSize.width * 0.5, winSize.height * 0.5), self)
    self.m_bg = bg
    local bgSize = bg:getContentSize()

    -- title
    local lb = Constants.getLabel("宽立同城斗地主", Constants.kSystemBoldName, 70, cc.p(bgSize.width * 0.5, 865), bg)
    lb:setColor(cc.c3b(93, 61, 4))

    -- version
    lb = Constants.getLabel("版本: 1.0.2", Constants.kSystemBoldName, 35, cc.p(1252, 826), bg)
    lb:setColor(cc.c3b(93, 61, 4))
      :setAnchorPoint(1, 0.5)

    -- button
    local menu = cc.Menu:create()
    menu:setPosition(0,0)
            :addTo(bg)

    local item = Constants.getMenuItem("confirm")
    item:addTo(menu)
        :setPosition(bgSize.width * 0.5, 106)
        :registerScriptTapHandler(function()
            SoundApp.playEffect("sounds/main/click.mp3")
            self:closeLayer()
        end)
end

function class:initLayer()
    local bgSize = self.m_bg:getContentSize()
    local bg = Constants.get9Sprite("bg_dialog_inner.png", cc.size(1200, 598), cc.p(bgSize.width * 0.5, 488), self.m_bg)

    -- qr code
    Constants.getSprite("about_qr.png", cc.p(218.5, 299), bg)

    -- text
    local str = "        如游戏中遇到问题,请扫描左侧二维码加入客服群向群主咨询,或手动添加客服QQ群号:"
    local lb = Constants.getLabel(str, Constants.kSystemBoldName, 35, cc.p(818, 493), bg)
    lb:setColor(cc.c3b(93, 61, 4))
      :setWidth(666)

    str = "543221539"
    lb = Constants.getLabel(str, Constants.kSystemBoldName, 35, cc.p(580, 453), bg)
    lb:setColor(cc.c3b(255, 0, 0))
      :setAnchorPoint(0, 0.5)

    str = "        本游戏诚招代理,更多详情及待遇请咨询微信:"
    lb = Constants.getLabel(str, Constants.kSystemBoldName, 35, cc.p(818, 353), bg)
    lb:setColor(cc.c3b(93, 61, 4))
      :setWidth(666)

    str = "qmkdd001"
    lb = Constants.getLabel(str, Constants.kSystemBoldName, 35, cc.p(610, 333), bg)
    lb:setColor(cc.c3b(255, 0, 0))
      :setAnchorPoint(0, 0.5)

    str = "© 2018 CronlyGames Ins 上海宽立信息技术有限公司"
    lb = Constants.getLabel(str, Constants.kSystemBoldName, 25, cc.p(1114, 73), bg)
    lb:setColor(cc.c3b(93, 61, 4))
      :setAnchorPoint(1, 0.5)

    local width = lb:getContentSize().width

    str = "沪ICP备16043106号"
    lb = Constants.getLabel(str, Constants.kSystemBoldName, 25, cc.p(1114 - width, 40), bg)
    lb:setColor(cc.c3b(93, 61, 4))
      :setAnchorPoint(0, 0.5)

    str = "《宽立游戏用户协议》"
    lb = Constants.getLabel(str, Constants.kSystemBoldName, 25, cc.p(1114, 40), bg)
    lb:setColor(cc.c3b(255, 0, 0))
      :setAnchorPoint(1, 0.5)

    local drawNode = cc.DrawNode:create()
    bg:addChild(drawNode)
    drawNode:drawLine(cc.p(870, 25), cc.p(1102, 25), cc.c4f(1,0,0,1))

    -- invisible button
    local menu = cc.Menu:create()
    menu:setPosition(0,0)
            :addTo(bg)

    local spButton = Constants.get9Sprite("bg_sheer.png", cc.size(240, 50))
    local item = cc.MenuItemSprite:create(spButton, spButton)
    item:addTo(menu)
        :setPosition(985, 40)
        :registerScriptTapHandler(function()
            cc.Application:getInstance():openURL("http://www.cronlygames.com")
        end)
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
