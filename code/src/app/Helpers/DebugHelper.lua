---------------------------------------------------
---! @file
---! @brief 调试辅助库
---------------------------------------------------

local filterHelper = require "FilterHelper"

---! DebugHelper 模块定义
local class = {}

---! @brief 日志打印函数
local function cclog (...)
    print(string.format(...))
end
class.cclog = cclog

---! @brief 打印表格信息
local function printDeepTable (_origin_info, curDepth,  _space_count, _printed_info)
    if not _space_count then
        _space_count = 1
    end
    if not _origin_info then
        _origin_info = {}
    end

    if type(_origin_info) ~= "table" then
        class.cclog("%s is not a table", tostring(_origin_info))
        return
    end

    if not _printed_info then
        _printed_info = {}
    end

    --防止存在互相嵌套的表而无限打印
    local listTable = {}
    for k,v in pairs(_printed_info) do
        listTable[k] = v
    end
    table.insert(listTable, _origin_info)
    --防止存在互相嵌套的表而无限打印

    local pre = ""
    for i = 1, _space_count - 1 do
        pre = pre .. "  "
    end
    class.cclog(pre .. "{")

    if curDepth and  curDepth < 1 then
        class.cclog(pre .." ****over depth****")
    else
        if curDepth then
            curDepth = curDepth - 1
        end
        for k,v in pairs(_origin_info) do
            if type(v) == "table" then
                if filterHelper.isElementInArray(v, listTable) then
                    class.cclog(pre .. "  " .. tostring(k) .. " = " .. "tableCache")
                else
                    class.cclog(pre .. "  " .. tostring(k) .. " = ")
                    printDeepTable(v, curDepth, _space_count + 1, listTable)
                end
            else
                local str = pre .. "    "
                str = str .. tostring(k) .. " = " .. tostring(v)
                class.cclog(str)
            end
        end
    end

    class.cclog(pre .. "}")
end
class.printDeepTable = printDeepTable


return class

