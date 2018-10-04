local class = {}

local raws = {
    {FUniqueID = "uid101", FNickName = "道哥", FCounter = 100, FAvatarID = 1, isGirl = false, FScore = 5},
    {FUniqueID = "uid103", FNickName = "发哥", FCounter = 200, FAvatarID = 3, isGirl = false, FScore = 20},
    {FUniqueID = "uid105", FNickName = "毛哥", FCounter = 500, FAvatarID = 5, isGirl = false, FScore = 40},
    {FUniqueID = "uid107", FNickName = "胡瓜", FCounter = 1000, FAvatarID = 7, isGirl = false, FScore = 80},
    {FUniqueID = "uid109", FNickName = "猫王", FCounter = 2000, FAvatarID = 9, isGirl = false, FScore = 144},
    {FUniqueID = "uid111", FNickName = "猴子", FCounter = 5000, FAvatarID = 11, isGirl = false, FScore = 260},
    {FUniqueID = "uid113", FNickName = "主任", FCounter = 10000, FAvatarID = 13, isGirl = false, FScore = 468},
    {FUniqueID = "uid115", FNickName = "毛头", FCounter = 20000, FAvatarID = 15, isGirl = false, FScore = 843},
    {FUniqueID = "uid117", FNickName = "老王", FCounter = 50000, FAvatarID = 17, isGirl = false, FScore = 1517},
    {FUniqueID = "uid119", FNickName = "叔叔", FCounter = 100000, FAvatarID = 19, isGirl = false, FScore = 2731},
    {FUniqueID = "uid110", FNickName = "萍萍", FCounter = 10, FAvatarID = 10, isGirl = true, FScore = 4916},
    {FUniqueID = "uid112", FNickName = "依依", FCounter = 20, FAvatarID = 12, isGirl = true, FScore = 9432},
    {FUniqueID = "uid114", FNickName = "美妍", FCounter = 50, FAvatarID = 14, isGirl = true, FScore = 18064},
    {FUniqueID = "uid116", FNickName = "少妇", FCounter = 100, FAvatarID = 16, isGirl = true, FScore = 35028},
    {FUniqueID = "uid118", FNickName = "龙女", FCounter = 200, FAvatarID = 18, isGirl = true, FScore = 68556},
    {FUniqueID = "uid120", FNickName = "尼姑", FCounter = 500, FAvatarID = 20, isGirl = true, FScore = 132112},
    {FUniqueID = "uid102", FNickName = "紫兰", FCounter = 1000, FAvatarID = 2, isGirl = true, FScore = 234224},
    {FUniqueID = "uid104", FNickName = "玉玲", FCounter = 2000, FAvatarID = 4, isGirl = true, FScore = 460448},
    {FUniqueID = "uid106", FNickName = "黄晶", FCounter = 5000, FAvatarID = 6, isGirl = true, FScore = 726753},
    {FUniqueID = "uid108", FNickName = "祖儿", FCounter = 10000, FAvatarID = 8, isGirl = true, FScore = 1053505},
    {FUniqueID = "uid100", FNickName = "天天", FCounter = 500,  FAvatarID = 54, isGirl = false, FScore = 0},
}
local rawCount = #raws - 1

function class.shufflePlayers()
    local players = class.getAIPlayers();
    if not players then
        players = class.loadAllPlayers();
        players = class.getAIPlayers();
    end

    return players
end

function class.loadAllPlayers()
    local players = raws
    local old = class.getAIPlayers();
    if old then
        local meIndex = -1;
        for i = 1,#old do
            local p = old[i];
            if p.FUniqueID == 'uid100' then
                meIndex = i
                break
            end
        end

        if meIndex > 1 then
            old[1], old[meIndex] = old[meIndex], old[1]
        end
        players = old
    end
    class.setAIPlayers(players)

    return players
end

