---------------------------------------------------
---! @file
---! @brief 文件和网络读写，打包解包等
---------------------------------------------------

---! 依赖库
local protobuf  = require "protobuf"

--! create the class metatable
local class = {mt = {}}
class.mt.__index = class

local msgFiles = {}

---! PacketHelper 模块定义
--! @brief The creator for PacketHelper
--! @return return the created object
local function create (protoFile)
    local self = {}
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

---! 编码
local function encodeMsg (self, msgFormat, packetData)
    return protobuf.encode(msgFormat, packetData)
end
class.encodeMsg = encodeMsg

---! 解码
local function decodeMsg (self, msgFormat, packet)
    return protobuf.decode(msgFormat, packet)
end
class.decodeMsg = decodeMsg

---! 深度递归解码
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

---! @brief 通过名称，创建类的对象
---! @param name 类名
---! @param ...  类的对象创建时所需要的其它参数
---! for hall interface: PacketHelper.createObject(conf.Interface, conf)
---! for game class:     PacketHelper.createObject(conf.GameClass, conf)
local function createObject(name, ...)
    local cls = require(name)
    if not cls then
        print("failed to load class", name)
    end

    return cls.create(...)
end
class.createObject = createObject


return class

