local LineScene = class("LineScene", cc.load("mvc").ViewBase)

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"
local UIHelper  = require "UIHelper"

function LineScene:onCreate()
    cc.SpriteFrameCache:getInstance():addSpriteFrames("linescene.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("buttons.plist")

    local packetHelper = require "PacketHelper"
    packetHelper:registerProtoName("protos/CGGame.pb")
    packetHelper:registerProtoName("protos/YunCheng.pb")

    display.newSprite(CC_DESIGN_RESOLUTION.background)
        :move(display.center)
        :addTo(self)

    local winSize = display.size
    Constants.getSprite("line_title.png", cc.p(winSize.width * 0.5, winSize.height * 0.5 + 145), self)

    local str = "抵制不良游戏，拒绝盗版游戏。注意自我保护，谨防受骗上当。适度游戏益脑，沉迷游戏伤身。合理安排时间，享受健康生活。"
    local lb = Constants.getLabel(str, Constants.kBoldFontName, 24,
                            cc.p(winSize.width * 0.5, 50), self)
    lb:setColor(cc.c3b(226, 226, 222))

    self:initBtn()
end

function LineScene:initBtn()
    local winSize = display.size

    local buttonMenu = cc.Menu:create()
    buttonMenu:addTo(self)
    buttonMenu:setPosition(0, 0)

    local item = Constants.getMenuItem("tour")
    item:registerScriptTapHandler(function()
        self:loginTour()
    end)
    item:addTo(buttonMenu)
    item:setPosition(winSize.width * 0.7, 288)
    self.m_btnTour = item

    item = Constants.getMenuItem("weixin")
    item:registerScriptTapHandler(function()
        self:loginWeixin()
    end)
    item:addTo(buttonMenu)
    item:setPosition(winSize.width * 0.3, 288)
    self.m_btnWeixin = item

    item = Constants.getMenuItem("close")
    local itemSize = item:getContentSize()
    item:registerScriptTapHandler(function() self:clickClose() end)
    item:addTo(buttonMenu)
    item:setPosition(itemSize.width * 0.64, winSize.height - itemSize.height * 0.6)
    if not Constants.isDeviceAndroid() then
        item:setEnabled(false)
        item:setVisible(false)
    end
end

function LineScene:loginTour()
    SoundApp.playEffect("sounds/main/click.mp3")
    self:switchScene("GameScene")
end

function LineScene:loginWeixin()
    SoundApp.playEffect("sounds/main/click.mp3")
    self:switchScene("LoginScene")
end

function LineScene:onEnter_ ()
    SoundApp.playBackMusic("music/Welcome.mp3")
end

function LineScene:onExit_ ()
end

function LineScene:switchScene(name)
    SoundApp.playEffect("sounds/main/click.mp3")

    local app = cc.exports.appInstance
    local view = app:createView("MainScene")
    view.nextSceneName = name
    view:showWithScene()
end

function LineScene:clickClose()
    SoundApp.playEffect("sounds/main/click.mp3")

    cc.UserDefault:getInstance():flush()
    cc.Director:getInstance():endToLua()
end

return LineScene
