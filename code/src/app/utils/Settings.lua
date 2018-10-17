local Constants = require "Constants"

local class = {}

local keyMusic      = "com.cronlygames.music"
local keySound      = "com.cronlygames.sound"

local isMusicOn = function()
    local t = cc.UserDefault:getInstance():getIntegerForKey(keyMusic)
    return t >= 0
end
class.isMusicOn = isMusicOn

local setMusicOn = function(play)
    local t = play and 0 or -1

    cc.UserDefault:getInstance():setIntegerForKey(keyMusic, t)
    cc.UserDefault:getInstance():flush()
end
class.setMusicOn = setMusicOn

local isSoundOn = function()
    local t = cc.UserDefault:getInstance():getIntegerForKey(keySound)
    return t >= 0
end
class.isSoundOn = isSoundOn

local setSoundOn = function(play)
    local t = play and 0 or -1

    cc.UserDefault:getInstance():setIntegerForKey(keySound, t)
    cc.UserDefault:getInstance():flush()
end
class.setSoundOn = setSoundOn

local function getLocalizedFileName(baseName, suffix)
    return OSNative.getLocalizedFileName(baseName, suffix)
end
class.getLocalizedFileName = getLocalizedFileName

local function getUTF8LocaleString(msgKey)
    return OSNative.getUTF8LocaleString(msgKey)
end
class.getUTF8LocaleString = getUTF8LocaleString


----------- playerId, playerName --------------
local keyPlayerId   = "com.cronlygames.playerId"
local keyPlayerName = "com.cronlygames.playerName"
local keyAvatarUrl  = "com.cronlygames.avatarUrl"
local keyGenderType = "com.cronlygames.genderType"

local function getPlayerId ()
    local ret = cc.UserDefault:getInstance():getStringForKey(keyPlayerId)
    return ret
end
class.getPlayerId = getPlayerId

local function setPlayerId (strId)
    cc.UserDefault:getInstance():setStringForKey(keyPlayerId, strId or "")
    cc.UserDefault:getInstance():flush()
end
class.setPlayerId = setPlayerId

local function getPlayerName ()
    local ret = cc.UserDefault:getInstance():getStringForKey(keyPlayerName)
    return ret
end
class.getPlayerName = getPlayerName

local function setPlayerName (strName)
    cc.UserDefault:getInstance():setStringForKey(keyPlayerName, strName or "")
    cc.UserDefault:getInstance():flush()
end
class.setPlayerName = setPlayerName

local function getAvatarUrl ()
    local ret = cc.UserDefault:getInstance():getStringForKey(keyAvatarUrl)
    return ret
end
class.getAvatarUrl = getAvatarUrl

local function setAvatarUrl (strUrl)
    cc.UserDefault:getInstance():setStringForKey(keyAvatarUrl, strUrl or "")
    cc.UserDefault:getInstance():flush()
end
class.setAvatarUrl = setAvatarUrl

local function getPlayerGender ()
    local ret = cc.UserDefault:getInstance():getIntegerForKey(keyGenderType)
    if ret < 1 or ret > 2 then
        ret = 0
    end

    return ret
end
class.getPlayerGender = getPlayerGender

local function setPlayerGender (gender)
    cc.UserDefault:getInstance():setIntegerForKey(keyGenderType, gender)
    cc.UserDefault:getInstance():flush()
end
class.setPlayerGender = setPlayerGender

local keyRoomId = "com.cronlygames.roomId"
local function getRoomId ()
    local ret = cc.UserDefault:getInstance():getIntegerForKey(keyRoomId)
    if ret < 100000 or ret > 999999 then
        ret = 0
    end

    return ret
end
class.getRoomId = getRoomId

local function setRoomId (roomId)
    cc.UserDefault:getInstance():setIntegerForKey(keyRoomId, roomId)
    cc.UserDefault:getInstance():flush()
end
class.setRoomId = setRoomId


local keyRoomResult = "com.cronlygames.roomResults"
local function getRoomResults ()
    local data = cc.UserDefault:getInstance():getStringForKey(keyRoomResult)
    local ret = {}
    if data ~= "" then
        local hp = require "TableHelper"
        ret = hp.decode(data)
    end

    return ret
end
class.getRoomResults = getRoomResults

local function setRoomResults (roomInfos)
    roomInfos = roomInfos or {}

    local hp = require "TableHelper"
    local data = hp.encode(roomInfos)

    cc.UserDefault:getInstance():setStringForKey(keyRoomResult, data)
    cc.UserDefault:getInstance():flush()
end
class.setRoomResults = setRoomResults

local keyOneRoomFormat = "com.cronlygames.roomId=%s"
local function getOneRoomResult (key)
    local keyOneRoom = string.format(keyOneRoomFormat, key)
    local data = cc.UserDefault:getInstance():getStringForKey(keyOneRoom)
    local ret = nil
    if data ~= "" then
        local hp = require "TableHelper"
        ret = hp.decode(data)
    end

    return ret
end
class.getOneRoomResult = getOneRoomResult

