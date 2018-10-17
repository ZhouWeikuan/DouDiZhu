local HallScene = class("HallScene", cc.load("mvc").ViewBase)
local class = HallScene

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"

local packetHelper  = require "PacketHelper"
local LoginHelper   = require "LoginHelper"
local UIHelper      = require "UIHelper"

local protoTypes    = require "ProtoTypes"
local const         = require "Const_YunCheng"
local AuthUtils     = require "AuthUtils"

function HallScene:onCreate()
    cc.SpriteFrameCache:getInstance():addSpriteFrames("hallscene.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("buttons.plist")

    self.authInfo = AuthUtils.getAuthInfo()
    self.userInfo = {}

    display.newSprite(CC_DESIGN_RESOLUTION.background)
        :move(display.center)
        :addTo(self)

    local winSize = display.size
    self.m_girl = Constants.getSprite("hs_center.png", cc.p(winSize.width * 0.5, winSize.height * 0.4), self)
    Constants.getSprite("hs_banner_bottom.png", cc.p(winSize.width * 0.5, 53), self)

    self:initBtn()
    self:initTopInfo()
    self:repaintRoomList()

    self:showNotice("【系统公告】", "本游戏仅供亲朋好友间娱乐，请遵守国家法律，禁止赌博，一经发现，终生封号！")
end

function HallScene:initBtn()
    local buttonMenu = cc.Menu:create()
    buttonMenu:addTo(self)
    buttonMenu:setPosition(0, 0)

    local item = Constants.getMenuItem("createroom")
    item:registerScriptTapHandler(function() self:clickCreateRoom() end)
    item:addTo(buttonMenu)
    item:setPosition(1595, 840)

    item = Constants.getMenuItem("enterroom")
    item:registerScriptTapHandler(function() self:clickEnterRoom() end)
    item:addTo(buttonMenu)
    item:setPosition(1595, 580)

    item = Constants.getMenuItem("createroom")
    item:registerScriptTapHandler(function() self:clickJoinGame() end)
    item:addTo(buttonMenu)
    item:setPosition(1595, 320)

    local btnDefs = {
        {name = "hsback", func = function() self:backLine() end},
        {name = "hsbind", func = function() self:clickBind() end},
        {name = "hs_set", func = function() self:clickSetting() end},
        {name = "about", func = function() self:clickAbout() end},
        {name = "history", func = function() self:clickHistory() end},
        {name = "store", func = function() self:shopInfo() end},
    }

    self.m_btns = {}

    for _, one in ipairs(btnDefs) do
        local item = Constants.getMenuItem(one.name)
        item:addTo(buttonMenu)
            :setAnchorPoint(0.5, 0)
            :registerScriptTapHandler(one.func)

        item.name = one.name
        table.insert(self.m_btns, item)
    end

    self:updateBtnPos()
end

function HallScene:updateBtnPos()
    local winSize = display.size
    local count = #self.m_btns
    local maxSpace = 230
    local area = 1000
    local space = area / (count - 1)
    space = math.min(space, maxSpace)

    local posx = winSize.width * 0.5 - (count - 1) * space * 0.5

    for _, item in ipairs(self.m_btns) do
        item:setPosition(posx, 44)
        posx = posx + space
    end
end

function HallScene:backLine ()
    SoundApp.playEffect("sounds/main/click.mp3")

    local app = cc.exports.appInstance
    local view = app:createView("MainScene")
    view.nextSceneName = "LineScene"
    view:showWithScene()
end

function HallScene:clickCreateRoom()
    SoundApp.playEffect("sounds/main/click.mp3")

    local CreateRoomLayer = require "CreateRoomLayer"
    local layer = CreateRoomLayer.create(self)
    layer:addTo(self, Constants.kLayerPopUp)
end

function HallScene:clickEnterRoom()
    SoundApp.playEffect("sounds/main/click.mp3")

    local EnterRoomLayer = require "EnterRoomLayer"
    local layer = EnterRoomLayer.create(self)
    layer:addTo(self, Constants.kLayerPopUp)
end

function HallScene:clickJoinGame()
    SoundApp.playEffect("sounds/main/click.mp3")

    Settings.setRoomId(0)

    self:toNextScene()
end

function HallScene:clickHistory()
    SoundApp.playEffect("sounds/main/click.mp3")

    local ReplayLayer = require "ReplayLayer"
    local layer = ReplayLayer.create(self)
    layer:addTo(self, Constants.kLayerPopUp)

    layer:showReplayLayer()
end

function HallScene:clickSetting()
    SoundApp.playEffect("sounds/main/click.mp3")

    local SettingLayer = require "SettingLayer"
    local layer = SettingLayer.create(self)
    layer:addTo(self, Constants.kLayerPopUp)
end

function HallScene:clickAbout()
    SoundApp.playEffect("sounds/main/click.mp3")

    local AboutLayer = require "AboutLayer"
    local layer = AboutLayer.create(self)
    layer:addTo(self, Constants.kLayerPopUp)
end

function HallScene:clickHead()
    SoundApp.playEffect("sounds/main/click.mp3")

    local winSize = display.size
    local pos = cc.p(64, winSize.height - 64)

    local HsPlayerInfo = require "HsPlayerInfo"
    local layer = HsPlayerInfo.create(self)
    layer:addTo(self ,Constants.kLayerPopUp)
         :showLayer(pos)

    if self.m_roomList then
        self.m_roomList:setVisible(false)
    end
end

function HallScene:makeHead()
    local headBg = Constants.getSprite("bg_hs_head.png")
    local headSize = headBg:getContentSize()

    local sten = cc.Sprite:createWithSpriteFrameName("bg_sten.png")
    local clipper = cc.ClippingNode:create()
    clipper:setStencil(sten)
    clipper:setAlphaThreshold(0.5)
           :addTo(headBg)
           :setScale(0.71)
           :setPosition(headSize.width * 0.5, headSize.height * 0.5)

    local roleSp = Constants.getSprite("icon_role0.png", cc.p(0,0), clipper)
    return headBg, roleSp
end

function HallScene:initTopInfo()
    if self.bg_topInfo then
        return
    end

    self.bg_topInfo = {}
    local winSize = display.size
    --top
    local bgUp = Constants.getSprite("hs_banner_top.png", cc.p(winSize.width * 0.5, winSize.height), self)
    bgUp:setAnchorPoint(0.5,1)

    local bgSize = bgUp:getContentSize()

    -- 头像
    local menu = cc.Menu:create()
    menu:addTo(bgUp)
    menu:setPosition(0, 0)

    local headBg, roleSp = self:makeHead()
    local itemHead = cc.MenuItemSprite:create(headBg, headBg)
    itemHead:registerScriptTapHandler(function() self:clickHead() end)
    itemHead:addTo(menu)
            :setPosition(64, bgSize.height - 64)
            :setScale(0.69)

    self.bg_topInfo.icon = roleSp

    -- 名字
    local bgNamelbl = Constants.getLabel("", Constants.kBoldFontName, 35, cc.p(138, bgSize.height - 20),bgUp)
    bgNamelbl:setAnchorPoint(0,1)
    self.bg_topInfo.nickname = bgNamelbl

    -- 公告
    local spBgNotice = Constants.getSprite("bg_hs_notice.png", cc.p(bgSize.width, bgSize.height - 57), bgUp)
    spBgNotice:setAnchorPoint(1, 1)

    local sten = Constants.get9Sprite("bg_vague.png", cc.size(895, 50))
    local clipper = cc.ClippingNode:create()
    clipper:setStencil(sten)
    clipper:addTo(spBgNotice)
           :setPosition(457, 27)

    self.bg_topInfo.ntcClipper = clipper

    -- uid
    local spBgUID = Constants.get9Sprite("bg_hs_uid.png", cc.size(264,41), cc.p(127, bgSize.height - 73), bgUp)
    spBgUID:setAnchorPoint(0, 1)
    Constants.getSprite("hs_uid.png", cc.p(42, 20), spBgUID)
    self.bg_topInfo.lbUID = Constants.getLabel("", Constants.kBoldFontName, 30,cc.p(246, 20),spBgUID)
    self.bg_topInfo.lbUID:setAnchorPoint(1, 0.5)

    -- 元宝
    local spBgCard = Constants.get9Sprite("bg_hs_uid.png", cc.size(222,41), cc.p(420, bgSize.height - 73), bgUp)
    spBgCard:setAnchorPoint(0, 1)
    Constants.getSprite("hs_gold.png", cc.p(29, 20), spBgCard)
    self.bg_topInfo.lbGoldNum = Constants.getLabel("", Constants.kBoldFontName, 30,cc.p(206, 20),spBgCard)
    self.bg_topInfo.lbGoldNum:setAnchorPoint(1, 0.5)
end

function HallScene:postAuthAction ()
    print("HallScene postAuthAction", self.authOK)
    local login = self.login
    if not login then
        return
    end

    login:tryHall(AuthUtils.getItem(AuthUtils.keyGameMode, 0))
end

function HallScene:postJoinAction ()
    print("HallScene postJoinAction", self.authOK)
    self:updateInfo()
end

function HallScene:onEnter_()
    self.lastUpdate = skynet.time()
    local ret = LoginHelper.createFromLayer(self, self, "BotPlayer_YunCheng", self.authInfo, const)
    if not ret then
        self:returnBack()
    end

    -- OSNative.setLeaveListener(function()
    --     if self.login then
    --         self.login:closeSocket()
    --     end
    -- end)

    Constants.startScheduler(self, self.tickFrame, 0.05)
    -- OSNative.startLocation()
end

-- function HallScene:updateLocation(longitude, latitude, altitude)
--     local info = {}
--     info.FUniqueID  = self.userInfo.FUniqueID

--     info.FLongitude = longitude
--     info.FLatitude  = latitude
--     info.FAltitude  = altitude
--     info.FLocation  = self.location_address

--     local packet  = packetHelper:encodeMsg("CGGame.UserInfo", info)
--     packet        = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_TYPE_SETUSERINFO, nil, packet)
--     self.agent:sendPacket(packet)
-- end

