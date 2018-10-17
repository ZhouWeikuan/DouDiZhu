local class = class("ReplayLayer")
class.__index = class

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"

local protoTypes = require "ProtoTypes"

local packetHelper  = require "PacketHelper"
local UIHelper      = require "UIHelper"

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
    cc.SpriteFrameCache:getInstance():addSpriteFrames("buttons.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("room.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("replaylayer.plist")

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

    local winSize = display.size

    local listenner = cc.EventListenerTouchOneByOne:create()
    listenner:setSwallowTouches(true)
    listenner:registerScriptHandler(function(touch, event)
        if self.m_uiBg then
            local pos = self:convertToNodeSpace(touch:getLocation())
            local rect = self.m_uiBg:getBoundingBox()
            if cc.rectContainsPoint(rect, pos) then
            else
                self:closeReplayLayer()
            end

            return true
        end
    end, cc.Handler.EVENT_TOUCH_BEGAN)

    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listenner, self)

    return self
end

function class:onEnter()
end

function class:onExit()
end

function class:initData()
    self:clearOldData()

    local roomInfKeys = Settings.getRoomResults()

    self.m_roomData = {}
    for k,v in ipairs(roomInfKeys) do
        local one = Settings.getOneRoomResult(v)
        table.insert(self.m_roomData, one)
    end
end

function class:clearOldData()
    local roomInfKeys = Settings.getRoomResults()
    table.sort(roomInfKeys, function (a, b)
            local aTime = tonumber(string.sub(a,-10))
            local bTime = tonumber(string.sub(b,-10))
            return (aTime > bTime)
        end)

    local maxItemNum = 30

    while #roomInfKeys > maxItemNum do
        local count = #roomInfKeys
        local roomInfKey = roomInfKeys[count]
        table.remove(roomInfKeys, count)

        Settings.rmvOneRoomResult(roomInfKey)
    end

    Settings.setRoomResults(roomInfKeys)
end

function class:initUIBg()
    local winSize = display.size

    self.bgShadow = ccui.Scale9Sprite:createWithSpriteFrameName("bg_vague.png")
    self.bgShadow:addTo(self)
                :setContentSize(winSize)
                :setPosition(winSize.width * 0.5, winSize.height * 0.5)
                :setOpacity(0)

    self.m_uiBg = Constants.get9Sprite("bg_dialog_frame.png", cc.size(1314,974), cc.p(winSize.width * 0.5, winSize.height * 0.5), self)

    self.m_ndTitle = display.newNode()
    self.m_uiBg:addChild(self.m_ndTitle)

    local lb = Constants.getLabel("战绩查看", Constants.kBoldFontNamePF, 72,cc.p(650, 850), self.m_ndTitle)
    lb:setColor(cc.c3b(0x5d, 0x3d, 0x04))


    local infoBg = Constants.get9Sprite("bg_info.png", cc.size(1200,680), cc.p(650,400), self.m_uiBg)
    if #self.m_roomData > 0 then
        local sten = ccui.Scale9Sprite:createWithSpriteFrameName("bg_rp_txt.png")
        sten:setContentSize(cc.size(1180,660))
        local clipper = cc.ClippingNode:create()
        clipper:setStencil(sten)
               :addTo(infoBg)
               :setPosition(600,340)

        self.m_scroll1 = ccui.ScrollView:create()
        self.m_scroll1:addTo(clipper)
                    :setTouchEnabled(true)
                    :setSwallowTouches(false)
                    :setContentSize(cc.size(1200,680))
                    :setPosition(-600,-340)
                    :setDirection(ccui.ScrollViewDir.vertical)

        self.m_scroll2 = ccui.ScrollView:create()
        self.m_scroll2:addTo(clipper)
                    :setTouchEnabled(true)
                    :setSwallowTouches(false)
                    :setContentSize(cc.size(1200,680))
                    :setPosition(-600 + 1200,-340)
                    :setDirection(ccui.ScrollViewDir.vertical)

        local menu = cc.Menu:create()
        menu:addTo(self.m_uiBg)
            :setPosition(0,0)
        local item = Constants.getMenuItem("share")
        item:setPosition(1128,840)
            :addTo(menu)
        item:registerScriptTapHandler(function() self:clickShare() end)
    end
end

function class:clickShare()
    SoundApp.playEffect("sounds/main/screenshot.mp3")

    UIHelper.captureScreen()
end