local function setOneRoomResult (key, roomInfo)
    local keyOneRoom = string.format(keyOneRoomFormat, key)

    local hp = require "TableHelper"
    local data = hp.encode(roomInfo)

    cc.UserDefault:getInstance():setStringForKey(keyOneRoom, data)
    cc.UserDefault:getInstance():flush()
end
class.setOneRoomResult = setOneRoomResult

local function rmvOneRoomResult (key)
    local keyOneRoom = string.format(keyOneRoomFormat, key)

    cc.UserDefault:getInstance():setStringForKey(keyOneRoom, "")
    cc.UserDefault:getInstance():flush()
end
class.rmvOneRoomResult = rmvOneRoomResult


local keyRoomList = "com.cronlygames.roomList"
local function getRoomList ()
    local data = cc.UserDefault:getInstance():getStringForKey(keyRoomList)
    local ret = {}
    if data ~= "" then
        local hp = require "TableHelper"
        ret = hp.decode(data)
    end

    return ret
end
class.getRoomList = getRoomList

local function addToRoomList (roomInfo)
    local roomList = class.getRoomList()
    local bSaved = false
    for _,one in ipairs(roomList) do
        if one.roomId == roomInfo.roomId then
            bSaved = true
            break
        end
    end
    if not bSaved then
        table.insert(roomList, roomInfo)
        class.setRoomList(roomList)
    end
end
class.addToRoomList = addToRoomList

local function setRoomList (roomList)
    roomList = roomList or {}

    table.sort(roomList, function (a, b)
            return (a.openTime > b.openTime)
        end)

    while #roomList > 20 do
        table.remove(roomList, 21)
    end

    local hp = require "TableHelper"
    local data = hp.encode(roomList)

    cc.UserDefault:getInstance():setStringForKey(keyRoomList, data)
    cc.UserDefault:getInstance():flush()
end
class.setRoomList = setRoomList

local function rmvFromRoomList (roomId)
    if not roomId then return end

    local roomList = class.getRoomList()
    for k,info in ipairs(roomList) do
        if info.roomId == roomId then
            table.remove(roomList, k)
            class.setRoomList(roomList)
            break
        end
    end
end
class.rmvFromRoomList = rmvFromRoomList

--------------------------- mist ---------------------------------
local keyCoinNum = "com.cronlygames.coin"

local function getCoinNum ()
    local ret = cc.UserDefault:getInstance():getIntegerForKey(keyCoinNum)
    return ret
end
class.getCoinNum = getCoinNum

local function setCoinNum (num)
    num = num or 0
    if num < 0 then
        num = 0
    end
    cc.UserDefault:getInstance():setIntegerForKey(keyCoinNum, num)
    cc.UserDefault:getInstance():flush()
end
class.setCoinNum = setCoinNum

class.getTodayKey = function ()
    return os.date("%D")
end

class.getTodayShareCount = function ()
    local key = class.getTodayKey()
    local ret = cc.UserDefault:getInstance():getIntegerForKey(key)
    return ret
end

class.setTodayShareCount = function (num)
    local key = class.getTodayKey()
    cc.UserDefault:getInstance():setIntegerForKey(key, num)
    cc.UserDefault:getInstance():flush()
end

----------------- Store Items ------------------
local function addStore_itemBought(productId)
    local sdk = require "OpenSDKWrapper"
    sdk.setAdsBought(true);
end
class.addStore_itemBought = addStore_itemBought

local function getStore_Item(set)
    local fmt = "com.cronlygames.yuncheng.chipset%d"
    if Constants.isDeviceMac() then
        fmt = "com.cronlygames.yuncheng.mac.chipset%d"
    end

    if set >= 1 and set <= Constants.chipsNum then
    else
        set = 1
    end

    local str = string.format(fmt, set - 1)
    return str
end
class.getStore_Item = getStore_Item

local function getStoreAllItems()
    local allItems = {}
    for i=1, Constants.chipsNum do
        table.insert(allItems, class.getStore_Item(i))
    end

    return allItems;
end
class.getStoreAllItems = getStoreAllItems

local function getStore_itemPrice(productId)
    local price = "1";

    local values = {"1", "2", "5", "10", "20", "50"}
    for i=1, Constants.chipsNum do
        local one = class.getStore_Item(i);

        if productId == one then
            price = values[i] or price
            price = math.tointeger(price) * 6
            price = string.format("%d", price)
            break;
        end
    end

    return price;
end
class.getStore_itemPrice  = getStore_itemPrice

local keyMode = "com.cronlygames.gamemode"
local function setGameMode(idx)
    cc.UserDefault:getInstance():setIntegerForKey(keyMode, idx)
    cc.UserDefault:getInstance():flush()
end
class.setGameMode  = setGameMode

local function getGameMode()
    local mode = cc.UserDefault:getInstance():getIntegerForKey(keyMode)
    if mode <= 0 or mode > 2 then
        mode = 1
    end
    return mode
end
class.getGameMode  = getGameMode


return class