-- function HallScene:checkLocation ()
--     if self.location_address then
--         return
--     end

--     local a, b, c, d = OSNative.getLocation()
--     if d ~= "" then
--         self.location_address = d
--         OSNative.stopLocation()

--         self:updateLocation(a, b, c)
--     end
-- end

function HallScene:onExit_()
    Constants.stopScheduler(self)

    if self.login then
        self.login:releaseFromLayer(self)
    end
end

function HallScene:tickFrame (dt)
    -- self:checkLocation()
    local now = skynet.time()

    local login = self.login
    if login:tickCheck(self) then
        local networkLayer = require "NetworkLayer"
        networkLayer.create(self)

        self.lastUpdate = now
    end

    local delta = now - self.lastUpdate
    if delta > 3.0 then
        login:closeSocket()
        self.lastSend = nil
    elseif (delta > 1.0 and not self.lastSend) then
        login:sendHeartBeat()
        self.lastSend = true
    end

    while login.remotesocket do
        local p = login.remotesocket:recvPacket()
        if p then
            self.lastSend   = nil
            self.lastUpdate = now
            self.agent:recvPacket(p)
        else
            break
        end
    end

    self.agent:tickFrame()
end

function HallScene:updateInfo()
    local login = self.login
    if not login then
        return
    end

    local info = {
        FUserCode   = self.authInfo.userCode,
        FNickName   = self.authInfo.nickname,
        FAvatarUrl  = self.authInfo.avatarUrl,
    }
    info.fieldNames = {"FUserCode", "FNickName", "FAvatarUrl", "FAvatarID"}

    if info.FAvatarUrl and info.FAvatarUrl ~= "" then
        local gender = Settings.getPlayerGender()
        info.FAvatarID = gender
    else
        info.FAvatarID  = self.authInfo.avatarId
    end

    local data = packetHelper:encodeMsg("CGGame.UserInfo", info)
    local packet = packetHelper:makeProtoData(protoTypes.CGGAME_PROTO_MAINTYPE_HALL,
                        protoTypes.CGGAME_PROTO_SUBTYPE_MYINFO, data)
    self.agent:sendPacket(packet)
