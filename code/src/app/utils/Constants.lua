local class = {}


class.kBoldFontName     = "Arial-BoldMT";
class.kNormalFontName   = "HelveticaNeue";

class.kBoldFontNamePF   = "PingFangSC-Semibold"
class.kNormalFontNamePF = "PingFangSC-Light"

class.kMaxPlayers         =   3
class.kCenterViewId       =   1

class.kMaxIconNum         =  54

class.kLayerNetLoading    =   99
class.kLayerPopUp         =   40
class.kLayerPopDown       =   39
class.kLayerResult        =   38
class.kLayerGiftEff       =   37
class.kLayerGift          =   35
class.kLayerWinner        =   32
class.kLayerMaster        =   26
class.kLayerLock          =   25
class.kLayerMenu          =   24
class.kLayerChat          =   21
class.kLayerText          =   9
class.kLayerCard          =   6
class.kLayerIcon          =   2
class.kLayerChip          =   1
class.kLayerBack          =   0

class.chipsCount        = {6, 12, 30, 60, 120}
class.giftChipsCount    = {1,  3,  8, 19, 45}
class.chipsNum          = #class.chipsCount

local loadConstants = function()
    local SoundApp = require("SoundApp")
    SoundApp.loadAllSounds()
end
class.loadConstants = loadConstants

-- btn_name_normal.png btn_name_hover.png btn_name_disable.png
class.getMenuItem = function (name, hasDisable, normIcon, seleIcon)
    local str = string.format("btn_%s_normal.png", name)
    local norm = cc.Sprite:createWithSpriteFrameName(str)

    if normIcon then
        local normSize = norm:getContentSize()
        local spIcon = cc.Sprite:createWithSpriteFrameName(normIcon)
        spIcon:addTo(norm)
              :setPosition(normSize.width * 0.5, normSize.height * 0.5)
    end

    str = string.format("btn_%s_hover.png", name)
    local sele = cc.Sprite:createWithSpriteFrameName(str)

    if seleIcon then
        local seleSize = sele:getContentSize()
        local spIcon = cc.Sprite:createWithSpriteFrameName(seleIcon)
        spIcon:addTo(sele)
              :setPosition(seleSize.width * 0.5, seleSize.height * 0.5)
    end

    local item
    if hasDisable then
        str = string.format("btn_%s_disable.png", name)
        local disa = cc.Sprite:createWithSpriteFrameName(str)

        item = cc.MenuItemSprite:create(norm, sele, disa)
    else
        item = cc.MenuItemSprite:create(norm, sele)
    end

    return item
end

class.get9Sprite = function (name, size, pos, parent, rect)
    local sp
    if not rect then
        sp = ccui.Scale9Sprite:createWithSpriteFrameName(name)
    else
        sp = ccui.Scale9Sprite:createWithSpriteFrameName(name,rect)
    end

    if size then
        if size.width == 0 then
            size.width = sp:getContentSize().width
        end
        if size.height == 0 then
            size.height = sp:getContentSize().height
        end

        sp:setContentSize(size)
    end

    if parent then
        sp:addTo(parent)
    end

    if pos then
        sp:setPosition(pos.x, pos.y)
    end

    return sp
end

class.getSprite = function (name, pos, parent, zOrder)
    local sp = cc.Sprite:createWithSpriteFrameName(name)

    if parent then
        sp:addTo(parent)
    end

    if pos then
        sp:setPosition(pos.x, pos.y)
    end

    if zOrder then
        sp:setLocalZOrder(zOrder)
    end

    return sp
end

class.getLabel = function (str, font, size, pos, parent)
    local lbl = cc.Label:createWithSystemFont(str, font, size)

    if parent then
        lbl:addTo(parent)
    end

    if pos then
        lbl:setPosition(pos.x, pos.y)
    end

    return lbl
end

class.getUserHeadName = function ()
    return "icon_role0.png"
end

