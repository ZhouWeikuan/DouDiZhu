---------------------------------
--! @file
--! @addtogroup NumSet
--! @brief a counted hash map NumSet
--! @author hr@cronlygames.com
-----------------------------------

--! reference to math library
local math = math

--! create the temp class
local class = {mt = {}}

--! create the class name NumSet
local NumSet = class

--! create the class metatable
class.mt.__index = class

--! @brief The creator for NumSet
--! @return return the created NumSet object
local function create ()
    local self = {
        count = 0,
        data = {},
    }
    setmetatable(self, class.mt)

    return self
end
class.create = create

--! @brief add an object to this numset self
--! @param self the numset
--! @param obj the object to add
--! @param key the key for added object, default the object itself
--! @return 

local function addObject(self, obj, key)
    key = key or obj
    if not self.data[key] then
        self.count = self.count + 1
        self.data[key] = obj
    end
end

class.addObject = addObject

--! @brief remove an object from this numset self
--! @param self the numset
--! @param obj the object to remove
--! @param key the key for removed object, default the object obj
local function removeObject(self, obj, key)
    key = key or obj
    if self.data[key] then
        self.count = self.count - 1
        self.data[key] = nil
    end
end
class.removeObject = removeObject

--! @brief remove objects from this numset
--! @param objs the objects to remove
--! @param keys the corresponding keys for each object, i.e. key=keys[one object], or key = object by default
--! @return return None.
local function removeObjects (self, objs, keys)
    for _, obj in ipairs(objs) do
        local k = keys and keys[obj] or obj
        self:removeObject(obj, k)
    end
end
class.removeObjects = removeObjects

--! @brief retrieve one object from this numset
--! @param key the key for the object to retrieve
--! @return return the object
local function getObject (self, key)
    local obj = self.data[key]
    return obj
end
class.getObject = getObject

--! @brief check one object if exists in the numset
--! @param obj the object to check 
--! @param key the key for the object to check, default the object itself
--! @return return true if the object with key exists
local function hasObject (self, obj, key)
    key = key or obj
    local o = self.data[key]
    if o and o == obj then
        return true
    end
end
class.hasObject = hasObject

--! @brief get first object from the numset
--! @return return the object
local function getAnyObject (self)
    local ret = nil
    self:forEach(function (obj)
        ret = obj
        return true
    end)

    return ret
end
class.getAnyObject = getAnyObject

--! @brief get one random object from the numset
--! @return return the random object
--! @note it is VERY slow, caution to use it
local function getRandomObject (self)
    local idx = math.random(self:getCount())
    local pos = 0
    local ret = nil
    self:forEach(function (obj)
        pos = pos + 1
        if pos == idx then
            ret = obj
            return true
        end
    end)

    return ret
end
class.getRandomObject = getRandomObject

--! @brief get count of objects for the numset
--! @return return the count, default 0
local function getCount (self)
    return self.count
end
class.getCount = getCount

--! @brief check whether this numset is equal to other numset
--! @param other the other numset
--! @return return true if their metatable, count, and elements all equal
local function isEqual (self, other)
    if getmetatable(self) ~= getmetatable(other) then
        -- ed.cclog("metable not same")
        return nil
    end

    if self:getCount() ~= other:getCount() then
        -- ed.cclog("count not same")
        return nil
    end

    local ret = true
    self:forEach(function(obj)
        if not other:hasObject(obj) then
            -- ed.cclog("element not same")
            return nil
        end
    end)

    return ret
end
class.isEqual = isEqual

--! @brief loop elements in this numset to execute function [handler],
--       until the function [handler] return true or all elements are checked
--! @param handler the function executed 
--! @return break if any element matches handler, or all elements checked
local function forEach (self, handler)
    local data = self.data
    for _,obj in pairs(data) do
        if handler(obj) then
            return
        end
    end
end
class.forEach = forEach

--! @brief reset the numset
local function clear (self)
    self.count = 0
    self.data = {}
end
class.clear = clear

--! reset the numset
local reset = clear
class.reset = reset

return NumSet

