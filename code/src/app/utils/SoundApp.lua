local Settings = require("Settings")

local class = {}
local SoundApp = class

local keyMusicVolume = "com.cronlygames.music.volume"
local keySoundVolume = "com.cronlygames.sound.volume"

local loadAllSounds = function()
    class.curEffectVolume = -1
end
class.loadAllSounds = loadAllSounds

local playEffect = function(key)
    if not Settings.isSoundOn() then
        return
    end

    local engine = cc.SimpleAudioEngine:getInstance()
    engine:playEffect(key)

    local vol = class.getEffectsVolume()
    if math.abs((class.curEffectVolume or -1) - vol) > 0.01 then
        engine:setEffectsVolume(vol)
        class.curEffectVolume = vol
    end
end
class.playEffect = playEffect

local unloadEffect = function(key)
    cc.SimpleAudioEngine:getInstance():unloadEffect(key);
end
class.unloadEffect = unloadEffect

local isBackMusicPlaying = function()
    return cc.SimpleAudioEngine:getInstance():isMusicPlaying();
end
class.isBackMusicPlaying = isBackMusicPlaying

local stopBackMusic = function()
    if cc.SimpleAudioEngine:getInstance():isMusicPlaying() then
        cc.SimpleAudioEngine:getInstance():stopMusic()
    end
end
class.stopBackMusic = stopBackMusic

local playBackMusic = function(back, isLoop)
    if isLoop == nil then
       isLoop = true
    end

    class.stopBackMusic();

    if not Settings.isMusicOn() then
        return;
    end

    local engine = cc.SimpleAudioEngine:getInstance();
    engine:playMusic(back, isLoop);

    local vol = class.getMusicVolume()
    class.setMusicVolume(vol)
end
class.playBackMusic = playBackMusic

class.getMusicVolume = function()
    local t = cc.UserDefault:getInstance():getFloatForKey(keyMusicVolume, 1.0)
    return t
end

class.setMusicVolume = function(vol)
    local engine = cc.SimpleAudioEngine:getInstance();
    engine:setMusicVolume(vol)

    cc.UserDefault:getInstance():setFloatForKey(keyMusicVolume, vol)
    cc.UserDefault:getInstance():flush()
end

class.getEffectsVolume = function()
    local t = cc.UserDefault:getInstance():getFloatForKey(keySoundVolume, 1.0)
    return t
end

class.setEffectsVolume = function(vol)
    cc.UserDefault:getInstance():setFloatForKey(keySoundVolume, vol)
    cc.UserDefault:getInstance():flush()
end

return class

