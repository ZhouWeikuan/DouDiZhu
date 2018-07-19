local MainScene = class("MainScene", cc.load("mvc").ViewBase)

local Constants = require("Constants")

function MainScene:onCreate()
    local rot = CC_DESIGN_RESOLUTION.backgroundAngle or 0
    -- add background image
    display.newSprite(CC_DESIGN_RESOLUTION.background)
        :move(display.center)
        :addTo(self)
        :setRotation(rot)

    local winSize = display.size
    local skeletonNode = sp.SkeletonAnimation:create("eff/loading/loading.json", "eff/loading/loading.atlas")
    skeletonNode:setAnimation(0, "loading", true)
        :addTo(self, 1)
        :setPosition(winSize.width * 0.5, winSize.height * 0.5)
        :setScale(1.5)
end

function MainScene:onEnter_()
    cc.SpriteFrameCache:getInstance():removeSpriteFrames();
    cc.Director:getInstance():getTextureCache():removeUnusedTextures();

    Constants.startScheduler(self, self.postEvent, 0.5)
end

function MainScene:onExit_()
    Constants.stopScheduler(self)

end

function MainScene:postEvent()
    Constants.stopScheduler(self)

    self.nextSceneName = self.nextSceneName or "LineScene"

    local app = self:getApp()
    local view = app:createView(self.nextSceneName)
    view:showWithScene()
end

return MainScene
