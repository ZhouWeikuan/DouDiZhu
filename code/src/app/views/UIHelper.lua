local class = {}

local SoundApp  = require "SoundApp"
local Constants = require "Constants"

local winSize = display.size

class.kPlayType_Realtime    = 1
class.kPlayType_Replay      = 2

-- 头像位置
class.getPlayerPosByViewId = function (viewId)
    local pos = {
        cc.p(100, 480),
        cc.p(1820, 800),
        cc.p(100, 800)
    }
    return pos[viewId]
end

-- 手牌位置
class.getCardsPos = function (index, count)
    local space = class.getCardsSpacing(count)
    local begin = winSize.width * 0.5 - (count-1) * space /2
    return cc.p(begin + index * space, 160)
end

class.getCardsSpacing = function (count)
    local cardSp = cc.Sprite:createWithSpriteFrameName("cardbg.png")
    local cardSize = cardSp:getContentSize()

    local maxWidth = winSize.width
    local maxSpace = 112

    local space
    if count > 1 then
        space = (maxWidth - cardSize.width) / (count - 1)

        if space > maxSpace then
            space = maxSpace
        end
    else
        space = maxSpace
    end

    return space
end

class.getOutCardPos = function (viewId)
    local playerOutCardPos = {
        cc.p(winSize.width * 0.5, 620),
        cc.p(winSize.width - 330, 833),
        cc.p(330, 833),
    }

    return playerOutCardPos[viewId]
end

class.NewRoomCfg = {
    {opID = "playRule",
     opName = "rm_txt_wf.png",
     rdName = {"普通斗地主", "花牌斗地主", "去两个三斗地主"},
     rdVal = {0, 1, 2},
     wOffset = 330,
     dftIdx = 1},

    {opID = "same3Bomb",
     opName = "rm_txt_gz.png",
     rdName = {"同色三算炸", "同色三不算炸"},
     rdVal = {1, 0},
     wOffset = 520,
     dftIdx = 0},

    {opID = "bombMax",
     opName = "rm_txt_bomb.png",
     rdName = {"不封顶", "3炸封顶", "4炸封顶", "5炸封顶"},
     rdVal = {0, 3, 4, 5},
     wOffset = 260,
     dftIdx = 0},

    {opID = "bottomScore",
     opName = "rm_txt_df.png",
     rdName = {"1分", "2分", "5分", "10分"},
     rdVal = {1, 2, 5, 10},
     wOffset = 260,
     dftIdx = 0},

    {opID = "passCount",
     opName = "rm_txt_js.png",
     rdName = {"8局/3个元宝", "16局/6个元宝"},
     rdVal = {8, 16},
     wOffset = 520,
     dftIdx = 0},

    {opID = "payType",
     opName = "rm_txt_ff.png",
     rdName = {"房主付费", "AA付费", "赢家付费"},
     rdVal = {0, 1, 2},
     wOffset = 330,
     dftIdx = 0}
}

class.parseRoomDetail = function (roomDetails)
    local tbID = {"playRule", "same3Bomb", "bombMax", "bottomScore", "passCount", "payType"}
    local strRet = ""
    for _,opID in pairs(tbID) do
        local v = roomDetails[opID]
        local oneCfg = class.getRoomCfgById(opID)
        if v and oneCfg then
            for i,value in ipairs(oneCfg.rdVal) do
                if v == value then
                    if opID == "bombMax" then
                        strRet = strRet .. "炸弹"
                    elseif opID == "bottomScore" then
                        strRet = strRet .. "底分"
                    end

                    strRet = strRet..oneCfg.rdName[i].." "
                    break
                end
            end
        end
    end

    return strRet
end

class.getRoomCfgById = function (opID)
    local ret = nil

    for k,v in ipairs(class.NewRoomCfg) do
        if v.opID == opID then
            ret = v
            break
        end
    end

    return ret
end

