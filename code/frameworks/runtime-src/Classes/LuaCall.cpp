#include "LuaCall.h"
#include "cocos2d.h"
#include "Settings.h"

#include "scripting/lua-bindings/manual/LuaBasicConversions.h"
#include "scripting/lua-bindings/manual/CCLuaEngine.h"

#include "LuaYunCheng.h"
#include "luaproc.h"

#include "LuaSkynet.h"

#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
//ANDROID_HEADER_START
//ANDROID_HEADER_END
#else
//APPLE_HEADER_START
//APPLE_HEADER_END
#endif


USING_NS_CC;

extern "C"{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#include "pbc-lua.h"

#ifdef __cplusplus
    extern "C" {
#endif
#include "tolua++.h"
#ifdef __cplusplus
    }
#endif


    void execLuaFunc(const char * luaFunc)
    {
        lua_State * L = cocos2d::LuaEngine::getInstance()->getLuaStack()->getLuaState();

        //注册C++函数
        // lua_register(L,"clib",clib);

        //调用函数
        lua_getglobal(L, luaFunc);

        lua_pushboolean(L, 1);

        //运行函数并把结果压入栈
        lua_pcall(L,
                  1,    // argument count
                  0,    // return value count
                  0);

    }

    static int reg_MessageBox(lua_State * L) {
        int n = lua_gettop(L);
        if (n != 2) {
            return luaL_error(L, "MessageBox: must 2 argument string");
        }

        const char * msg = lua_tostring(L, 1);
        const char * tit = lua_tostring(L, 2);

        MessageBox(msg, tit);

        return 0;
    }

    static int reg_getUTF8LocaleString(lua_State * L) {
        int n = lua_gettop(L);
        if (n != 1) {
            return luaL_error(L, "getUTF8LocaleString: must 1 argument string");
        }

        const char * key = lua_tostring(L, 1);
        std::string ret = Settings::getUTF8LocaleString(key);

        lua_pushstring(L, ret.c_str());

        return 1;
    }

    void registerLuaCFuncs() {
        lua_State * L = cocos2d::LuaEngine::getInstance()->getLuaStack()->getLuaState();

        luaopen_YunCheng(L);
        luaopen_luaproc(L);

#if (CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID)
        //ANDROID_LIB_START
        //ANDROID_LIB_END
#else // Apple iOS/MacOS
        //APPLE_LIB_START
        //APPLE_LIB_END
#endif

        register_skynet_libs(L);

        lua_register(L, "getUTF8LocaleString", reg_getUTF8LocaleString);
        lua_register(L, "MessageBox", reg_MessageBox);

        luaL_requiref(L, "protobuf.c", luaopen_protobuf_c, 1);
        lua_pop(L, 1);  /* remove lib */
    }

}