end

function HallScene:command_handler (user, packet)
    local login = self.login

    if login.remotesocket then
        login.remotesocket:sendPacket(packet)
    end
end

function HallScene:recvNotice(chatInfo)
    local str = string.format("[%s]:%s", chatInfo.speakerNick or "系统通知", chatInfo.chatText)

    local winSize = display.size
    local bg_sys = ccui.Scale9Sprite:createWithSpriteFrameName("bg_notice.png")
    bg_sys:addTo(self, Constants.kLayerPopUp)
    bg_sys:setAnchorPoint(0.5, 1.0)
    bg_sys:setPosition(winSize.width * 0.5, winSize.height)
    bg_sys:setContentSize(1300, 80)
    bg_sys:setOpacity(0)
    bg_sys:setCascadeOpacityEnabled(true)

    local bg_sysSize = bg_sys:getContentSize()

    local lblsys = cc.Label:createWithSystemFont(str, Constants.kBoldFontName, 36)
    lblsys:addTo(bg_sys)
    lblsys:setAnchorPoint(0.5, 0.5)
    lblsys:setPosition(bg_sysSize.width * 0.5, bg_sysSize.height * 0.5)
    lblsys:setColor(cc.c3b(255, 243, 53))
    lblsys:enableOutline(cc.c4b(0, 0, 0, 255), 1)

    local act = cc.Sequence:create(
        cc.FadeIn:create(1.0),
        cc.DelayTime:create(5.0),
        cc.FadeOut:create(1.0),
        cc.CallFunc:create(function()
            bg_sys:removeFromParent()
            end)
        )
    bg_sys:runAction(act)
