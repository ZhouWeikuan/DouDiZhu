-----------------------------------------------------
---! @file
---! @brief
------------------------------------------------------
local const = {}
setmetatable(const, {
    __index = function (t, k)
        return function()
            print("unknown field from const: ", k, t)
        end
    end
    })

const.GAMEID                = 2013
const.GAMEVERSION           = 20180901
const.LOWVERSION            = 20180901


---! const values
const.YUNCHENG_CARD_FLOWER           = 55
const.YUNCHENG_CARD_BACKGROUND       = 56
const.YUNCHENG_PLAYER_CARD_NUM       = 17
const.YUNCHENG_LORD_CARD_NUM         = 20
const.YUNCHENG_MAX_PLAYER_NUM        = 3

const.kCard_ValueLeast        =   2
const.kCard_Value3            =   3
const.kCard_Value4            =   4
const.kCard_Value5            =   5
const.kCard_Value6            =   6
const.kCard_Value7            =   7
const.kCard_Value8            =   8
const.kCard_Value9            =   9
const.kCard_ValueT            =   10     -- Ten
const.kCard_ValueJ            =   11
const.kCard_ValueQ            =   12
const.kCard_ValueK            =   13
const.kCard_ValueA            =   14
const.kCard_Value2            =   15
const.kCard_ValueJoker1       =   16
const.kCard_ValueJoker2       =   17

const.kCard_Joker1            =   53
const.kCard_Joker2            =   54


const.kCardType_Single        =   1   -- 单纯类型, seriaNum == 1
const.kCardType_Serial        =   2   -- 单顺, 双顺, 三顺(飞机), 4顺
const.kCardType_Rocket        =   3   -- 火箭(大小王)


---! game trace
const.YUNCHENG_GAMETRACE_PICKUP          = 1    -- 发牌
const.YUNCHENG_GAMETRACE_DISCLOSE        = 2    -- 明牌
const.YUNCHENG_GAMETRACE_REFRESH         = 3    -- 更新牌面
const.YUNCHENG_GAMETRACE_LANDLORD        = 4    -- 叫地主
const.YUNCHENG_GAMETRACE_MULTIPLE        = 5    -- 加倍
const.YUNCHENG_GAMETRACE_THROW           = 6    -- 出牌
const.YUNCHENG_GAMETRACE_SHOWBOTTOM      = 7    -- 显示底牌
const.YUNCHENG_GAMETRACE_BOMBMULT        = 8    -- 炸弹, 更新倍数
const.YUNCHENG_GAMETRACE_GAMEOVER        = 10


---! table status
const.YUNCHENG_TABLE_STATUS_WAIT_NEWGAME      = 5
const.YUNCHENG_TABLE_STATUS_WAIT_PICKUP       = 6       -- 发牌
const.YUNCHENG_TABLE_STATUS_WAIT_LANDLORD     = 7       -- 叫地主
const.YUNCHENG_TABLE_STATUS_WAIT_MULTIPLE     = 8       -- 加倍
const.YUNCHENG_TABLE_STATUS_WAIT_THROW        = 9
const.YUNCHENG_TABLE_STATUS_WAIT_GAMEOVER     = 10

---! time out
const.YUNCHENG_TIMEOUT_WAIT_PICKUP       = 5
const.YUNCHENG_TIMEOUT_WAIT_LANDLORD     = 10
const.YUNCHENG_TIMEOUT_WAIT_MULTIPLE     = 10
const.YUNCHENG_TIMEOUT_WAIT_THROW        = 25
const.YUNCHENG_TIMEOUT_WAIT_OFFLINE      = 5
const.YUNCHENG_TIMEOUT_WAIT_GAMEOVER     = 2
const.YUNCHENG_TIMEOUT_WAIT_NEWGAME      = 3

---! card types
const.kGiftItems = {
    egg     =   0,
    water   =   0,
    bomb    =   0,
    cheer   =   0,
    flower  =   0,
    kiss    =   0,
    slap    =   0,
    car     =   0,
    house   =   0,
}

const.YUNCHENG_ACL_STATUS_RESTART_NO_MASTER                     =   101;  -- 没有人叫地主， 重新开始

