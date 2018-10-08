local skynet    = skynet or require "skynet"
local crypt     = skynet.crypt or require "skynet.crypt"

local tableHelper   = require "TableHelper"
local strHelper     = require "StringHelper"

local data = nil
local path
if skynet.init then
    path = "client/auth.tmp"
else
    path = cc.FileUtils:getInstance():getWritablePath() .. "auth.tmp"
end


---! create the class metatable
local class = {}

---! class variables
class.keyAgentList = "com.cronlygames.agentservers.list"
class.keyHallCount = "com.cronlygames.hallservers.count"
class.keyGameMode  = "com.cronlygames.gameMode"

class.base64AuthChallenge = "com.cronlygames.auth.challenge"
class.base64AuthSecret    = "com.cronlygames.auth.secret"
class.keyAuthIndex        = "com.cronlygames.auth.index"

class.keyPlayerId   = "com.cronlygames.auth.playerId"
class.keyPassword   = "com.cronlygames.auth.password"
class.keyNickname   = "com.cronlygames.auth.nickname"
class.keyAvatarUrl  = "com.cronlygames.auth.avatarUrl"
class.keyAvatarId   = "com.cronlygames.auth.avatarId"

class.keyUserCode   = "com.cronlygames.auth.usercode"

class.keyAccessToken= "com.cronlygames.auth.accessToken"
class.keyOSType     = "com.cronlygames.auth.ostype"
class.keyPlatform   = "com.cronlygames.auth.platform"

---! class functions
class.load = function ()
    local f = io.open(path)
    if not f then
        data = {}
        return
    end
    local source = f:read "*a"
    f:close()
    data = tableHelper.decode(source) or {}
end

class.save = function ()
    local f = io.open(path, "w")
    if not f then
        return
    end
    local text = tableHelper.encode(data)
    f:write(text)
    f:close()
end

class.getItem = function (key, def)
    if not data then
        class.load()
    end
    def = def or ""
    return data[key] or def
end

class.setItem = function (key, obj)
    if not data then
        class.load()
    end

    data[key] = obj or ""
    class.save()
end

class.getAuthInfo = function ()
    local ret = {}
    ret.playerId = class.getItem(class.keyPlayerId)
    if strHelper.isNullKey(ret.playerId) then
        skynet.error("AuthInfo incomplete")
        skynet.error(debug.traceback())
    end

    ret.userCode    = class.getItem(class.keyUserCode)
    ret.playerId    = class.getItem(class.keyPlayerId)
    ret.password    = class.getItem(class.keyPassword)
    ret.nickname    = class.getItem(class.keyNickname)
    ret.avatarUrl   = class.getItem(class.keyAvatarUrl)
    ret.avatarId    = class.getItem(class.keyAvatarId, 0)

    ret.accessToken = class.getItem(class.keyAccessToken)
    ret.osType      = class.getItem(class.keyOSType)
    ret.platform    = class.getItem(class.keyPlatform)

    ret.authIndex   = class.getItem(class.keyAuthIndex, 0)
    ret.challenge   = crypt.base64decode(class.getItem(class.base64AuthChallenge))
    ret.secret      = crypt.base64decode(class.getItem(class.base64AuthSecret))

    return ret
end

return class

