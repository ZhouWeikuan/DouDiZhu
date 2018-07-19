---------------------------------------------------
---! @file
---! @brief 用户信息协助库
---------------------------------------------------

---! DBHelper 模块定义
local DBHelper = {}
local class = DBHelper

local function timestamp()
    local ts = os.date('%Y-%m-%d %H:%M:%S')
    return ts
end
class.timestamp = timestamp

local function getDiffDate(old, now)
    if not old or not now then
        return 10
    end

    local told = os.date("*t", old)
    local tnew = os.date("*t", now)

    told.hour = 0; told.min = 0; told.sec = 0
    tnew.hour = 0; tnew.min = 0; tnew.sec = 0

    local diff = os.difftime(os.time(tnew),os.time(told))
    diff = diff / (24 * 60 * 60)
    diff = math.floor(diff)

    return diff
end
class.getDiffDate = getDiffDate

class.trimSQL = function (text, length) 
    if not text then
        return text
    end
    local pat = "^$()%[]*+?`'\"!;{}@";
    for k=1,string.len(pat) do
        local one = string.sub(pat, k, k)
        one = "%" .. one
        text = string.gsub(text, one, '');
    end

    if length then
        text = string.sub(text, 1, length);
    end

    return text
end

local function kv_copy (obj)
    local ele = {}
    for k, v in pairs(obj) do
        ele[k] = class.trimSQL(v)
    end
    return ele
end

local function is_keys_ok (obj, keys)
    local ok = #keys >= 1
    for _, k in pairs(keys) do
        if not obj[k] or obj[k] == '' then
            ok = nil
        end
    end

    return ok
end

local function get_where (ele, keys)
    local str = ''
    for _, k in ipairs(keys) do
        if ele[k] then
            if str == '' then
                str = string.format("%s='%s'", k, ele[k])
            else
                str = str .. string.format(" AND %s='%s'", k, ele[k])
            end
            ele[k] = nil
        end
    end

    return str
end

local function get_insert_body (ele)
    -- () values ()
    local ks = ''
    local vs = ''
    for k, v in pairs(ele) do
        if ks == '' then
            ks = k
        else
            ks = ks .. string.format(", %s", k)
        end

        if vs == '' then
            vs = string.format("'%s'", v)
        else
            vs = vs .. string.format(", '%s'", v)
        end
    end
    ks = "(" .. ks .. ")"
    vs = "(" .. vs .. ")"

    local str = ks .. " VALUES " .. vs
    return str
end

local function get_update_body (ele)
    local str = ''
    for k, v in pairs(ele) do
        if str == '' then
            str = string.format("%s='%s'", k, v)
        else
            str = str .. string.format(", %s='%s'", k, v)
        end
    end

    return str
end

class.insert_sql = function (tableName, obj, keys)
    if not is_keys_ok(obj, keys) then
        return nil
    end

    local ele = kv_copy(obj)

    --- where condition
    local ws = get_where(ele, keys)

    -- insert command
    local cmd = string.format("INSERT %s ", tableName)

    local body = get_insert_body(ele)

    local sql = cmd .. body .. " WHERE " .. ws
    return sql
end

class.delete_sql = function (tableName, obj, keys)
    if not is_keys_ok(obj, keys) then
        return nil
    end

    local ele = kv_copy(obj)
    local ws  = get_where(ele, keys)
    local cmd = string.format("DELETE FROM %s ", tableName)

    local sql = cmd .. " WHERE " .. ws
    return sql
end

class.update_sql = function (tableName, obj, keys)
    if not is_keys_ok(obj, keys) then
        return nil
    end

    local ele = kv_copy(obj)
    local ws = get_where(ele, keys)
    local cmd = string.format("UPDATE %s ", tableName)
    local body = get_update_body(ele)

    local sql = cmd .. " SET " .. body .. " WHERE " .. ws
    return sql
end


return DBHelper

