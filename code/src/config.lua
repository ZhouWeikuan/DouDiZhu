
-- 0 - disable debug info, 1 - less debug info, 2 - verbose debug info
DEBUG = 1

-- use framework, will disable all deprecated API, false - use legacy API
CC_USE_FRAMEWORK = true

-- show FPS on screen
CC_SHOW_FPS = false

-- disable create unexpected global variable
CC_DISABLE_GLOBAL = true

-- for module display
CC_DESIGN_RESOLUTION = {
    width = 1920,
    height = 1080,
    autoscale = "SHOW_ALL",
    background = "Default-Landscape.png",
    backgroundAngle = 0,

    callback = function(framesize)
        local ratio = math.max(framesize.width, framesize.height) / math.min(framesize.width, framesize.height)
        if ratio <= 1.4 then
            -- iPad 768*1024(1536*2048) is 4:3 screen
            return {
                width = 2048,
                height= 1536,
                autoscale = "SHOW_ALL",
                background = "Default-Landscape.png",
                backgroundAngle = 0,
            }
        end
        return CC_DESIGN_RESOLUTION
    end
}
