local LoginScene = class("LoginScene", cc.load("mvc").ViewBase)
local class = LoginScene

local skynet        = skynet or require "skynet"

local Constants     = require "Constants"
local LoginHelper   = require "LoginHelper"
local WaitList      = require "WaitList"
local AuthUtils     = require "AuthUtils"

local protoTypes    = require "ProtoTypes"
local const         = require "Const_YunCheng"
local BotPlayer     = require "BotPlayer_YunCheng"

function LoginScene:onCreate()
    local rot = CC_DESIGN_RESOLUTION.backgroundAngle or 0

    -- add background image
    self.back = display.newSprite(CC_DESIGN_RESOLUTION.background)
        :move(display.center)
        :addTo(self)
        :setRotation(rot)

    local winSize = display.size
    local skeletonNode = sp.SkeletonAnimation:create("eff/loading/loading.json", "eff/loading/loading.atlas")
    skeletonNode:setAnimation(0, "loading", true)
        :addTo(self, 1)
        :setPosition(winSize.width * 0.5, winSize.height * 0.5)
        :setScale(1.5)

    local lblTips = cc.Label:createWithSystemFont("", Constants.kBoldFontName, 48)
    self.lblTips = lblTips
    lblTips:addTo(self, Constants.kLayerText)
        :move(winSize.width*0.5, winSize.height*0.18)

    if not Constants.isScreenIPad() then
        lblTips:move(winSize.width*0.5, winSize.height*0.13)
    end

    self:initAuth()
    self.authInfo = AuthUtils.getAuthInfo()

    self.exes = WaitList.create()

    self.lastUpdate = skynet.time()
    self.login = LoginHelper.create(const)
    self:updateTips(self.login.message)

    local agent = BotPlayer.create(self, self.authInfo)
    self.agent  = agent
end

function LoginScene:onEnter_()
    self.back:runAction(cc.Sequence:create(cc.DelayTime:create(10),
            cc.CallFunc:create(function()
                self:returnBack("msgConnectError", "msgServerIsFull")
            end)))

    Constants.startScheduler(self, self.tickFrame, 0.05)

    local co = coroutine.create(function ()
            self:mainLoop()
        end)
    coroutine.resume(co)
end

function LoginScene:onExit_()
    Constants.stopScheduler(self)

    local login = self.login
    if login then
        login:releaseFromLayer(self)
    end
end

local function toNextScene(self, delay)
    self.back:runAction(cc.Sequence:create(cc.DelayTime:create(delay or 1),
        cc.CallFunc:create(function() self:nextScene() end)))
end
class.toNextScene = toNextScene

local function nextScene(self)
    local name = "HallScene"

    local app = self:getApp()
    local view = app:createView(name)
    view:showWithScene()
end
class.nextScene = nextScene

local function lastScene(self)
    local name = "LineScene"

    local app = self:getApp()
    local view = app:createView(name)
    view:showWithScene()
end
class.lastScene = lastScene

local function returnBack(self, msgTitle, msgBody, delay)
    Constants.stopScheduler(self)

    local strTitle = getUTF8LocaleString(msgTitle)
    local strBody = getUTF8LocaleString(msgBody)
    MessageBox(strBody, strTitle)

    self.back:runAction(cc.Sequence:create(cc.DelayTime:create(delay or 2),
        cc.CallFunc:create(function() self:lastScene() end)))
end
class.returnBack = returnBack

function LoginScene:initAuth ()
    print("initAuth")

    local uid = AuthUtils.getItem(AuthUtils.keyPlayerId, "")
    if uid == "" then
        local uid = math.random(100000, 999999)
        AuthUtils.setItem(AuthUtils.keyPlayerId, "G:" .. tostring(uid))
        AuthUtils.setItem(AuthUtils.keyPassword, "apple")
        AuthUtils.setItem(AuthUtils.keyNickname, "test" .. tostring(uid))
        AuthUtils.setItem(AuthUtils.keyOSType, "client")
        AuthUtils.setItem(AuthUtils.keyPlatform, "client")
    end
end

function LoginScene:command_handler (user, packet)
    local login = self.login
    if login.remotesocket then
        login.remotesocket:sendPacket(packet)
    end
end

function LoginScene:tickFrame (dt)
    local now = skynet.time()
    local login = self.login

    local delta = now - self.lastUpdate
    if delta > 3.0 then
        login:closeSocket()
    elseif delta > 1.0 then
        login:sendHeartBeat()
    end

    while login.remotesocket do
        local p = login.remotesocket:recvPacket()
        if p then
            self.lastUpdate = now
            self.agent:recvPacket(p)
        else
            break
        end
    end

    self.agent:tickFrame()

    self.exes:resume()
end

function LoginScene:delaySomeTime (delay)
    local limit = skynet.time() + delay
    local now = skynet.time()
    while now < limit do
        self.exes:pause()
        now = skynet.time()
    end
end

function LoginScene:mainLoop()
    -- 1. check network
    -- local netOk = OSNative.isNetworkOpen(true)
    -- if not netOk then
    --     self:returnBack("msgNetworkIssue", "msgUnableConnect_CheckNetworkSettings")
    --     return
    -- end

    -- 2. refresh login list
    local login = self.login
    login:getOldLoginList(true, true)
    self:updateTips(login.message)
    self:delaySomeTime(0.1)

    -- 3. check agent list
    local hasAgent = nil
    for k, v in pairs(login.agentList) do
        hasAgent = true
        break
    end
    if not hasAgent then
        self:returnBack("msgConnectError", "msgServerIsFull")
        return
    end

    -- 4. connect to agent server
    login:tryConnect()
    self:updateTips(login.message)
    self:delaySomeTime(0.1)

    -- 5. get new agent list
    login:getAgentList()
    self:updateTips(login.message)
    self:delaySomeTime(0.1)

    -- 6. ask auth
    login.message = "msgUserAskAuthResume"
    self:updateTips(login.message)
    self.agent:sendAuthOptions(protoTypes.CGGAME_PROTO_SUBTYPE_ASKRESUME)

    while not self.authOK do
        self.exes:pause()
    end
end

function LoginScene:postAuthAction ()
    Constants.stopScheduler(self)
    self:toNextScene()
end

local function updateTips(self, str)
    local str = getUTF8LocaleString(str)
    self.lblTips:setString(str)
end
class.updateTips = updateTips

return LoginScene
