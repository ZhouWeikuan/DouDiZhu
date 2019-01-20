----------------------------------------------------------------
---! @file
---! @brief protocol type status
----------------------------------------------------------------

local class = {}
setmetatable(class, {
    __index = function (t, k)
        return function()
            print("unknown field from protoTypes: ", k)
        end
    end
    })


---! 游戏中的常量
class.CGGAME_TIMEOUT_KEEPLINE              = 150
class.CGGAME_TIMEOUT_FORBID                = 30
class.CGGAME_TIMEOUT_WAITREADY             = 24

class.CGGAME_ROOM_TABLE_MAXID              = 999999
class.CGGAME_ROOM_TABLE_MINID              = 100000
class.CGGAME_ROOM_TABLE_EXPIRE_TIME		   = 8 * 60 * 60        -- 8小时停止游戏  12小时删除数据库
class.CGGAME_ROOM_TABLE_EXPIRE_NO_PLAYING  = 2 * 60 * 60        -- 无人玩时，最多2小时

--- main proto types
class.CGGAME_PROTO_MAINTYPE_BASIC   = 1                         -- basic proto type
    class.CGGAME_PROTO_SUBTYPE_MULTIPLE     =   1               -- mulitiple message
    class.CGGAME_PROTO_SUBTYPE_ACL          =   2               -- acl info
    class.CGGAME_PROTO_SUBTYPE_HEARTBEAT    =   3               -- heart beat
        class.CGGAME_PROTO_HEARTBEAT_CLIENT    =   1            -- heart beat from client
        class.CGGAME_PROTO_HEARTBEAT_SERVER    =   2            -- heart beat from server
    class.CGGAME_PROTO_SUBTYPE_AGENTLIST    =   4               -- ask for agent list
    class.CGGAME_PROTO_SUBTYPE_HALLTEXT     =   5               -- 大厅进入通知文本
    class.CGGAME_PROTO_SUBTYPE_GAMETEXT     =   6               -- 游戏进入通知文本
    class.CGGAME_PROTO_SUBTYPE_NOTICE       =   7               -- system notice

class.CGGAME_PROTO_MAINTYPE_AUTH    = 10                        -- auth proto type
    class.CGGAME_PROTO_SUBTYPE_ASKRESUME    =   1               -- client -> server, ask resume/ask auth
    class.CGGAME_PROTO_SUBTYPE_CHALLENGE    =   2               -- server -> client, give a challenge key
    class.CGGAME_PROTO_SUBTYPE_CLIENTKEY    =   3               -- client -> server, give a client key
    class.CGGAME_PROTO_SUBTYPE_SERVERKEY    =   4               -- server -> client, give a server key
    class.CGGAME_PROTO_SUBTYPE_RESUME_OK    =   5               -- server -> client, tell resume ok

class.CGGAME_PROTO_MAINTYPE_HALL    = 20                        -- hall proto type
    class.CGGAME_PROTO_SUBTYPE_QUIT         =   1               -- quit hall and game
    class.CGGAME_PROTO_SUBTYPE_HALLJOIN     =   2               -- join to hall
    class.CGGAME_PROTO_SUBTYPE_MYINFO       =   3               -- update user info
    class.CGGAME_PROTO_SUBTYPE_MYSTATUS     =   4               -- update user status
    class.CGGAME_PROTO_SUBTYPE_BONUS        =   5               -- recv bonus
        class.CGGAME_PROTO_BONUS_DAILY  =   1                   -- daily bonus
        class.CGGAME_PROTO_BONUS_SHARE  =   2                   -- bonus for share
    class.CGGAME_PROTO_SUBTYPE_CHAT         =   6               -- chat to user
    class.CGGAME_PROTO_SUBTYPE_USERINFO     =   7               -- 别人用户信息
    class.CGGAME_PROTO_SUBTYPE_USERSTATUS   =   8               -- 别人的在线信息


class.CGGAME_PROTO_MAINTYPE_CLUB    = 30                        -- 俱乐部

class.CGGAME_PROTO_MAINTYPE_ROOM    = 40                        -- 房卡 房间信息
    class.CGGAME_PROTO_SUBTYPE_CREATE      =  1                 -- 开房
    class.CGGAME_PROTO_SUBTYPE_JOIN        =  2                 -- 进房
    class.CGGAME_PROTO_SUBTYPE_RELEASE     =  3                 -- 退房
    class.CGGAME_PROTO_SUBTYPE_INFO        =  4                 -- 信息
    class.CGGAME_PROTO_SUBTYPE_RESULT      =  5                 -- 一局战绩
    class.CGGAME_PROTO_SUBTYPE_RESULT_ALL  =  6                 -- 全部战绩


