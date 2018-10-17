local class = class("AllGameOverLayer")
class.__index = class

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"

local protoTypes= require "ProtoTypes"

local UIHelper  = require "UIHelper"

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
    cc.SpriteFrameCache:getInstance():addSpriteFrames("gameover.plist")

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

    self.delegate  = delegate -- CommonLayer

    return self
end

function class:onEnter()
    -- setLeaveListener(function()
    --     -- do nothing
    -- end)
end

function class:onExit()
end

function class:initLayer(roomResult)
    if roomResult then
        self.m_roomResult = roomResult

        self:initBg()
        self:initUI()

        self.m_uiBg:stopAllActions()
        self.m_uiBg:setScale(0)
                   :runAction(cc.EaseElasticOut:create(cc.ScaleTo:create(0.3, 1), 0.8))

        self.m_bgShadow:stopAllActions()
        self.m_bgShadow:runAction(cc.FadeTo:create(0.2, 255))
    end
end

function class:initBg()
    local winSize = display.size

    self.m_bgShadow = ccui.Scale9Sprite:createWithSpriteFrameName("bg_vague.png")
    self.m_bgShadow:addTo(self, -1)
                :setContentSize(cc.size(winSize.width, winSize.height))
                :setPosition(cc.p(winSize.width * 0.5, winSize.height * 0.5))
                :setOpacity(0)

    self.m_uiBg = Constants.get9Sprite("bg_allover1.png", cc.size(1560,924),
                                    cc.p(winSize.width * 0.5 , winSize.height * 0.5), self)


    local bgSize = self.m_uiBg:getContentSize()
    Constants.getSprite("allover_ttl.png", cc.p(bgSize.width * 0.5, bgSize.height-12),self.m_uiBg)

    local menu = cc.Menu:create()
    menu:addTo(self.m_uiBg)
        :setPosition(0,0)

    local closeItem = Constants.getMenuItem("close")
    closeItem:registerScriptTapHandler(function() self:closeLayer() end)
    closeItem:setPosition(bgSize.width -10, bgSize.height -10)
            :addTo(menu)
            :setScale(0.75)

    local shareItem = Constants.getMenuItem("share")
    shareItem:registerScriptTapHandler(function() self:clickShare() end)
    shareItem:setPosition(bgSize.width * 0.5, 100)
            :addTo(menu)
end

function class:getRankSeat(seatScore)
    local rankScore = {}
    for k,v in ipairs(seatScore) do rankScore[k] = v.score end
    table.sort(rankScore, function (a, b) return(a > b) end)
    local rankSeat = {}
    for k,v in ipairs(rankScore) do
        for sid, one in ipairs(seatScore) do
            if one.score == v and not one.seekflg then
                table.insert(rankSeat, sid)
                one.seekflg = true
                break
            end
        end
    end

    return rankSeat
end

