LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := cocos2dlua_shared

LOCAL_MODULE_FILENAME := libcocos2dlua

Protobuf_Path := ../../../../../3rd/protobuf

LOCAL_SRC_FILES := \
../../../Classes/AppDelegate.cpp \
$(Protobuf_Path)/alloc.c \
$(Protobuf_Path)/array.c \
$(Protobuf_Path)/bootstrap.c \
$(Protobuf_Path)/context.c \
$(Protobuf_Path)/decode.c \
$(Protobuf_Path)/map.c \
$(Protobuf_Path)/pattern.c \
$(Protobuf_Path)/pbc-lua.c \
$(Protobuf_Path)/proto.c \
$(Protobuf_Path)/register.c \
$(Protobuf_Path)/rmessage.c \
$(Protobuf_Path)/stringpool.c \
$(Protobuf_Path)/varint.c \
$(Protobuf_Path)/wmessage.c \
hellolua/main.cpp

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../../../Classes \
					$(LOCAL_PATH)/$(Protobuf_Path)

# _COCOS_HEADER_ANDROID_BEGIN
# _COCOS_HEADER_ANDROID_END

LOCAL_STATIC_LIBRARIES := cocos2d_lua_static
LOCAL_STATIC_LIBRARIES += cocos_ui_static
LOCAL_STATIC_LIBRARIES += cocosdenshion_static
LOCAL_STATIC_LIBRARIES += cocos_extension_static

# _COCOS_LIB_ANDROID_BEGIN
# _COCOS_LIB_ANDROID_END

include $(BUILD_SHARED_LIBRARY)

$(call import-module,scripting/lua-bindings/proj.android)

# _COCOS_LIB_IMPORT_ANDROID_BEGIN
# _COCOS_LIB_IMPORT_ANDROID_END