function class.getAIPlayers()
    local one = class.loadPlayerAtIndex(100)
    if one.FNickName == "" then
        return nil
    end

    local ret = {}
    for i=100,100 + rawCount do
        local tmp = class.loadPlayerAtIndex(i)
        table.insert(ret, tmp)
    end

    local len = #ret
    for i=1,rawCount do
        local idx = math.random(3, len)
        ret[2], ret[idx] = ret[idx], ret[2]
    end

    return ret
end

function class.setAIPlayers(players)
    for i, one in ipairs(players) do
        local index = string.match(one.FUniqueID, "(%d+)");
        if index then
            class.savePlayerAtIndex(one, index)
        end
    end
end

function class.savePlayerAtIndex(one, index)
    index = index - 100
    if index < 0 or index > rawCount then
        index = 0
    end

    one.FNickName = one.FNickName or ""
    if one.FNickName == "" then
        for i=1,rawCount do
            local tmp = raws[i]
            if tmp.FUniqueID == one.FUniqueID then
                one.FNickName   = tmp.FNickName
                one.FCounter    = tmp.FCounter
                one.FAvatarID   = tmp.FAvatarID
                one.isGirl      = tmp.isGirl
                one.FScore      = tmp.FScore
                break
            end
        end
    end

    local key = string.format("aiplayer%d.playerName", index);
    cc.UserDefault:getInstance():setStringForKey(key, one.FNickName);

    key = string.format("aiplayer%d.picIndex", index);
    cc.UserDefault:getInstance():setIntegerForKey(key, one.FAvatarID or 54);

    local Settings  = require ("Settings")
    if Settings.getCoinNum() > 0 then
        one.FCounter = (one.FCounter or 0) + Settings.getCoinNum()
        Settings.setCoinNum(0)
    end

    key = string.format("aiplayer%d.chipNum", index);
    cc.UserDefault:getInstance():setIntegerForKey(key, one.FCounter or 0);

    one.FWins = one.FWins or 0
    one.FLoses = one.FLoses or 0
    one.FDraws = one.FDraws or 0
    one.FScore = one.FScore or 0

    key = string.format("aiplayer%d.FScore", index);
    cc.UserDefault:getInstance():setIntegerForKey(key, one.FScore);

    key = string.format("aiplayer%d.FWins", index);
    cc.UserDefault:getInstance():setIntegerForKey(key, one.FWins);

    key = string.format("aiplayer%d.FLoses", index);
    cc.UserDefault:getInstance():setIntegerForKey(key, one.FLoses);

    key = string.format("aiplayer%d.FDraws", index);
    cc.UserDefault:getInstance():setIntegerForKey(key, one.FDraws);

    cc.UserDefault:getInstance():flush();
end

function class.loadPlayerAtIndex(index)
    index = index - 100
    if index < 0 or index > rawCount then
        index = 0
    end

    local one = {}
    local key = string.format("aiplayer%d.playerName", index);
    one.FNickName = cc.UserDefault:getInstance():getStringForKey(key);

    key = string.format("aiplayer%d.picIndex", index);
    one.FAvatarID = cc.UserDefault:getInstance():getIntegerForKey(key);
    if one.FAvatarID == 0 then
        one.FAvatarID = 54
    end

    one.FUserCode = index + 100
    one.FUniqueID = string.format("uid%03d", one.FUserCode)
    one.address   = "127.0.0.1:888"

    key = math.tointeger(index) % 2
    one.isGirl = false
    if key == 1 then
        one.isGirl = true
    end

    key = string.format("aiplayer%d.chipNum", index);
    one.FCounter = cc.UserDefault:getInstance():getIntegerForKey(key);

    key = string.format("aiplayer%d.FScore", index);
    one.FScore = cc.UserDefault:getInstance():getIntegerForKey(key);

    key = string.format("aiplayer%d.FWins", index);
    one.FWins = cc.UserDefault:getInstance():getIntegerForKey(key);

    key = string.format("aiplayer%d.FLoses", index);
    one.FLoses = cc.UserDefault:getInstance():getIntegerForKey(key);

    key = string.format("aiplayer%d.FDraws", index);
    one.FDraws = cc.UserDefault:getInstance():getIntegerForKey(key);

    return one
end

return class