class.CGGAME_PROTO_MAINTYPE_GAME    = 50                        -- 游戏
    class.CGGAME_PROTO_SUBTYPE_GAMEJOIN     =   1               -- 加入游戏
    class.CGGAME_PROTO_SUBTYPE_GAMETRACE    =   2               -- 各游戏内部协议
    class.CGGAME_PROTO_SUBTYPE_BROADCAST    =   3               -- 游戏的广播
        ---! events
        class.CGGAME_MSG_EVENT_SITDOWN         =   1            -- 坐下
        class.CGGAME_MSG_EVENT_STANDUP         =   2            -- 站起
        class.CGGAME_MSG_EVENT_STANDBY         =   3            -- 旁观
        class.CGGAME_MSG_EVENT_READY           =   4            -- 准备
        class.CGGAME_MSG_EVENT_QUITTABLE       =   5            -- 退桌
        class.CGGAME_MSG_EVENT_BREAK           =   6            -- 掉线
        class.CGGAME_MSG_EVENT_CONTINUE        =   7            -- 继续

    class.CGGAME_PROTO_SUBTYPE_GIFT         =   4               -- 发送礼物
    class.CGGAME_PROTO_SUBTYPE_TABLEMAP     =   5               -- 座位图
    class.CGGAME_PROTO_SUBTYPE_GAMEINFO     =   6               -- 游戏信息
    class.CGGAME_PROTO_SUBTYPE_WAITUSER     =   7               -- 等候用户
    class.CGGAME_PROTO_SUBTYPE_GAMEOVER     =   8               -- 结束信息

    class.CGGAME_PROTO_SUBTYPE_SITDOWN      =  11               -- 坐下
    class.CGGAME_PROTO_SUBTYPE_READY        =  12               -- 准备
    class.CGGAME_PROTO_SUBTYPE_CONFIRM      =  13               -- 确定开始
    class.CGGAME_PROTO_SUBTYPE_STANDUP      =  14               -- 站起
    class.CGGAME_PROTO_SUBTYPE_STANDBY      =  15               -- 旁观
    class.CGGAME_PROTO_SUBTYPE_CHANGETABLE  =  16               -- 换桌

    class.CGGAME_PROTO_SUBTYPE_QUITTABLE    =  17               -- for card/board game
    class.CGGAME_PROTO_SUBTYPE_QUITSTAGE    =  18               -- for strategy game

    class.CGGAME_PROTO_SUBTYPE_USER_DEFINE  = 100               -- each game's subtype data start from 100


---! 房卡支付
class.CGGAME_ROOM_LEAST_COINS           = 1
class.CGGAME_ROOM_PAYTYPE_OWNER         = 0
class.CGGAME_ROOM_PAYTYPE_PLAYERS       = 1
class.CGGAME_ROOM_PAYTYPE_WINNER        = 2


---! 用户在线状态
class.CGGAME_USER_STATUS_IDLE              =   0
class.CGGAME_USER_STATUS_OFFLINE           =   1
class.CGGAME_USER_STATUS_STANDUP           =   2
class.CGGAME_USER_STATUS_STANDBY           =   3
class.CGGAME_USER_STATUS_SITDOWN           =   4
class.CGGAME_USER_STATUS_READY             =   5
class.CGGAME_USER_STATUS_PLAYING           =   6


---! 桌子状态
class.CGGAME_TABLE_STATUS_IDLE			   =   0
class.CGGAME_TABLE_STATUS_WAITREADY		   =   1
class.CGGAME_TABLE_STATUS_WAITCONFIRM      =   2
class.CGGAME_TABLE_STATUS_PLAYING          =   3


---! ACL status code 用于回应客户端消息的状态码
--- 0 ~ 9  for success
class.CGGAME_ACL_STATUS_SUCCESS					            =   0
class.CGGAME_ACL_STATUS_ALREADY					            =   1
-- class.CGGAME_ACL_STATUS_ALREADY_AGENTCODE			        =   1011

--- 100 ~ 999 for each game

---- 1000 for common handler
class.CGGAME_ACL_STATUS_SERVER_BUSY						    =   1000        -- 服务器繁忙
class.CGGAME_ACL_STATUS_INVALID_INFO						=   1001        -- 提供的信息有误
class.CGGAME_ACL_STATUS_INVALID_COMMAND						=   1002        -- 未知或不合法的命令
class.CGGAME_ACL_STATUS_AUTH_FAILED			                =   1003        -- 授权失败
class.CGGAME_ACL_STATUS_COUNTER_FAILED                      =   1004        --
class.CGGAME_ACL_STATUS_SERVER_ERROR						=   1005
class.CGGAME_ACL_STATUS_SHARE_EXCEED						=   1006
class.CGGAME_ACL_STATUS_OLDVERSION						    =   1007        -- 版本过旧
class.CGGAME_ACL_STATUS_NODE_OFF						    =   1008        -- 所在服务器的节点即将关闭

class.CGGAME_ACL_STATUS_INVALID_AGENTCODE			        =   1010        -- 代理号有误

class.CGGAME_ACL_STATUS_ROOM_DB_FAILED					    =   1020        -- 房间创建时数据库有误
class.CGGAME_ACL_STATUS_ROOM_CREATE_FAILED					=   1021        -- 房间创建失败
class.CGGAME_ACL_STATUS_ROOM_FIND_FAILED					=   1022        -- 找不到房间号
class.CGGAME_ACL_STATUS_ROOM_JOIN_FULL						=   1023        -- 房间已满，无法加入
class.CGGAME_ACL_STATUS_ROOM_NOT_SUPPORT					=   1024        -- 尚不支持房号功能
class.CGGAME_ACL_STATUS_ROOM_NO_SUCH_PAYTYPE                =   1025        -- 支付方式不支持


class.isACLSuccess = function (status)
    return status < 100
end

class.isACLFailed = function (status)
    return status >= 100
end

return class

