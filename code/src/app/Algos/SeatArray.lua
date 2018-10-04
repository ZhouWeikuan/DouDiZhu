---------------------------------
--! @file
--! @addtogroup SeatArray
--! @brief a counted array SeatArray
--! @author hr@cronlygames.com
-----------------------------------

--! create the class name SeatArray
--! create the class metatable
local class = {mt = {}}
class.mt.__index = class

--! @brief The creator for SeatArray
--! @return return the created SeatArray object
local function create ()
    local self = {
        count = 0,
        data = {},
    }
    setmetatable(self, class.mt)

    return self
end
class.create = create

--! @brief get an object from this numarray
--! @param self the numarray
--! @param idx the position to get the object, default at the last element
local function getObjectAt (self, idx)
    return self.data[idx]
end
class.getObjectAt = getObjectAt

--! @brief set an object to this numarray
--! @param self the numarray
--! @param obj the object to set or replace
--! @param idx the position to set the object, default replace the last element
local function setObjectAt (self, idx, obj)
    local old = self.data[idx]
    if old then
        self.count = self.count - 1
    end
    if obj then
        self.count = self.count + 1
    end

    self.data[idx] = obj
end
class.setObjectAt = setObjectAt

--! @brief remove an object from this numarray
--! @param self the numarray
--! @param idx the position to remove the object, must not nil
local function removeObjectAt (self, idx)
    local old = self.data[idx]
    if old then
        self.count = self.count - 1
    end
    self.data[idx] = nil
end
class.removeObjectAt = removeObjectAt

--! @brief get the count for this numarray
--! @param self the numarray
local function getCount (self)
    return self.count
end
class.getCount = getCount

--! @brief loop elements in this numarray to execute function [handler],
--       until the function [handler] return true or all elements are checked
--! @param self the numarray
--! @param handler the executed function
--! @note  remember return true in handler for matched element
local function forEach (self, handler)
    local data = self.data
    for idx,obj in pairs(data) do
        if handler(idx, obj) then
            return
        end
    end
end
class.forEach = forEach

--! @brief reset the numarray
local function clear (self)
    self.count = 0
    self.data = {}
end
class.clear = clear

--! @brief reset the numarray
class.reset = clear

return class