const.YUNCHENG_ACL_STATUS_NO_SELECT_CARDS                       =   102;  -- 你没有选择任何牌

const.YUNCHENG_ACL_STATUS_NOT_VALID_TYPE                        =   103;  -- 不能组成有效牌型
const.YUNCHENG_ACL_STATUS_NOT_SAME_TYPE                         =   104;  -- 不是同一牌型
const.YUNCHENG_ACL_STATUS_NOT_BIGGER                            =   105;  -- 打不过别人的牌
const.YUNCHENG_ACL_STATUS_NO_BIG_CARDS                          =   106;  -- 没有牌能大过上家
const.YUNCHENG_ACL_STATUS_NO_YOUR_CARDS                         =   107;  -- 发的牌不是你的牌

const.deltaSeat = function (seatId, delta)
    seatId = seatId + (delta and delta or 1)
    seatId = (seatId - 1 + const.YUNCHENG_MAX_PLAYER_NUM) % const.YUNCHENG_MAX_PLAYER_NUM + 1

    return seatId
end

const.isRocket = function (node)
    return node.cardType == const.kCardType_Rocket
end

const.isBomb = function (node)
    return node.seralNum==1 and node.mainNum >= 4 and node.subNum == 0
end

const.removeSubset = function (main, sub)
    local all = true
    for _, n in ipairs(sub) do
        local idx = nil
        for i,v in ipairs(main) do
            if v == n then
                idx = i
                break
            end
        end

        if not idx then
            all = nil
            print(n , " not found in main ")
        else
            table.remove(main, idx)
        end
    end

    return all
end

const.getCardValue = function (card)
    if card == const.kCard_Joker1 then
        return const.kCard_ValueJoker1;
    end

    if card == const.kCard_Joker2 then
        return const.kCard_ValueJoker2;
    end

    local t = card % 13;
    if t < 3 then
        t = t + 13;
    end
    return t;
end

const.getCardItSelf = function (card)
    return card
end

const.getSelCards = function (array, mainFunc, subset, subFunc)
    local cards = {}
    local subArr = {}
    for i, v in ipairs(subset) do
        subArr[i] = v
    end

    for _, sp in ipairs(array) do
        local valueT = mainFunc(sp)

        for i, v in ipairs(subArr) do
            if valueT == subFunc(v) then
                table.insert(cards, sp)

                table.remove(subArr, i)
                break
            end
        end
    end

    local ok = false
    if #subArr == 0 then
        ok = true
    end

    return ok, cards
end


const.levelScores = {
    -1000,
    0,
    500,
    1000,
    2000,
    5000,
    10000,
    20000,
    50000,
    100000,
    200000,
    500000,
    1000000,
    2000000,
    5000000,
    10000000,
    20000000,
    50000000,
    100000000,
    200000000,
    500000000,
    1000000000,
    2000000000,
}

const.levelName = {
    "包身工",
    "短工",
    "长工",
    "佃户",
    "贫农",
    "渔夫",
    "猎人",
    "中农",
    "富农",
    "掌柜",
    "商人",
    "衙役",
    "小财主",
    "大财主",
    "小地主",
    "大地主",
    "知县",
    "通判",
    "知府",
    "总督",
    "巡抚",
    "丞相",
    "帝王",
}

const.findLevelRank = function(score)
    local ret = 1
    for i = 1, #const.levelScores do
        if score >= const.levelScores[i] then
            ret = i
        else
            break
        end
    end

    return ret
end

const.findLevelName = function(lvl)
    if not lvl or lvl < 1 then
        lvl = 1
    elseif lvl > #const.levelScores then
        lvl = #const.levelScores
    end

    local str = const.levelName[lvl]
    return str
end

const.getNextLevelScore = function(score)
    if score then
        local lvl = const.findLevelRank(score) + 1
        local nextScore
        if not lvl or lvl < 1 then
            lvl = 1
        elseif lvl > #const.levelScores then
            return nil
        end
        nextScore = const.levelScores[lvl]
        return nextScore
    end
    return 1
end

return const