class.makeBaseHead = function ()
    local headBg = Constants.getSprite("bg_role.png")
    local headSize = headBg:getContentSize()

    local sten = cc.Sprite:createWithSpriteFrameName("bg_sten.png")
    local clipper = cc.ClippingNode:create()
    clipper:setStencil(sten)
    clipper:setAlphaThreshold(0.5)
           :addTo(headBg)
           :setPosition(headSize.width * 0.5, headSize.height * 0.5)

    local roleSp = Constants.getSprite("icon_role0.png", cc.p(0,0), clipper)
    return headBg, roleSp
end

class.popMsg = function (parent, strMsg)
    local MsgBox = require "MsgBox"
    local layer = MsgBox.create(strMsg)
    layer:addTo(parent ,Constants.kLayerPopUp)
end

class.doAnimation = function (type, parent)
    if type == 3 then
        local skeletonNode = sp.SkeletonAnimation:create("eff/plane_out/plane.json", "eff/plane_out/plane.atlas")
        skeletonNode:setAnimation(0, "plane", false)
        skeletonNode:addTo(parent, Constants.kLayerPopUp)
        skeletonNode:setPosition(winSize.width * 0.5, winSize.height * 0.5)
            :setScale(1.6)

        local act = cc.Sequence:create(
                        cc.DelayTime:create(3),
                        cc.FadeOut:create(0.5),
                        cc.CallFunc:create(function()
                            if skeletonNode then
                                skeletonNode:removeFromParent()
                            end
                        end))
        skeletonNode:runAction(act)
        return
    end

    if type == 1 then
        SoundApp.playEffect("sounds/main/boom.mp3")
        local skeletonNode = sp.SkeletonAnimation:create("eff/boom_out/boom.json","eff/boom_out/boom.atlas")
        skeletonNode:setAnimation(0, "boom", false)
        skeletonNode:addTo(parent, Constants.kLayerPopUp)
        skeletonNode:setPosition(winSize.width * 0.5, winSize.height * 0.2)
            :setScale(1.6)
        parent:runAction(class.shakeWorld())

        local act = cc.Sequence:create(
                        cc.DelayTime:create(3),
                        cc.FadeOut:create(0.5),
                        cc.CallFunc:create(function()
                            if skeletonNode then
                                skeletonNode:removeFromParent()
                            end
                        end))
        skeletonNode:runAction(act)
    else
        SoundApp.playEffect("sounds/main/boom.mp3")
        local skeletonNode = sp.SkeletonAnimation:create("eff/boom1_out/boom1.json","eff/boom1_out/boom1.atlas")
        skeletonNode:setAnimation(0, "boom1", false)
        skeletonNode:addTo(parent, Constants.kLayerPopUp)
        skeletonNode:setPosition(winSize.width * 0.5, winSize.height * 0.15)
            :setScale(1.6)
        parent:runAction(class.shakeWorld())

        local act = cc.Sequence:create(
                        cc.DelayTime:create(3),
                        cc.FadeOut:create(0.5),
                        cc.CallFunc:create(function()
                            if skeletonNode then
                                skeletonNode:removeFromParent()
                            end
                        end))
        skeletonNode:runAction(act)
    end
end

class.shakeWorld = function()
    local diff = 32
    local act = cc.Sequence:create(cc.MoveTo:create(0.02, cc.p(-diff,0)),
                                 cc.MoveTo:create(0.02, cc.p(0, diff * 0.5)),
                                 cc.MoveTo:create(0.04, cc.p(diff * 2, 0)),
                                 cc.MoveTo:create(0.04, cc.p(0,-diff)),
                                 cc.MoveTo:create(0.02, cc.p(-diff,0)),
                                 cc.MoveTo:create(0.02, cc.p(0, 0.5 * diff)),
                                 cc.MoveTo:create(0.02, cc.p(0, 0)))
    act = cc.Repeat:create(act, 6);
    return act
end

