
#include "scripting/lua-bindings/manual/network/lua_extensions.h"

#if __cplusplus
extern "C" {
#endif
// socket
#include "luasocket/luasocket.h"
#include "luasocket/luasocket_scripts.h"
#include "luasocket/mime.h"

static luaL_Reg luax_exts[] = {
    {"socket.core", luaopen_socket_core},
    {"mime.core", luaopen_mime_core},
    {NULL, NULL}
};

void luaopen_lua_extensions(lua_State *L)
{
    // load extensions
    luaL_Reg* lib = luax_exts;
    for (; lib->func; lib++)
    {
        luaL_requiref(L, lib->name, lib->func, 1);
        lua_pop(L, 1);  /* remove lib */
    }

    luaopen_luasocket_scripts(L);
}

#if __cplusplus
} // extern "C"
#endif
