---------------------------------------------------
---! @file
---! @brief 数据库相关协助库
---------------------------------------------------

---! DBHelper 模块定义
local class = {}

---! 时间戳
class.timestamp = function ()
    local ts = os.date('%Y-%m-%d %H:%M:%S')
    return ts
end

---! 传入时间戳，获得相差天数
class.getDiffDate = function (old, now)
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

---! 去掉不合法的字符，避免干扰sql语句
class.trimSQL = function (text, length)
    if not text or type(text) ~= 'string' then
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

---! 处理where的条件 对 值 进行处理
local function kv_copy (obj)
    local ele = {}
    for k, v in pairs(obj) do
        ele[k] = class.trimSQL(v)
    end
    return ele
end

---! 条件合法判断
local function is_keys_ok (obj, keys)
    local ok = #keys >= 1
    if not ok then return ok end
    for _, k in pairs(keys) do
        if not obj[k] or obj[k] == '' then
            ok = nil
        end
    end

    return ok
end

---! 形成 where 子句, {[k] = v, ...}
class.getKeys = function (keys)
    local str = ''
    for k, v in pairs(keys) do
        local val = class.trimSQL(v)
        if str == '' then
            str = string.format("%s='%s'", k, val)
        else
            str = str .. string.format(" AND %s='%s'", k, val)
        end
    end

    return str
end

---! 形成 where 子句
local function get_where (ele, keys)
    local str = ''
    for _, k in ipairs(keys) do
        if ele[k] then
            if str == '' then
                str = string.format("%s='%s'", k, ele[k])
            else
                str = str .. string.format(" AND %s='%s'", k, ele[k])
            end
        end
    end

    return str
end

---! 形成插入语句体
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

---! 形成更新语句体
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

---! 形成选择语句体
local function get_select_body (ele)
    local str = ''
    for k, v in pairs(ele) do
        if str == '' then
            str = string.format("%s", k)
        else
            str = str .. string.format(", %s", k)
        end
    end
    if str == '' then
        str = '*'
    end
    return str
end

---! 形成完整的插入语句
class.insert_sql = function (tableName, obj, keys)
    local ele = kv_copy(obj)

    -- insert command
    local cmd = string.format("INSERT %s ", tableName)

    local body = get_insert_body(ele)

    local sql = cmd .. body

    if keys then
        if not is_keys_ok(obj, keys) then
            return nil
        end

        --- where condition
        local ws = get_where(ele, keys)
        sql = sql .. " WHERE " .. ws
    end

    return sql
end

---! 形成完整的删除语句
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

---! 形成完整的更新语句
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

---! 形成完整的选择语句
class.select_sql = function (tableName, obj, keys)
    if not is_keys_ok(obj, keys) then
        return nil
    end

    local ele = kv_copy(obj)
    local ws  = get_where(ele, keys)
    local body = get_select_body(ele)
    local cmd = string.format("SELECT %s FROM %s ", body, tableName)

    local sql = cmd .. " WHERE " .. ws
    return sql
end

return class