function class:initRoomInf()
    if not self.m_uiBg then
        self:initUIBg()
    end

    local dataTbl = self.m_roomData
    if not dataTbl or #dataTbl <= 0 then
        return
    end

    table.sort(dataTbl, function (a, b)
            return (a.openTime > b.openTime)
        end)

    self.m_scroll1:removeAllChildren()

    local contentSize = cc.size(1180, math.max(690, #dataTbl * 220))
    self.m_scroll1:setInnerContainerSize(contentSize)

    self.m_ndTitle:removeAllChildren()
    local lb = Constants.getLabel("战绩查看", Constants.kSystemBoldName, 72, cc.p(650, 850), self.m_ndTitle)
    lb:setColor(cc.c3b(93, 61, 4))

    for k,v in ipairs(dataTbl) do
        local onegrade = Constants.get9Sprite("bg_rp_item.png",
                                                cc.size(1170,210),
                                                cc.p(600, contentSize.height - 120 - 220 * (k-1)),
                                                self.m_scroll1)

        local oneInfoBg = Constants.get9Sprite("bg_rp_txt.png",
                                                cc.size(640,125),
                                                cc.p(520, 78),
                                                onegrade)

        local onenumberBg = Constants.getSprite("bg_table_idx.png", cc.p(105, 100), onegrade)

        local strRoomId = string.format("房间号:%d", v.roomId)
        local lbRoomId = Constants.getLabel(strRoomId, Constants.kBoldFontNamePF, 36,cc.p(200,170), onegrade)
        lbRoomId:setAnchorPoint(0,0.5)
                :setColor(cc.c3b(0x5d,0x3d,0x04))

        local strDT = os.date("%Y-%m-%d %H:%M:%S", v.openTime)
        local lbDT = Constants.getLabel(strDT, Constants.kBoldFontNamePF, 36,cc.p(1115,170), onegrade)
        lbDT:setAnchorPoint(1,0.5)
            :setColor(cc.c3b(0x5d,0x3d,0x04))

        local strIdx = string.format("%d", k)
        local lbIdx = Constants.getLabel(strIdx, Constants.kBoldFontNamePF, 72, cc.p(56,56), onenumberBg)
        lbIdx:enableOutline(cc.c4b(0x66, 0x66, 0x66, 255), 5)

        if v.seatScore and #v.seatScore > 0 then
            local seatNamePos = {cc.p(5, 100), cc.p(5, 60), cc.p(5, 20)}
            local seatScorePos = {cc.p(635, 100), cc.p(635, 60), cc.p(635, 20)}
            for seatId,one in ipairs(v.seatScore) do
                local lbName = Constants.getLabel(one.name, Constants.kBoldFontNamePF, 30, seatNamePos[seatId], oneInfoBg)
                lbName:setAnchorPoint(0,0.5)
                lbName:setColor(cc.c3b(0x5d,0x3d,0x04))


                local strScore = string.format("%d", one.score)
                if one.score > 0 then
                    strScore = "+"..strScore
                end
                local lbScore = Constants.getLabel(strScore, Constants.kBoldFontNamePF, 30, seatScorePos[seatId], oneInfoBg)
                lbScore:setAnchorPoint(1,0.5)
                lbScore:setColor(cc.c3b(0x5d,0x3d,0x04))
                if seatId == 1 then
                    lbName:setColor(cc.c3b(0xfc,0x7a,0x1b))
                    lbScore:setColor(cc.c3b(0xfc,0x7a,0x1b))
                end
            end
        end

        local menu = cc.Menu:create()
        menu:addTo(onegrade)
            :setPosition(0,0)
        local item = Constants.getMenuItem("care")
        item:setPosition(995,80)
            :addTo(menu)
        item:registerScriptTapHandler(function() self:clickDetail(k) end)
    end
end

function class:initRoomDetail(idx)
    if not self.m_uiBg then
        self:initUIBg()
    end

    self.m_scroll2:removeAllChildren()

    local oneData = self.m_roomData[idx]
    if oneData == nil then
        return
    end

    self.selfSeatId = oneData.selfSeatId

    self.m_ndTitle:removeAllChildren()
    local strRoomId = string.format("房间号:%d", oneData.roomId)
    local lbRoomId = Constants.getLabel(strRoomId, Constants.kBoldFontNamePF, 72,cc.p(650, 850), self.m_ndTitle)
    lbRoomId:setColor(cc.c3b(0x5d, 0x3d, 0x04))

    local gameInfo = oneData.gameInfo
    if gameInfo == nil or #gameInfo <= 0 then
        return
    end

    local contentSize = cc.size(1180, math.max(690, #gameInfo * 220))
    self.m_scroll2:setInnerContainerSize(contentSize)

    for k,v in ipairs(gameInfo) do
        local onegrade = Constants.get9Sprite("bg_rp_item.png",
                                                cc.size(1170,210),
                                                cc.p(600, contentSize.height - 120 - 220 * (k-1)),
                                                self.m_scroll2)

        local oneInfoBg = Constants.get9Sprite("bg_rp_txt.png",
                                                cc.size(640,125),
                                                cc.p(520, 78),
                                                onegrade)

        local onenumberBg = Constants.getSprite("bg_table_idx.png", cc.p(105, 100), onegrade)

        local strDT = os.date("%Y-%m-%d %H:%M:%S", v.startTime)
        local lbDT = Constants.getLabel(strDT, Constants.kBoldFontNamePF, 36,cc.p(200,170), onegrade)
        lbDT:setAnchorPoint(0,0.5)
            :setColor(cc.c3b(0x5d,0x3d,0x04))

        local strIdx = string.format("%d", v.gameIndex)
        local lbIdx = Constants.getLabel(strIdx, Constants.kBoldFontNamePF, 72, cc.p(56,56), onenumberBg)
        lbIdx:enableOutline(cc.c4b(0x66, 0x66, 0x66, 255), 5)

        if v.seatInfo and #v.seatInfo > 0 then
            local seatNamePos = {cc.p(5, 100), cc.p(5, 60), cc.p(5, 20)}
            local seatScorePos = {cc.p(635, 100), cc.p(635, 60), cc.p(635, 20)}
            for seatId,one in ipairs(v.seatInfo) do
                local lbName = Constants.getLabel(one.name, Constants.kBoldFontNamePF, 30, seatNamePos[seatId], oneInfoBg)
                lbName:setAnchorPoint(0,0.5)
                lbName:setColor(cc.c3b(0x5d,0x3d,0x04))


                local strScore = string.format("%d", one.deltaScore)
                if one.deltaScore > 0 then
                    strScore = "+"..strScore
                end
                local lbScore = Constants.getLabel(strScore, Constants.kBoldFontNamePF, 30, seatScorePos[seatId], oneInfoBg)
                lbScore:setAnchorPoint(1,0.5)
                lbScore:setColor(cc.c3b(0x5d,0x3d,0x04))
                if seatId == 1 then
                    lbName:setColor(cc.c3b(0xfc,0x7a,0x1b))
                    lbScore:setColor(cc.c3b(0xfc,0x7a,0x1b))
                end
            end
        end

        local menu = cc.Menu:create()
        menu:addTo(onegrade)
            :setPosition(0,0)
        local item = Constants.getMenuItem("playBack")
        item:setPosition(995,95)
            :addTo(menu)
        item:registerScriptTapHandler(function() self:clickplayBack(v) end)
    end

    local menu = cc.Menu:create()
    menu:addTo(self.m_uiBg)
    menu:setPosition(0, 0)
    self.backMenu = menu

    local item = Constants.getMenuItem("gradeback")
    item:registerScriptTapHandler(function() self:clickback() end)
    item:addTo(menu)
        :setPosition(120,855)
end

function class:clickDetail(idx)
    SoundApp.playEffect("sounds/main/click.mp3")

    self:initRoomDetail(idx)

    self.m_scroll1:stopAllActions()
    self.m_scroll1:runAction(cc.MoveTo:create(0.2, cc.p(-600 - 1200, -340)))

    self.m_scroll2:stopAllActions()
    self.m_scroll2:runAction(cc.MoveTo:create(0.2, cc.p(-600, -340)))
end

function class:clickback()
    SoundApp.playEffect("sounds/main/click.mp3")
    self.backMenu:removeFromParent()

    self.m_ndTitle:removeAllChildren()
    local lb = Constants.getLabel("战绩查看", Constants.kBoldFontNamePF, 72,cc.p(650, 850), self.m_ndTitle)
    lb:setColor(cc.c3b(0x5d, 0x3d, 0x04))

    self.m_scroll1:stopAllActions()
    self.m_scroll1:runAction(cc.MoveTo:create(0.2, cc.p(-600, -340)))

    self.m_scroll2:stopAllActions()
    self.m_scroll2:runAction(cc.MoveTo:create(0.2, cc.p(-600 + 1200, -340)))
end

function class:clickplayBack(gameInfo)
    SoundApp.playEffect("sounds/main/click.mp3")

    local scene = cc.Scene:create()
    local PlaybackLayer = require "PlaybackLayer.lua"
    local playback = PlaybackLayer.create(self.selfSeatId, gameInfo)
    playback:addTo(scene)
    cc.Director:getInstance():pushScene( scene )
end

function class:showReplayLayer()
    self:initData()
    self:initRoomInf()

    self.m_uiBg:setScale(0)
               :runAction(cc.EaseElasticOut:create(cc.ScaleTo:create(0.3, 1), 0.8))

    self.bgShadow:runAction(cc.FadeTo:create(0.2, 255))
end

function class:closeReplayLayer()
    SoundApp.playEffect("sounds/main/click.mp3")
    if self.m_uiBg then
        self.m_uiBg:stopAllActions()
        self.m_uiBg:runAction(cc.Sequence:create(cc.ScaleTo:create(0.1, 0),
                                                  cc.CallFunc:create(function()
                                                        self:removeAllChildren()
                                                        self.m_uiBg = nil
                                                        end)))
        self.bgShadow:stopAllActions()
        self.bgShadow:runAction(cc.FadeTo:create(0.2, 0))
    end
end

function class:initPlayBack(gameInfo)
    if self.m_uiBg then
        self:removeAllChildren()
        self.m_uiBg = nil
    end
end

return class
