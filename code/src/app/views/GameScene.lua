
local GameScene = class("GameScene", cc.load("mvc").ViewBase)

local Constants     = require "Constants"

local protoTypes    = require "ProtoTypes"

local packetHelper  = require "PacketHelper"
local UIHelper      = require "UIHelper"

local CommonLayer   = require "CommonLayer"

function GameScene:onCreate()
    UIHelper.createSceneBg(self)

    self.comLayer = CommonLayer.create(self, 0)
    self.comLayer.is_offline = true

    self.comLayer:addTo(self, 1)
    self.comLayer:setPosition(cc.p(0, 0))

    local config = packetHelper.load_config("protos/yuncheng.cfg")
    self.hallInterface = packetHelper.createObject(config.Interface, config)
    self.config = config
    config.SeatOrder = true

    self:initAgentList()
end

function GameScene:initAgentList()
    if self.agent_list then
        return
    end

    local AIPlayer = require "AIPlayer"
    local players = AIPlayer.shufflePlayers()

    local agent_list = {}
    local count = 3
    for i = 1, count do
        local handler = nil
        local p = players[i]
        if p.FUniqueID == "uid100" then
            handler = self.comLayer
        else
            p.client_fd = -math.random(1, 1000)
        end

        local BotPlayer = require "BotPlayer_YunCheng"
        p.agent = BotPlayer.create(self, p, handler)
        p.agent.selfUserCode = p.FUserCode
        p.apiLevel = 1
        if handler then
            self.comLayer.agent = p.agent
        end
        p.agent.is_offline = true

        self.hallInterface:addPlayer(p)
        p.agent:sendSitDownOptions()
        p.agent:request_userinfo(p.FUserCode)
        table.insert(agent_list, p.agent)
    end

    self.agent_list = agent_list
end

function GameScene:onEnter_()
    Constants.startScheduler(self, self.tickFrame, 0.1)
end

function GameScene:onExit_()
    Constants.stopScheduler(self)

    for _, agent in ipairs(self.agent_list) do
        agent:remove_all_long_func()
    end
end

function GameScene:tickFrame(dt)
    xpcall (function ()
        self.hallInterface:tick(dt)
        for i, agent in ipairs(self.agent_list) do
            agent:tickFrame(dt)
        end
    end, __G__TRACKBACK__)

    for _, agent in ipairs(self.agent_list) do
        agent:check_long_func()
    end
end

--------------------------------------------
---! @addtogroup   CommonLayerDelegate
function GameScene:command_handler (user, packet)
    local args = packetHelper:decodeMsg("CGGame.ProtoInfo", packet)
    if args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_GAME then
        self.hallInterface:handleGameData(user, args.subType, args.msgBody)
    elseif args.mainType == protoTypes.CGGAME_PROTO_MAINTYPE_HALL then
        self.hallInterface:handleHallData(user, args.subType, args.msgBody)
    else
        print ("unknown data type ", args.mainType, args.subType, args.msgBody)
    end
end


---! @endgroup   CommonLayerDelegate


return GameScene

