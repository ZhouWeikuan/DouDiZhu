
local OnlineScene = class("OnlineScene", cc.load("mvc").ViewBase)

local Constants = require "Constants"
local Settings  = require "Settings"

local LoginHelper   = require "LoginHelper"
local UIHelper      = require "UIHelper"

local packetHelper  = require "PacketHelper"

local const         = require "Const_YunCheng"
local AuthUtils     = require "AuthUtils"

function OnlineScene:onCreate()
    UIHelper.createSceneBg(self)

    local CommonLayer = require("CommonLayer")
    self.comLayer = CommonLayer.create(self, 0)
    self.comLayer.is_offline = nil

    self.comLayer:addTo(self, 1)
    self.comLayer:setPosition(cc.p(0, 0))
end

function OnlineScene:postAuthAction ()
    local login = self.login
    if not login then
        return
    end
    login:tryGame(AuthUtils.getItem(AuthUtils.keyGameMode, 0))
end

function OnlineScene:postJoinAction ()
    local login = self.login
    if not login then
        return
    end

    local tableId  = Settings.getRoomId()
    self.agent:sendSitDownOptions(tableId)
end

function OnlineScene:onEnter_()
    self.lastUpdate = skynet.time()
    local ret = LoginHelper.createFromLayer(self, self.comLayer, "BotPlayer_YunCheng", AuthUtils.getAuthInfo(), const)
    if not ret then
        local act = cc.Sequence:create(
            cc.DelayTime:create(0.5),
            cc.CallFunc:create(function()
                self:returnBack()
            end))
        self:runAction(act)
        return
    end

    -- OSNative.setLeaveListener(function()
    --     if self.login then
    --         self.login:closeSocket()
    --     end
    -- end)

    Constants.startScheduler(self, self.tickFrame, 0.01)
end

function OnlineScene:onExit_()
    Constants.stopScheduler(self)

    if self.login then
        self.login:releaseFromLayer(self)
    end

    self.agent:remove_all_long_func()
end

function OnlineScene:tickFrame ()
    local login = self.login
    if login:tickCheck(self) then
        local networkLayer = require "NetworkLayer"
        networkLayer.create(self)

        self.comLayer:handleOffline()
    end

    local now = skynet.time()
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

    self.agent:check_long_func()
end

function OnlineScene:returnBack()
    local app = cc.exports.appInstance
    local view = app:createView('MainScene')
    view:showWithScene()
end

--------------------------------------------
---! @addtogroup   CommonLayerDelegate
function OnlineScene:command_handler (user, packet)
    local login = self.login
    if login.remotesocket then
        login.remotesocket:sendPacket(packet)
    end
end


return OnlineScene
