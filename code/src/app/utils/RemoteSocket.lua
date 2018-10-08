---------------------------------
--! @file
--! @brief RemoteSocket
---------------------------------

local socket    = require "socket.core"

--! define RemoteSocket
local class = {mt = {}}
class.mt.__index = class

class.getTCPSocket = function(self, host, port)
    local isipv6_only = false
    local addrinfo, err = socket.dns.getaddrinfo(host)
    local addr = host
    for i,v in ipairs(addrinfo) do
        if v.family == "inet6" then
            isipv6_only = true
            addr = v.addr
            break
        end
    end

    local sock = nil
    if isipv6_only then
        sock = socket.tcp6()
    else
        sock = socket.tcp()
    end

    sock:settimeout(1.0)
    sock:setoption('tcp-nodelay', true)
    local res, err = sock:connect(addr, port)
    if not res then
        print("socket connect to ", addr, port, "error", err)
        sock:close()
        return nil
    end

    sock:settimeout(0)
    self.host = addr
    self.port = port

    return sock
end

--! @brief create a remote socket,
--! @param ip   ip addr or host name
--! @param port port
local function create (ip, port)
	local self = {}
	setmetatable(self, class.mt)
    self:resetPartial()

    self.sockfd = self:getTCPSocket(ip, port)
    if not self.sockfd then
        return nil
    end

	return self
end
class.create = create

class.resetPartial = function (self)
    self.pack_len = nil
    self.partial  = ""
end

class.readHead = function (self)
    if self.pack_len then
        return true
    end

    local len = 2 - string.len(self.partial)
    local tmp, status, partial = self.sockfd:receive(len)
    if status == nil then
        self.partial = self.partial .. tmp
    elseif status == "timeout" then
        self.partial = self.partial .. partial
    else
        self:abort("read pack size 2, error" .. tostring(status))
        return
    end

    if string.len(self.partial) == 2 then
        self.pack_len = string.unpack(">I2", self.partial)
        self.partial = ""
        return true
    end
end

class.readBody = function (self)
    local tmp, status, partial = self.sockfd:receive(self.pack_len)
    if status == nil then
        self.partial = self.partial .. tmp
        self.pack_len = self.pack_len - string.len(tmp)
    elseif status == "timeout" then
        self.partial = self.partial .. partial
        self.pack_len = self.pack_len - string.len(partial)
    else
        self:abort("read content size " .. tostring(self.pack_len) .. " error " .. tostring(status))
        return
    end

    if self.pack_len <= 0 then
        local p = self.partial

        self:resetPartial()
        return p
    end
end


--! @brief receive one valid packet from server
--! @param self   the remote socket
--! @param delaySecond  delay time, like 5.0, nil means no delay, -1.0 means blocked wait until some bytes arrive
--! @param the packet or nil
local function recvPacket (self, delaySecond)
    if not self.sockfd then
        return
    end

    local read_list = {self.sockfd}
    local readys = socket.select(read_list, nil, delaySecond and delaySecond or 0)
    if #readys < 1 then
        return
    end

    if not self:readHead() then
        return
    end

    return self:readBody()
end
class.recvPacket = recvPacket

---! @breif send a packet to remote
---! @param pack  is a valid proto data string
local function sendPacket (self, pack)
    if not self.sockfd then
        return
    end

    pack = string.pack(">s2", pack)

    local status, err = self.sockfd:send(pack)
    if not status then
        self:abort(err)
    end
end
class.sendPacket = sendPacket

class.isClosed = function (self)
    return (self.sockfd == nil)
end

---! @brief close
local function close (self, err)
    local c = self.sockfd
    if c then
        c:close()
    end

    self:resetPartial()
    self.sockfd = nil
end
class.close = close

---! @brief abort with error
local function abort (self, err)
    print("socket abort", err)
    self:close(err)
    do return end

    local app = cc.exports.appInstance
    local view = app:createView("LineScene")
    view:showWithScene()
end
class.abort = abort

return class