end

function HallScene:handleACL(aclInfo)
    local aclType = aclInfo.aclType
    if aclType == protoTypes.CGGAME_ACL_STATUS_SERVER_BUSY then
        MessageBox("msgConnectError", "msgServerIsFull")
        self:returnBack()
    elseif aclType == protoTypes.CGGAME_ACL_STATUS_INVALID_INFO then
        UIHelper.popMsg(self, "invalid command, acl invalid")

    elseif aclType == protoTypes.CGGAME_ACL_STATUS_COUNTER_FAILED then
        local title = getUTF8LocaleString("msgLackCounter")
        local body  = getUTF8LocaleString("msgBuyCounterOrDailyLogin")

        UIHelper.popMsg(self, title..","..body)
    elseif aclType == protoTypes.CGGAME_ACL_STATUS_AUTH_FAILED then
    else
        if aclType == protoTypes.CGGAME_ACL_STATUS_ROOM_FIND_FAILED then
            Settings.rmvFromRoomList(self.m_roomList:getRoomId())
            self:repaintRoomList()
        end

        local strErr = Constants.getAclErrText(aclType)
        if strErr == nil then
            print ("unknown acl type = ", aclType)
            return
        end

        UIHelper.popMsg(self, strErr)
    end
end

function HallScene:handleRoomInfo (roomInfo, roomDetails)
    Settings.setRoomId(roomInfo.roomId)
    Settings.addToRoomList(roomInfo)

    self.m_roomList:clearRoomId()

    self:repaintRoomList()

    self:toNextScene()
end

function HallScene:handleBuyChip (msg)
    local count = msg.subType
    local str = string.format("您已购买%d个元宝", count)

    UIHelper.popMsg(self, str)
end

