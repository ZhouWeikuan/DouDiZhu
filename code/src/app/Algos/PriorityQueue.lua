---------------------------------
--! @file
--! @brief PriorityQueue
--!     all objects in queue is sorted heap by priority, that is
--!        the lowest priority value is first
--!
--!  Object in queue must have three keys,
--!      1) getKey(obj)             to identify itself from others, default the event itself
--!      2) getPriority(obj)        like os.time(), when we should fire this event,
--!      3) .queueIndex              index to find/update in queue, only meaningful when it is in queue
--!
--------------------------------

--! define class for PriorityQueue
local class = {mt = {}}
--! define class for PriorityQueue
local PriorityQueue = class
--! define class for PriorityQueue
class.mt.__index = class

--! @brief creator for PriorityQueue
local function create (getKey, getPriority, queueIndexKey)
    local self = {
        count = 0,
        objects = {},
        queue = {},

        getKeyFunc = getKey,
        getPriorityFunc = getPriority,
        queueIndexKey = queueIndexKey or ".queueIndex"
    }

    setmetatable(self, class.mt)
    return self
end
class.create = create

--! @brief add Object to PriorityQueue
--! @param self the queue
--! @param ele an object to add
local function addObject (self, obj)
    local e = self:findObject(obj)
    if e then
        return
    end

    e = obj
    local key = self.getKeyFunc(e)
    self.count = self.count + 1
    self.objects[key] = obj
    local index = self.count
    self.queue[index] = obj
    obj[self.queueIndexKey] = index

    self:shiftUp(index)
end
class.addObject = addObject

--! @brief update an existing object with a priority in queue
--! @param self the queue
--! @param obj  the object
--! @param setPriorityFunc set new priority for the object, setPriorityFunc(obj)
local function updateObject (self, obj, setPriorityFunc)
    local e = self:findObject(obj)
    if not e then
        setPriorityFunc(obj)
        self:addObject(obj)
    end

    e = self:findObject(obj)
    if not e then
        return
    end

    local oldTimeout = self.getPriorityFunc(e)
    setPriorityFunc(e)
    if self.getPriorityFunc(e) >= oldTimeout then
        self:shiftDown(e[self.queueIndexKey])
    else
        self:shiftUp(e[self.queueIndexKey])
    end
end
class.updateObject = updateObject

--! @brief remove an existing event from queue
--! @param self, event
local function removeObject (self, obj)
    local e = self:findObject(obj)
    if not e then
        return
    end

    local key= self.getKeyFunc(e)
    self.objects[key] = nil
    if e[self.queueIndexKey] == self.count then
        self.queue[e[self.queueIndexKey]] = nil
        self.count = self.count - 1

    else
        local last = self.queue[self.count]
        self.queue[self.count] = nil
        self.count = self.count - 1

        self.queue[e[self.queueIndexKey]] = last
        last[self.queueIndexKey] = e[self.queueIndexKey]

        if self.getPriorityFunc(last)  >= self.getPriorityFunc(e) then
            self:shiftDown(last[self.queueIndexKey])
        else
            self:shiftUp(last[self.queueIndexKey])
        end
    end

    return e
end
class.removeObject = removeObject

--! @brief find object in queue
--! @param obj object to find
--! @return the object or nil
local function findObject (self, obj)
    local key = self.getKeyFunc(obj)
    local e = self.objects[key]
    return e
end
class.findObject = findObject

--! @brief internal function to shift object in queue up
--! @param index the queue index to shift
local function shiftUp (self, index)
    local parent = math.floor(index / 2)
    if parent < 1 then
        return
    end

    local p = self.queue[parent]
    local e = self.queue[index]
    if self.getPriorityFunc(e) < self.getPriorityFunc(p) then
        p[self.queueIndexKey] = index
        e[self.queueIndexKey] = parent

        self.queue[e[self.queueIndexKey]] = e
        self.queue[p[self.queueIndexKey]]  = p

        self:shiftUp(parent)
    end
end
class.shiftUp = shiftUp

--! @brief internal function to shift object in queue down
--! @param index the queue index to shift
local function shiftDown (self, index)
    local sub2 = math.floor(index * 2 + 1)
    local sub  = math.floor(index * 2)

    if sub > self.count then
        return
    end

    if sub2 > self.count or self.getPriorityFunc(self.queue[sub2]) >= self.getPriorityFunc(self.queue[sub]) then
    else
        sub = sub2
    end

    local p = self.queue[index]
    local e = self.queue[sub]

    if self.getPriorityFunc(e) < self.getPriorityFunc(p) then
        p[self.queueIndexKey] = sub
        e[self.queueIndexKey] = index

        self.queue[e[self.queueIndexKey]] = e
        self.queue[p[self.queueIndexKey]]  = p

        self:shiftDown(sub)
    end
end
class.shiftDown = shiftDown

--! @brief pop the first object in queue
local function pop (self)
    if self.count <= 0 then
        return nil
    end

    local e = self.queue[1]
    return self:removeObject(e)
end
class.pop = pop

--! @brief retrieve the first object in queue, but not pop
--! @see top
local function top (self)
    if self.count <= 0 then
        return nil
    end

    local e = self.queue[1]
    return e
end
class.top = top

--! @brief forEach iterate through each items
--!         break if handler(obj) return true
local function forEach (self, handler)
    for i=1,self.count do
        local e = self.queue[i]
        if handler(e) then
            break
        end
    end
end
class.forEach = forEach


--! @brief debug output all event in queue
local function debugOut (self)
    local ret = ""
    for i=1,self.count do
        local e = self.queue[i]
        local str = string.format("%s --> {%s, %s}",
            tostring(e[self.queueIndexKey]),
            tostring(self.getKeyFunc(e)),
            tostring(self.getPriorityFunc(e)))
        ret = ret .. str .. "\n"
    end
    return ret
end
class.debugOut = debugOut

return PriorityQueue
