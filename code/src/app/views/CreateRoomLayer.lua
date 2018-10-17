local class = class("CreateRoomLayer")
class.__index = class

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"

local packetHelper  = require "PacketHelper"
local UIHelper      = require "UIHelper"

local protoTypes    = require "ProtoTypes"

local kRoomCfgSaveKey = "com.cronlygames.yuncheng.roomcfg."

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

    self.m_rdGrp = {}

    self:initRoomBg()
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

function class:initRoomBg()
    local winSize = display.size

    self.m_bgShadow = Constants.get9Sprite("bg_vague.png",
                            cc.size(winSize.width, winSize.height),
                            cc.p(winSize.width * 0.5 , winSize.height * 0.5),
                            self)
    self.m_bgShadow:setOpacity(0)

    local bg = Constants.get9Sprite("bg_dialog_frame.png",
                                cc.size(1314, 974),
                                cc.p(winSize.width * 0.5 , winSize.height * 0.5),
                                self)
    self.m_bg = bg


    local menu = cc.Menu:create()
    menu:addTo(bg)
        :setPosition(0,0)

    local item = Constants.getMenuItem("rm_create")
    item:setPosition(895,105)
        :addTo(menu)
    item:registerScriptTapHandler(function() self:clickCreate() end)

    item = Constants.getMenuItem("rm_back")
    item:setPosition(410,105)
        :addTo(menu)
    item:registerScriptTapHandler(function() self:clickBack() end)
end

function class:initUI()
    local posx = 37
    local posy = 535
    local m_bg_size = self.m_bg:getContentSize()
    local infoBg = Constants.get9Sprite("bg_dialog_inner.png",
                                cc.size(1200, 600),
                                cc.p(m_bg_size.width * 0.5 , m_bg_size.height * 0.5),
                                self.m_bg)

    local lb = Constants.getLabel("创建房间", Constants.kSystemBoldName, 72, cc.p(m_bg_size.width * 0.5, 865), self.m_bg)
    lb:setColor(cc.c3b(93, 61, 4))

    local playRuleIdx = 0
    for _,one in ipairs(UIHelper.NewRoomCfg) do
        if one.opName then
            local spName = Constants.getSprite(one.opName, cc.p(posx, posy), infoBg)
            spName:setAnchorPoint(0,0.5)
        end

        if one.rdName then
            local radioGrp = ccui.RadioButtonGroup:create()
            infoBg:addChild(radioGrp)
            table.insert(self.m_rdGrp, radioGrp)

            for i,strRdName in ipairs(one.rdName) do
                local rb = ccui.RadioButton:create("rm_radio_bg.png",           -- backGround
                                                "rm_radio_bg.png",              -- backGroundSelected
                                                "rm_radio_cross.png",           -- cross
                                                "rm_radio_bg_disable.png",      -- backGroundDisabled
                                                "rm_radio_cross_disable.png",   -- frontCrossDisabled
                                                1)
                radioGrp:addRadioButton(rb)
                infoBg:addChild(rb)
                rb:setAnchorPoint(0,0.5)
                rb:setPosition(posx + 125 + one.wOffset * (i-1), posy)
                rb.value = one.rdVal[i]

                local pos = cc.p(posx + 210 + one.wOffset * (i-1), posy)
                local lb = Constants.getLabel(strRdName, Constants.kBoldFontName, 36, pos, infoBg)
                lb:setAnchorPoint(0,0.5)
                  :setColor(cc.c3b(0xde, 0x8d, 0x00))
            end

            local saveKey = kRoomCfgSaveKey .. one.opID
            local savedIdx = cc.UserDefault:getInstance():getIntegerForKey(saveKey, -1)
            savedIdx = (savedIdx > -1) and savedIdx or one.dftIdx

            if one.opID == "playRule" then
                playRuleIdx = savedIdx

                radioGrp:addEventListener(function(button, index, eventType)
                        self:enableSame3Grp(index)
                    end)
            elseif one.opID == "same3Bomb" then
                self.m_grpSame3 = radioGrp

                self:enableSame3Grp(playRuleIdx)
            end

            radioGrp:setSelectedButton(savedIdx)
        end

        posy = posy - 95
    end
end

function class:enableSame3Grp(index)
    if self.m_grpSame3 then
        local tbValid = {{false, true},   -- 普通斗地主
                         {true, true},    -- 花牌斗地主
                         {true, false}}   -- 运城斗地主
        local curValid = tbValid[index+1]
        if curValid then
            for i = 1, 2 do
                local rdBtn = self.m_grpSame3:getRadioButtonByIndex(i-1)
                rdBtn:setEnabled(curValid[i])
            end
        end

        if index == 0 then
            self.m_grpSame3:setSelectedButton(1)
        else
            self.m_grpSame3:setSelectedButton(0)
        end
    end
end

function class:clickCreate()
    SoundApp.playEffect("sounds/main/click.mp3")

    local hall = self.delegate
    local info = {}

    for i,rdGrp in ipairs(self.m_rdGrp) do
        local opID = UIHelper.NewRoomCfg[i].opID
        local idx = rdGrp:getSelectedButtonIndex()

        local saveKey = kRoomCfgSaveKey .. opID
        cc.UserDefault:getInstance():setIntegerForKey(saveKey, idx)

        idx = math.floor(idx+1)
        local val = UIHelper.NewRoomCfg[i].rdVal[idx]

        info[opID] = val
    end

    cc.UserDefault:getInstance():flush()

    local data    = packetHelper:encodeMsg("YunCheng.RoomDetails", info)

    info = {}
    info.ownerCode      = hall.userInfo.FUserCode
    info.roomDetails    = data
    local packet  = packetHelper:encodeMsg("CGGame.RoomInfo", info)

    hall.agent:sendRoomOptions(protoTypes.CGGAME_PROTO_SUBTYPE_CREATE, packet)

    self:closeLayer()
end

function class:clickBack()
    SoundApp.playEffect("sounds/main/click.mp3")
    self:closeLayer()
end

return class
