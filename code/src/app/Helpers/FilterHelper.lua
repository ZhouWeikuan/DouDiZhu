---------------------------------------------------
---! @file
---! @brief 对table进行过滤或者判断
---------------------------------------------------

---! FilterHelper 模块定义
local FilterHelper = {}

---! @brief 以k-v的方式 过滤集合
---! @return 返回所有合适的k-v表
local function filterSet (set, filter)
    local ret = {}
    for k, v in pairs(set) do
        if filter(k, v) then
            ret[k] = v
        end
    end
    return ret
end
FilterHelper.filterSet = filterSet

---! @brief 过滤数组里的元素
---! @return 返回所有符合要求的元素数组
local function filterArray(array, filter)
    local ret = {}
    for k, v in ipairs(array) do
        if filter(v) then
            table.insert(ret, v)
        end
    end
    return ret
end
FilterHelper.filterArray = filterArray

---! @brief 判断元素是否在数组里
local function isElementInArray (ele, arr)
    if arr == nil then
        return false
    end

    for k,v in pairs(arr) do
        if ele == v then
            return true
        end
    end
    return false
end
FilterHelper.isElementInArray = isElementInArray


return FilterHelper

