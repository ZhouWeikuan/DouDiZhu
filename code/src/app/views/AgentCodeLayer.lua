local class = class("AgentCodeLayer")
class.__index = class

local Constants = require("Constants")
local SoundApp = require("SoundApp")
local Settings = require("Settings")

local protoTypes = require("ProtoTypes")
local packetHelper = require "PacketHelper"

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

    self.delegate = delegate

    self.m_inputTxts = {}

    self:initBg()
    self:initUI()
    self:showLayer()
    return self
end

function class:onEnter()
    local listenner = cc.EventListenerTouchOneByOne:create()
    listenner:setSwallowTouches(true)
    listenner:registerScriptHandler(function(touch, event)
            if self.m_bg then
                local pos = self:convertToNodeSpace(touch:getLocation())
                local rect = self.m_bg:getBoundingBox()
                if not cc.rectContainsPoint(rect, pos) then
                    self:closeLayer()
                end
            end

            return true

        end,cc.Handler.EVENT_TOUCH_BEGAN )

    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listenner, self)
end

function class:onExit()
end

function class:showLayer()
    if self.m_bg then
        self.m_bgShadow:runAction(cc.FadeTo:create(0.2, 255))

        self.m_bg:setScale(0)
                 :runAction(cc.EaseElasticOut:create(cc.ScaleTo:create(0.3, 1), 0.8))
    end
end

function class:closeLayer()
    if self.m_bg and self.m_bg:getNumberOfRunningActions() == 0 then
        self.m_bg:runAction(cc.Sequence:create(cc.ScaleTo:create(0.1, 0),
                                              cc.CallFunc:create(function()
                                                    self:removeFromParent()
                                                    end)))

    end
end

function class:initBg()
    local winSize = display.size

    self.m_bgShadow = Constants.get9Sprite("bg_vague.png",
                            cc.size(winSize.width, winSize.height),
                            cc.p(winSize.width * 0.5 , winSize.height * 0.5),
                            self)
    self.m_bgShadow:setOpacity(0)

    local bg = Constants.get9Sprite("bg_dialog_frame.png",
                                cc.size(1000, 974),
                                cc.p(winSize.width * 0.5 , winSize.height * 0.5),
                                self)
    self.m_bg = bg

    -- txt
    local lb = Constants.getLabel("请输入邀请码", Constants.kSystemBoldName, 72, cc.p(500, 840), bg)
    lb:setColor(cc.c3b(93, 61, 4))
end

function class:initUI()
    local bgEdit = ccui.Scale9Sprite:createWithSpriteFrameName("rm_num_bg.png", cc.rect(30,30,20,20))
    bgEdit:addTo(self.m_bg)
          :setContentSize(cc.size(800, 100))
          :setPosition(500, 670)
    self.m_bgEdit = bgEdit

    -- 按钮
    local menu = cc.Menu:create()
    menu:addTo(self.m_bg)
    menu:setPosition(cc.p(0,0))

    local pos = cc.p(220, 508)
    for i = 1,12 do
        if i == 11 then
            local spBack = Constants.getMenuItem("confirm")
            spBack:addTo(menu)
                  :setPosition(cc.p(220,155))

            spBack:registerScriptTapHandler(function() self:clickOk() end)
        elseif i == 12 then
            local spDel = Constants.getMenuItem("rm_del")
            spDel:addTo(menu)
                 :setPosition(cc.p(790,155))
            spDel:registerScriptTapHandler(function() self:clickDel() end)
        else
            local num = i
            if i == 10 then
                num = 0
                pos = cc.p(500,160)
            end
            local item = Constants.getMenuItem("rm_num")
            item:addTo(menu)
                :setPosition(pos)

            local btnSize = item:getContentSize()

            if num then
                local strNum = string.format("%d", num)
                local pnt = cc.p(btnSize.width*0.5,btnSize.height*0.57)
                local lbTxt = Constants.getLabel(strNum, Constants.kBoldFontNamePF, 72, pnt, item)
                lbTxt:setColor(cc.c3b(0x5d, 0x3d, 0x04))

                item:registerScriptTapHandler(function() self:clickNum(num) end)
            end
            if i % 3 == 0 then
                pos.x = 220
                pos.y = pos.y - btnSize.height - 10
            else
                pos.x = pos.x + btnSize.width + 30
            end
        end
    end
end

function class:clickNum(num)
    SoundApp.playEffect("sounds/main/click.mp3")

    if #self.m_inputTxts >= 10 then
        return
    end

    local bgEdit = self.m_bgEdit
    local strNum = string.format("%d", num)
    local lbTxt = Constants.getLabel(strNum, Constants.kBoldFontNamePF, 60, cc.p(0,0), bgEdit)
    lbTxt:setColor(cc.c3b(0x5d, 0x3d, 0x04))
    table.insert(self.m_inputTxts, lbTxt)

    self:updateInputNum()
end

function class:updateInputNum()
    local space = 60
    local count = #self.m_inputTxts
    if count > 0 then
        local bgSize = self.m_bgEdit:getContentSize()
        local posx = (bgSize.width - space * (count - 1)) * 0.5
        local posy = 50

        for _,lbTxt in ipairs(self.m_inputTxts) do
            lbTxt:setPosition(posx, posy)
            posx = posx + space
        end
    end
end

function class:clickOk()
    SoundApp.playEffect("sounds/main/click.mp3")

    local strInput = ""
    for _,one in ipairs(self.m_inputTxts) do
        if one:getString() == "" then
            break
        else
            strInput = strInput .. one:getString()
        end
    end

    if strInput ~= "" then
        local info = {
            FUserCode   = self.delegate.authInfo.userCode,
            FAgentCode  = tonumber(strInput),
        }

        local data      = packetHelper:encodeMsg("YunCheng.UserStatus", info)
        local packet    = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                                protoTypes.CGGAME_PROTO_SUBTYPE_MYSTATUS, data)

        self.delegate.agent:sendPacket(packet)

        self:closeLayer()
    end
end

function class:clickDel()
    SoundApp.playEffect("sounds/main/click.mp3")

    local count = #self.m_inputTxts
    self.m_inputTxts[count]:removeFromParent()
    table.remove(self.m_inputTxts, count)
    self:updateInputNum()
end

return class