class.getUserHeadSprite = function (spHead, userInfo)
    local frameName = class.getUserHeadName(userInfo.FAvatarID)

    if not spHead then
        spHead = cc.Sprite:createWithSpriteFrameName(frameName)
    end

    local headSize = spHead:getContentSize()
    local xs, ys = spHead:getScaleX(), spHead:getScaleY()
    local s = cc.size(headSize.width * xs, headSize.height * ys)

    local frame = cc.SpriteFrameCache:getInstance():getSpriteFrame(frameName)
    if frame then
        spHead:setSpriteFrame(frame)
        headSize = spHead:getContentSize()
        spHead:setScale(s.width/headSize.width, s.height/headSize.height)
    end

    if userInfo.FAvatarUrl then
        if class.cachedImages[userInfo.FUniqueID] then
            class.updateSprite(spHead, userInfo.FUniqueID, s)
        else
            class.updateSpriteWithUrl(spHead, userInfo.FUniqueID, userInfo.FAvatarUrl, s)
        end
    end

    return spHead
end

class.updateSprite = function (sprite, uniqueId, size)
    xpcall(function ()
        local fileName = device.writablePath .. uniqueId
        sprite:setTexture(fileName)

        if size then
            local s = sprite:getContentSize()
            sprite:setScale(size.width/s.width, size.height/s.height)
        end
    end, function(err)
        print(err)
    end)
end

class.cachedImages = {}
class.updateSpriteWithUrl = function (sprite, uniqueId, url, size)
    local xhr = cc.XMLHttpRequest:new()
    xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_STRING
    xhr:open("GET", url)

    local function onDownloadImage()
        if xhr.readyState == 4 and (xhr.status >= 200 and xhr.status < 207) then
            local fileData = xhr.response
            local fileName = device.writablePath .. uniqueId
            local file = io.open(fileName, "wb")
            if file then
                file:write(fileData)
                file:close()

                class.cachedImages[uniqueId] = true
                class.updateSprite(sprite, uniqueId, size)
            else
                print("write file failed !")
            end
        else
            print("xhr.readyState is:", xhr.readyState, "xhr.status is: ", xhr.status)
        end
        xhr:unregisterScriptHandler()
    end

    xhr:registerScriptHandler(onDownloadImage)
    xhr:send()
end

------------------- Scheduler ---------------------
local function stopScheduler (self)
    if self.scheduleEntry then
        local    scheduler = cc.Director:getInstance():getScheduler()
        scheduler:unscheduleScriptEntry(self.scheduleEntry)
        self.scheduleEntry = nil
    end
end
class.stopScheduler = stopScheduler

local function startScheduler (self, handler, deltaTime)
    stopScheduler(self)

    local    scheduler = cc.Director:getInstance():getScheduler()
    self.scheduleEntry = scheduler:scheduleScriptFunc(function(dt)
        handler(self, dt)
    end, deltaTime, false)
end
class.startScheduler = startScheduler
----------------------------------------------------------------

local Ratio = math.max(CC_DESIGN_RESOLUTION.width, CC_DESIGN_RESOLUTION.height) / math.min(CC_DESIGN_RESOLUTION.width, CC_DESIGN_RESOLUTION.height)

local isScreenIPhone5 = function()
	return Ratio > 1.6
end
class.isScreenIPhone5 = isScreenIPhone5

local isScreenIPhone4 = function()
	return Ratio <= 1.6 and Ratio > 1.4
end
class.isScreenIPhone4 = isScreenIPhone4

local isScreenIPad = function()
	return Ratio <= 1.4
end
class.isScreenIPad = isScreenIPad

local isDeviceIOS = function()
	local targetPlatform = cc.Application:getInstance():getTargetPlatform()
	return cc.PLATFORM_OS_IPHONE == targetPlatform or cc.PLATFORM_OS_IPAD == targetPlatform
end
class.isDeviceIOS = isDeviceIOS

local isDeviceMac = function()
	local targetPlatform = cc.Application:getInstance():getTargetPlatform()
	return cc.PLATFORM_OS_MAC  == targetPlatform
end
class.isDeviceMac = isDeviceMac

local isDeviceAndroid = function()
	local targetPlatform = cc.Application:getInstance():getTargetPlatform()
	return cc.PLATFORM_OS_ANDROID == targetPlatform
end
class.isDeviceAndroid = isDeviceAndroid

local getAclErrText = function(acl)
    local strMsgId = string.format("msgErr%d", acl or 0)
    local strErr = getUTF8LocaleString(strMsgId)

    return strErr
end
class.getAclErrText = getAclErrText


return class

