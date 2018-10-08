#ifndef __Lua_Skynet_H__
#define __Lua_Skynet_H__

extern "C"{
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

    extern void register_skynet_libs(lua_State* L);
}


#endif
