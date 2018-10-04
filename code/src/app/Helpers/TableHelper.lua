---------------------------------------------------
---! @file
---! @brief table相关协助库
---------------------------------------------------

---! TableHelper 模块定义
local class = {}

---! @brief 判断table是否为空
local function isTableEmpty(table)
    local count = 0
    for k,v in pairs(table) do
        count = count + 1
        break
    end
    return count == 0
end
class.isTableEmpty = isTableEmpty

---! @brief 判断数组是否为空
local function isArrayEmpty(table)
    local count = 0
    for k,v in ipairs(table) do
        count = count + 1
        break
    end
    return count == 0
end
class.isArrayEmpty = isArrayEmpty

---! @brief 复制数组部分
local function cloneArray(arr)
    local test = {}
    for i, v in ipairs(arr) do
        test[i] = v
    end
    return test
end
class.cloneArray = cloneArray

---! @brief 深度复制table
local function cloneTable(_table)
    local tar = {}
    for k,v in pairs(_table) do
        local vt = type(v)
        if vt == "table" then
            tar[k] = cloneTable(v)
        else
            tar[k] = v
        end
    end
    return tar
end
class.cloneTable = cloneTable

---! 合并数组
local function mergeArray(dst, src)
    table.move(src, 1, #src, #dst + 1, dst)
end
class.mergeArray = mergeArray

---! @brief 把源table的内容复制到目标table,
---!    如果有keys数组, 以数组的元素为key进行复制
local function copyTable(dstTable, srcTable, keys)
    if not srcTable then
        return
    end
    if keys then
        for _, k in ipairs(keys) do
            dstTable[k] = srcTable[k]
        end
    else
        for k, v in pairs(srcTable) do
            dstTable[k] = v
        end
    end
end
class.copyTable = copyTable

--- encode & decode
local function table_ser (tablevalue, tablekey, mark, assign)
    -- 标记当前table, 并记录其key名
    mark[tablevalue] = tablekey
    -- 记录表中各项
    local container = {}
    for k, v in pairs(tablevalue) do
        -- 序列化key
        local keystr = nil
        if type(k) == "string" then
            keystr = string.format("[\"%s\"]", k)
        elseif type(k) == "number" then
            keystr = string.format("[%d]", k)
        end

        -- 序列化value
        local valuestr = nil
        if type(v) == "string" then
            valuestr = string.format("\"%s\"", tostring(v))
        elseif type(v) == "number" or type(v) == "boolean" then
            valuestr = tostring(v)
        elseif type(v) == "table" then
            -- 获得从根表到当前表项的完整key， tablekey(代表tablevalue的key)， mark[v]代表table v的key
            local fullkey = string.format("%s%s", tablekey, keystr)
            if mark[v] then table.insert(assign, string.format("%s=%s", fullkey, mark[v]))
            else valuestr = class.table_ser(v, fullkey, mark, assign)
            end
        end

        if keystr and valuestr then
            local keyvaluestr = string.format("%s=%s", keystr, valuestr)
            table.insert(container, keyvaluestr)
        end
    end
    return string.format("{%s}", table.concat(container, ","))
end
class.table_ser = table_ser

local function encode (var)
    assert(type(var)=="table")
    -- 标记所有出现的table, 并记录其key, 用于处理循环引用
    local mark = {}
    -- 用于记录循环引用的赋值语句
    local assign = {}
    -- 序列化表, ret字符串必须与后面的loca ret=%s中的ret相同，因为这个ret可能也会组织到结果字符串中。
    local data = class.table_ser(var, "data", mark, assign)
    local data = string.format("local data=%s %s; return data", data, table.concat(assign, ";"))
    return data
end
class.encode = encode

local function decode (data)
    local res = nil
    xpcall(function()
        local func = load(data)
        if func then
            res = func()
        end
    end, function(err)
        res = nil
        print(err)
        print(debug.traceback())
    end)
    return res
end
class.decode = decode

return class

