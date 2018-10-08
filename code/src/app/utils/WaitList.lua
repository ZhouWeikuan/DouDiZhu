local skynet    = skynet or require "skynet"

local class = {mt = {}}
class.mt.__index = class

class.create = function ()
    local self = {}
    setmetatable(self, class.mt)
    self.pause_list = {}

    return self
end

class.resume = function (self)
    local co = table.remove(self.pause_list)
    if not co then
        return
    end

    if skynet.init then
        skynet.wakeup(co)
    else
        coroutine.resume(co)
    end
end

class.pause = function (self)
    local co = coroutine.running()
    table.insert(self.pause_list, co)

    if skynet.init then
        skynet.wait(co)
    else
        coroutine.yield()
    end
end

return class

