local class = class("HsPlayerInfo")
class.__index = class

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"
local const     = require "Const_YunCheng"

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
    cc.SpriteFrameCache:getInstance():addSpriteFrames("hallscene.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("buttons.plist")

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

    self.delegate = delegate

    self:initBg()
    self:initInfo(delegate.userInfo)

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
    end, cc.Handler.EVENT_TOUCH_BEGAN)
    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listenner, self)
end

function class:onExit()
end

function class:initBg()
    local winSize = display.size

    local bg = Constants.get9Sprite("bg_hs_info.png", cc.size(574,734), cc.p(3, 190), self)
    bg:setAnchorPoint(0, 0)
    self.m_bg = bg

    local bgSize = bg:getContentSize()
    local bgTitle = Constants.get9Sprite("bg_hs_infotitle.png", cc.size(540,70),
                                cc.p(bgSize.width * 0.5, bgSize.height -27), bg)
    bgTitle:setAnchorPoint(0.5, 1)

    Constants.getSprite("hs_msn.png", cc.p(169, 36), bgTitle)
    Constants.getSprite("hs_txt_info.png", cc.p(282, 34), bgTitle)
end

function class:initInfo(info)
    local bg = self.m_bg
    local bgSize = bg:getContentSize()

    -- 头像
    local headBg, roleSp = self.delegate:makeHead()
    headBg:setPosition(bgSize.width * 0.5, 503)
          :addTo(bg)
    Constants.getUserHeadSprite(roleSp, info)

    self:drawPlayerInfo(bg, info)
end

function class:drawPlayerInfo(bg, info)
    local bgSize = bg:getContentSize()
    local centerx = bgSize.width * 0.5
    local tbBg = {
        {size = cc.size(500, 40), opacity = 178, pos = cc.p(centerx, 372)},
        {size = cc.size(240, 40), opacity = 114, pos = cc.p(157, 312)},
        {size = cc.size(240, 40), opacity = 114, pos = cc.p(417, 312)},
        {size = cc.size(240, 40), opacity = 114, pos = cc.p(157, 252)},
        {size = cc.size(240, 40), opacity = 114, pos = cc.p(417, 252)},
        {size = cc.size(500, 40), opacity = 114, pos = cc.p(centerx, 192)},
        {size = cc.size(500, 40), opacity = 114, pos = cc.p(centerx, 132)},
        {size = cc.size(500, 40), opacity = 114, pos = cc.p(centerx, 72)}
    }

    local tbInfo = {
        {valPos = cc.p(250,20), valAnch = cc.p(0.5,0.5)},
        {infoKey = "胜",   keyPos = cc.p(15,20), valPos = cc.p(230,20), valAnch = cc.p(1,0.5)},
        {infoKey = "负",   keyPos = cc.p(15,20), valPos = cc.p(230,20), valAnch = cc.p(1,0.5)},
        {infoKey = "胜率", keyPos = cc.p(15,20), valPos = cc.p(230,20), valAnch = cc.p(1,0.5)},
        {infoKey = "积分", keyPos = cc.p(15,20), valPos = cc.p(230,20), valAnch = cc.p(1,0.5)},
        {infoKey = "等级", keyPos = cc.p(15,20), valPos = cc.p(490,20), valAnch = cc.p(1,0.5)},
        {infoKey = "元宝", keyPos = cc.p(15,20), valPos = cc.p(490,20), valAnch = cc.p(1,0.5)},
        {infoKey = "代理", keyPos = cc.p(15,20), valPos = cc.p(490,20), valAnch = cc.p(1,0.5)}
    }

    info.FWins = info.FWins or 0
    info.FLoses = info.FLoses or 0
    local rate = (info.FWins + info.FLoses >= 1) and (info.FWins * 1.0 / (info.FWins + info.FLoses)) or 0
    local level = const.findLevelRank(info.FScore or 0)
    level = const.findLevelName(level)
    local values  = {
        info.FNickName or "",
        string.format("%d", info.FWins or 0),
        string.format("%d", info.FLoses or 0),
        string.format("%2.2f%%", rate * 100),
        string.format("%d", info.FScore or 0),
        string.format("%s", level),
        string.format("%d", info.FCounter or 0),
        info.FAgentCode and info.FAgentCode > 0 and info.FAgentCode or "代理未绑定",
    }

    for i, one in ipairs(tbInfo) do
        local bgTxt = Constants.get9Sprite("bg_hs_infoitem.png", tbBg[i].size,
                                tbBg[i].pos, bg)
        bgTxt:setOpacity(tbBg[i].opacity)

        local strKey = one.infoKey
        if strKey then
            local bgLbl = Constants.getLabel(strKey, Constants.kBoldFontName, 27, one.keyPos, bgTxt)
            bgLbl:setAnchorPoint(0, 0.5)
        end

        local infoLbl = Constants.getLabel(values[i], Constants.kBoldFontName, 27, one.valPos, bgTxt)
        infoLbl:setAnchorPoint(one.valAnch)
    end
end

function class:showLayer(startPos)
    local winSize = display.size

    local rect = self.m_bg:getBoundingBox()
    local anchX = (startPos.x - cc.rectGetMinX(rect)) / rect.width
    local anchY = (startPos.y - cc.rectGetMinY(rect)) / rect.height

    self.m_bg:setAnchorPoint(anchX, anchY)
             :setPosition(startPos)
             :setScale(0)
             :runAction(cc.EaseElasticOut:create(cc.ScaleTo:create(0.3, 1), 0.8))
end

function class:closeLayer()
    if self.m_bg and self.m_bg:getNumberOfRunningActions() == 0 then
        self.delegate:removePlayerInfo()
        self.m_bg:runAction(cc.Sequence:create(cc.ScaleTo:create(0.1, 0),
                                              cc.CallFunc:create(function()
                                                    self:removeFromParent()
                                                    end)))
    end
end

return class
