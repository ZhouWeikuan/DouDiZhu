
cc.FileUtils:getInstance():setPopupNotify(false)

local patchPath = cc.FileUtils:getInstance():getWritablePath() .. "doudizhu_1.0.0/"
cc.FileUtils:getInstance():addSearchPath(patchPath, true)

local path = {
    "src",
    "src/app",
    "src/app/Helpers",
    "src/app/Algos",
    "src/app/Classes",
    "src/app/Stages",
    "src/app/utils",
    "src/app/views",
    "res",
    "res/all",
    "res/both"
}
for i, p in ipairs(path) do
    cc.FileUtils:getInstance():addSearchPath(patchPath .. p)
    cc.FileUtils:getInstance():addSearchPath(p)
end

local one = patchPath .. "src"
local str = string.format("%s/?.lua;", one)
str = str .. "?.lua;"

package.path = package.path .. str

cc.prev_loaded = {}
for k, v in pairs(package.loaded) do
    cc.prev_loaded[k] = v
end

require "config"
require "cocos.init"

local function main()
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

    local Constants = require "Constants"
    Constants.loadConstants()

    cc.exports.appInstance = require("app.MyApp"):create()
    cc.exports.appInstance:run()
end

local status, msg = xpcall(main, __G__TRACKBACK__)
if not status then
    print(msg)
end
