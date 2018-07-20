#ifndef _LUA_LUAPROC_H_
#define _LUA_LUAPROC_H_

#ifdef __cplusplus
extern "C" {
#endif
#include "tolua++.h"
    
    LUALIB_API int luaopen_luaproc( lua_State *L );
    
#ifdef __cplusplus
}
#endif


#endif
