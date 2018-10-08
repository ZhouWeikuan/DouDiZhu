---------------------------------------------------
---! @file
---! @brief 字符串辅助处理
---------------------------------------------------

---! 模块定义
local class = {}

---! @brief 创建一个UUID
local function uuid ()
    local seed = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'}
    local tb = {}
    for i=1,32 do
        table.insert(tb, seed[math.random(1, 16)])
    end
    local sid = table.concat(tb)
    return string.format('%s-%s-%s-%s-%s',
            string.sub(sid, 1, 8),
            string.sub(sid, 9,12),
            string.sub(sid, 13,16),
            string.sub(sid, 17,20),
            string.sub(sid, 21,32))
end
class.uuid = uuid

---! @brief 分割字符串
---! @param text 被分割的字符串
---! @param regularExp 用来表示间隔的正则表达式 默认是空格区分 "[^%s]+"
---! @return 返回分割后的字符串数组
local function split (text, regularExp)
    text = text or ""
    regularExp = regularExp or "[^%s]+"

    local arr = {}
    for w in string.gmatch(text, regularExp) do
        table.insert(arr, w)
    end
    return arr
end
class.split = split

---! @brief 合并字符串数组
---! @param arr 需要合并的字符串数组
---! @param sep 间隔符
---! @return 返回合并后的字符串
local function join (arr, sep)
    arr = arr or {}
    sep = sep or " "

    local str = nil
    for _, txt in ipairs(arr) do
        txt = tostring(txt)
        if str then
            str = str .. sep .. txt
        else
            str = txt
        end
    end

    str = str or ""
    return str
end
class.join = join

-- like 10.132.42.12
class.isInnerAddr = function (addr)
    if not addr then
        return false
    end
    local checks = {
        {"10.0.0.0",    "10.999.255.255"},
        {"172.16.0.0",  "172.31.999.255"},
        {"192.168.0.0", "192.168.999.255"},
        {"127.0.0.0",   "127.999.255.255"},
    }
    for _, one in ipairs(checks) do
        if addr >= one[1] and addr <= one[2] then
            return true
        end
    end
    return false
end

class.isNullKey = function (key)
    return (not key) or key == ""
end

return class

