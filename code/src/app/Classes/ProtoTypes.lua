----------------------------------------------------------------
---! @file
---! @brief protocol type status
----------------------------------------------------------------

local class = {}
local ProtoTypes = class

---! 游戏中的常量
class.CGGAME_TIMEOUT_KEEPLINE              = 150;
class.CGGAME_TIMEOUT_FORBID                = 30;
class.CGGAME_TIMEOUT_WAITSTART             = 24;

class.CGGAME_ROOM_TABLE_MAXID              = 999999;
class.CGGAME_ROOM_TABLE_MINID              = 100000;
class.CGGAME_ROOM_TABLE_EXPIRE_TIME		   = 8 * 60 * 60; -- 8小时停止游戏  12小时删除数据库
class.CGGAME_ROOM_TABLE_EXPIRE_NO_PLAYING  = 2 * 60 * 60; -- 无人玩时，最多2小时

---! 状态码 用于交流的第一个标志
class.CGGAME_PROTO_TYPE_ACL            = 0;
class.CGGAME_PROTO_TYPE_HEARTBEAT      = 1;

---! login a game, we use user_info, specially use FUserID as gameId,
---!     but FUserName, FNickName are as before
class.CGGAME_PROTO_TYPE_LOGIN          = 2;

class.CGGAME_PROTO_TYPE_JOINGAME       = 3;    --- join a hall
class.CGGAME_PROTO_TYPE_QUITGAME       = 4;    --- quit a hall

class.CGGAME_PROTO_TYPE_NOTICE         = 5;
class.CGGAME_PROTO_TYPE_BROADCAST      = 6;
class.CGGAME_PROTO_TYPE_SETUSERINFO    = 7;
class.CGGAME_PROTO_TYPE_GETUSERINFO    = 7;
class.CGGAME_PROTO_TYPE_ROOMTEXT       = 9;

---! communicate game list between c-s
class.CGGAME_PROTO_TYPE_GAMELIST       = 10;
class.CGGAME_PROTO_TYPE_GETGAMELIST    = 10;

---! communicate server list between c-s
class.CGGAME_PROTO_TYPE_LOGINLIST      = 11;
class.CGGAME_PROTO_TYPE_GETLOGINLIST   = 11;

class.CGGAME_PROTO_SUBTYPE_LIST_DIRECT  = 0;  -- get hall/login list directly
class.CGGAME_PROTO_SUBTYPE_LIST_PIPE    = 1;  -- get hall/login list via pipe server

---! communicate server list between c-s
class.CGGAME_PROTO_TYPE_HALLLIST       = 12;
class.CGGAME_PROTO_TYPE_GETHALLLIST    = 12;

class.CGGAME_PROTO_TYPE_DAILYBONUS 	   = 13;

class.CGGAME_PROTO_TYPE_SETLOCATION       = 15;  -- AnQing 更新后删除
class.CGGAME_PROTO_TYPE_GETLOCATION       = 15;

class.CGGAME_PROTO_TYPE_SETUSERSTATUS     = 16;
class.CGGAME_PROTO_TYPE_GETUSERSTATUS     = 16;

class.CGGAME_PROTO_TYPE_GAMEDATA           = 20;
class.CGGAME_PROTO_TYPE_SUBMIT_GAMEDATA    = 20;

class.CGGAME_PROTO_SUBTYPE_SITDOWN         = 1;
class.CGGAME_PROTO_SUBTYPE_READY           = 2;
class.CGGAME_PROTO_SUBTYPE_START           = 2;
class.CGGAME_PROTO_SUBTYPE_STANDUP         = 3;

class.CGGAME_PROTO_SUBTYPE_QUITTABLE       = 4;     -- for card/board game
class.CGGAME_PROTO_SUBTYPE_QUITSTAGE       = 4;     -- for strategy game

class.CGGAME_PROTO_SUBTYPE_CHANGETABLE     = 5;
class.CGGAME_PROTO_SUBTYPE_WAITUSER        = 6;
class.CGGAME_PROTO_SUBTYPE_USERINFO        = 7;
class.CGGAME_PROTO_SUBTYPE_USERSTATUS      = 8;
class.CGGAME_PROTO_SUBTYPE_GAMEINFO        = 9;