function class:initUI()
    local bgSize = self.m_uiBg:getContentSize()
    local gameInfo = self.m_roomResult.gameInfo
    local gameInfCnt = #gameInfo
    local lastGameInfo = gameInfo[gameInfCnt]

    local seatScore = self.m_roomResult.seatScore
    local rankSeat = self:getRankSeat(seatScore)

    -- roomid
    local strRoomId = string.format("房间号:%d", self.m_roomResult.roomId)
    local lbRoomId = Constants.getLabel(strRoomId, Constants.kBoldFontNamePF, 36,
                                        cc.p(bgSize.width * 0.5 - 725, 855), self.m_uiBg)
    lbRoomId:setAnchorPoint(0,0.5)
            :setColor(cc.c3b(0, 83, 113))

    -- opentime

    local strDT = os.date("%Y-%m-%d %H:%M:%S", self.m_roomResult.openTime)
    local lbDT = Constants.getLabel(strDT, Constants.kBoldFontNamePF, 36,
                                    cc.p(bgSize.width * 0.5 + 725, 855), self.m_uiBg)
    lbDT:setAnchorPoint(1,0.5)
        :setColor(cc.c3b(0, 83, 113))
    --

    local panelPosY = {715, 496, 275}
    local rankPic = {"allover_rank1.png", "allover_rank2.png", "allover_rank3.png"}
    for i,seatId in ipairs(rankSeat) do
        local seatInfo = lastGameInfo.seatInfo[seatId]

        local bgOne = Constants.get9Sprite("bg_allover2.png", cc.size(1460,212),
                                    cc.p(bgSize.width * 0.5 , panelPosY[i]), self.m_uiBg)
        bgOne:setVisible(false)
             :runAction(cc.Sequence:create(cc.DelayTime:create(0.1+0.1 * (i-1)),
                                           cc.Show:create(),
                                           cc.ScaleTo:create(0.1, 1.1),
                                           cc.ScaleTo:create(0.2, 1)))

        local panelSize = bgOne:getContentSize()

        -- rank
        Constants.getSprite(rankPic[i], cc.p(1340, 105), bgOne)

        --head
        local headBg, roleSp = UIHelper.makeBaseHead()
        headBg:addTo(bgOne)
              :setPosition(120, 105)
              :setScale(0.77)

        local userInfo = {
            FAvatarUrl  = seatInfo.AvatarUrl,
            FUserCode   = seatInfo.userCode,
            FAvatarID   = seatInfo.AvatarID
        }
        Constants.getUserHeadSprite(roleSp, userInfo)

        -- name
        local bgName = Constants.get9Sprite("bg_allover_name.png", cc.size(960,0),
                                            cc.p(panelSize.width * 0.5 , panelSize.height * 0.71), bgOne)
        local bgNameSize = bgName:getContentSize()
        local lbName = Constants.getLabel(seatInfo.name, Constants.kSystemBoldName, 50,
                                        cc.p(bgNameSize.width * 0.5, bgNameSize.height * 0.5 + 3), bgName)
        lbName:setColor(cc.c3b(0, 83, 113))

        -- 局数
        local bgGameNum = Constants.get9Sprite("bg_allover_txt.png", cc.size(960,0),
                                                cc.p(panelSize.width * 0.5 , panelSize.height * 0.29), bgOne)
        local bgGameNumSize = bgGameNum:getContentSize()

        local strGameNum = string.format("局数: %d局", self.m_roomResult.gameCount)
        local lbGameNum = Constants.getLabel(strGameNum, Constants.kSystemBoldName, 50,
                                            cc.p(60, bgGameNumSize.height * 0.5), bgGameNum)
        lbGameNum:setAnchorPoint(0, 0.5)

        local strWinCnt = string.format("胜局: %d局", seatScore[seatId].winCount)
        local lbWinCnt = Constants.getLabel(strWinCnt, Constants.kSystemBoldName, 50,
                                            cc.p(360, bgGameNumSize.height * 0.5), bgGameNum)
        lbWinCnt:setAnchorPoint(0, 0.5)

        -- 分数
        local strScore = string.format("累计: %d", seatScore[seatId].score)
        local lbScore = Constants.getLabel(strScore, Constants.kSystemBoldName, 50,
                            cc.p(660, bgGameNumSize.height * 0.5), bgGameNum)
        lbScore:setAnchorPoint(0, 0.5)
    end
end

function class:closeLayer()
    SoundApp.playEffect("sounds/main/click.mp3")

    self.m_uiBg:stopAllActions()
    self.m_uiBg:runAction(cc.Sequence:create(cc.ScaleTo:create(0.2, 0),
                                              cc.CallFunc:create(function()
                                                    self.delegate:quitAllOverLayer()
                                                    end)))

    self.m_bgShadow:stopAllActions()
    self.m_bgShadow:runAction(cc.FadeTo:create(0.2, 0))
end

function class:clickShare()
    SoundApp.playEffect("sounds/main/screenshot.mp3")

    UIHelper.captureScreen()
end

return class
