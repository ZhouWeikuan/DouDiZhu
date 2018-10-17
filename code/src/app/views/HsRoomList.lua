local class = class("HsRoomList")
class.__index = class

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"

local packetHelper  = require "PacketHelper"
local protoTypes    = require "ProtoTypes"
local const         = require "Const_YunCheng"

function class.extend(target)
    local t = tolua.getpeer(target)
    if not t then
        t = {}
        tolua.setpeer(target, t)
    end
    setmetatable(t, class)
    return target
end

function class.create(delegate)
    cc.SpriteFrameCache:getInstance():addSpriteFrames("hallscene.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("buttons.plist")

    local self = class.extend(cc.Layer:create())
    if nil ~= self then
        local function onNodeEvent(event)
            if "enter" == event then
                self:onEnter()
            elseif "exit" == event then
                self:onExit()
            end
        end
        self:registerScriptHandler(onNodeEvent)
    end

    self.delegate = delegate

    self:initBg()

    return self
end

function class:onEnter()
end

function class:onExit()
end

function class:initBg()
    local winSize = display.size

    local bg = Constants.get9Sprite("bg_hs_info.png", cc.size(574,734), cc.p(3, 190), self)
    bg:setAnchorPoint(0, 0)
    self.m_bg = bg

    local bgSize = bg:getContentSize()
    local bgTitle = Constants.get9Sprite("bg_hs_infotitle.png", cc.size(540,70),
                                cc.p(bgSize.width * 0.5, bgSize.height -27), bg)
    bgTitle:setAnchorPoint(0.5, 1)

    Constants.getSprite("hs_msn.png", cc.p(152, 36), bgTitle)
    Constants.getSprite("hs_txt_roomlist.png", cc.p(304, 34), bgTitle)

    local bgTxt = Constants.get9Sprite("bg_hs_infoitem.png", cc.size(500, 40),
                                cc.p(bgSize.width * 0.5, 575), bg)
    bgTxt:setOpacity(178)
    Constants.getLabel("房号", Constants.kBoldFontNamePF, 28, cc.p(124,20), bgTxt)
    Constants.getLabel("底分", Constants.kBoldFontNamePF, 28, cc.p(203,20), bgTxt)
    Constants.getLabel("局数", Constants.kBoldFontNamePF, 28, cc.p(276,20), bgTxt)
    Constants.getLabel("房主", Constants.kBoldFontNamePF, 28, cc.p(397,20), bgTxt)

    local ndInfo = display.newNode()
    bg:addChild(ndInfo)
    self.m_ndInfo = ndInfo
end

function class:repaintInfo()
    local ndInfo = self.m_ndInfo
    ndInfo:removeAllChildren()

    self:updateRoomListData()
    if self.m_count <= 0 then return end

    local view = cc.TableView:create(cc.size(540, 500))
    view:setDirection(cc.SCROLLVIEW_DIRECTION_VERTICAL)
    view:setVerticalFillOrder(cc.TABLEVIEW_FILL_TOPDOWN)
    view:setAnchorPoint(0, 0)
    view:setPosition(cc.p(17, 45))
    view:setDelegate()
    view:addTo(ndInfo)

    view:registerScriptHandler(function(table) return self:numberOfCellsInTableView(table) end,cc.NUMBER_OF_CELLS_IN_TABLEVIEW)
    view:registerScriptHandler(function() self:scrollViewDidScroll(view) end,cc.SCROLLVIEW_SCRIPT_SCROLL)
    view:registerScriptHandler(function(table, cell) self:tableCellTouched(table,cell) end, cc.TABLECELL_TOUCHED)
    view:registerScriptHandler(function(table, idx) return self:cellSizeForTable(table, idx) end, cc.TABLECELL_SIZE_FOR_INDEX)
    view:registerScriptHandler(function(table, idx) return self:tableCellAtIndex(table, idx) end, cc.TABLECELL_SIZE_AT_INDEX)
    view:reloadData()
end

function class:updateRoomListData()
    self.m_roomList = Settings.getRoomList()
    local count = #self.m_roomList
    local i = 1
    local outOfTime = 8 * 3600

    while count > 0 and i <= count do
        local roomInfo = self.m_roomList[i]
        local openTime = roomInfo.openTime or 0

        if skynet.time() - openTime > outOfTime then
            table.remove(self.m_roomList, i)
            count = count - 1
        else
            i = i + 1
        end
    end

    Settings.setRoomList(self.m_roomList)

    self.m_count = math.min(#self.m_roomList, 10)
end

function class:scrollViewDidScroll(view)
end

function class:tableCellTouched(table, cell)
    SoundApp.playEffect("sounds/main/click.mp3")

    local idx = cell:getIdx()
    local info = self.m_roomList[math.floor(idx+1)]
    if info then
    	self.m_roomId = info.roomId

        local roomInfo = {}
        roomInfo.ownerCode  = self.delegate.userInfo.FUserCode
        roomInfo.roomId     = info.roomId
        local packet  = packetHelper:encodeMsg("CGGame.RoomInfo", roomInfo)

        self.delegate.agent:sendRoomOptions(protoTypes.CGGAME_PROTO_SUBTYPE_JOIN, packet)
    end
end

function class:cellSizeForTable(table, idx)
    return 540, 100
end

function class:tableCellAtIndex(table, idx)
    local cell = table:cellAtIndex(idx)
    if not cell then
        cell = cc.TableViewCell:new()

        local bgCell = Constants.get9Sprite("bg_hs_infoitem.png", cc.size(500, 80),
                                cc.p(270, 50), cell)
        bgCell:setOpacity(114)

        -- index
        local onenumberBg = Constants.getSprite("bg_table_idx.png", cc.p(38, 40), bgCell)
        onenumberBg:setScale(0.6)
        local strIdx = string.format("%d", math.floor(idx+1))
        local lbIdx = Constants.getLabel(strIdx, Constants.kBoldFontNamePF, 72, cc.p(56,56), onenumberBg)
        lbIdx:enableOutline(cc.c4b(0x66, 0x66, 0x66, 255), 5)

        local info = self.m_roomList[math.floor(idx+1)]
        if info then
            local roomDetails = info.roomDetails

            -- roomid
            local strRoomId = string.format("%d", info.roomId)
            local lb = Constants.getLabel(strRoomId, Constants.kBoldFontNamePF, 28, cc.p(124,56), bgCell)
            lb:setColor(cc.c3b(255, 220, 0))

            -- bottomScore
            local strBtmScore = string.format("%d", roomDetails.bottomScore or 1)
            lb = Constants.getLabel(strBtmScore, Constants.kBoldFontNamePF, 28, cc.p(203,56), bgCell)
            lb:setColor(cc.c3b(255, 220, 0))

            -- passcount
            local strPassCnt = string.format("%d", info.passCount or 0)
            lb = Constants.getLabel(strPassCnt, Constants.kBoldFontNamePF, 28, cc.p(276,56), bgCell)
            lb:setColor(cc.c3b(255, 220, 0))

            -- owner
            lb = Constants.getLabel(info.ownerName or "", Constants.kBoldFontNamePF, 28, cc.p(397,56), bgCell)
            lb:setColor(cc.c3b(255, 220, 0))

            -- 创建时间
            Constants.getLabel("创建时间", Constants.kBoldFontNamePF, 28, cc.p(130,18), bgCell)
            local strTime = os.date("%Y-%m-%d %H:%M:%S", info.openTime or 0)
            lb = Constants.getLabel(strTime, Constants.kBoldFontNamePF, 28, cc.p(490,18), bgCell)
            lb:setColor(cc.c3b(255, 220, 0))
              :setAnchorPoint(1, 0.5)
        end
    end

    return cell
end

function class:numberOfCellsInTableView(table)
    return self.m_count
end

function class:getRoomId()
	return self.m_roomId
end

function class:clearRoomId()
	self.m_roomId = nil
end

return class
