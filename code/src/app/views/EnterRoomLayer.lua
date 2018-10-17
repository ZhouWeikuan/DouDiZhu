local class = class("EnterRoomLayer")
class.__index = class

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"

local packetHelper  = require "PacketHelper"

local protoTypes    = require "ProtoTypes"

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

        end, cc.Handler.EVENT_TOUCH_BEGAN )

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
    local lb = Constants.getLabel("输入房号", Constants.kSystemBoldName, 72, cc.p(500, 840), bg)
    lb:setColor(cc.c3b(93, 61, 4))
end

function class:initUI()
    local bgEdit = ccui.Scale9Sprite:createWithSpriteFrameName("rm_num_bg.png", cc.rect(30,30,20,20))
    bgEdit:addTo(self.m_bg)
          :setContentSize(cc.size(800, 100))
          :setPosition(500, 670)

    local posInput = cc.p(100, 50)
    self.m_inputTxts = {}
    for i = 1, 6 do
        local lbTxt = Constants.getLabel("", Constants.kBoldFontNamePF, 60, posInput, bgEdit)
        lbTxt:setColor(cc.c3b(0x5d, 0x3d, 0x04))
        table.insert(self.m_inputTxts, lbTxt)
        posInput.x = posInput.x + 115
    end

    -- 按钮
    local menu = cc.Menu:create()
    menu:addTo(self.m_bg)
    menu:setPosition(cc.p(0,0))

    local pos = cc.p(220, 508)
    for i = 1,12 do
        if i == 11 then
            local spBack = Constants.getMenuItem("rm_back")
            spBack:addTo(menu)
                  :setPosition(cc.p(220,155))

            spBack:registerScriptTapHandler(function() self:clickBack() end)
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
    for _,one in ipairs(self.m_inputTxts) do
        if one:getString() == "" then
            local strNum = string.format("%d", num)
            one:setString(strNum)
            break
        end
    end
    if self.m_inputTxts[6]:getString() ~= "" then
        self:clickOk()
    else
        SoundApp.playEffect("sounds/main/click.mp3")
    end
end

function class:clickOk()
    SoundApp.playEffect("sounds/main/click.mp3")

    local strRoomId = ""
    for _,one in ipairs(self.m_inputTxts) do
        if one:getString() == "" then
            break
        else
            strRoomId = strRoomId .. one:getString()
        end
    end

    if strRoomId ~= "" then
        local hall = self.delegate

        local info = {}
        info.ownerCode  = hall.userInfo.FUserCode
        info.roomId     = tonumber(strRoomId)
        local packet    = packetHelper:encodeMsg("CGGame.RoomInfo", info)

        self.delegate.agent:sendRoomOptions(protoTypes.CGGAME_PROTO_SUBTYPE_JOIN, packet)
        self:closeLayer()
    end
end

function class:clickDel()
    SoundApp.playEffect("sounds/main/click.mp3")

    for i = #self.m_inputTxts, 1, -1 do
        local one = self.m_inputTxts[i]
        if one:getString() ~= "" then
            one:setString("")
            break
        end
    end
end

function class:clickBack()
    SoundApp.playEffect("sounds/main/click.mp3")
    self:closeLayer()
end

return class