class.CGGAME_PROTO_SUBTYPE_GAMETRACE       =  10;
class.CGGAME_PROTO_SUBTYPE_GAMEOVER        =  11;
class.CGGAME_PROTO_SUBTYPE_TABLEMAP        =  12;
class.CGGAME_PROTO_SUBTYPE_ROOMSEAT        =  13;

class.CGGAME_PROTO_SUBTYPE_CHAT            =  20;   -- chat to one table, use ChatInfo
class.CGGAME_PROTO_SUBTYPE_GIFT            =  21;   -- gift to one table, use GiftInfo

-- class.CGGAME_PROTO_SUBTYPE_USER_DEFINE  = 100    -- each game's subtype data start from 100

---! events
class.CGGAME_MSG_EVENT_SITDOWN         =   1;
class.CGGAME_MSG_EVENT_STANDUP         =   2;
class.CGGAME_MSG_EVENT_READY           =   3;
class.CGGAME_MSG_EVENT_QUITTABLE       =   4;
class.CGGAME_MSG_EVENT_BREAK           =   5;
class.CGGAME_MSG_EVENT_CONTINUE        =   6;


---! user status
class.CGGAME_USER_STATUS_IDLE              =   0;
class.CGGAME_USER_STATUS_OFFLINE           =   1;
class.CGGAME_USER_STATUS_STANDUP           =   10;
class.CGGAME_USER_STATUS_SITDOWN           =   20;
class.CGGAME_USER_STATUS_READY             =   30;
class.CGGAME_USER_STATUS_PLAYING           =   50;

---! table status
class.CGGAME_TABLE_STATUS_IDLE			   =   0;
class.CGGAME_TABLE_STATUS_WAITSTART		   =   1;
class.CGGAME_TABLE_STATUS_PLAYING          =   2;


---! ACL status code 用于回应客户端消息的状态码
--- 0 ~ 9  for success
class.CGGAME_ACL_STATUS_SUCCESS					            =   0;

--- 100 ~ 999 for each game

---- 1000 for common handler
class.CGGAME_ACL_STATUS_SERVER_BUSY						    =   1001;
class.CGGAME_ACL_STATUS_INVALID_INFO						=   1002;

class.CGGAME_ACL_STATUS_ROOM_DB_FAILED					    =   1003;
class.CGGAME_ACL_STATUS_ROOM_CREATE_FAILED					=   1004;
class.CGGAME_ACL_STATUS_ROOM_FIND_FAILED					=   1005;
class.CGGAME_ACL_STATUS_ROOM_JOIN_FULL						=   1006;
class.CGGAME_ACL_STATUS_ROOM_NOT_SUPPORT					=   1007;
class.CGGAME_ACL_STATUS_INVALID_USERINFO					=   1008;
class.CGGAME_ACL_STATUS_ROOM_NO_SUCH_PAYTYPE                =   1009;
class.CGGAME_ACL_STATUS_UNKNOWN_COMMAND						=   1010;
class.CGGAME_ACL_STATUS_AUTHENTICATION_FAILED			    =   1011;
class.CGGAME_ACL_STATUS_ALREADY_AGENTCODE			        =   1012;
class.CGGAME_ACL_STATUS_PLAYING							    =   1013;
class.CGGAME_ACL_STATUS_INVALID_AGENTCODE			        =   1014;
class.CGGAME_ACL_STATUS_SERVER_ERROR						=   1015;
class.CGGAME_ACL_STATUS_OLDVERSION						    =   1018;

class.CGGAME_ACL_STATUS_COUNTER_LACK						=   1028;
class.CGGAME_ACL_STATUS_COUNTER_FAILED                      =   1029;

local function isACLSuccess (status)
    return status < 1000
end
class.isACLSuccess = isACLSuccess

local function isACLFailed (status)
    return status >= 1000
end
class.isACLFailed = isACLFailed


return class

