---------------------------------------------------
---! @file
---! @brief 网络打包 解包
---------------------------------------------------

local protobuf  = require "protobuf"

local class = {mt = {}}
--! create the class name PacketHelper
local PacketHelper = class
--! create the class metatable
class.mt.__index = class

local msgFiles = {}

---! PacketHelper 模块定义
--! @brief The creator for PacketHelper
--! @return return the created object
local function create (protoFile)
    local self = {
        partial = "",
    }
    setmetatable(self, class.mt)

    if protoFile then
        self:registerProtoName(protoFile)
    end

    return self
end
class.create = create


---! @brief  make sure the protoFile is registered
local function registerProtoName (self, protoFile)
    if not msgFiles[protoFile] then
        local buffer = cc.FileUtils:getInstance():getStringFromFile(protoFile)
        protobuf.register(buffer)

        msgFiles[protoFile] = true
    end
end
class.registerProtoName  = registerProtoName

---! @brief make a general proto data for client - server.
local function makeProtoData (self, main, sub, body)
    local msg = {
        mainType = main,
        subType  = sub,
        msgBody  = body
    }

    local packet = protobuf.encode("CGGame.ProtoInfo", msg)
    return packet
end
class.makeProtoData = makeProtoData

local function encodeMsg (self, msgFormat, packetData)
    return protobuf.encode(msgFormat, packetData)
end
class.encodeMsg = encodeMsg

local function decodeMsg (self, msgFormat, packet)
    return protobuf.decode(msgFormat, packet)
end
class.decodeMsg = decodeMsg

local function extractMsg (self, msg)
    protobuf.extract(msg)
    return msg
end
class.extractMsg = extractMsg

---! @brief 加载配置文件, 文件名为从 backend目录计算的路径
local function load_config(filename)
    local source = cc.FileUtils:getInstance():getStringFromFile(filename)
    local tmp = {}
    assert(load(source, "@"..filename, "t", tmp))()

    return tmp
end
class.load_config = load_config

---! @brief 复制表格内容 key - value
local function copyTable(srcTable, dstTable)
    for k, v in pairs(srcTable) do
        dstTable[k] = v
    end
end
class.copyTable = copyTable


---! @brief create a class object by name
---! @param name the class name
---! for hall interface: TaskHelper.createObject(conf.Interface, conf)
---! for game class:     TaskHelper.createObject(conf.GameClass, conf)
local function createObject(name, ...)
    local cls = require(name)
    if not cls then
        print("failed to load class", name)
    end

    return cls.create(...)
end
class.createObject = createObject


return class

