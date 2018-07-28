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
