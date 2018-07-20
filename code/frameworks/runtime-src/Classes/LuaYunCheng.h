#ifndef __LUACOCOS2D_YUNCHENG_H__
#define __LUACOCOS2D_YUNCHENG_H__

#ifdef __cplusplus
extern "C" {
#endif
#include "tolua++.h"

    int light_robotFirstPlay (lua_State* L);
    int light_robotFollowCards (lua_State* L);

    int light_getDirectPrompts (lua_State* L);
    int light_getFollowPrompts (lua_State* L);

    int light_calcPowerValue (lua_State* L);

    int luaopen_YunCheng(lua_State* tolua_S);


#ifdef __cplusplus
}
#endif


#endif