class.removeSpriteArray = function (arr)
    if not arr then return end

    for k, v in pairs(arr) do
        if v then
            v:removeFromParent()
            v = nil
        end
    end
end

class.getSoundValue = function (v)
    if v == 14 or v == 15 then
        v = v - 13
    elseif v == 16 or v == 17 then
        v = v - 2
    end
    return v
end

class.parseCardType = function (node, sexStr)
    local const = require "Const_YunCheng"
    local ret = {sound = {}}

    if const.isRocket(node) then
        ret.music = "music/Normal2.mp3"
        ret.anim = 1
        table.insert(ret.sound, sexStr .. "wangzha.mp3")

    elseif const.isBomb(node) then
        ret.music = "music/Normal2.mp3"
        ret.anim = 2
        table.insert(ret.sound, sexStr .. "zhadan.mp3")

    elseif node.cardType == const.kCardType_Serial and node.seralNum > 1 then
        if node.mainNum == 1 then
            table.insert(ret.sound, sexStr .. "shunzi.mp3")
            table.insert(ret.sound, "sounds/main/flower.mp3")

        elseif node.mainNum == 2 then
            table.insert(ret.sound, sexStr .. "liandui.mp3")
            table.insert(ret.sound, "sounds/main/flower.mp3")

        elseif node.mainNum == 3 then
            table.insert(ret.sound, "sounds/main/plane.mp3")
            table.insert(ret.sound, sexStr .. "feiji.mp3")
            ret.anim = 3
        else
            table.insert(ret.sound, "sounds/main/flower.mp3")
        end

    elseif node.cardType == const.kCardType_Single then
        if node.mainNum == 1 then
            local val = class.getSoundValue(node.value)
            local str = string.format("1%02d.mp3", val)
            str = sexStr .. str
            table.insert(ret.sound, str)
        elseif node.mainNum == 2 then
            local val = class.getSoundValue(node.value)
            local str = string.format("2%02d.mp3", val)
            str = sexStr .. str
            table.insert(ret.sound, str)
        elseif node.mainNum == 3 then
            if node.subNum == 0 then
                local value = class.getSoundValue(node.value)
                local str = string.format("3%02d.mp3", value)
                str = sexStr .. str
                table.insert(ret.sound, str)
            elseif node.subNum == 1 then
                local str = string.format("sandaiyi.mp3")
                str = sexStr .. str
                table.insert(ret.sound, str)
            else
                local str = string.format("sandaiyidui.mp3")
                str = sexStr .. str
                table.insert(ret.sound, str)
            end
        else
            if node.subNum == 1 then
                local str = string.format("sidaier.mp3")
                str = sexStr .. str
                table.insert(ret.sound, str)
            elseif node.subNum == 2 then
                local str = string.format("sidailiangdui.mp3")
                str = sexStr .. str
                table.insert(ret.sound, str)
            end
        end
    end

    return ret
end

class.getUserGender = function (avatarId)
    if avatarId and avatarId % 2 == 1 then
        return "boy"
    else
        return "girl"
    end
end

class.showTalkBubble = function (viewId, strType, wordCnt, parent, zOrder, bReplay)
    wordCnt = wordCnt or 2
    local playerTipPos = {
        cc.p(380, 540),
        cc.p(winSize.width - 380, 820),
        cc.p(380, 820)
    }

    if bReplay then
        playerTipPos = {
            cc.p(380, 475),
            cc.p(winSize.width - 380, winSize.height - 125),
            cc.p(380, winSize.height - 125)
        }
    end

    local strPath = string.format("txt_%s.png", strType)
    local sp = Constants.getSprite(strPath, playerTipPos[viewId], parent)
    sp:setLocalZOrder(zOrder)
        :setCascadeOpacityEnabled(true)

    local size = sp:getContentSize()
    local bg = Constants.get9Sprite("bg_bubble.png",
                                    cc.size(220, 90),
                                    cc.p(size.width * 0.5, size.height * 0.5),
                                    sp)
    bg:setLocalZOrder(-1)
    if viewId ~= 2 then
        bg:setScaleX(-1)
    end

    if wordCnt > 2 then
        bg:setContentSize(250, 90)
    end

    local act = cc.Sequence:create(cc.DelayTime:create(1.5),
        cc.FadeTo:create(0.5, 20),
        cc.CallFunc:create(function()
            sp:removeFromParent()
            end))
    sp:runAction(act)
