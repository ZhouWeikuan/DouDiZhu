#include "scripting/lua-bindings/manual/CCLuaEngine.h"

#include "LuaYunCheng.h"

#include "YunChengAI.h"
#include "AutoLock.h"

USING_NS_CC;

extern "C"{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#ifdef __cplusplus
    extern "C" {
#endif
#include "tolua++.h"
#ifdef __cplusplus
    }
#endif

    static const char * const pMetaTableName = "YunChengMetatable";

    void readIntArray(lua_State * L, int stackIndex, std::vector<int> & cards) {
        cards.clear();

        int len = (int)luaL_len(L, stackIndex);
        for (int i = 1; i <= len; ++i) {
            lua_rawgeti(L, stackIndex, i);

            int card = (int)lua_tointeger(L, -1);
            cards.push_back(card);

            lua_pop(L, 1);
        }
    }

    void writeIntArray(lua_State * L, const std::vector<int> & cards) {
        lua_newtable(L);
        for (int i=0; i < (int)cards.size(); ++i) {
            lua_pushinteger(L, cards[i]);
            lua_rawseti(L, -2, i+1);
        }
    }


#pragma mark - YunCheng Library
    int new_yuncheng(lua_State* L)
    {
        int n = lua_gettop(L);
        if (n != 1) {
            return luaL_error(L, "Illegal param num for yuncheng.new, required 1, provided %d", n);
        }

        int bomb3 = (int)lua_tointeger(L, 1);
        size_t nbytes = sizeof(struct YunChengGame);

        struct YunChengGame * game = (struct YunChengGame *)lua_newuserdata(L, nbytes);
        game->init(bomb3);

        // 设置元表
        luaL_getmetatable(L, pMetaTableName);
        lua_setmetatable(L, -2);

        return 1;
    }

#pragma mark - Game Environments
    // struct YunChengGame * yuncheng, masterSeatId, curSeatId
    int lupdateSeats(lua_State* L) {
        int n = lua_gettop(L);
        if (n != 3) {
            return luaL_error(L, "Illegal param num for yuncheng:updateSeats, required 3, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        int masterId            = (int)lua_tointeger(L, 2);
        int curSeatId           = (int)lua_tointeger(L, 3);

        game->masterSeatId  = masterId;
        game->curSeatId     = curSeatId;

        return 0;
    }

    // struct YunChengGame * yuncheng, std::vector<int> & turnCards
    int laddHistCards(lua_State* L) {
        int n = lua_gettop(L);
        if (n != 2) {
            return luaL_error(L, "Illegal param num for yuncheng:addHistCards, required 2, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        game = game;

        int len = (int)luaL_len(L, 2);
        for (int i = 1; i <= len; ++i) {
            lua_rawgeti(L, 2, i);

            int card = (int)lua_tointeger(L, -1);
            card = card;
            //game->addHistoryCard(card);

            lua_pop(L, 1);
        }

        return 0;
    }

    // struct YunChengGame * yuncheng, seatId, std::vector<int>& handCards
    int lsetHandCards(lua_State* L) {
        int n = lua_gettop(L);
        if (n != 3) {
            return luaL_error(L, "Illegal param num for yuncheng:setHandCards, required 3, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        int seatId   = (int)lua_tointeger(L, 2);

        LordCards & one = *game->seatHands[seatId];

        std::vector<int> cards;
        int len = (int)luaL_len(L, 3);
        for (int i = 1; i <= len; ++i) {
            lua_rawgeti(L, 3, i);

            int card = (int)lua_tointeger(L, -1);
            cards.push_back(card);

            lua_pop(L, 1);
        }

        assert((int)cards.size() <= 21);
        one.assign(game, cards);

        return 0;
    }

    // must call setHandCards first
    // struct YunChengGame * yuncheng
    int lgetHandCards(lua_State* L) {
        int n = lua_gettop(L);
        if (n != 2) {
            return luaL_error(L, "Illegal param num for yuncheng:getHandCards, required 2, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        int seatId   = (int)lua_tointeger(L, 2);

        LordCards & one = *game->seatHands[seatId];

        lua_newtable(L);
        for (int i=0; i < one.theCards.size(); ++i) {
            lua_pushinteger(L, one.theCards[i]);
            lua_rawseti(L, -2, i+1);
        }

        return 1;
    }

    // struct YunChengGame * yuncheng, cnt1, cnt2, cnt3
    int lsetHandCount(lua_State* L) {
        int n = lua_gettop(L);
        if (n != 3) {
            return luaL_error(L, "Illegal param num for yuncheng:setHandCount, required 3, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        game = game;

        int cnt1 = (int)lua_tointeger(L, 2);
        int cnt2 = (int)lua_tointeger(L, 3);
        int cnt3 = (int)lua_tointeger(L, 4);

        assert(cnt1 <= 21 && cnt2 <= 21 && cnt3 <= 21);

        //        game->seatHands[1].num = cnt1;
        //        game->seatHands[2].num = cnt2;
        //        game->seatHands[3].num = cnt3;
        //
        return 0;
    }

    // input: yuncheng, cards
    int lsortMyCards(lua_State* L) {
        int n = lua_gettop(L);
        if (n != 2) {
            return luaL_error(L, "Illegal param num for yuncheng:sortMyCards, required 2, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        game = game;

        int bomb3[kCard_KindMax] = {0};
        std::vector<int> head;
        std::vector<int> tail;
        int len = (int)luaL_len(L, 2);
        for (int i = 1; i <= len; ++i) {
            lua_rawgeti(L, 2, i);

            int card = (int)lua_tointeger(L, -1);
            if (card >= kCard_Joker1) {
                head.push_back(card);
            } else {
                int val = LordCards::getCardValue(card);
                if (val == kCard_Value3) {
                    int suit = LordCards::getCardSuit(card);
                    assert(bomb3[suit] == 0);
                    bomb3[suit] = card;
                } else {
                    tail.push_back(card);
                }
            }

            lua_pop(L, 1);
        }

        {
            mergeTwoVectors(head, tail);
            for (int i=0; i<kCard_KindMax; ++i) {
                if (bomb3[i] > 0) {
                    head.push_back(bomb3[i]);
                    bomb3[i] = 0;
                }
            }

            std::sort(head.begin(), head.end(), cardGreaterThan);
        }
        assert(head.size() <= 21);

        lua_newtable(L);
        for (int i=0; i < head.size(); ++i) {
            lua_pushinteger(L, head[i]);
            lua_rawseti(L, -2, i+1);
        }

        return 1;
    }

    // must call setHandCards first
    // param 1. struct YunChengGame * yuncheng,
    // param 2. seatId
    // param 3. subset
    int lremoveSubset (lua_State* L) {
        // struct YunChengGame * yuncheng, int lvl, int card, int type
        int n = lua_gettop(L);
        if (n != 2) {
            return luaL_error(L, "Illegal param num for yuncheng:removeSubset, required 2, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        int seatId   = (int)lua_tointeger(L, 2);
        std::vector<int> subset;

        int len = (int)luaL_len(L, 3);
        for (int i = 1; i <= len; ++i) {
            lua_rawgeti(L, 3, i);

            int card = (int)lua_tointeger(L, -1);
            subset.push_back(card);

            lua_pop(L, 1);
        }

        LordCards & one = *game->seatHands[seatId];
        std::vector<int> cards = one.removeSubset(subset);

        lua_newtable(L);
        for (int i=0; i < cards.size(); ++i) {
            lua_pushinteger(L, cards[i]);
            lua_rawseti(L, -2, i+1);
        }

        return 1;
    }

    // param 1. userdata
    // param 2. cards
    int ldebugSnakeInfo(lua_State* L) {
        int n = lua_gettop(L);
        if (n != 2) {
            return luaL_error(L, "Illegal param num for yuncheng:debugSnakeInfo, required 2, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);

        std::vector<int> cards;

        int len = (int)luaL_len(L, 2);
        for (int i = 1; i <= len; ++i) {
            lua_rawgeti(L, 2, i);

            int card = (int)lua_tointeger(L, -1);
            cards.push_back(card);

            lua_pop(L, 1);
        }

        std::string str = game->debugSnakeInfo(cards);

        lua_pushstring(L, str.c_str());
        return 1;
    }

    // 做地主获胜几率
    // input: YunChengGame, cards
    // output: float between [0, 1]
    int lgetWinPossible (lua_State* L) {
        int n = lua_gettop(L);
        if (n != 2) {
            return luaL_error(L, "Illegal param num for yuncheng:getWinPossible, required 2, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        game = game;

        std::vector<int> cards;

        int len = (int)luaL_len(L, 2);
        for (int i = 1; i <= len; ++i) {
            lua_rawgeti(L, 2, i);

            int card = (int)lua_tointeger(L, -1);
            cards.push_back(card);

            lua_pop(L, 1);
        }

        LordCards lord(game, cards);

        float p = lord.winRateIfLord();
        lua_pushnumber(L, p);

        return 1;
    }

    // 必须做地主
    // input: YunChengGame, cards
    // output: true or false
    int lbigEnough (lua_State* L) {
        int n = lua_gettop(L);
        if (n != 2) {
            return luaL_error(L, "Illegal param num for yuncheng:bigEnough, required 2, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        game = game;

        std::vector<int> cards;

        int len = (int)luaL_len(L, 2);
        for (int i = 1; i <= len; ++i) {
            lua_rawgeti(L, 2, i);

            int card = (int)lua_tointeger(L, -1);
            cards.push_back(card);

            lua_pop(L, 1);
        }

        LordCards lord(game, cards);
        bool ret = lord.bigEnough();
        lua_pushboolean(L, ret);

        return 1;
    }

    // 获得牌型
    // input: YunChengGame, cards
    // output: float between [0, 1]
    int lgetNodeType (lua_State* L) {
        int n = lua_gettop(L);
        if (n != 2) {
            return luaL_error(L, "Illegal param num for yuncheng:getNodeType, required 2, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        game = game;

        std::vector<int> cards;

        int len = (int)luaL_len(L, 2);
        for (int i = 1; i <= len; ++i) {
            lua_rawgeti(L, 2, i);

            int card = (int)lua_tointeger(L, -1);
            cards.push_back(card);

            lua_pop(L, 1);
        }

        LordCards lord(game, cards);
        AINode node = lord.typeAndValueFind();

        lua_newtable(L);

        lua_pushstring(L, "cardType");
        lua_pushinteger(L, node.cardType);
        lua_settable(L, -3);

        lua_pushstring(L, "mainNum");
        lua_pushinteger(L, node.mainNum);
        lua_settable(L, -3);

        lua_pushstring(L, "subNum");
        lua_pushinteger(L, node.subNum);
        lua_settable(L, -3);

        lua_pushstring(L, "seralNum");
        lua_pushinteger(L, node.seralNum);
        lua_settable(L, -3);

        lua_pushstring(L, "value");
        lua_pushinteger(L, node.value);
        lua_settable(L, -3);

        return 1;
    }

    // input: game
    int lgetLight(lua_State* L) {
        int n = lua_gettop(L);
        if (n != 1) {
            return luaL_error(L, "Illegal param num for userdata:getLight, required 1, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        long p = (long)(void*)game;

        lua_pushinteger(L, p);

        return 1;
    }

    int do_robotFirstPlay(lua_State* L, struct YunChengGame * game) {
        int n = lua_gettop(L);
        if (n != 1) {
            return luaL_error(L, "Illegal param num for yuncheng:robotFirstPlay, required 1, provided %d", n);
        }

        AutoLock lock;

        AINode lastNode;

        LordCards & one = *game->seatHands[game->curSeatId];
        printf("handCards : %s\n", game->debugSnakeInfo(one.theCards).c_str());

        std::vector<AINode> nodes = one.getNodesGreaterThan(lastNode);
        if (!nodes.empty()) {
            lastNode = nodes[0];
        }

        printf("direct    : %s\n\n", game->debugSnakeInfo(lastNode.cards).c_str());

        if (!lastNode.isValidNode()) {
            printf("can't find a direct valid node!!!\n");
        }

        writeIntArray(L, lastNode.cards);
        return 1;
    }

    int light_robotFirstPlay (lua_State* L) {
        long p = luaL_checkinteger(L, 1);
        struct YunChengGame * game = (struct YunChengGame *)(void *)p;

        return do_robotFirstPlay(L, game);
    }

    // you must call updateSeats first
    // param 1. YunChengGame
    int lrobotFirstPlay (lua_State* L) {
        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        return do_robotFirstPlay(L, game);
    }

    int do_robotFollowCards (lua_State* L, struct YunChengGame * game) {
        int n = lua_gettop(L);
        if (n != 3) {
            return luaL_error(L, "Illegal param num for yuncheng:robotFollowCards, required 1, provided %d", n);
        }

        AutoLock lock;

        int prevSeatId = (int) lua_tointeger(L, 2);
        prevSeatId = prevSeatId;

        std::vector<int> cards;
        readIntArray(L, 3, cards);

        LordCards playerCards(game, cards);
        AINode prevNode = playerCards.typeAndValueFind();
        assert(prevNode.isValidNode());

        LordCards & one = *game->seatHands[game->curSeatId];
        printf("handCards : %s\n", game->debugSnakeInfo(one.theCards).c_str());

        std::vector<AINode> nodes = one.getNodesGreaterThan(prevNode);

        printf("othercards: %s\n", game->debugSnakeInfo(prevNode.cards).c_str());


        if (!nodes.empty()) {
            prevNode = nodes[0];
        } else {
            prevNode.resetNode();
        }

        printf("follow    : %s\n\n", game->debugSnakeInfo(prevNode.cards).c_str());

        if (!prevNode.isValidNode()) {
            prevNode.cards.clear();
        }

        writeIntArray(L, prevNode.cards);
        return 1;
    }

    int light_robotFollowCards (lua_State* L) {
        long p = luaL_checkinteger(L, 1);
        struct YunChengGame * game = (struct YunChengGame *)(void *)p;

        return do_robotFollowCards(L, game);
    }

    // you must call updateSeats first
    // param 1. YunChengGame
    // param 2. prevSeatId
    // param 3. prevCards
    int lrobotFollowCards (lua_State* L) {
        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        return do_robotFollowCards(L, game);
    }

    // param 1. struct YunChengGame *,
    // param 2. selCards
    // param 3? prevCards
    int lcanPlayCards (lua_State* L) {
        int n = lua_gettop(L);
        if (n < 2) {
            return luaL_error(L, "Illegal param num for yuncheng:canPlayCards, at least 2, provided %d", n);
        }

        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        LordCards & handCards = *game->seatHands[game->curSeatId];

        std::vector<int> cards;
        int len = (int)luaL_len(L, 2);
        for (int i = 1; i <= len; ++i) {
            lua_rawgeti(L, 2, i);

            int card = (int)lua_tointeger(L, -1);
            cards.push_back(card);

            lua_pop(L, 1);
        }

        LordCards testCards(game, handCards.theCards);
        std::vector<int> removed = testCards.removeSubset(cards);
        if (removed.size() != cards.size()) {
            lua_pushinteger(L, 107);
            // const.YUNCHENG_ACL_STATUS_NO_YOUR_CARDS
            return 1;
        }

        if (removed.size() == 1 && removed[0] == kCard_Flower) {
            // 不能只打花牌
            lua_pushinteger(L, 103);
            // const.YUNCHENG_ACL_STATUS_NOT_VALID_TYPE
            return 1;
        }


        if (len <= 0) {
            lua_pushinteger(L, 102);
            // const.YUNCHENG_ACL_STATUS_NO_SELECT_CARDS                       =   102;  -- 没有选择任何牌
            return 1;
        }

        LordCards playerCards(game, cards);
        AINode node = playerCards.typeAndValueFind();
        if (!node.isValidNode()) {
            lua_pushinteger(L, 103);
            // const.YUNCHENG_ACL_STATUS_NOT_VALID_TYPE                        =   103;  -- 不能组成有效牌型
            return 1;
        }

        AINode prevNode;
        if (n == 3 && LUA_TNIL != lua_type(L, 3)) {
            cards.clear();
            int len = (int)luaL_len(L, 3);
            for (int i = 1; i <= len; ++i) {
                lua_rawgeti(L, 3, i);

                int card = (int)lua_tointeger(L, -1);
                cards.push_back(card);

                lua_pop(L, 1);
            }

            LordCards lordCards(game, cards);
            prevNode = lordCards.typeAndValueFind();
            assert(prevNode.isValidNode());
        }

        if (prevNode.isValidNode()) {
            int retCode = 0;
            if (!prevNode.isStrictLessThan(node)) {
                retCode = 105;
                // const.YUNCHENG_ACL_STATUS_NOT_BIGGER                            =   105;  -- 打不过别人的牌
            }

            if (retCode != 0) {
                lua_pushinteger(L, retCode);
                return 1;
            }
        }

        lua_pushinteger(L, 0);
        writeIntArray(L, node.cards);
        return 2;
    }

    int do_getDirectPrompts (lua_State* L, struct YunChengGame * game) {
        int n = lua_gettop(L);
        if (n != 1) {
            return luaL_error(L, "Illegal param num for yuncheng:getDirectPrompts, required 1, provided %d", n);
        }

        AutoLock lock;

        LordCards & playerCards = *game->seatHands[game->curSeatId];

        AINode none;
        std::vector<AINode > prompts = playerCards.getNodesGreaterThan(none);

        lua_newtable(L);
        for (int i=0; i < prompts.size(); ++i) {
            writeIntArray(L, prompts[i].cards);

            lua_rawseti(L, -2, i+1);
        }

        return 1;
    }

    int light_getDirectPrompts (lua_State* L) {
        long p = luaL_checkinteger(L, 1);
        struct YunChengGame * game = (struct YunChengGame *)(void *)p;

        return do_getDirectPrompts(L, game);
    }

    // call updateSeats first
    // return {{cards}, {}, ...}
    int lgetDirectPrompts (lua_State* L) {
        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        return do_getDirectPrompts(L, game);
    }

    int do_getFollowPrompts (lua_State* L, struct YunChengGame * game) {
        int n = lua_gettop(L);
        if (n != 2) {
            return luaL_error(L, "Illegal param num for yuncheng:getFollowPrompts, required 2, provided %d", n);
        }

        AutoLock lock;

        std::vector<int> cards;
        readIntArray(L, 2, cards);

        // test
        //        cards.clear();
        //        cards.push_back(4);
        // end test

        LordCards prevLords(game, cards);
        AINode prevNode = prevLords.typeAndValueFind();
        assert(prevNode.isValidNode());

        LordCards & playerCards = *game->seatHands[game->curSeatId];

        // test
        //        {
        //            int arr[] = {55, 2, 14, 13, 39, 10, 23, 7, 33, 46, 45, 44, 31, 18, 5, 43, 29};
        //            int len = sizeof(arr)/sizeof(arr[0]);
        //            playerCards.theCards.assign(arr, arr + len);
        //        }
        //end test

        std::vector<AINode > prompts = playerCards.getNodesGreaterThan(prevNode);
        lua_newtable(L);
        for (int i=0; i < prompts.size(); ++i) {
            writeIntArray(L, prompts[i].cards);

            lua_rawseti(L, -2, i+1);
        }

        return 1;
    }

    int light_getFollowPrompts (lua_State* L) {
        long p = luaL_checkinteger(L, 1);
        struct YunChengGame * game = (struct YunChengGame *)(void *)p;

        return do_getFollowPrompts(L, game);
    }

    // call updateSeats first
    // param 1. game
    // param 2. prevCards
    // return {{cards}, {}, ...}
    int lgetFollowPrompts (lua_State* L) {
        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        return do_getFollowPrompts(L, game);
    }

    int do_calcPowerValue (lua_State* L, struct YunChengGame * game) {
        int n = lua_gettop(L);
        if (n != 2) {
            return luaL_error(L, "Illegal param num for yuncheng:calcPowerValue, required 2, provided %d", n);
        }

        AutoLock lock;

        std::vector<int> cards;
        readIntArray(L, 2, cards);

        LordCards lord(game, cards);
        lord.calcPowerValue(true);

        lua_newtable(L);
        return 1;
    }

    int light_calcPowerValue (lua_State* L) {
        long p = luaL_checkinteger(L, 1);
        struct YunChengGame * game = (struct YunChengGame *)(void *)p;

        return do_calcPowerValue(L, game);
    }

    int lcalcPowerValue (lua_State* L) {
        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);
        return do_calcPowerValue(L, game);
    }

    static int gc_yuncheng(lua_State *L) {
        struct YunChengGame * game = (struct YunChengGame *)luaL_checkudata(L, 1, pMetaTableName);

        delete game->powerOfCards;
        game->powerOfCards = 0;

        for (int i=0; i<=kMaxPlayers; ++i) {
            delete game->seatHands[i];
            game->seatHands[i] = NULL;
        }

        return 0;
    }

#pragma mark - Library Settings
    static const struct luaL_Reg yunchenglib[] =
    {
        {"new",             new_yuncheng},
        {NULL, NULL}
    };

    static const struct luaL_Reg yunchengMeta[] =
    {
        // 环境设置
        {"updateSeats",             lupdateSeats},
        {"addHistCards",            laddHistCards},
        {"setHandCards",            lsetHandCards},
        {"getHandCards",            lgetHandCards},
        {"setHandCount",            lsetHandCount},

        // 牌面排序
        {"sortMyCards",         lsortMyCards},
        {"removeSubset",        lremoveSubset},

        {"debugSnakeInfo",      ldebugSnakeInfo},

        // 叫地主
        {"getWinPossible",      lgetWinPossible},
        {"bigEnough",           lbigEnough},

        // 出牌选择
        {"getNodeType",         lgetNodeType},
        
        {"getLight",            lgetLight},

        {"robotFirstPlay",      lrobotFirstPlay},
        {"robotFollowCards",    lrobotFollowCards},

        {"canPlayCards",        lcanPlayCards},

        {"getDirectPrompts",    lgetDirectPrompts},
        {"getFollowPrompts",    lgetFollowPrompts},

        {"calcPowerValue",      lcalcPowerValue},

        {NULL, NULL}
    };

    int luaopen_YunCheng (lua_State* L)
    {
        // 创建一个新的元表
        luaL_newmetatable(L, pMetaTableName);

        // 元表.__index = 元表
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");

        lua_pushcfunction(L, gc_yuncheng);
        lua_setfield(L, -2, "__gc");

        luaL_register(L, NULL, yunchengMeta);
        luaL_register(L, "YunCheng", yunchenglib);

        return 1;
    }
}



