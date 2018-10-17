local class = class("ChatLayer")
class.__index = class

local Constants = require "Constants"
local SoundApp  = require "SoundApp"
local Settings  = require "Settings"

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
    cc.SpriteFrameCache:getInstance():addSpriteFrames("buttons.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("propertylayer.plist")
    cc.SpriteFrameCache:getInstance():addSpriteFrames("emoji.plist")

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

    local listenner = cc.EventListenerTouchOneByOne:create()
    listenner:setSwallowTouches(true)
    listenner:registerScriptHandler(function(touch, event)
            if self.m_chatBoxBg then
                local rect = self.m_chatBoxBg:getBoundingBox()
                local pos = self:convertToNodeSpace(touch:getLocation())
                if cc.rectContainsPoint(rect, pos) then
                    self.m_touchStartPos = pos
                else
                    self:closeChat()
                end

                return true
            end

        end, cc.Handler.EVENT_TOUCH_BEGAN )

    listenner:registerScriptHandler(function(touch, event)
        if self.m_curTab == self.TabEmoji and self.m_emojiLayer then
            local pos = self:convertToNodeSpace(touch:getLocation())
            local oldPos = self:convertToNodeSpace(touch:getPreviousLocation())
            local offset_y = pos.y - oldPos.y
            local curLyPosY = self.m_emojiLayer:getPositionY()
            curLyPosY = cc.clampf(curLyPosY + offset_y, self.m_minY, self.m_maxY)
            self.m_emojiLayer:setPositionY(curLyPosY)
        end

    end, cc.Handler.EVENT_TOUCH_MOVED)

    listenner:registerScriptHandler(function(touch, event)
        if self.m_curTab == self.TabEmoji and self.m_emojiLayer then
            local pos = self:convertToNodeSpace(touch:getLocation())
            local dist = cc.pDistanceSQ(pos, self.m_touchStartPos)
            if dist < 100 then
                self:procEmojiTouch(touch)
            end
        end
    end, cc.Handler.EVENT_TOUCH_ENDED)

    local eventDispatcher = self:getEventDispatcher()
    eventDispatcher:addEventListenerWithSceneGraphPriority(listenner, self)

    self.delegate  = delegate

    self.TabOften = 1
    self.TabHistory = 2
    self.TabEmoji = 3

    self.histroyTalk = {}

    return self
end

function class:onEnter()
end

function class:onExit()
end

function class:initChatBoxBg()
    local winSize = display.size

    local bg1 = ccui.Scale9Sprite:createWithSpriteFrameName("chat_bg1.png", cc.rect(30,30,4,4))
    bg1:setContentSize(cc.size(620, 740))
       :addTo(self)

    self.m_chatBoxBg = bg1

    local bg2 = ccui.Scale9Sprite:createWithSpriteFrameName("chat_bg2.png", cc.rect(30,30,4,4))
    bg2:setContentSize(cc.size(600, 720))
        :addTo(bg1, -1)
        :setAnchorPoint(0, 0)
        :setPosition(cc.p(10, 10))

    -- 按钮: 常用语、表情、历史
    local menu = cc.Menu:create()
    menu:addTo(bg1)
    menu:setPosition(cc.p(0,0))

    local btnDefs = {
        {"chat_often",  "clickOften",   cc.p(30,  640),  self.TabOften},
        {"chat_emo",    "clickEmoji",   cc.p(220,  640), self.TabEmoji},
        {"chat_his",    "clickHistory", cc.p(410,  640), self.TabHistory}
    }

    self.m_buttons = {}
    for _, one in ipairs(btnDefs) do
        local item = Constants.getMenuItem(one[1])

        local funcName = one[2]
        item:registerScriptTapHandler(function() self[funcName](self, item) end)
        item:addTo(menu)
        item:setAnchorPoint(cc.p(0,0))
        item:setPosition(one[3])

        self.m_buttons[one[4]] = item
    end
end

function class:showChat()
    local winSize = display.size
    if not self.m_chatBoxBg then
        self:initChatBoxBg()
    end

    self:showOften()
    self.m_chatBoxBg:setAnchorPoint(1, 0.5)
                    :setPosition(cc.p(winSize.width - 10, winSize.height * 0.5))
                    :setScale(0)
                    :runAction(cc.EaseElasticOut:create(cc.ScaleTo:create(0.3, 1), 0.8))

    self.m_curTab = self.TabOften
    self.m_buttons[self.TabOften]:selected()
end

function class:closeChat()
    SoundApp.playEffect("sounds/main/click.mp3")
    if self.m_chatBoxBg and self.m_chatBoxBg:getNumberOfRunningActions() == 0 then
        self.m_chatBoxBg:runAction(cc.Sequence:create(cc.ScaleTo:create(0.1, 0),
                                                      cc.CallFunc:create(function()
                                                            self.m_chatBoxBg:removeFromParent()
                                                            self.m_chatBoxBg = nil
                                                            self.m_curLayer = nil
                                                            self.m_emojiLayer = nil
                                                        end)))

    end
end

function class:clickOften(item)
    SoundApp.playEffect("sounds/main/click.mp3")
    self:switchToTab(self.TabOften)
end

function class:clickHistory(item)
    SoundApp.playEffect("sounds/main/click.mp3")
    self:switchToTab(self.TabHistory)
end

function class:clickEmoji(item)
    SoundApp.playEffect("sounds/main/click.mp3")
    self:switchToTab(self.TabEmoji)
end

function class:switchToTab(tab)
    if self.m_curTab ~= tab then
        self.m_buttons[self.m_curTab]:unselected()
        self.m_curTab = tab

        if self.m_curTab == self.TabOften then
            self:showOften()
        elseif self.m_curTab == self.TabHistory then
            self:showHistory()
        elseif self.m_curTab == self.TabEmoji then
            self:showEmoji()
        end
    end

    self.m_buttons[tab]:selected()
end

function class:cleanLayer()
    if self.m_curLayer then
        self.m_curLayer:removeAllChildren()
        self.m_emojiLayer = nil
    else
        self.m_curLayer = cc.Node:create()
        self.m_chatBoxBg:addChild(self.m_curLayer)
    end
end

function class:showOften()
    self:cleanLayer()

    local view = cc.TableView:create(cc.size(560, 530))
    view:setDirection(cc.SCROLLVIEW_DIRECTION_VERTICAL)
    view:setVerticalFillOrder(cc.TABLEVIEW_FILL_TOPDOWN)
    view:setAnchorPoint(0, 0)
    view:setPosition(cc.p(30, 100))
    view:setDelegate()
    view:addTo(self.m_curLayer)

    view:registerScriptHandler(function(table) return self:numberOfCellsInTableView(table) end,cc.NUMBER_OF_CELLS_IN_TABLEVIEW)
    view:registerScriptHandler(function() self:scrollViewDidScroll(view) end,cc.SCROLLVIEW_SCRIPT_SCROLL)
    view:registerScriptHandler(function(table, cell) self:tableCellTouched(table,cell) end, cc.TABLECELL_TOUCHED)
    view:registerScriptHandler(function(table, idx) return self:cellSizeForTable(table, idx) end, cc.TABLECELL_SIZE_FOR_INDEX)
    view:registerScriptHandler(function(table, idx) return self:tableCellAtIndex(table, idx) end, cc.TABLECELL_SIZE_AT_INDEX)
    view:reloadData()

    self:showEditBox()
end

function class:clickSend()
    local agent = self.delegate.agent

    if self.edit then
        local str = self.edit:getText()
        if str and str ~= "" then
            agent:sendMsgOptions(str)
            self.edit:setText("")
        end
    end
end

function class:showHistory()
    self:cleanLayer()

    local labelLayer = self:drawChatHist()
    if labelLayer == nil then
        return
    end

    local scroll = cc.ScrollView:create()
    scroll:setViewSize(cc.size(560, 530))
    scroll:setDirection(cc.SCROLLVIEW_DIRECTION_VERTICAL)
    self.m_curLayer:addChild(scroll)
    scroll:setPosition(30, 100)

    local size = labelLayer:getContentSize()

    local containerLayer = cc.Node:create()
    labelLayer:addTo(containerLayer)
              :setPosition(0, math.max(size.height, 530))

    containerLayer:setContentSize(560, math.max(size.height, 530))

    scroll:setContainer(containerLayer)

    self:showEditBox()
end

function class:showEmoji()
    self:cleanLayer()

    self.m_emojiLayer = self:drawEmojis()
    if self.m_emojiLayer then
        local sten = ccui.Scale9Sprite:createWithSpriteFrameName("chat_bg3.png")
        sten:setContentSize(cc.size(560, 630))
        local clipper = cc.ClippingNode:create()
        clipper:addTo(self.m_curLayer)
               :setStencil(sten)
               :setPosition(310, 325)


        local size = self.m_emojiLayer:getContentSize()
        self.m_minY = 315
        if size.height > 630 then
            self.m_maxY = self.m_minY + size.height - 630
        else
            self.m_maxY = self.m_minY
        end

        self.m_emojiLayer:addTo(clipper)
                         :setPosition(-280, self.m_minY)
    end
end

function class:drawEmojis()
    local emojiLayer = cc.Node:create()
    local emojiSize = 140
    local areaWidth = 560
    local height = 0

    self.m_emojiTbl = {}

    local i = 1
    local x, y = 0, -15
    while i <= 32 do
        local strPath = string.format("emoji_%d.png", i)
        local spEmoji = cc.Sprite:createWithSpriteFrameName(strPath)
        if spEmoji then
            spEmoji:addTo(emojiLayer)
                   :setAnchorPoint(0, 1)
                   :setPosition(x, y)
                   :setScale(0.75)

            spEmoji.emoji = i

            table.insert(self.m_emojiTbl, spEmoji)

            height = -(y - emojiSize)

            x = x + emojiSize
            if x >= areaWidth then
                x = 0
                y = y - emojiSize - 18
            end

            i = i + 1
        else
            break
        end
    end

    emojiLayer:setContentSize(560, height)

    if i == 1 then
        return nil
    else
        return emojiLayer
    end
end

function class:procEmojiTouch(touch)
    if not self.m_emojiLayer
        or self.m_sending then
        return
    end

    local pos = self.m_emojiLayer:convertToNodeSpace(touch:getLocation())

    for _,one in ipairs(self.m_emojiTbl) do
        local rect = one:getBoundingBox()
        if cc.rectContainsPoint(rect, pos) then
            SoundApp.playEffect("sounds/main/click.mp3")

            local str = string.format("emoji_%d", one.emoji)
            local agent = self.delegate.agent
            agent:sendMsgOptions(str)

            self.m_sending = true
            self:runAction(cc.Sequence:create(cc.DelayTime:create(2),
                                              cc.CallFunc:create(function()
                                                    self.m_sending = nil
                                                  end)))
            break
        end
    end
end

function class:showEditBox()
    local bgSend = Constants.get9Sprite("chat_bg4.png", cc.size(558, 60), cc.p(30, 30), self.m_curLayer)
    bgSend:setLocalZOrder(Constants.kLayerBack)
        :setAnchorPoint(0,0)

    local editBox = ccui.EditBox:create(cc.size(440, 60), "bg_sheer.png", 1)
    bgSend:addChild(editBox)

    editBox:setFont(Constants.kNormalFontName, 36)
    editBox:setPlaceholderFont(Constants.kNormalFontName, 36)
    editBox:setAnchorPoint(0,0)
    editBox:setPosition(cc.p(0, 0))
    editBox:setInputMode(6)
    editBox:setInputFlag(2)
    editBox:setMaxLength(50)
    editBox:setPlaceholderFontColor(cc.c3b(255, 255, 255))
    --editBox:setPlaceHolder(Settings.getUTF8LocaleString("请输入信息"))
    --editBox:setText("请输入信息")
    editBox:setReturnType(1)
    self.edit = editBox

    -- 发送按钮
    local menu = cc.Menu:create()
    menu:addTo(self.m_curLayer,Constants.kLayerMenu)
    menu:setPosition(cc.p(0,0))

    local item = Constants.getMenuItem("chat_send")

    item:registerScriptTapHandler(function() self:clickSend() end)
    item:addTo(menu)
    item:setAnchorPoint(cc.p(0,0))
    item:setPosition(475, 35)
end

function class:drawChatHist()
    local chatHist = self.histroyTalk
    if #chatHist <= 0 then
        return nil
    end

    local labelLayer = cc.Node:create()
    local height = 0
    for k,one in ipairs(chatHist) do
        local x, anch_x = 0, 0

        if one.seatId == self.delegate:GetSelfSeatId() then
            x = 560
            anch_x = 1
        end

        local strNameTime = one.nameTime
        local lbTxt = cc.Label:createWithSystemFont(strNameTime, Constants.kNormalFontName, 32)
        lbTxt:addTo(labelLayer)
             :setAnchorPoint(anch_x,1)
             :setPosition(x, -height)
             :setColor(cc.c3b(230, 134, 0))
        local size = lbTxt:getContentSize()
        height = height + size.height

        lbTxt = cc.Label:createWithSystemFont(one.chatText, Constants.kNormalFontName, 32)
        lbTxt:addTo(labelLayer)
             :setAnchorPoint(anch_x,1)
             :setPosition(x, -height)
             :setColor(cc.BLACK)

        local size = lbTxt:getContentSize()
        if size.width > 560 then
            lbTxt:setWidth(560)
            size = lbTxt:getContentSize()
            height = height + size.height
        else
            height = height + size.height
        end
    end

    labelLayer:setContentSize(560, height)
    return labelLayer
end

function class:updateHistory(chatInfo)
    local agent = self.delegate.agent

    local seatId = 0
    local users = agent.tableInfo.playerUsers

    users:forEach(function (sid, uid)
        if chatInfo.speekerId == uid then
            seatId = sid
            return true
        end
    end)

    if (seatId == 0) then return end

    local one = {}
    one.seatId = seatId

    local strTime = os.date("%X")
    local name = chatInfo.speakerNick and chatInfo.speakerNick or "系统通知"
    one.nameTime = string.format("%s(%s)", name, strTime)

    one.chatText = chatInfo.chatText
    table.insert(self.histroyTalk, one)
end

function class:scrollViewDidScroll(view)
end

function class:tableCellTouched(table, cell)
    if self.m_sending then
        return
    end

    local str = cell.lbTxt:getString()
    local agent = self.delegate.agent
    if str and str ~= "" then
        agent:sendMsgOptions(str)

        self.m_sending = true
        self:runAction(cc.Sequence:create(cc.DelayTime:create(2),
                                          cc.CallFunc:create(function()
                                                self.m_sending = nil
                                              end)))
    end
end

function class:cellSizeForTable(table, idx)
    return 560, 80
end

function class:tableCellAtIndex(table, idx)
    local cell = table:dequeueCell()
    if nil == cell then
        cell = cc.TableViewCell:new()

        local bg3 = ccui.Scale9Sprite:createWithSpriteFrameName("chat_bg3.png")
        bg3:setContentSize(cc.size(560, 70))
           :addTo(cell, -1)
           :setAnchorPoint(0, 0)
           :setPosition(cc.p(0, 0))

        local lbTxt = cc.Label:createWithSystemFont("", Constants.kNormalFontName, 32)
        bg3:addChild(lbTxt)
        lbTxt:setAnchorPoint(0,0.5)
             :setPosition(20, 35)
             :setColor(cc.BLACK)
        cell.lbTxt = lbTxt
    end

    local fmt = string.format("msgChatMsg%02d", idx + 1)
    local str = getUTF8LocaleString(fmt)
    cell.lbTxt:setString(str)

    return cell
end

function class:numberOfCellsInTableView(table)
    return 12
end

return class
