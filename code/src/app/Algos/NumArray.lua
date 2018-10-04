---------------------------------
--! @file
--! @addtogroup NumArray
--! @brief a counted array NumArray
--! @author hr@cronlygames.com
-----------------------------------

--! create the class, etc. NumArray
--! create the class metatable
local class = {mt = {}}
class.mt.__index = class


--! @brief The creator for NumArray
--! @return return the created NumArray object
local function create ()
    local self = {
        count = 0,
        data = {},
    }
    setmetatable(self, class.mt)

    return self
end
class.create = create

--! @brief add an object to this numarray self
--! @param self the numarray
--! @param obj the object to insert
--! @param idx the position for inserted object, default to append at last
local function insertObject (self, obj, idx)
    if idx then
        table.insert(self.data, idx, obj)
    else
        table.insert(self.data, obj)
    end
    self.count = self.count + 1
end
class.insertObject = insertObject

--! @brief get an object from this numarray
--! @param self the numarray
--! @param idx the position to get the object, default at the last element
local function getObjectAt (self, idx)
    idx = idx or self:getCount()
    return self.data[idx]
end
class.getObjectAt = getObjectAt

--! @brief set an object to this numarray
--! @param self the numarray
--! @param obj the object to set or replace
--! @param idx the position to set the object, default replace the last element
local function setObjectAt (self, obj, idx)
    idx = idx or self:getCount()
    if idx >= 1 and idx <= self:getCount() then
        self.data[idx] = obj
    end
end
class.setObjectAt = setObjectAt

--! @brief remove an object from this numarray
--! @param self the numarray
--! @param idx the position to remove the object, must not nil
local function removeObjectAt (self, idx)
    table.remove(self.data, idx)
    self.count = self.count - 1
end
class.removeObjectAt = removeObjectAt

--! @brief sort this numarray
--! @param self the numarray
--! @param cmp the comparator
local function sort (self, cmp)
    table.sort(self.data, cmp)
end
class.sort = sort

--! @brief get the count for this numarray
--! @param self the numarray
local function getCount (self)
    return self.count
end
class.getCount = getCount

--! @brief get an random object from this numarray
--! @param self the numarray
--! @note different to NumSet:getRandomObject, this function is not very slow, acceptable
local function getRandomObject (self)
    local idx = math.random(self:getCount())
    return self:getObjectAt(idx)
end
class.getRandomObject = getRandomObject

--! @brief get an raw data table from this numarray
--! @param self the numarray
--! @note don't use it unless you know what you are doing
local function getData (self)
    return self.data
end
class.getData = getData

--! @brief loop elements in this numarray to execute function [handler],
--       until the function [handler] return true or all elements are checked
--! @param self the numarray
--! @param handler the executed function
--! @note  remember return true in handler for matched element
local function forEach (self, handler)
    local data = self.data
    for _,obj in ipairs(data) do
        if handler(obj) then
            return
        end
    end
end
class.forEach = forEach

--! @brief reset the NumArray
local function clear (self)
    self.count = 0
    self.data = {}
end
class.clear = clear

--! @brief reset the NumArray
class.reset = clear

return class