end

class.getCardSprite = function (value, pos, parent, zOrder, isMaster)
    local spCardBg

    if value == 53 or value == 54 or value == 56 then
        local cardStr = string.format("card%02d.png", value)
        spCardBg = Constants.getSprite(cardStr, pos, parent, zOrder)
    else
        spCardBg = Constants.getSprite("cardbg.png", pos, parent, zOrder)
        if spCardBg then
            spCardBg:setCascadeOpacityEnabled(true)

            local bgSize = spCardBg:getContentSize()
            local pos1 = cc.p(49, 225)
            local pos2 = cc.p(bgSize.width - pos1.x, bgSize.height - pos1.y)

            local cardStr = string.format("card%02d.png", value)

            Constants.getSprite(cardStr, pos1, spCardBg)
            local sp2 = Constants.getSprite(cardStr, pos2, spCardBg)
            sp2:setRotation(180)
        end
    end

    if isMaster then
        local cardSize = spCardBg:getContentSize()
        local spMaster = Constants.getSprite("flag_landlord.png", cc.p(cardSize.width, cardSize.height), spCardBg)
        spMaster:setAnchorPoint(1,1)
    end

    return spCardBg
end

-- class.captureScreen = function ()
--     local fileName = "game.jpg"
--     if Constants.isDeviceAndroid() then
--         fileName = "/mnt/sdcard/game.jpg"
--     end

--     cc.utils:captureScreen(function(flag, name)
--         class.showShare(flag, name)
--     end, fileName)
-- end

-- class.showShare = function (success, fileName)
--     if not success then
--         print ("failed to capture screen")
--         return
--     end

--     -- the native airdrop and android share codes
--     if Constants.isDeviceMac() then
--         OSNative.shareFile(fileName)
--         return
--     end

--     local shareInfo = {
--         imagePath   = fileName,
--         mediaType   = 1,
--         shareTo     = 0,
--     }

--     local function onSharedResultListener (code, msg )
--         require "opensdkConst3"
--         local ShareResultCode = cc.exports.ShareResultCode

--         local title, body
--         if code == ShareResultCode.kShareSuccess then
--             title = OSNative.getUTF8LocaleString("msgShareSuccess")
--             body  = OSNative.getUTF8LocaleString("msgShareOK")
--         else
--             title = OSNative.getUTF8LocaleString("msgShareFailed")
--             body  = OSNative.getUTF8LocaleString("msgShareFailInfo") .. msg
--         end

--         MessageBox(body, title)
--     end

--     local sdk = require "OpenSDKWrapper"
--     sdk.showShare(shareInfo, onSharedResultListener)
-- end

class.createSceneBg = function (parent)
    local strPath = string.format("all/bg_game%d.png", math.random(1,3))

    local winSize = display.size
    local spBg = cc.Sprite:create(strPath)
    local spSize = spBg:getContentSize()
    local scaleX = winSize.width / spSize.width
    local scaleY = winSize.height / spSize.height
    spBg:addTo(parent, -1)
        :setPosition(display.center)
        :setScale(scaleX, scaleY)
end

class.getChatSoundPath = function (str, sexStr)
    local strPath = nil
    for i = 1, 12 do
        if i ~= 2 then
            local msgId = string.format("msgChatMsg%02d", i)
            local strLocal = getUTF8LocaleString(msgId)

            if str == strLocal then
                strPath = string.format("%s%s.mp3", sexStr, msgId)
                break
            end
        end
    end

    return strPath
end

return class

