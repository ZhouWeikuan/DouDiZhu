local CommonLayer = class("CommonLayer")
CommonLayer.__index = CommonLayer

local Constants = require("Constants")
local Settings  = require ("Settings")
local const = require("Const_YunCheng")
local protoTypes = require("ProtoTypes")
local NumSet    = require ("NumSet")

local packetHelper  = require "PacketHelper"

local SoundApp = require("SoundApp")
local ClockLayer = require("ClockLayer")
local UIHelper = require("UIHelper")

function CommonLayer.extend(target)
    local t = tolua.getpeer(target)
    if not t then
        t = {}
        tolua.setpeer(target, t)
    end
    setmetatable(t, CommonLayer)
    return target
end

function CommonLayer.create(delegate, uid)
    local winSize = display.size
    cc.SpriteFrameCache:getInstance():addSpriteFrames("buttons.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("comlayer.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("card_big.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("card_small.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("propertylayer.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("userbuttons.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("emoji.plist")

    local self = CommonLayer.extend(cc.Layer:create())
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

    self.clockLayer = ClockLayer.create(self)
    self.clockLayer:addTo(self, Constants.kLayerLock)

    self.delegate  = delegate
    self.agent     = nil

    ----- UI related ---------
    self.player_info    = {}
    self.showCards      = {}
    self.bottomCards    = {}
    self.callCard       = {}
    self.runHandCards   = {}
    self.runCount       = 1
    self.selectCards    = {}
    self.discloseLbl   = {}

    self.topInfo        = {}
    self.gameMaster     = nil
    self.stepWinner     = nil
    self.gameover       = nil
    self.lastCards      = {{},{},{}}
    self.openMultiple   = nil
    self.aclNext        = 1
    self.showhandCards      = {{},{},{}}

    -- 提示
    self:resetPrompts()

    self.touchedCards = NumSet.create()

    self:initSysMenu()
    self:initPlayerInfo()

    self:setCardListenner()

    local lbGame = Constants.getLabel("宽立同城斗地主", Constants.kBoldFontName, 60,
                                        cc.p(winSize.width * 0.5, winSize.height * 0.56),self)
    lbGame:setColor(cc.c3b(120, 79, 37))

    return self
end

function CommonLayer:onEnter()
    SoundApp.playBackMusic("music/Normal.mp3")

    Constants.startScheduler(self, self.tickFrame, 0.2)
end

function CommonLayer:onExit()
    Constants.stopScheduler(self)
end

function CommonLayer:initSysMenu()
    local winSize = display.size

    local menu = cc.Menu:create()
    menu:addTo(self, Constants.kLayerMenu)
    menu:setPosition(cc.p(0,0))

    menu.buttons = {}
    self.m_sysMenu = menu

    local btnDefs = {
        start        = {func = function() self:clickStart() end,
                         pos = cc.p(winSize.width * 0.65, winSize.height * 0.4)},
        zhanji        = {func = function() self:clickZhanji() end,
                         pos = cc.p(winSize.width * 0.65, winSize.height * 0.4)},
        switch       = {func = function() self:clickSwitch() end,
                         pos = cc.p(winSize.width * 0.35, winSize.height * 0.4)},
        invite       = {func = function() self:clickInvite() end,
                         pos = cc.p(winSize.width * 0.35, winSize.height * 0.4)},
        buchu        = {func = function() self:ClickPass() end,
                         pos = cc.p(396, 443)},
        chongxuan    = {func = function() self:ClickReChoose() end,
                         pos = cc.p(920, 443)},
        tishi        = {func = function() self:ClickTip() end,
                         pos = cc.p(1222, 443)},
        chupai       = {func = function() self:ClickThrow() end,
                         pos = cc.p(1526, 443)},
        bujiao       = {func = function() self:RequestCall(1, 1) end,
                         pos = cc.p(750, 443)},
        jiaodizhu    = {func = function() self:RequestCall(2, 1) end,
                         pos = cc.p(winSize.width - 750, 443)},
        buti         = {func = function() self:ClickJiaBei(1) end,
                         pos = cc.p(750, 443)},
        ti           = {func = function() self:ClickJiaBei(2) end,
                         pos = cc.p(winSize.width - 750, 443)},
        genti        = {func = function() self:ClickJiaBei(2) end,
                         pos = cc.p(winSize.width - 750, 443)},
        huiti        = {func = function() self:ClickJiaBei(2) end,
                         pos = cc.p(winSize.width - 750, 443)},
        home         = {func = function() self:backHome() end,
                         pos = cc.p(60, winSize.height - 55)},
        setting      = {func = function() self:clickSetting() end,
                         pos = cc.p(180, winSize.height - 55)},
    }

    for name, one in pairs(btnDefs) do
        local item = nil
        if name == "buchu" then
            item = Constants.getMenuItem(name, true)
        else
            item = Constants.getMenuItem(name)
        end

        item:setPosition(one.pos)
            :addTo(menu)
            :registerScriptTapHandler(one.func)
        menu[name] = item
    end

    self:changeSysMenuStatus("zhanji", false, false)
    self:changeSysMenuStatus("invite", false, false)
    self:changeSysMenuStatus("switch", false, false)
    self:changeSysMenuStatus("chupai", false, false)
    self:changeSysMenuStatus("tishi", false, false)
    self:changeSysMenuStatus("buchu", false, false)
    self:changeSysMenuStatus("chongxuan", false, false)
    self:changeSysMenuStatus("bujiao", false, false)
    self:changeSysMenuStatus("jiaodizhu", false, false)
    self:changeSysMenuStatus("buti", false, false)
    self:changeSysMenuStatus("ti", false, false)
    self:changeSysMenuStatus("huiti", false, false)
    self:changeSysMenuStatus("genti", false, false)
end

function CommonLayer:changeSysMenuStatus(name, visible, enable)
    local btn = self.m_sysMenu[name]
    if btn then
        btn:setVisible(visible)
        btn:setEnabled(enable)

        if name == "invite" and visible then
            local bFull = true
            for seatId = 1,Constants.kMaxPlayers do
                local user = self.agent:GetUserAtSeat(seatId)
                if not user then
                    bFull = false
                    break
                end
            end

            if bFull then
                btn:setVisible(false)
                btn:setEnabled(false)
            end
        end
    end

    local names = {"invite", "start", "switch", "zhanji"}
    local activeBtns = {}
    local btnWidth = 0;
    for k,v in ipairs(names) do
        btn = self.m_sysMenu[v]
        if btn and btn:isEnabled() then
        	table.insert(activeBtns, btn)
            btnWidth = btn:getContentSize().width
        end
    end

    if #activeBtns > 0 then
    	local btnSpace = 40
    	local winSize = display.size
        local ttlWidth = #activeBtns * btnWidth + (#activeBtns - 1) * btnSpace
        local posx = winSize.width * 0.5 - ttlWidth * 0.5
        posx = posx + btnWidth * 0.5

        for k,btn in ipairs(activeBtns) do
            btn:setPosition(posx, 390);
            posx = posx + btnWidth + btnSpace
        end
    end
end

function CommonLayer:initPlayerInfo()
    local winSize = display.size
    local menu = cc.Menu:create()
    menu:addTo(self, Constants.kLayerText)
    menu:setPosition(0, 0)
    for viewId = 1,Constants.kMaxPlayers do
        local itemPos = UIHelper.getPlayerPosByViewId(viewId)

        -- head
        local headBg, roleSp = UIHelper.makeBaseHead()
        local normSize = headBg:getContentSize()
        local itemPlayerInfo = cc.MenuItemSprite:create(headBg, headBg)
        itemPlayerInfo:registerScriptTapHandler(function() self:clickHead(viewId) end)
        itemPlayerInfo:addTo(menu, Constants.kLayerIcon)
                      :setPosition(itemPos)
                      --:setVisible(false)
        self.player_info[viewId] = itemPlayerInfo
        itemPlayerInfo:setScale(0.68)
        local infoSize = itemPlayerInfo:getContentSize()
        itemPlayerInfo.icon = roleSp

        local frame = cc.SpriteFrameCache:getInstance():getSpriteFrame("icon_sitdown.png")
        roleSp:setSpriteFrame(frame)

        -- status
        local statusSp = Constants.getSprite("state_down.png", cc.p(0,0), itemPlayerInfo)
        local statusSize = statusSp:getContentSize()
        statusSp:setLocalZOrder(Constants.kLayerText)
        itemPlayerInfo.status = statusSp

        -- mult
        local lblMult = Constants.getLabel("", Constants.kBoldFontName, 48,
                            cc.p(infoSize.width * 0.5, infoSize.height * 1.3),itemPlayerInfo)
        lblMult:setAnchorPoint(0.5, 1.0)
        lblMult:enableOutline(cc.WHITE, 0.3)
        itemPlayerInfo.mult = lblMult

        -- player name
        local playerName = Constants.getLabel("", Constants.kBoldFontName, 48,
                            cc.p(infoSize.width * 0.5, 0),itemPlayerInfo)
        playerName:setAnchorPoint(0.5, 1.0)
        playerName:enableOutline(cc.WHITE, 0.3)
        itemPlayerInfo.name = playerName

        -- score
        local bgPlayerScore = Constants.get9Sprite("bg_score.png",
                                        cc.size(120, 60),
                                        cc.p(infoSize.width * 0.5, -55),
                                        itemPlayerInfo)

        bgPlayerScore:setAnchorPoint(0.5, 1.0)
                     :setVisible(false)
        itemPlayerInfo.bgscore = bgPlayerScore

        local playerScore = Constants.getLabel("0", Constants.kBoldFontName, 48,
                            cc.p(0,0), bgPlayerScore)

        local scoreSize = playerScore:getContentSize()
        bgPlayerScore:setContentSize(cc.size(math.max(120, scoreSize.width + 40), scoreSize.height))
        local bgPlayerScoreSize = bgPlayerScore:getContentSize()
        playerScore:setColor(cc.c3b(255, 240, 1))
        playerScore:setPosition(bgPlayerScoreSize.width * 0.5, bgPlayerScoreSize.height * 0.495)
        playerScore:enableOutline(cc.WHITE, 0.3)
        bgPlayerScore.score = playerScore

        -- add score
        local lbAddScore = Constants.getLabel("+5", Constants.kBoldFontNamePF, 100,
                            cc.p(infoSize.width,50), itemPlayerInfo)
        lbAddScore:setAnchorPoint(0,1)
        		  :setColor(cc.c3b(255, 255, 0))
        		  :setVisible(false)
        if viewId == 2 then
        	lbAddScore:setPosition(0, 50)
        			  :setAnchorPoint(1,1)
        end
        itemPlayerInfo.addScore = lbAddScore

        -- seatId
        local lbSeatId = Constants.getLabel("", Constants.kBoldFontName, 50,
                            cc.p(infoSize.width * 0.5, 40),itemPlayerInfo)
        lbSeatId:setVisible(false)
        itemPlayerInfo.lbSeatId = lbSeatId


		itemPlayerInfo.cards = {}
		itemPlayerInfo.throw = {}
		itemPlayerInfo.lastRound = {}
    end
end

------- initSysMenu help -----------------
function CommonLayer:resetPrompts()
    self.prompts      = nil
    self.promptIndex  = -1
    self.promptCount  = nil
end

--------------------- packet helper -------------------------------
---
--- local packetHelper = require "PacketHelper"
--- local packet    = packetHelper:makeProtoData(main, sub, body)
--- local packet    = packetHelper:encodeMsg(msgFmt, info)
--- local info      = packetHelper:decodeMsg(msgFmt, packet)

--- if you want to send action to server, you should call
--- self.delegate:sendToServer(packet)

---------------------common game info ------------------------------
function CommonLayer:GetSelfSeatId ()
    local selfSeatId = self.agent.selfSeatId
    return selfSeatId
end

function CommonLayer:MapSeatToView (seatId)
    local gameInfo = self.agent.tableInfo.gameInfo
    local num = gameInfo.maxPlayer or Constants.kMaxPlayers
    local meSeat = self:GetSelfSeatId()
    if not meSeat then
        return seatId
    end

    local viewId = Constants.kCenterViewId + (seatId - meSeat)
    if viewId > num then
        viewId = viewId - num
    elseif viewId < 1 then
        viewId = viewId + num
    end

    return viewId
end

function CommonLayer:MapViewToSeat (viewId)
    local gameInfo = self.agent.tableInfo.gameInfo
    local num = gameInfo.maxPlayer or Constants.kMaxPlayers
    local meSeat = self:GetSelfSeatId()
    if not meSeat then
        return seatId
    end

    local seatId = viewId - Constants.kCenterViewId + meSeat
    if seatId > num then
        seatId = seatId - num
    elseif seatId < 1 then
        seatId = seatId + num
    end

    return seatId
end

function CommonLayer:Mask2Seat (mask)
    local gameInfo = self.agent.tableInfo.gameInfo
    local num = gameInfo.maxPlayer or Constants.kMaxPlayers

    local seats = {}
    for i = 1, num do
        if (mask & (1 << i)) ~= 0 then
            seats[i] = i
        end
    end

    return seats
end

-------------------------------------------------------------------
----------------------common game flow ----------------------------
function CommonLayer:seatStatusChange (seatId, newStatus)
    self:RepaintPlayerInfo(seatId, newStatus)

    if seatId == self.agent.selfSeatId and newStatus == protoTypes.CGGAME_USER_STATUS_STANDUP then
        if self.agent.tableInfo.roomInfo then
            self:changeSysMenuStatus("invite", false, false)
        elseif not self.is_offline then
            self:changeSysMenuStatus("switch", true, true)
        end
    end
end

function CommonLayer:UpdateUserStatus (user)
    if self.is_offline and user then
        local index = string.match(user.FUniqueID, "(%d+)");
        if index then
            local AIPlayer = require "AIPlayer"
            AIPlayer.savePlayerAtIndex(user, index)
        end
    end

    if user.FUniqueID == self.agent.selfUserId
        and (not user.status or user.status ~= protoTypes.CGGAME_USER_STATUS_SITDOWN) then
        local item = self.m_sysMenu.sitdown
        if item then
            item:setVisible(true)
            item:setEnabled(true)
        end
    end
end

function CommonLayer:TableMapHandler()
    -- draw all playerUsers
    for seatId = 1, Constants.kMaxPlayers do
        self:RepaintPlayerInfo(seatId)
    end
end

function CommonLayer:gameInfoHandler()
    -- 重画本局游戏界面
    SoundApp.playEffect("sounds/main/start.mp3")
    self:resetStartGame(true)

    for i = 1, 3 do
        self.player_info[i].addScore:setVisible(false)
    end

    self:changeSysMenuStatus("start", false, false)

    local info = self.agent.tableInfo.gameInfo
    for _,seatInfo in pairs(info.seatInfo) do
        local user = self.agent:GetUserAtSeat(seatInfo.seatId)
        self:RepaintPlayerInfo(seatInfo.seatId, user.status)
        self:repaintCardsBySeatId(seatInfo.seatId, seatInfo)

        if seatInfo.seatId == self.agent.selfSeatId then
            self:changeSysMenuStatus("switch", false, false)
            self:changeSysMenuStatus("invite", false, false)
        end

        self:RepaintThrowCards(seatInfo.seatId, seatInfo.throwCards)
        if seatInfo.multiple and seatInfo.multiple >= 2 then
            self:ShowMultiple(seatInfo.seatId, seatInfo.multiple, true)
        end
    end
    self:repaintMaster()
    self:repaintBottomMult()
    self:repaintBottomCards(info.bottomCards)
end

function CommonLayer:repaintMaster()
    local seatId = self.agent.tableInfo.gameInfo.masterSeatId
    if not seatId or seatId < 1 or seatId > Constants.kMaxPlayers then
        return
    end

    local size = display.size

    local viewId = self:MapSeatToView(seatId)
    local pos = UIHelper.getPlayerPosByViewId(viewId)
    pos.x = (viewId == 2) and pos.x + 56 or pos.x - 56
    pos.y = pos.y + 44
    local master = self.gameMaster
    if not master then
        master = Constants.getSprite("info_host.png", pos, self)
        master:setScale(0.1)
        master:setLocalZOrder(Constants.kLayerMaster)
        self.gameMaster = master
        local act = cc.Sequence:create(cc.ScaleTo:create(0.2, 1.5),
                            cc.ScaleTo:create(0.2, 1.0)
            )
        master:runAction(act)
    else
        master:stopAllActions()
        local startPos = cc.p(master:getPosition())
        local distance = math.sqrt(cc.pDistanceSQ(startPos, pos))
        local time = distance/1400
        local act = cc.Sequence:create(cc.ScaleTo:create(0.2, 1.5),
            cc.DelayTime:create(0.2),
            cc.MoveTo:create(time, pos),
            cc.DelayTime:create(0.2),
            cc.ScaleTo:create(0.2, 1.0))

        master:runAction(act)
    end
end

function CommonLayer:repaintCardsBySeatId(seatId, seatInfo, runtype, pickup)
    local viewId = self:MapSeatToView(seatId)
    local winSize = display.size
    local handCards = seatInfo.handCards or {}
    local count = #handCards

    if self.player_info[viewId].cards then
        for k, v in pairs(self.player_info[viewId].cards) do
            if v then
                v:removeFromParent()
            end
        end
        self.discloseLbl[viewId] = nil;
    end
    self.player_info[viewId].cards = {}

    local masterSeatId = self.agent.tableInfo.gameInfo.masterSeatId
    local isMaster = masterSeatId and (masterSeatId == seatId)

    if viewId == 1 then
        local time = 0
        for k, card in pairs(handCards) do
            local startPos = UIHelper.getCardsPos(count - 1, count)
            local endPos = UIHelper.getCardsPos(k-1, count)

            local cardSp = UIHelper.getCardSprite(card, startPos, self, Constants.kLayerCard, isMaster)
            cardSp:setVisible(false)

            if runtype == 1 then
                table.insert(self.runHandCards, cardSp)
            else
                cardSp:setVisible(true)
                cardSp:setPosition(endPos)
                self.runHandCards = {}
            end
            time = time + 0.4
            self.player_info[viewId].cards[k] = cardSp
            cardSp.value = card
        end

        self.selectCards = {}
    else
        local k = 1;
        local card = handCards[k];
        local itemPos = UIHelper.getPlayerPosByViewId(viewId)

        local node = cc.Node:create();
        node:addTo(self, Constants.kLayerCard)
            :setPosition(itemPos.x + 116, itemPos.y + 10)

        if viewId == 2 then
            node:setPosition(itemPos.x - 116, itemPos.y + 10)
        end

        self.player_info[viewId].cards[k] = node
        node.value = card

        local cardSp = Constants.getSprite("card56.png", cc.p(0,0),node)
        cardSp:setScale(0.3)

        if not self.discloseLbl[viewId] then
            local lbl = Constants.getLabel(count, Constants.kBoldFontName, 40,
                            cc.p(0, 0), node)

            self.discloseLbl[viewId] = lbl
        else
            self.discloseLbl[viewId]:setString(count)
        end

        if count == 0 then
            node:setVisible(false);
        end
    end
end

function CommonLayer:doAction()
    local count = #self.runHandCards
    if self.runCount <= count then
        for i = 1, self.runCount do
            local sp = self.runHandCards[i]
            if sp then
                local pos = UIHelper.getCardsPos(i-1, self.runCount)
                sp:setPosition(pos)
                sp:setVisible(true)
            end
        end

        self.runCount = self.runCount + 1
    else
        self.runHandCards = {}
        self.runCount = 1
    end
end

function CommonLayer:handleOffline()
    self:removeQuitRoomWaitLayer()

    self:resetStartGame(true)
    self.agent.allUsers = {}
    self.agent:resetTableInfo()
    self.agent.selfSeatId = nil
end

function CommonLayer:handleACL(aclType)
    SoundApp.playEffect("sounds/main/error.mp3")
    if aclType == const.YUNCHENG_ACL_STATUS_RESTART_NO_MASTER then
        local strInfo = "acl_no_landlord.png"
        local strBack = "bg_again.png"
        local size = cc.size(502, 205)
        self:showACLInfo(strInfo, strBack, size)
    elseif aclType == const.YUNCHENG_ACL_STATUS_NO_SELECT_CARDS then
        local strInfo = "tips_no_select.png"
        local strBack = "state_down.png"
        self:showACLInfo(strInfo, strBack)
    elseif aclType == const.YUNCHENG_ACL_STATUS_NOT_VALID_TYPE then
        local strInfo = "tips_no_type.png"
        local strBack = "state_down.png"
        self:showACLInfo(strInfo, strBack)
        self:cleanSelectCards()
    elseif aclType == const.YUNCHENG_ACL_STATUS_NOT_SAME_TYPE then
        local strInfo = "tips_diff_type.png"
        local strBack = "state_down.png"
        self:showACLInfo(strInfo, strBack)
        self:cleanSelectCards()
    elseif aclType == const.YUNCHENG_ACL_STATUS_NOT_BIGGER then
        local strInfo = "tips_cards_too_small.png"
        local strBack = "state_down.png"
        self:showACLInfo(strInfo, strBack)
        self:cleanSelectCards()
    elseif aclType == const.YUNCHENG_ACL_STATUS_NO_BIG_CARDS then
        local strInfo = "tips_noway.png"
        local strBack = "state_down.png"
        self:showACLInfo(strInfo, strBack)
        self:cleanSelectCards()
    elseif aclType == const.YUNCHENG_ACL_STATUS_NO_YOUR_CARDS then
        local strInfo = "tips_not_your_cards.png"
        local strBack = "state_down.png"
        self:showACLInfo(strInfo, strBack)
        self:cleanSelectCards()
    elseif aclType == protoTypes.CGGAME_ACL_STATUS_COUNTER_LACK then
        local strInfo = "acl_gold.png"
        local strBack = "bg_again.png"
        local size = cc.size(924, 113)
        self:showACLInfo(strInfo, strBack, size)
    elseif aclType == protoTypes.CGGAME_ACL_STATUS_INVALID_INFO then
        UIHelper.popMsg(self, "invalid command, acl invalid")
    else
        local strErr = Constants.getAclErrText(aclType)
        if strErr == nil then
            print ("unknown acl type = ", aclType)
            return
        end

        UIHelper.popMsg(self, strErr)
    end
end

function CommonLayer:showWaitInfo(waitType)
    if waitType == const.YUNCHENG_TABLE_STATUS_WAIT_LANDLORD then
        SoundApp.playEffect("sounds/main/sendcard.mp3")
        SoundApp.playBackMusic("music/Exciting.mp3")
        local time = self.agent.tableInfo.timeout
        local act = cc.Sequence:create(
            cc.DelayTime:create(time),
            cc.CallFunc:create(function()
            local strInfo = "acl_wait_landlord.png"
            local strBack = "bg_again.png"
            local size = cc.size(579, 112)
            self:showACLInfo(strInfo, strBack, size)
        end))
        self:runAction(act)
    elseif waitType == const.YUNCHENG_TABLE_STATUS_WAIT_MULTIPLE then
        local strInfo = "acl_wait_multiple.png"
        local strBack = "bg_again.png"
        local size = cc.size(502, 112)
        self:showACLInfo(strInfo, strBack, size)
    end
end

function CommonLayer:showACLInfo(strInfo, strBack, size)
    local winSize = display.size
    local backSp = nil
    if (not strBack) or (not strInfo) then
        return
    end
    if size then
        backSp = Constants.get9Sprite(strBack,
                                      size,
                                      cc.p(winSize.width * 0.5, winSize.height * 0.55),
                                      self)

        backSp:setLocalZOrder(Constants.kLayerText)

    else
        backSp = Constants.getSprite(strBack, cc.p(winSize.width * 0.5, winSize.height * 0.33),self)
        backSp:setLocalZOrder(Constants.kLayerText)
    end
    backSp:setCascadeOpacityEnabled(true)

    local backSpSize = backSp:getContentSize()
    Constants.getSprite(strInfo, cc.p(backSpSize.width * 0.5, backSpSize.height * 0.5), backSp)

    local act = cc.Sequence:create(
        cc.FadeIn:create(1.0),
        cc.DelayTime:create(1.5),
        cc.FadeOut:create(1.0),
        cc.CallFunc:create(function()
            backSp:removeFromParent()
        end))
    backSp:runAction(act)
end

function CommonLayer:handleBuyChip (msg)
    local count = msg.subType
    local str = string.format("您已购买%d个元宝", count)

    UIHelper.popMsg(self, str)
end

function CommonLayer:showQuitRoomConfirmLayer ()
    local quitLayer = require "QuitRoomConfirmLayer"

    local hasPlayRecord = false
    local roomInfKeys = Settings.getRoomResults()
    for k,v in ipairs(roomInfKeys) do
        local oneRoomRslt = Settings.getOneRoomResult(v)
        if oneRoomRslt and oneRoomRslt.roomId == self.m_curRoomId then
            hasPlayRecord = true
            break
        end
    end

    local gameInfo = self.agent.tableInfo.gameInfo
    local started = (gameInfo.seatInfo ~= nil) or hasPlayRecord

    local layer = quitLayer.create(self, started)
    layer:setPosition(cc.p(0, 0))
        :addTo(self, Constants.kLayerPopUp)
end

function CommonLayer:voteExit ()
    SoundApp.playEffect("sounds/main/click.mp3")

    local agent = self.agent
    local roomInfo = agent.tableInfo.roomInfo

    local info = {}
    info.roomId         = roomInfo.roomId
    info.seatId         = agent.selfSeatId
    info.mask           = 1 << info.seatId
    info.ownerId        = agent.selfUserId
    local packet  = packetHelper:encodeMsg("CGGame.ExitInfo", info)

    agent:sendRoomOptions(protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_RELEASE, packet)
end

function CommonLayer:voteKeep ()
    SoundApp.playEffect("sounds/main/click.mp3")

    local agent = self.agent
    local roomInfo = agent.tableInfo.roomInfo

    local info = {}
    info.roomId         = roomInfo.roomId
    info.seatId         = agent.selfSeatId
    info.mask           = 0
    info.ownerId        = agent.selfUserId
    local packet  = packetHelper:encodeMsg("CGGame.ExitInfo", info)

    agent:sendRoomOptions(protoTypes.CGGAME_PROTO_SUBTYPE_ROOM_RELEASE, packet)
end

function CommonLayer:removeQuitRoomWaitLayer ()
    if self.m_quitRoomWaitLayer then
        self.m_quitRoomWaitLayer:removeFromParent()
        self.m_quitRoomWaitLayer = nil
    end
end

function CommonLayer:showAllOver()
    local roomInfKeys = Settings.getRoomResults()
    local curRoomRslt = nil
    for k,v in ipairs(roomInfKeys) do
        local oneRoomRslt = Settings.getOneRoomResult(v)
        if oneRoomRslt and oneRoomRslt.roomId == self.m_curRoomId then
            curRoomRslt = oneRoomRslt
            break
        end
    end

    if curRoomRslt then
        local AllGameOverLayer = require "AllGameOverLayer"
        self.m_allOverLayer = AllGameOverLayer.create(self);
        self:addChild(self.m_allOverLayer, Constants.kLayerResult);
        self.m_allOverLayer:initLayer(curRoomRslt)
    else
        self:quitGame()
    end
end

function CommonLayer:handleRoomRelease (exitInfo)
    if exitInfo.timeout and exitInfo.timeout == -1 then
        Settings.setRoomId(0)
        Settings.rmvFromRoomList(self.m_curRoomId)
        self:showAllOver()
    end

    if (not exitInfo.seatId or exitInfo.seatId == 0) then
        if not exitInfo.mask or exitInfo.mask == 0 then
            if self.m_quitRoomWaitLayer then
                self.m_quitRoomWaitLayer:closeLayer()
            end
            return
        end
    end

    if not self.m_quitRoomWaitLayer then
        local quitLayer = require "QuitRoomWaitLayer"

        local layer = quitLayer.create(self)
        self.m_quitRoomWaitLayer = layer

        layer:setPosition(cc.p(0, 0))
            :addTo(self, Constants.kLayerPopUp)
    end

    self.m_quitRoomWaitLayer:update(exitInfo)
end

function CommonLayer:addRoomResult(msg, seatId)
    if not msg or msg == "" then
        return
    end

    local hp = require "TableHelper"
    local one = hp.decode(msg)

    -- print("add Room Result")
    -- local debugHelper = require "DebugHelper"
    -- debugHelper.printDeepTable(one)

    if one and one.roomId then
        one.selfSeatId = seatId

        local key = string.format("%d.%d", one.roomId, one.openTime)
        local  all = Settings.getRoomResults() or {}
        local last = all[#all]
        if not last or last ~= key then
            table.insert(all, key)
        end
        Settings.setRoomResults(all)

        local roomInfo = Settings.getOneRoomResult(key)
        if not roomInfo then
            roomInfo = one
            roomInfo.gameInfo = {one.gameInfo}
        else
            roomInfo.gameCount = one.gameCount
            roomInfo.seatScore = one.seatScore
            table.insert(roomInfo.gameInfo, one.gameInfo)
        end

        -- print("Room full info is")
        -- local debugHelper = require "DebugHelper"
        -- debugHelper.printDeepTable(roomInfo)

        Settings.setOneRoomResult(key, roomInfo)
    end
end

function CommonLayer:handleRoomResult (msg, seatId)
    self:addRoomResult(msg, seatId)

    local hp = require "TableHelper"
    local curRoomResult = hp.decode(msg)

    if curRoomResult.gameOver then
        Settings.setRoomId(0)

        self:showGameOverRoomTip("msgAllGameOverTip")

        self:changeSysMenuStatus("zhanji", true, true)

        Settings.rmvFromRoomList(self.m_curRoomId)
    else
        self:showGameOverRoomTip("msgDontLeaveTip")
    end

    if self.m_roomInfoPanel then
        local gameIndex = curRoomResult.gameInfo.gameIndex + 1
        if gameIndex > curRoomResult.passCount then
            gameIndex = curRoomResult.passCount
        end
        local strGameCnt = string.format("局数: %d/%d", gameIndex,curRoomResult.passCount)
        self.lblGameCnt:setString(strGameCnt)
    end
end

function CommonLayer:quitAllOverLayer ()
    self.m_allOverLayer:removeFromParent()
    self.m_allOverLayer = nil

    self:quitGame()
end

function CommonLayer:showGameOverRoomTip(msg)
    local winSize = display.size

    local bgBar = Constants.getSprite("bg_error.png", cc.p(winSize.width * 0.5, winSize.height * 0.08), self)
    bgBar:setLocalZOrder(Constants.kLayerResult)
         :setCascadeOpacityEnabled(true)

    local bgSize = bgBar:getContentSize()

    local strMsg = OSNative.getUTF8LocaleString(msg)
    local lbMsg = Constants.getLabel(strMsg, Constants.kBoldFontName, 42,
                            cc.p(bgSize.width * 0.5, bgSize.height * 0.5), bgBar)

    lbMsg:setColor(cc.c3b(255, 193, 47))

    self.m_roomOverTip = bgBar
end

function CommonLayer:handleRoomInfo (roomInfo, roomDetails)
    Settings.setRoomId(roomInfo.roomId)
    Settings.addToRoomList(roomInfo)

    local winSize = display.size

    roomDetails.passCount = roomDetails.passCount or 0
    roomDetails.costCoins = roomDetails.costCoins or 0
    roomDetails.payType = roomDetails.payType or 0
    roomDetails.playRule = roomDetails.playRule or 0
    roomDetails.same3Bomb = roomDetails.same3Bomb or 0
    roomDetails.bombMax = roomDetails.bombMax or 0
    roomDetails.bottomScore = roomDetails.bottomScore or 0

    local strDetails = UIHelper.parseRoomDetail(roomDetails)
    local lbDetail = Constants.getLabel(strDetails, Constants.kBoldFontName, 40,
                                        cc.p(winSize.width * 0.5, winSize.height * 0.48),self)
    lbDetail:setColor(cc.c3b(120, 79, 37))

    self.m_curRoomId = roomInfo.roomId
    local strRoomId = string.format("房间号: %d", roomInfo.roomId)

    local gameIndex = 1
    local roomInfKeys = Settings.getRoomResults()
    for k,v in ipairs(roomInfKeys) do
        local oneRoomRslt = Settings.getOneRoomResult(v)
        if oneRoomRslt and oneRoomRslt.roomId == roomInfo.roomId then
            local count = #oneRoomRslt.gameInfo
            gameIndex = oneRoomRslt.gameInfo[count].gameIndex + 1
            break
        end
    end
    local strGameCnt = string.format("局数: %d/%d", gameIndex,roomInfo.passCount)

    if not self.m_roomInfoPanel then
        local bgRoomInfo = Constants.get9Sprite("bg_wifi.png",
                                    cc.size(490, 0),
                                    cc.p(winSize.width - 485, winSize.height - 45),
                                    self)
        local bgSize = bgRoomInfo:getContentSize()

        self.m_roomInfoPanel = bgRoomInfo

        self.lblRoomId = Constants.getLabel(strRoomId, Constants.kBoldFontNamePF, 36,cc.p(470, bgSize.height * 0.5),bgRoomInfo)
        self.lblRoomId:setAnchorPoint(1, 0.5)

        self.lblGameCnt = Constants.getLabel(strGameCnt, Constants.kBoldFontNamePF, 36,cc.p(20, bgSize.height * 0.5),bgRoomInfo)
        self.lblGameCnt:setAnchorPoint(0, 0.5)
    end

    self.lblRoomId:setString(strRoomId)
    self.lblGameCnt:setString(strGameCnt)

    self:changeSysMenuStatus("switch", false, false)

    local cnt = self.agent.tableInfo.playerUsers:getCount()
    local hasSeat = (cnt < Constants.kMaxPlayers)
    self:changeSysMenuStatus("invite", hasSeat, hasSeat)
end

function CommonLayer:GameOverHandler()
    local winSize = display.size
    local gameOverInfo = self.agent.gameOverInfo
    for _, site in pairs (gameOverInfo.sites) do
        local user = self.agent:GetUserAtSeat(site.seatId)
        if self.is_offline and user then
            local index = string.match(user.FUniqueID, "(%d+)");
            if index then
                local AIPlayer = require "AIPlayer"
                AIPlayer.savePlayerAtIndex(user, index)
            end
        end
    end

    self:showOverPanel()
end

function CommonLayer:showOverScore(seatId, deltaScore)
    local viewId = self:MapSeatToView(seatId)
    local score = deltaScore == 0 and "0" or string.format("%+d", deltaScore)
    local lbAddScore = self.player_info[viewId].addScore
    lbAddScore:setVisible(true)
     		  :setString(score)
end

function CommonLayer:showOverAnim()
    local winSize = display.size
    local gameInfo = self.agent.tableInfo.gameInfo
    local gameOverInfo = self.agent.gameOverInfo
    local sites = gameOverInfo.sites
    local winSeatId = 0
    for k, site in pairs(sites) do
        if site.deltaScore > 0 then
            winSeatId = site.seatId
            break
        end
    end

    if winSeatId == 0 then return end

    if winSeatId == self.agent.selfSeatId then
        OSNative.showRate()
        SoundApp.playEffect("sounds/main/win.mp3")
    else
        SoundApp.playEffect("sounds/main/lose.mp3")
    end

    local skeletonNode = nil
    local overpos = cc.p(winSize.width * 0.5, winSize.height * 0.15)
    if gameOverInfo.resType == 0 then
        if winSeatId == gameInfo.masterSeatId then
            skeletonNode = sp.SkeletonAnimation:create("eff/MagnateWin_out/MagnateWin.json",
                                                       "eff/MagnateWin_out/MagnateWin.atlas")
            skeletonNode:setAnimation(0, "MagnateWin", true)
        else
            skeletonNode = sp.SkeletonAnimation:create("eff/FarmerWin_out/FarmerWin.json",
                                                       "eff/FarmerWin_out/FarmerWin.atlas")
            skeletonNode:setAnimation(0, "FarmerWin", true)
        end
    else
        SoundApp.playEffect("sounds/main/spring.mp3")
        skeletonNode = sp.SkeletonAnimation:create("eff/Spring_out/Spring.json",
                                                   "eff/Spring_out/Spring.atlas")
        skeletonNode:setAnimation(0, "Spring", false)
        overpos = cc.p(winSize.width * 0.42, winSize.height * 0.58)
    end

    if skeletonNode then
        local act = cc.Sequence:create(
                        cc.FadeIn:create(0.4),
                        cc.DelayTime:create(1),
                        cc.FadeOut:create(0.4),
                        cc.CallFunc:create(function()
                            if skeletonNode then
                                skeletonNode:removeFromParent()
                            end
                        end))

        skeletonNode:setTimeScale(1.6)
        skeletonNode:addTo(self, Constants.kLayerPopUp)
        skeletonNode:setPosition(overpos)
        skeletonNode:setOpacity(0)
        skeletonNode:setScale(1.6)
        skeletonNode:runAction(act)
    end
end

function CommonLayer:getCardOverPos(index, count, viewId)
    local winSize = display.size
    local pos = {
        cc.p(winSize.width * 0.5, 570),
        cc.p(winSize.width - 366, 833),
        cc.p(366, 730)
    }

    local endPos = nil
    local cardSpace = 53

    if viewId == 2 then
        endPos = cc.p(pos[viewId].x - (count - index) * cardSpace , pos[viewId].y)
    else
        endPos = cc.p(pos[viewId].x + (index - 1) * cardSpace , pos[viewId].y)
    end
    return endPos
end

function CommonLayer:showOverHandCards(seatId, handCards)
    local viewId = self:MapSeatToView(seatId)
    local masterSeatId = self.agent.tableInfo.gameInfo.masterSeatId
    local isMaster = masterSeatId and (masterSeatId == seatId)

	if handCards then
        local count = #handCards
        for k, v in pairs(handCards) do
            local pos = self:getCardOverPos(k, count, viewId)
            if viewId == 1 then
                pos = UIHelper.getCardsPos(k-1, count)
            end

            local cardSp = UIHelper.getCardSprite(v, pos, self, 0, isMaster)

            if viewId > 1 then
                cardSp:setScale(0.6)
            end
            cardSp:setLocalZOrder(Constants.kLayerCard+viewId-1)

            table.insert(self.showhandCards[viewId], cardSp)
        end
    end
end

function CommonLayer:showOverPanel()
    SoundApp.playBackMusic("music/Normal.mp3")

    local gameOverInfo = self.agent.gameOverInfo
    local sites = gameOverInfo.sites

    self:showOverAnim()

    for k, site in pairs(sites) do
        local seatId = site.seatId
        local viewId = self:MapSeatToView(seatId)

        self:showOverScore(seatId, site.deltaScore)

        if self.player_info[viewId] then
            if self.player_info[viewId].cards then
                UIHelper.removeSpriteArray(self.player_info[viewId].cards)
                self.player_info[viewId].cards = {}
            end
        end

        UIHelper.removeSpriteArray(self.lastCards[viewId])
        self.lastCards[viewId] = {}

        UIHelper.removeSpriteArray(self.showhandCards[viewId])
        self.showhandCards[viewId] = {}

        self:showOverHandCards(seatId, site.handCards)
    end
end

function CommonLayer:GameWaitHandler(mask, status, timeout)
    self.clockLayer:repaintClock(mask, timeout)

    -- self.m_sysMenu.start:setVisible(false)
    -- self.m_sysMenu.start:setEnabled(false)

    self:HideAllButton()
    if status == protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
        self:resetStartGame(false)
    elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_PICKUP then
    elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_LANDLORD then
    elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_THROW then
    elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_MULTIPLE then
        self:showWaitInfo(const.YUNCHENG_TABLE_STATUS_WAIT_MULTIPLE)
    end

    if self.agent:IsWaitingForMe(mask) then
        if status == protoTypes.CGGAME_TABLE_STATUS_IDLE then
        elseif status == protoTypes.CGGAME_TABLE_STATUS_WAITSTART then
            self:changeSysMenuStatus("start", true, true)

            if self.agent.tableInfo.roomInfo then
                local cnt = self.agent.tableInfo.playerUsers:getCount()
                local hasSeat = (cnt < Constants.kMaxPlayers)
                self:changeSysMenuStatus("invite", hasSeat, hasSeat)
            elseif not self.is_offline then
                self:changeSysMenuStatus("switch", true, true)
            end

        elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_PICKUP then
            self:showWaitInfo(const.YUNCHENG_TABLE_STATUS_WAIT_LANDLORD)
        elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_LANDLORD then
            local gameInfo = self.agent.tableInfo.gameInfo
            if gameInfo.masterSeatId and gameInfo.masterSeatId > 0 then
            else
                local seatInfo  = gameInfo.seatInfo[self.agent.selfSeatId]
                local userdata = gameInfo.userdata
                if not userdata:bigEnough(seatInfo.handCards) then
                    self:changeSysMenuStatus("bujiao", true, true)
                end

                self:changeSysMenuStatus("jiaodizhu", true, true)
            end

            self:showWinZhishu()
        elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_MULTIPLE then
            self:changeSysMenuStatus("buti", true, true)

            local masterSeatId = self.agent.tableInfo.gameInfo.masterSeatId
            if masterSeatId and self:GetSelfSeatId() == masterSeatId then
                self:changeSysMenuStatus("huiti", true, true)
            else
            	local gameInfo = self.agent.tableInfo.gameInfo
            	local bGenti = false
            	for seatId = 1,Constants.kMaxPlayers do
            		local seatInfo = gameInfo.seatInfo[seatId]
            		if seatId ~= masterSeatId and seatId ~= self:GetSelfSeatId() then
            			if seatInfo.multiple > 1 then
            				bGenti = true
            				break
            			end
            		end
            	end

            	if bGenti then
            		self:changeSysMenuStatus("genti", true, true)
            	else
            		self:changeSysMenuStatus("ti", true, true)
            	end
            end

        elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_THROW then
            local gameInfo = self.agent.tableInfo.gameInfo
            if gameInfo.winCards and gameInfo.winCards.seatId == self.agent.selfSeatId then
                gameInfo.winCards = nil
            end

            self:resetPrompts()

            local co = coroutine.create(function ()
                self:checkPass()
            end)
            coroutine.resume(co)

            self:SayRemain()
        elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_GAMEOVER then
            print ("wait for me to game over")
        elseif status == const.YUNCHENG_TABLE_STATUS_WAIT_NEWGAME then
            print ("wait for me to new game")
        else
            print ("wait for me to do evil".. status)
        end
    end
end

-------------------------------------------------------------------
-----------------common game ui update ----------------------------
function CommonLayer:RepaintPlayerInfo (seatId, newStatus)
    local viewId = self:MapSeatToView(seatId)
    local bg_info = self.player_info[viewId]
    local user = self.agent:GetUserAtSeat(seatId)

    if not bg_info then
        return
    end

    if not user then
        local frame = cc.SpriteFrameCache:getInstance():getSpriteFrame("icon_sitdown.png")
        bg_info.icon:setSpriteFrame(frame)
        bg_info.icon:setScale(1)

        frame = cc.SpriteFrameCache:getInstance():getSpriteFrame("state_down.png")
        bg_info.status:setSpriteFrame(frame)

        bg_info.name:setString("")

        bg_info.lbSeatId:setVisible(true)
                        :setString(tostring(seatId))
        return
    else
        bg_info:setVisible(true)
        bg_info.lbSeatId:setVisible(false)
    end

    Constants.getUserHeadSprite(bg_info.icon, user)

    if newStatus then
        local statusStr = "state_down.png"

        if newStatus == protoTypes.CGGAME_USER_STATUS_READY then
            statusStr = "state_ready.png"
        elseif newStatus == protoTypes.CGGAME_USER_STATUS_STANDUP then
            statusStr = "state_stand.png"
        elseif newStatus == protoTypes.CGGAME_USER_STATUS_IDLE then
            statusStr = "state_leave.png"
        elseif newStatus == protoTypes.CGGAME_USER_STATUS_OFFLINE then
            statusStr = "state_offline.png"
        end

        local frame = cc.SpriteFrameCache:getInstance():getSpriteFrame(statusStr)
        bg_info.status:setSpriteFrame(frame)

        local statusSize = bg_info.status:getContentSize()
        local bgSize = bg_info:getContentSize()
        bg_info.status:setPosition(cc.p(-statusSize.width * 0.5 - 120, bgSize.height * 0.5 + 15))
                      :setScaleX(1)
        if viewId == 1 or viewId == 3 then
            bg_info.status:setPosition(cc.p(bgSize.width + statusSize.width * 0.5 + 120, bgSize.height * 0.5 + 15))
        end
    end

    if seatId == self:GetSelfSeatId()
        and (newStatus == protoTypes.CGGAME_USER_STATUS_PLAYING
            or newStatus == protoTypes.CGGAME_USER_STATUS_READY) then
        self:changeSysMenuStatus("start", false, false)
    end

    local name = user.FNickName or ""
    bg_info.name:setString(name)

    local score = user.FScore or 0
    if self.agent.tableInfo.roomInfo then
        score = 0
        local gameInfo = self.agent.tableInfo.gameInfo
        if gameInfo and gameInfo.seatInfo then
            local seatInfo = gameInfo.seatInfo[seatId]
            score = seatInfo and seatInfo.scoreCard or 0
        end
    end

    bg_info.bgscore:setVisible(true)
    bg_info.bgscore.score:setString(score)
    local scoreSize = cc.size(math.max(120, bg_info.bgscore.score:getContentSize().width+40), 60)
    bg_info.bgscore:setContentSize(scoreSize)
    bg_info.bgscore.score:setPosition(scoreSize.width*0.5, scoreSize.height*0.5)

    if bg_info.fang then
        bg_info.fang:setVisible(true)
    end

    self.player_info[viewId] = bg_info
end

function CommonLayer:clickHead (viewId)
    SoundApp.playEffect("sounds/main/click.mp3")

    local seatId = self:MapViewToSeat(viewId)
    local user = self.agent:GetUserAtSeat(seatId)
    if user then
        self:showPlayerInfo(seatId)
    else
        self.agent:sendRoomSeatOptions(seatId)
    end
end

function CommonLayer:showPlayerInfo (seatId)
    local PlayerInfoLayer = require "PlayerInfoLayer"
    local layer = PlayerInfoLayer.create(self, seatId)
    if layer then
        layer:addTo(self, Constants.kLayerPopUp)
        layer:setPosition(cc.p(0, 0))
    end
end

function CommonLayer:recvGift(info)
    local giftInfo = {}
    giftInfo.giftName   = info.giftName
    giftInfo.getId      = info.dstSeatId
    giftInfo.sendId     = info.srcSeatId
    giftInfo.coin       = info.coinCost

    self:showGift(giftInfo)
end

function CommonLayer:showGift(info)
    SoundApp.playEffect("sounds/gifts/recvgift.mp3")
    local getViewId = self:MapSeatToView(info.getId)
    local sendViewId = self:MapSeatToView(info.sendId)
    local startPos = UIHelper.getPlayerPosByViewId(sendViewId)
    local destPos = UIHelper.getPlayerPosByViewId(getViewId)

    local str = info.giftName
    if not const.kGiftItems[str] then
        return
    end

    local skeletonNode = sp.SkeletonAnimation:create("gift/giftopen_out/skeleton.json","gift/giftopen_out/picture.atlas")
    skeletonNode:addTo(self, Constants.kLayerPopUp)
        :setPosition(startPos)
        :setScale(1.6)

    skeletonNode:setAnimation(0, "static", true)
    local act = cc.Sequence:create(cc.MoveTo:create(1.0, destPos),
                                   cc.CallFunc:create(function()
                                    skeletonNode:setToSetupPose()
                                    SoundApp.playEffect("sounds/gifts/open.mp3")
                                    skeletonNode:setAnimation(0, "attack", false)
                                    self:callBacllGiftOpen(skeletonNode,str,getViewId)
                                    end)

        )
    skeletonNode:runAction(act)
end

function CommonLayer:callBacllGiftOpen(skeletonNode,str,getViewId)

        local pos = cc.p(skeletonNode:getPosition())
        local jsonName = string.format("gift/%s_out/skeleton.json", str)
        local atlasName = string.format("gift/%s_out/picture.atlas", str)
        local animation = string.format("%s_attack", str)

        skeletonNode:runAction(cc.Sequence:create(cc.DelayTime:create(1.6),
            cc.CallFunc:create(function()
                local gift = sp.SkeletonAnimation:create(jsonName,atlasName)
                gift:registerSpineEventHandler(function (event)
                        if event.eventData.name == "sound" then
                            SoundApp.playEffect(string.format("sounds/gifts/%s.mp3", str))
                        end
                    end,sp.EventType.ANIMATION_EVENT)
                gift:addTo(self, Constants.kLayerGift)
                    :setPosition(pos)
                    :setVisible(false)
                if getViewId < Constants.kCenterViewId then
                    gift:setScaleX(-1)
                end
                gift:runAction(cc.Sequence:create(
                    cc.Show:create(),
                    cc.CallFunc:create(function() gift:setAnimation(0, animation, false) end)
                    ))
                gift:registerSpineEventHandler(function(event)
                    self:callBacllGift(gift)
                    end, sp.EventType.ANIMATION_COMPLETE)
                 end),
            cc.Spawn:create(cc.CallFunc:create(function()
                skeletonNode:runAction(cc.Sequence:create(cc.DelayTime:create(0.5),
                    cc.CallFunc:create(function() skeletonNode:removeFromParent() end)
                    ))
                end))
            ))
end

function CommonLayer:callBacllGift(gift)
    gift:runAction(cc.CallFunc:create(function()
        gift:removeFromParent() end))
end

function CommonLayer:tickFrame (dt)
    if self.runHandCards and self.runHandCards ~= {} then
        self:doAction()
    end

    self:updateNetorkStatus()
    self:updateBatteryStatus()
end

function CommonLayer:repaintBottomCards(topCards)
    local winSize = display.size
    local gameInfo = self.agent.tableInfo.gameInfo
    if gameInfo.showBottoms then
        UIHelper.removeSpriteArray(self.topInfo.cards)
        self.topInfo.cards = {}

        if topCards and #topCards >= 3 then
            local ndCards = display.newNode()
            self:addChild(ndCards)

            local width = 0
            for k, v in pairs(topCards) do
                local cardSp = Constants.getSprite(string.format("cards%02d.png", v),
                                cc.p(width, 0), ndCards)
                cardSp:setAnchorPoint(0, 1)

                width = width + cardSp:getContentSize().width

                self.topInfo.cards[k] = cardSp
            end

            ndCards:setPosition(winSize.width * 0.5 - width * 0.5, winSize.height)
        end
    end
end

function CommonLayer:backHome()
    SoundApp.playEffect("sounds/main/click.mp3")

    if self.is_offline or self:canSwitchTable() then
        self:quitGame()

    elseif self.agent.tableInfo.roomInfo then
        self:showQuitRoomConfirmLayer()
    else
        UIHelper.popMsg(self, "正在游戏中,请游戏结束后重试")
    end
end

function CommonLayer:clickSetting()
    SoundApp.playEffect("sounds/main/click.mp3")

    local SettingLayer = require "SettingLayer"
    local layer = SettingLayer.create(self)
    layer:addTo(self, Constants.kLayerPopUp)
end

function CommonLayer:quitGame()
    local app = cc.exports.appInstance
    local view = app:createView("MainScene")
    if self.is_offline then
        view.nextSceneName = "LineScene"
    else
        self.agent:sendTableOptions(protoTypes.CGGAME_PROTO_SUBTYPE_QUITTABLE, self:GetSelfSeatId())

        Settings.setRoomId(0)
        view.nextSceneName = "HallScene"
    end
    view:showWithScene()
end

function CommonLayer:canSwitchTable()
    local tableInfo = self.agent.tableInfo

    if tableInfo.roomInfo then
        return false
    end

    if not tableInfo.status or tableInfo.status <= const.YUNCHENG_TABLE_STATUS_WAIT_NEWGAME then
        return true
    end

    local gameInfo = tableInfo.gameInfo
    if not gameInfo.seatInfo then
        return true
    end

    local mySeatId = self.agent.selfSeatId
    local seatInfo = gameInfo.seatInfo[mySeatId]
    if not seatInfo then
        return true
    end

    return false
end

function CommonLayer:clickSwitch()
    SoundApp.playEffect("sounds/main/click.mp3")
    if self.is_offline then
        UIHelper.popMsg(self, "单机版暂不支持换桌功能")
        return
    end
    if not self:canSwitchTable() then
        UIHelper.popMsg(self, "正在游戏中,请游戏结束后重试")
        return
    end

    local subType = protoTypes.CGGAME_PROTO_SUBTYPE_CHANGETABLE
    self.agent:sendTableOptions(subType)
end

function CommonLayer:changeTableHandler()
end

function CommonLayer:shopInfo()
    do return end
    SoundApp.playEffect("sounds/main/click.mp3")
    local ShopLayer = require "ShopLayer"

    local shop = ShopLayer.create(self)
    if shop then
        shop:setPosition(cc.p(0, 0))
        shop:addTo(self, Constants.kLayerPopUp)

        local winSize = display.size
        shop:showShop(cc.p(winSize.width * 0.5, winSize.height * 0.5))
    end
end

function CommonLayer:clickStart()
    SoundApp.playEffect("sounds/main/click.mp3")

    local subType = protoTypes.CGGAME_PROTO_SUBTYPE_READY
    self.agent:sendTableOptions(subType)

    self:changeSysMenuStatus("start", false, false)
end

function CommonLayer:clickZhanji()
    SoundApp.playEffect("sounds/main/click.mp3")

    self:showAllOver()
end

function CommonLayer:getIconPathInSDCard()
    local iconPath = "/mnt/sdcard/yuncheng.png";
    local instance = cc.FileUtils:getInstance()

    if not Constants.cachedImages["icon"] then
        local path = instance:fullPathForFilename("icon.png")
        local data = OSNative.getFileData(path)
        local file = io.open(iconPath, "wb")
        if file then
            Constants.cachedImages["icon"] = true
            file:write(data)
            file:close()
        end
    end
    return iconPath
end

function CommonLayer:clickInvite()
    SoundApp.playEffect("sounds/main/click.mp3")
    local roomInfo = self.agent.tableInfo.roomInfo
    if not roomInfo then
        return
    end

    local title = string.format("房间号: %d", roomInfo.roomId)
    local text  = UIHelper.parseRoomDetail(roomInfo.roomDetails)

    local url = "www.cronlygames.com/download/download.php?p=com.cronlygames.yuncheng"

    local shareInfo = {
        title       = title,
        text        = text,
        mediaType   = 2,
        shareTo     = 0,
        url         = url,
    }
    if Constants.isDeviceAndroid() then
        shareInfo.imagePath = self:getIconPathInSDCard()
    else
        shareInfo.thumbImage = "AppIcon60x60@3x.png"
    end

    local function onSharedResultListener (code, msg )
        require "opensdkConst3"
        local ShareResultCode = cc.exports.ShareResultCode

        local title, body
        if code == ShareResultCode.kShareSuccess then
            title = OSNative.getUTF8LocaleString("msgShareSuccess")
            body  = OSNative.getUTF8LocaleString("msgShareOK")
        else
            title = OSNative.getUTF8LocaleString("msgShareFailed")
            body  = OSNative.getUTF8LocaleString("msgShareFailInfo") .. msg
        end

        UIHelper.popMsg(self, title..","..body)
    end

    local sdk = require "OpenSDKWrapper"
    sdk.showShare(shareInfo, onSharedResultListener)
end

function CommonLayer:quitTableHandler(uid, seatId)
    if self.agent.selfSeatId == seatId then

        self:resetStartGame(false)
    else
        local viewId = self:MapSeatToView(seatId)
        local bg_info = self.player_info[viewId]

        local frame = cc.SpriteFrameCache:getInstance():getSpriteFrame("icon_sitdown.png")
        bg_info.icon:setSpriteFrame(frame)
                    :setScale(1)

        frame = cc.SpriteFrameCache:getInstance():getSpriteFrame("state_down.png")
        bg_info.status:setSpriteFrame(frame)

        bg_info.name:setString("")
        bg_info.bgscore:setVisible(false)

        bg_info.lbSeatId:setVisible(true)
                        :setString(tostring(seatId))
    end

    if self.agent.tableInfo.roomInfo then
        if self.agent.selfSeatId == seatId then
            self:changeSysMenuStatus("invite", false, false)
            self:changeSysMenuStatus("start", false, false)

            self:HideAllButton()

            if self.m_roomInfoPanel then
                self.m_roomInfoPanel:removeFromParent()
                self.m_roomInfoPanel = nil
            end
        end
    elseif not self.is_offline then
        self:changeSysMenuStatus("switch", true, true)
    end

    if seatId == self.agent.selfSeatId and self.is_offline then
        UIHelper.popMsg(self, "超时退出，请重新进入")
        local app = cc.exports.appInstance
        local nextScene = "LineScene"
        local view = app:createView(nextScene)
        view:showWithScene()
    end
end

function CommonLayer:repaintSysSay(str)
    local lblSay = self.topInfo.saying
    if not lblSay then
        local size = self.topInfo:getContentSize()

        lblSay = Constants.getLabel("", Constants.kBoldFontName, 26,
                            cc.p(size.width * 0.4,size.height * 0.5), self.topInfo)

        self.topInfo.saying = lblSay

        :setAnchorPoint(cc.p(0, 0.5))
        :setColor(cc.c3b(255, 255, 203))
        :setVisible(false)

        local saySize = lblSay:getContentSize()
        local sp = Constants.getSprite("loudspeaker.png", cc.p(0, saySize.height * 0.01), lblSay)
        sp:setAnchorPoint(cc.p(1.0, 0.5))
        lblSay.sp = sp
    end

    if str then
        str = string.format("［系统］:  %s", str)
        lblSay:setString(str)
        lblSay.sp:setPosition(cc.p(0, lblSay:getContentSize().height * 0.5))

        lblSay:stopAllActions()

        local act = cc.Show:create()
        local act1 = cc.DelayTime:create(2.5)
        local act2 = cc.Hide:create()
        lblSay:runAction(cc.Sequence:create(act, act1, act2))
    end
end

function CommonLayer:resetStartGame(type)
    self.selectCards = {}
    self.runHandCards = {}
    self.runCount   = 1
    self.discloseLbl = {}

    if type then
        if self.gameMaster then
            self.gameMaster:removeFromParent()
            self.gameMaster = nil
        end

        UIHelper.removeSpriteArray(self.topInfo.cards)
        self.topInfo.cards = {}

        for i = 1, 3 do
            UIHelper.removeSpriteArray(self.player_info[i].cards)
            self.player_info[i].cards = {}

            UIHelper.removeSpriteArray(self.lastCards[i])
            self.lastCards[i] = {}

        	UIHelper.removeSpriteArray(self.showhandCards[i])
        	self.showhandCards[i] = {}

            local bg_info = self.player_info[i]
            bg_info.mult:setString("")
            bg_info.bgscore:setVisible(false)
            bg_info.name:setString("")
        end
    end

    if self.m_roomOverTip then
        self.m_roomOverTip:runAction(cc.Sequence:create(cc.FadeTo:create(0.5, 0),
                                                cc.CallFunc:create(function()
                                                    self.m_roomOverTip:removeFromParent()
                                                    self.m_roomOverTip = nil
                                                end)))
    end
end

function CommonLayer:touchChooseBegin(pos)
    for k, v in pairs(self.player_info[1].cards) do
        v.userdata = false
    end
    local cards = self.player_info[1].cards
    local num = self:PointToNum(pos, #cards) + 1
    local winSize = display.size
    if num > 0 and num <= #cards then
        SoundApp.playEffect("sounds/main/select.mp3")
    end
end

function CommonLayer:touchChoose(pos)
    local cards = self.player_info[1].cards
    local num = self:PointToNum(pos, #cards) + 1
    if num <= 0 or num > #cards then
        return
    end

    local sp = cards[num]
    if not sp then
        return
    end
    if not sp.userdata then
        self:toggleOneCard(sp)
        sp.userdata = true
    end
end

function CommonLayer:toggleOneCard(sp)
    local winSize = display.size
    local pos = cc.p(sp:getPosition())
    pos.y = 160
    local bool = false
    for k, v in pairs(self.selectCards) do
        if v == sp then
            table.remove(self.selectCards, k)
            bool = true
            break
        end
    end
    if not bool then
        table.insert(self.selectCards, sp)
        pos.y = pos.y + 50
    end

    sp:runAction(cc.MoveTo:create(0.05, pos))
end

function CommonLayer:PointToNum(pos, cardsCountT)
    local winSize = display.size
    local cardSp = Constants.getSprite("cardbg.png")
    local cardSize = cardSp:getContentSize()
    local leftBoundT = UIHelper.getCardsPos(0, cardsCountT).x - cardSize.width/2
    local rightBoundT = UIHelper.getCardsPos(cardsCountT-1, cardsCountT).x + cardSize.width/2
    local cardSpacingT = UIHelper.getCardsSpacing(cardsCountT)
    local topBoundT = winSize.height * 0.15 + cardSize.height/2
    local bottomBoundT = winSize.height * 0.15 - cardSize.height/2

    if pos.x < leftBoundT or pos.x > rightBoundT or pos.y > topBoundT or pos.y < bottomBoundT then
        return -1
    end

    local num = -1
    if pos.x > leftBoundT + cardSpacingT * cardsCountT then
        return cardsCountT-1
    else
        num = math.floor((pos.x - leftBoundT)/cardSpacingT)
    end

    return num
end

function CommonLayer:setCardListenner()
    local  listenner = cc.EventListenerTouchOneByOne:create()
    listenner:setSwallowTouches(true)

    listenner:registerScriptHandler(function(touch, event)
        local pos = self:convertToNodeSpace(touch:getLocation())
        self:touchChooseBegin(pos)
        self:touchChoose(pos)
        return true
    end,cc.Handler.EVENT_TOUCH_BEGAN)
    listenner:registerScriptHandler(function(touch, event)
        local pos = self:convertToNodeSpace(touch:getLocation())
        self:touchChoose(pos)
    end,cc.Handler.EVENT_TOUCH_MOVED)

    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listenner, self)
end

function CommonLayer:RequestCall(idx, type)
    SoundApp.playEffect("sounds/main/click.mp3")
    if idx == 1 then
        self.agent:sendLandlordOptions(1)
    else
        self.agent:sendLandlordOptions(2)
    end

    if self.winTip then
        self.winTip:removeFromParent()
        self.winTip = nil
    end
end

function CommonLayer:ClickJiaBei(idx)
    SoundApp.playEffect("sounds/main/click.mp3")
    if idx == 1 then
        self.agent:sendMultipleOptions(1)
    elseif idx == 2 then
        self.agent:sendMultipleOptions(2)
    else
        self.agent:sendMultipleOptions(4)
    end

    self:changeSysMenuStatus("buti", false, false)
    self:changeSysMenuStatus("ti", false, false)
    self:changeSysMenuStatus("huiti", false, false)
    self:changeSysMenuStatus("genti", false, false)
end

function CommonLayer:ClickThrow()
    SoundApp.playEffect("sounds/main/click.mp3")
    local gameInfo = self.agent.tableInfo.gameInfo
    local seatInfo = gameInfo.seatInfo[self.agent.selfSeatId]
    if not gameInfo then
        return
    end

    local cards = {}
    for k, v in pairs(self.player_info[1].cards) do
        for i, j in pairs(self.selectCards) do
            if v == j then
                table.insert(cards, v.value)
            end
        end
    end
    self.agent:sendThrowOptions(cards)
end

function CommonLayer:ClickPass()
    SoundApp.playEffect("sounds/main/click.mp3")
    local cards = {-1}
    self.agent:sendThrowOptions(cards)
    self:cleanSelectCards()
end

function CommonLayer:ClickReChoose()
    SoundApp.playEffect("sounds/main/click.mp3")
    self:cleanSelectCards()
    self.promptIndex = 0
end

function CommonLayer:ClickTip()
    SoundApp.playEffect("sounds/main/click.mp3")
    local co = coroutine.create(function ()
        self:do_ClickTip()
    end)

    coroutine.resume(co)
end

function CommonLayer:do_ClickTip()
    local winSize = display.size
    local gameInfo = self.agent.tableInfo.gameInfo
    local userdata = gameInfo.userdata
    local seatInfo = gameInfo.seatInfo[self.agent.selfSeatId]
    local testarr = {}

    if not self.prompts then
        local winCards  = gameInfo.winCards
        if not winCards then
            userdata:updateSeats(gameInfo.masterSeatId, self.agent.selfSeatId)
            self.prompts = self.agent:run_long_func("getDirectPrompts")
            --userdata:getDirectPrompts()
        else
            userdata:updateSeats(gameInfo.masterSeatId, self.agent.selfSeatId)
            self.prompts = self.agent:run_long_func("getFollowPrompts", gameInfo.winCards.cards)
            -- userdata:getFollowPrompts(gameInfo.winCards.cards)
        end
        self.promptCount = #self.prompts
        self.promptIndex = 0
    end

    local count = self.promptCount
    if count == 0 then
        self:ClickPass()
        self:handleACL(const.YUNCHENG_ACL_STATUS_NO_BIG_CARDS)
        return
    end

    self:cleanSelectCards()
    if self.promptIndex < count then
        self.promptIndex = self.promptIndex + 1
        testarr = self.prompts[self.promptIndex]
    elseif self.promptIndex == count then
        self.promptIndex = 0
        return
    end

    local ok, cards = const.getSelCards(seatInfo.handCards, const.getCardItSelf, testarr, const.getCardItSelf)
    if not ok then
        return
    end

    for k, v in pairs(cards) do
        if v then
            for i, j in pairs(self.player_info[1].cards) do
                if j.value == v then
                    local pos = cc.p(j:getPosition())
                    pos.y = 160 + 50
                    j:runAction(cc.Sequence:create(cc.DelayTime:create(0.05),
                        cc.MoveTo:create(0.05, pos)))
                    table.insert(self.selectCards, j)
                end
            end
        end
    end
    if self.aclNext == 1 or self.aclNext == 3 or self.aclNext == 6 or self.aclNext == 10 or self.aclNext == 15 then
        local strInfo = "tips_next.png"
        local strBack = "state_down.png"
        self:showACLInfo(strInfo, strBack)
    end
    self.aclNext = self.aclNext + 1
end

function CommonLayer:hideLandLordWinRate()
    if self.tip then
        self.tip:removeFromParent()
        self.tip = nil
    end
end

function CommonLayer:cleanSelectCards()
    local winSize = display.size
    for k, v in pairs(self.selectCards) do
        if v then
            local pos = cc.p(v:getPosition())
            pos.y = 160

            v:stopAllActions()
            v:runAction(cc.MoveTo:create(0.05, pos))
        end
    end
    self.selectCards = {}
end

function CommonLayer:outCardsAction(cards, seatId)
    local winSize = display.size

    local playerCardPos = {
        cc.p(winSize.width * 0.5, 160),
        cc.p(1702, 794),
        cc.p(218, 794)
    }

    local gameInfo = self.agent.tableInfo.gameInfo
    if not gameInfo then
        return
    end
    local userdata = gameInfo.userdata
    local node = userdata:getNodeType(cards)

    self:doEffect(node, seatId)

    local count = #cards
    local viewId = self:MapSeatToView(seatId)
    local fScaleFrom =  (viewId == 1) and 1.0 or 0.3
    local fScaleTo =  (viewId == 1) and 0.8 or 0.6
    local cardSpace = (viewId == 1) and 91 or 53

    local masterSeatId = self.agent.tableInfo.gameInfo.masterSeatId
    local isMaster = masterSeatId and (masterSeatId == seatId)

    UIHelper.removeSpriteArray(self.lastCards[viewId])
    self.lastCards[viewId] = {}

    local posOutCard = UIHelper.getOutCardPos(viewId)

    for k, v in ipairs(cards) do
        local sp = UIHelper.getCardSprite(v, playerCardPos[viewId], self, Constants.kLayerCard + 1, isMaster)
        sp:setScale(fScaleFrom)

    	local pos
    	if viewId == 2 then
    		pos = cc.p(posOutCard.x - (count - k)*cardSpace, posOutCard.y)
    	elseif viewId == 3 then
    		pos = cc.p(posOutCard.x + (k-1)*cardSpace, posOutCard.y)
    	else
    		local cardwidth = sp:getContentSize().width * fScaleTo
    		local width = (count - 1) * cardSpace + cardwidth
    		local startx = posOutCard.x - width * 0.5 + cardwidth * 0.5
    		pos = cc.p(startx+(k-1)*cardSpace,posOutCard.y)
    	end

        local act = cc.Spawn:create(cc.MoveTo:create(0.1, pos),
        							cc.ScaleTo:create(0.1, fScaleTo))
        act = cc.Sequence:create(act, cc.DelayTime:create(1.0))
        sp:runAction(act)

        table.insert(self.lastCards[viewId], sp)
    end

    self:repaintCardsBySeatId(seatId, gameInfo.seatInfo[seatId])

    if viewId == const.kCenterViewId then
        self.selectCards = {}
    end
end

function CommonLayer:RepaintThrowCards(seatId, cards)
    local winSize = display.size

    local viewId = self:MapSeatToView(seatId)
    local fScale =  (viewId == 1) and 0.8 or 0.6
    local cardSpace = (viewId == 1) and 91 or 48
    local count = #cards

    local masterSeatId = self.agent.tableInfo.gameInfo.masterSeatId
    local isMaster = masterSeatId and (masterSeatId == seatId)

    UIHelper.removeSpriteArray(self.lastCards[viewId])
    self.lastCards[viewId] = {}

    local posOutCard = UIHelper.getOutCardPos(viewId)

    for k, v in pairs(cards) do
        local sp = UIHelper.getCardSprite(v, cc.p(0,0), self, Constants.kLayerCard + 1, isMaster)
        sp:setScale(fScale)

        local pos
    	if viewId == 2 then
    		pos = cc.p(posOutCard.x - (count - k)*cardSpace, posOutCard.y)
    	elseif viewId == 3 then
    		pos = cc.p(posOutCard.x + (k-1)*cardSpace, posOutCard.y)
    	else
    		local cardwidth = sp:getContentSize().width * fScale
    		local width = (count - 1) * cardSpace + cardwidth
    		local startx = posOutCard.x - width * 0.5 + cardwidth * 0.5
    		pos = cc.p(startx+(k-1)*cardSpace,posOutCard.y)
    	end

    	sp:setPosition(pos)

        table.insert(self.lastCards[viewId], sp)
    end
end

function CommonLayer:ShowAllButton()
    if self.m_sysMenu then
        self:changeSysMenuStatus("buchu", true, true)
        self:changeSysMenuStatus("chupai", true, true)
        self:changeSysMenuStatus("chongxuan", true, true)
        self:changeSysMenuStatus("tishi", true, true)
    end
end

function CommonLayer:ShowAllButtonT()
    if self.m_sysMenu then
        self:changeSysMenuStatus("buchu", true, false)
        self:changeSysMenuStatus("chupai", true, true)
        self:changeSysMenuStatus("chongxuan", true, true)
        self:changeSysMenuStatus("tishi", true, true)
    end
end

function CommonLayer:HideAllButton()
    if self.m_sysMenu then
        self:changeSysMenuStatus("buchu", false, false)
        self:changeSysMenuStatus("chupai", false, false)
        self:changeSysMenuStatus("chongxuan", false, false)
        self:changeSysMenuStatus("tishi", false, false)
        self:changeSysMenuStatus("bujiao", false, false)
        self:changeSysMenuStatus("jiaodizhu", false, false)
        self:changeSysMenuStatus("buti", false, false)
        self:changeSysMenuStatus("ti", false, false)
        self:changeSysMenuStatus("huiti", false, false)
        self:changeSysMenuStatus("genti", false, false)
    end
end

function CommonLayer:repaintBottomMult(seatId)
    if seatId then
        local sexStr = self:getSexStr(seatId)
        local str = sexStr .. "jiabei1.mp3"
        self:playSoundDelay(str, 0.7)
    end

    self:repaintAllMultiple()
end

function CommonLayer:cleanLastCards(seatId)
    local winSize = display.size
    local num = math.random(1, 4)
    local sexStr = self:getSexStr(seatId)
    local str = string.format("buyao%d.mp3", num)
    str = sexStr .. str
    SoundApp.playEffect(str)

    local viewId = self:MapSeatToView(seatId)

    UIHelper.removeSpriteArray(self.lastCards[viewId])
    self.lastCards[viewId] = {}

    self:showTalkBubble(seatId, "buchu")
end

function CommonLayer:callLandLord(seatId, type)
    local gameInfo = self.agent.tableInfo.gameInfo
    local sexStr = self:getSexStr(seatId)
    local winSize = display.size
    local viewId = self:MapSeatToView(seatId)
    local str = ""

    if type == 2 then
        self:showTalkBubble(seatId, "bujiao")
        str = "noorder.mp3"
    else
        self:showTalkBubble(seatId, "jiaodizhu", 3)
        str = "order.mp3"

        local pos = {
	        cc.p(winSize.width * 0.5, 570),
	        cc.p(winSize.width - 600, 833),
	        cc.p(600, 833),
	    }

        local img = Constants.getSprite("dizhu.png", pos[viewId], self)
        img:setLocalZOrder(Constants.kLayerCard)
        img:setScale(0.1)
        img:runAction(cc.Sequence:create(cc.ScaleTo:create(0.2, 1),
                        cc.DelayTime:create(1),
                        cc.ScaleTo:create(0.3, 0.3),
                        cc.CallFunc:create(function()
                        img:removeFromParent()
                    end)))
    end

    str = sexStr .. str
    SoundApp.playEffect(str)
end

function CommonLayer:doEffect(node, seatId)
    self:playSoundDelay("sounds/main/givecard.mp3", 0.3)
    local sexStr = self:getSexStr(seatId)

    local gameInfo = self.agent.tableInfo.gameInfo
    local winCards  = gameInfo.winCards
    local xr = math.random(1, 10)
    if winCards and winCards.seatId and winCards.seatId ~= seatId then
        if xr < 4 then
            if (not const.isRocket(node)) and (not const.isBomb(node)) then
                local str = string.format("dani%d.mp3",xr)
                str = sexStr .. str
                self:playSoundDelay(str, 0.3)
                return
            end
        end
    end

    local resTbl = UIHelper.parseCardType(node, sexStr)
    if resTbl.music then
        SoundApp.playBackMusic(resTbl.music)
    end

    if resTbl.anim then
        UIHelper.doAnimation(resTbl.anim, self)
    end

    for _,sound in ipairs(resTbl.sound) do
        self:playSoundDelay(sound, 0.3)
    end
end

function CommonLayer:playSoundDelay(str, t)
    self:runAction(cc.Sequence:create(cc.DelayTime:create(t),
                                     cc.CallFunc:create(function() SoundApp.playEffect(str) end)
                                     ))
end

function CommonLayer:getSexStr(seatId)
    local user = self.agent:GetUserAtSeat(seatId)
    local avatarID = 1
    if user and user.FAvatarID then
        avatarID = user.FAvatarID
    end
    local sexStr = string.format("sounds/%s/", UIHelper.getUserGender(avatarID))

    return sexStr
end

function CommonLayer:repaintAllMultiple()
    local gameInfo = self.agent.tableInfo.gameInfo
    for i=1,3 do
        local viewId = self:MapSeatToView(i)
        local one = self.player_info[viewId]
        local seatInfo = gameInfo.seatInfo[i]
        local str = string.format("%d倍", seatInfo.multiple * (1 << gameInfo.bombCount))
        one.mult:setString(str)
    end
end

function CommonLayer:ShowMultiple(seatId, callMult, notSay)
    local viewId = self:MapSeatToView(seatId)
    local sexStr = self:getSexStr(seatId)
    local str = nil

    if callMult == -1 then
        str = sexStr .. "jiabei0.mp3"
    else
        str = sexStr .. "jiabei1.mp3"
    end

    if str and (not notSay) then
        SoundApp.playEffect(str)
    end

    self:repaintAllMultiple()
end

function CommonLayer:showWinZhishu()
    local winSize = display.size
    local gameInfo = self.agent.tableInfo.gameInfo
    local seatInfo = gameInfo.seatInfo[self.agent.selfSeatId]
    local userdata = gameInfo.userdata
    local winPoss = math.floor(userdata:getWinPossible(seatInfo.handCards) * 10)
    local star = {}

    for i = 1, 5 do
        if math.floor(winPoss/2) ~= 0 then
            winPoss = winPoss - 2
            table.insert(star, 1)
        elseif winPoss%2 ~= 0 then
            winPoss = winPoss - 1
            table.insert(star, 2)
        else
            table.insert(star, 3)
        end
    end

    local pos = cc.p(winSize.width * 0.4, winSize.height * 0.32)

    local tip = Constants.getSprite("tips_zhishu.png", pos, self)
    tip:setLocalZOrder(Constants.kLayerText)
    self.winTip = tip
    local TipSize = tip:getContentSize()

    for i = 1, 5 do
        local str = string.format("star%02d.png", star[i])
        local sp = Constants.getSprite(str)

        local offX = sp:getContentSize().width
        tip:addChild(sp, Constants.kLayerText)
        sp:setPosition(cc.p(TipSize.width + offX/2 + offX * i, TipSize.height * 0.55))
    end

    if self.winTip then
        local act = cc.Sequence:create(
            cc.DelayTime:create(3),
            cc.CallFunc:create(function()
            if self.winTip then
                self.winTip:removeFromParent()
                self.winTip = nil
            end
            end))
        self.winTip:runAction(act)
    end
end

function CommonLayer:SayLeftCard(seatId, cards)
    local count = #cards
    if count == 1 then
        local sexStr = self:getSexStr(seatId)
        local str = sexStr .."baojing1.mp3"
        self:playSoundDelay(str, 0.5)
        SoundApp.playEffect("sounds/main/alert.mp3")
    elseif count == 2 then
        local sexStr = self:getSexStr(seatId)
        local str = sexStr .."baojing2.mp3"
        self:playSoundDelay(str, 0.5)
        SoundApp.playEffect("sounds/main/alert.mp3")
    end
end

function CommonLayer:SayRemain()
    SoundApp.playEffect("sounds/main/ring.mp3")
end

function CommonLayer:GetUserAtSeat(seatId)
    local user = self.agent:GetUserAtSeat(seatId)
    return user
end

function CommonLayer:showTalkBubble(seatId, strType, wordCnt)
    local viewId = self:MapSeatToView(seatId)
    UIHelper.showTalkBubble(viewId, strType, wordCnt, self, Constants.kLayerText)
end

function CommonLayer:initLeftTopPanel()
    local winSize = display.size
    local bg = Constants.get9Sprite("bg_wifi.png",
                                    cc.size(305, 0),
                                    cc.p(480, winSize.height - 45),
                                    self)
    self.m_leftTopPanel = bg
end

function CommonLayer:updateNetorkStatus()
    if not self.m_leftTopPanel then
        self:initLeftTopPanel()
    end

    local bg = self.m_leftTopPanel
    if bg.netUpTime and (skynet.time() - bg.netUpTime < 3) then
        return
    end

    if bg.spNet then
        bg.spNet:removeFromParent()
        bg.spNet = nil
    end

    local netType = OSNative.getNetworkType() or ""
    local strPath = nil
    if netType == "WIFI" then
        strPath = "net_wifi.png"
    elseif netType == "4G" then
        strPath = "net_mobile.png"
    else
        strPath = "net_none.png"
    end

    if strPath then
        local bgSize = bg:getContentSize()
        bg.spNet = Constants.getSprite(strPath, cc.p(110, bgSize.height * 0.5), bg)
        bg.spNet:setScale(0.6)
    end

    bg.netUpTime = skynet.time()
end

function CommonLayer:updateBatteryStatus()
    if not self.m_leftTopPanel then
        self:initLeftTopPanel()
    end

    local bg = self.m_leftTopPanel
    local bgSize = bg:getContentSize()

    if not bg.lblTime then
        bg.lblTime = Constants.getLabel("", Constants.kBoldFontNamePF, 36,cc.p(140, bgSize.height * 0.5), bg)
        bg.lblTime:setAnchorPoint(0, 0.5)
    end
    bg.lblTime:setString(""..os.date("%X"))

    if bg.btUpTime and (skynet.time() - bg.btUpTime < 3) then
        return
    end

    if bg.spBattery then
        bg.spBattery:removeFromParent()
        bg.spBattery = nil
    end

    local batteryLvl = OSNative.getBatteryLevel() or 0
    bg.spBattery = Constants.getSprite("bg_battery.png", cc.p(50, bgSize.height * 0.5), bg)
    bg.spBattery:setScale(0.6)

    local prgrs = cc.ProgressTimer:create(cc.Sprite:createWithSpriteFrameName("battery_prgrs.png"))
    prgrs:setType(cc.PROGRESS_TIMER_TYPE_BAR)
    prgrs:setBarChangeRate(cc.p(1, 0))
    prgrs:setMidpoint(cc.p(0, 1))
    prgrs:setPosition(cc.p(43, 18))
    prgrs:setPercentage(100 * batteryLvl)
    bg.spBattery:addChild(prgrs)

    bg.btUpTime = skynet.time()
end

function CommonLayer:checkPass()
    local winSize = display.size
    local gameInfo = self.agent.tableInfo.gameInfo
    local userdata = gameInfo.userdata

    if not self.prompts then
        local winCards  = gameInfo.winCards
        if not winCards then
            userdata:updateSeats(gameInfo.masterSeatId, self.agent.selfSeatId)
            self.prompts = self.agent:run_long_func("getDirectPrompts")
            --userdata:getDirectPrompts()
        else
            userdata:updateSeats(gameInfo.masterSeatId, self.agent.selfSeatId)
            self.prompts = self.agent:run_long_func("getFollowPrompts", gameInfo.winCards.cards)
            -- userdata:getFollowPrompts(gameInfo.winCards.cards)
        end
        self.promptCount = #self.prompts
        self.promptIndex = 0
    end

    local count = self.promptCount
    if count == 0 then
        local ndAction = display.newNode()
        ndAction:addTo(self)
                :runAction(cc.Sequence:create(cc.DelayTime:create(2),
                                              cc.CallFunc:create(function()
                                                    self:ClickPass()
                                                    self:handleACL(const.YUNCHENG_ACL_STATUS_NO_BIG_CARDS)
                                                end),
                                              cc.RemoveSelf:create()))
        return
    else
        if not gameInfo.winCards then
            self:ShowAllButtonT()
        else
            self:ShowAllButton()
        end
    end
end

return CommonLayer