function HallScene:UpdateUserStatus (user)
    local info = self.agent:GetUserInfo(user.FUserCode)
    if not info then
        return
    end

    self.userInfo = info
    if self.bg_topInfo then
        local bg = self.bg_topInfo

        Constants.getUserHeadSprite(bg.icon, info)

        local str = info.FNickName or ""
        bg.nickname:setString(str)

        local nick = Settings.getPlayerName()
        if nick ~= str then
            Settings.setPlayerName(str)
        end

        str = info.FUserCode or ""
        bg.lbUID:setString(str)

        str = string.format("%d", info.FCounter or 0)
        bg.lbGoldNum:setString(str)

        -- OSNative.submitScore(info.FScore or 0, "com.cronlygames.yuncheng.score")

        self:updateBindInfo(info)
    end
end

function HallScene:returnBack()
    local app = cc.exports.appInstance
    local view = app:createView('MainScene')
    view:showWithScene()
end

function HallScene:toNextScene ()
    local app = cc.exports.appInstance
    local view = app:createView('MainScene')
    view:showWithScene()
    view.nextSceneName = "OnlineScene"
end

function HallScene:shopInfo()
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

function HallScene:showNotice(strHead, strBody)
    local clipper = self.bg_topInfo.ntcClipper
    clipper:removeAllChildren()
    local hw = 895 * 0.5

    local ndNotice = display.newNode()
    clipper:addChild(ndNotice)

    local lb = Constants.getLabel(strHead, Constants.kBoldFontName, 25, cc.p(0, 0),ndNotice)
    lb:setColor(cc.c3b(0xd3, 0xfd, 0x52))
      :setAnchorPoint(0, 0.5)
    local lbHeadSize = lb:getContentSize()

    lb = Constants.getLabel(strBody, Constants.kBoldFontName, 25, cc.p(lbHeadSize.width, 0),ndNotice)
    lb:setColor(cc.c3b(0xc1, 0xbf, 0xbf))
      :setAnchorPoint(0, 0.5)
    local lbBodySize = lb:getContentSize()

    local noticeWidth = lbHeadSize.width + lbBodySize.width
    local dur = 3 * noticeWidth / (1090 / 5)

    local act = cc.Sequence:create(
            cc.Place:create(cc.p(hw, 0)),
            cc.MoveTo:create(1, cc.p(-hw, 0)),
            cc.DelayTime:create(2),
            cc.MoveTo:create(dur, cc.p(-hw-noticeWidth, 0)))

    ndNotice:runAction(cc.RepeatForever:create(act))
end

function HallScene:updateBindInfo(info)
    local pos = cc.p(806, 72)

    local agentCode = info.FAgentCode or 0
    if self.m_sp_flag then
        self.m_sp_flag:removeFromParent()
        self.m_sp_flag = nil
    end

    local bgSize = self.m_girl:getContentSize()
    local pos = cc.p(bgSize.width - 105, bgSize.height - 118)
    if agentCode > 0 then
        local img = Constants.getSprite("flg_bind_y.png", pos, self.m_girl)
        self.m_sp_flag = img
        img:setVisible(false)
        img:runAction(cc.Sequence:create(
            cc.DelayTime:create(3.0),
            cc.Show:create(),
            cc.DelayTime:create(10.0),
            cc.FadeTo:create(0.5, 20),
            cc.CallFunc:create(function()
                img:removeFromParent()
            end)
        ))

        for k,item in ipairs(self.m_btns) do
            if item.name == "hsbind" then
                item:removeFromParent()
                table.remove(self.m_btns, k)
                self:updateBtnPos()
                break
            end
        end
    else
        self.m_sp_flag = Constants.getSprite("flg_bind_n.png", pos, self.m_girl)
    end
end

function HallScene:clickBind()
    SoundApp.playEffect("sounds/main/click.mp3")

    local AgentCodeLayer = require "AgentCodeLayer"
    local layer = AgentCodeLayer.create(self)
    layer:addTo(self, Constants.kLayerPopUp)
end

function HallScene:repaintRoomList()
    if not self.m_roomList then
        local HsRoomList = require "HsRoomList"
        local layer = HsRoomList.create(self)
        layer:addTo(self)
        self.m_roomList = layer
    end

    self.m_roomList:repaintInfo()
end

function HallScene:removePlayerInfo()
    if self.m_roomList then
        self.m_roomList:setVisible(true)
    end
end


return HallScene
