
--! define class for PriorityQueue
local class = {mt = {}}
--! define class for PriorityQueue
local Queue = class
--! define class for PriorityQueue
class.mt.__index = class

---! @brief create Queue 
---! @return return a self table
local function create()
    local self = {}
    setmetatable(self, class.mt)

    self.first = 1
    self.last = 0

    return self
end
class.create = create

---! @brief The first element to determine the queue
---! @return The first element of the queue
local function front(self)
    local first = self.first
    if first > self.last then
        return nil
    else
        return self[first]
    end
end
class.front = front

---! @brief Take the element of the queue
---! @return The first element of the queue
local function popFront(self)
    local first = self.first
    if first>self.last then
        return nil
    end
    local value = self[first]
    self[first] = nil
    self.first = first+1
    return value
end
class.popFront = popFront

---! @brief Judge the last element of the queue
---! @return The last element of the queue
local function back(self)
    local last = self.last 
    if self.first > last then
        return nil
    else
        return self[last]
    end
end
class.back = back

---! @brief Put an element in the last position of the queue
---! @param element the element to pushed in
local function pushBack(self, element)
    self.last = self.last + 1
    self[self.last] = element
end
class.pushBack = pushBack

---! @brief Queue length
---! @param Queue length
local function count(self)
    if self.first>self.last then
        return 0
    end
    local count = self.last-self.first+1 
    return count
end
class.count = count

local function clear(self)
    for i=self.first,self.last do
        self[i] = nil
    end
    self.first = 1
    self.last = 0
end
class.clear = clear
class.reset = clear

          
return Queue

