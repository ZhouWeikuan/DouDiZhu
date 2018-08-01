//
//
//  Created by CronlyGames Inc. on 14-8-26.
//  Copyright (c) 2014年 CronlyGames. All rights reserved.
//

#include "YunChengAI.h"
#include "PermutationCombine.h"
#include <assert.h>

int getMaskValue (int card) {
    return (card & kCardMask_CardValue);
}

int isCardAnyMatch(int card) {
    return (card & kCardMask_AnyMatch) != 0;
}

int getCardExpand (int card) {
    card |= kCardMask_AnyMatch;

    return card;
}

int getCardOrigin (int card) {
    if (isCardAnyMatch(card)) {
        card = kCard_Flower;
    }

    return card;
}

void restoreAnyMatch(std::vector<int> & cards) {
    for (std::vector<int>::iterator it = cards.begin(); it != cards.end(); ++it) {
        if (isCardAnyMatch(*it)) {
            *it = getCardOrigin(*it);
        }
    }

    std::sort(cards.begin(), cards.end(), cardGreaterThan);
}


#pragma mark - compares
bool AINode_Compare_Aggregate_Reversed(const AINode &a, const AINode &b) {
    float absValue = fabs(a.aggregate - b.aggregate);
    if (absValue < 0.01) {
        return a.cards < b.cards;
    }

    return a.aggregate > b.aggregate;
}

#pragma mark - AINode
AINode::AINode() {
    resetNode();
}

AINode::AINode(int type, int val, int mainN, int len, int sub) {
    cardType = type;
    value = val;
    mainNum = mainN;
    seralNum = len;
    subNum = sub;

    aggregate = 0.0f;

    cards.clear();
}

AINode::AINode(const AINode &other) {
    cardType = other.cardType;
    mainNum = other.mainNum;
    value = other.value;
    seralNum = other.seralNum;
    subNum = other.subNum;

    aggregate = other.aggregate;

    cards = other.cards;
}

AINode & AINode::operator = (const AINode &other) {
    cardType = other.cardType;
    mainNum = other.mainNum;
    value = other.value;
    seralNum = other.seralNum;
    subNum = other.subNum;

    aggregate = other.aggregate;

    cards = other.cards;

    return *this;
}

bool AINode::isValidNode() const {
    return mainNum != 0;
}

void AINode::resetNode() {
    cardType = 0;
    value = 0;
    mainNum = 0;
    seralNum = 0;
    subNum = 0;

    aggregate = 0.0f;

    cards.clear();
}

int AINode::getTopValue() const {
    int top = value;
    if (cardType == kCardType_Serial) {
        top = value + seralNum - 1;
    }

    return top;
}

int AINode::getMaxCapacity() const {
    int ret = 0;
    if (cardType == kCardType_Rocket) {
        ret += 2;
    } else if (cardType == kCardType_Serial) {
        int times = std::max(0, mainNum - 2);
        ret += (mainNum + times * subNum) * seralNum;
    } else {
        int times = std::max(0, mainNum - 2);
        ret += (mainNum + times * subNum);
    }

    return  ret;
}

void AINode::fillJokers() {
    cards.clear();

    if (cardType == kCardType_Rocket) {
        cards.push_back(kCard_Joker1);
        cards.push_back(kCard_Joker2);
    } else {
        assert(false);
    }
}

bool AINode::isRocket() const {
    return cardType == kCardType_Rocket;
}

bool AINode::isBomb() const {
    return (seralNum==1 && mainNum >= 4 && subNum == 0);
}


// same type less than
bool AINode::isExactLessThan(const AINode & other) const {
    if (!isValidNode()) {
        return true;
    }
    return (cardType == other.cardType && mainNum == other.mainNum
        && subNum == other.subNum && seralNum == other.seralNum
        && getTopValue() < other.getTopValue());
}

// same type or big bomb
bool AINode::isStrictLessThan(const AINode &other) const {
    if (!isValidNode())
        return true;

    if (isRocket()) {
        return false;
    }
    if (other.isRocket()) {
        return true;
    }

    if (isBomb() && other.isBomb()) {
        return getTopValue() < other.getTopValue();
    } else if (isBomb()) {
        return false;
    } else if (other.isBomb()) {
        return true;
    }

    return isExactLessThan(other);
}

void AINode::merge(const AINode & other) {
    mergeTwoVectors(cards, other.cards);
}

// 计算当前牌型的权重，全部是预估的；应该用AI来估算会更准确
float AINode::getPower() const {
    float bad  = 0.0f;

    if (cardType == kCardType_Rocket) {
        bad = -8.0f; // -1.5 * 4.2f
    } else {
        float top = ( value + value + seralNum)/2.0f;

        if (mainNum == 4) {
            if (subNum) {
                bad = -1.5 * 3.0f + 0.003 * (kCard_Value2 - top) + (seralNum > 1 ? seralNum : 0) * 0.002 - subNum * 0.002;
            } else if (value == kCard_Value2) {
                bad = -1.5f * 3.1f;
            } else {
                bad = -1.5f * 4.0f + 0.175 * (kCard_Value2 - top) + (seralNum > 1 ? seralNum : 0) * 0.002;
            }
        } else if (mainNum == 3) {
            bad = 0.433  + 0.02 * (kCard_Value2 - top) + (seralNum > 1 ? seralNum : 0)  * 0.02 - subNum * 0.01;
        } else if (mainNum == 2) {
            bad = 0.437  + 0.015 * (kCard_Value2 - top) + (seralNum > 2 ? seralNum : 0) * 0.02;
        } else { // 1
            bad = 0.435  + 0.0151 * (kCard_Value2 - top) + (seralNum > 4 ? seralNum : 0) * 0.02;
        }
    }

    float ret = kOneHandPower + kPowerUnit * bad;
    return ret;
}

bool AINode::operator < (const AINode & other) const {
    if (mainNum != other.mainNum) {
        return mainNum > other.mainNum;
    }

    if (value != other.value) {
        return value < other.value;
    }

    if (cardType != other.cardType) {
        return cardType < other.cardType;
    }

    if (seralNum != other.seralNum) {
        return seralNum < other.seralNum;
    }

    if (cards.size() != other.cards.size()) {
        return cards.size() < other.cards.size();
    }

    for (int i=0; i<cards.size(); ++i) {
        if (cards[i] != other.cards[i]) {
            return cards[i] < other.cards[i];
        }
    }
    return false;
}

bool AINode::isEqualTo(const AINode & other) const {
    if (isRocket() && other.isRocket()) {
        return true;
    }

    if (mainNum == other.mainNum && value == other.value
        && seralNum == other.seralNum && subNum == other.subNum) {
        return cards == other.cards;
    } else {
        return false;
    }
}


static const char * cardSuits[] = {"♣️", "♦️", "♥️", "♠️"};
static const char * cardValues[] = {"", "1", "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A", "2"};
std::string AINode::description() const {
    std::string ret = "";

    for (int i=0; i<cards.size(); ++i) {
        if (cards[i] == kCard_Flower) {
            ret += "🌹 ";
        } else if (cards[i] == kCard_Joker1) {
            ret += "jj ";
        } else if (cards[i] == kCard_Joker2) {
            ret += "JJ ";
        } else {
            ret += cardSuits[LordCards::getCardSuit(cards[i])];
            ret += cardValues[LordCards::getCardValue(cards[i])];
            ret += " ";
        }
    }

    return ret;
}

// 按面值进行比较，面值相同，再按牌值(即花色)
bool cardLessThan(const int a, const int b) {
    int res = LordCards::getCardValue(a) - LordCards::getCardValue(b);
    if (res == 0) {
        res = a - b;
    }
    return res < 0;
}

bool cardGreaterThan(const int a, const int b) {
    return !cardLessThan(a, b);
}

#pragma mark - static values
int LordCards::getMinSerialLength(int mainNum) {
    int ret = 1000;
    if (mainNum >= 3) {
        ret = 2;
    } else if (mainNum == 2) {
        ret = 3;
    } else if (mainNum == 1) {
        ret = 5;
    }

    return ret;
}

int LordCards::getMaxSubNum(int mainNum) {
    int ret = mainNum >= 3 ? 2: 0;

    return ret;
}

int LordCards::getDupSubNum(int mainNum) {
    mainNum = std::min(4, mainNum);
    int ret = std::max(0, mainNum - 2);

    return ret;
}

int LordCards::getCardSuit(int card) {
    card &= kCardMask_CardValue;
    assert (card > 0 && card <= kCard_Joker2);

    if (card >= kCard_Joker1) {
        return 0;
    }

    return (card-1)/13;
}

int LordCards::getCardValue(int card) {
    int v = getMaskValue(card);
    if (v == kCard_Flower) {
        return kCard_ValueMax;
    }
    if (v == kCard_Joker1) {
        return kCard_ValueJoker1;
    }
    if (v == kCard_Joker2) {
        return kCard_ValueJoker2;
    }
    int t = v % 13;
    if (t < 3) {
        t += 13;
    }
    return t;
}

#pragma mark LordCards - init & dealloc
LordCards::LordCards(class YunChengGame *game, const std::vector<int>&vec)
{
    assign(game, vec);
}

LordCards::LordCards(class YunChengGame *game, int cards[], int num) {
    std::vector<int> vec(cards, cards + num);
    assign(game, vec);
}

LordCards::~LordCards() {

}

void LordCards::assign(class YunChengGame *game, const std::vector<int>&vec) {
    theGame = game;
    memset(cardsTable, 0, sizeof(cardsTable));

    theCards = vec;
}

void LordCards::assign(class YunChengGame * game, int cards[], int num) {
    std::vector<int> vec(cards, cards + num);
    assign(game, vec);
}

LordCards & LordCards::operator = (const LordCards & other) {
    theCards = other.theCards;
    theGame = other.theGame;

    memcpy(cardsTable, other.cardsTable, sizeof(cardsTable));

    return *this;
}

#pragma mark - search find
float LordCards::winRateIfLord() {
    float score = 0.0f;

    int count = this->scanToTable();

    if (cardsTable[0][kCard_ValueJoker1] && cardsTable[0][kCard_ValueJoker2]) {
        score += 8;
    } else if (cardsTable[0][kCard_ValueJoker2]) {
        score += 4;
    } else if (cardsTable[0][kCard_ValueJoker1]) {
        score += 3;
    }

    if (count) {
        score += 3;
    }

    score += cardsTable[0][kCard_Value2] * 2;
    for (int i=kCard_Value3; i<=kCard_ValueA; ++i) {
        score += (cardsTable[0][i] >= 4) * 6;
    }

    const float maxValue = 30.0f;
    if (score > maxValue) {
        score = maxValue;
    }
    score /= maxValue;

    return score;
}

bool LordCards::bigEnough() {
    this->scanToTable();

    if (cardsTable[0][kCard_ValueJoker1] && cardsTable[0][kCard_ValueJoker2]) {
        return true;
    }

    if (cardsTable[0][kCard_Value2] >= 4) {
        return true;
    }

    return false;
}

std::vector<int> LordCards::removeSubset(const std::vector<int> & subset) {
    std::vector<int> affected;
    for (int s=0; s<subset.size(); ++s) {
        bool removed = false;
        int obj = subset[s];

        for (int k=0; k<theCards.size(); ++k) {
            if (theCards[k] == obj) {
                affected.push_back(theCards[k]);

                theCards.erase(theCards.begin() + k);
                removed = true;
                break;
            }
        }

        if (!removed) {
            printf("no subset for %d found\n", obj);
        }
    }

    return affected;
}

int LordCards::scanToTable(){
    memset(cardsTable, 0, sizeof(cardsTable));
    for (int i=0; i<kCard_ValueMax; ++i) {
        m_fillCards[i].clear();
    }

    int countAny = 0;

    std::sort(theCards.begin(), theCards.end(), cardLessThan);
    for (int i=0; i<theCards.size(); i++) {
        if (theCards[i] == kCard_Flower) {
            ++countAny;
            continue;
        }
        int val = LordCards::getCardValue(theCards[i]);
        cardsTable[0][val]++;
        m_fillCards[val].push_back(theCards[i]);
    }

    for (int i = kCard_Value3; i <= kCard_ValueJoker2; ++i) {
        for (int num = 4; num >= 1; --num) {
            if (cardsTable[0][i] >= num) {
                if (i <= kCard_ValueA) {
                    cardsTable[num][i] = cardsTable[num][i - 1] + 1;
                } else {
                    cardsTable[num][i] = 1;
                }
            } else {
                cardsTable[num][i] = 0;
            }
        }
    }

    return countAny;
}

#pragma mark - power status

bool LordCards::updateHandForNode(OneHand & best, OneHand &left, AINode & trimNode, bool isTrim) {
    bool ret = false;
    float power = left.totalPower + trimNode.getPower();
    float absValue = fabs(power - best.totalPower);
    if ((absValue < 1.00f && best.bestNode.getPower() > trimNode.getPower()) || (power > best.totalPower)) {
        best.totalPower = power;
        best.handNum = left.handNum + isTrim;
        best.bestNode = trimNode;
        ret = true;
    }

    return ret;
}

OneHand LordCards::calcPowerByRemoveNode(const AINode & node) {
    LordCards other(theGame, theCards);
    other.removeSubset(node.cards);

    OneHand hand = other.calcPowerValue(true);
    return hand;
}

void LordCards::checkRocket (const std::string & key, OneHand & hand) {
    AINode one(kCardType_Rocket, kCard_ValueJoker1, 1, 1, 0);
    one.fillJokers();

    OneHand left = calcPowerByRemoveNode(one);
    updateHandForNode(hand, left, one, 1);
}

void LordCards::checkBomb4 (const std::string & key, OneHand & hand, int top) {
    AINode one(kCardType_Single, top, 4, 1, 0);
    if (!collectNode(one, top, 4)) {
        return;
    }

    OneHand left = calcPowerByRemoveNode(one);
    updateHandForNode(hand, left, one, 1);
};

// subNum, 带几个,  subCount 每个是单还是对
void LordCards::checkSerial (const std::string & key, OneHand & hand, int top, int mainNum, int len, int subNum) {
    AINode one(len == 1 ? kCardType_Single : kCardType_Serial, top - len + 1, mainNum, len, subNum);
    for (int val = top - len + 1; val <= top; ++val) {
        if (!collectNode(one, val, mainNum)) {
            return;
        }
    }

    if (subNum > 0) {
        std::vector<AINode> poss;
        for (int i = kCard_Value3; i < top - len + 1; ++i) {
            if (cardsTable[0][i] >= subNum) {
                AINode tmp(kCardType_Single, i, subNum, 1, 0);
                if (containsFlower(i, subNum) || !collectNode(tmp, i, subNum)) {
                    continue;
                }

                poss.push_back(tmp);
            }
        }

        int N = (int)poss.size();
        int M = len * (mainNum == 4 ? 2 : 1);
        if (M > N) {
            return;
        }

        std::vector<int> old = one.cards;

        PermutationCombine com(N, M);
        const std::vector<int> &vec = com.firstPerm();
        do {
            one.cards = old;
            for (int i = 0; i < M; i++) {
                const AINode & other = poss[vec[i + 1]];
                one.merge(other);
            }

            OneHand left = calcPowerByRemoveNode(one);
            updateHandForNode(hand, left, one, 1);

            com.nextPerm();
        } while (!com.isEnd());

    } else {
        OneHand left = calcPowerByRemoveNode(one);
        updateHandForNode(hand, left, one, 1);
    }
}

void LordCards::checkSub (const std::string & key, OneHand & hand, int mainNum, int subNum, int poss) {
    AINode possNode(kCardType_Single, poss, subNum, 1, 0);
    if (containsFlower(poss, subNum) || !collectNode(possNode, poss, subNum)) {
        return;
    }

    for (int i = kCard_Value2; i >= kCard_Value3; --i) {
        int num = cardsTable[mainNum][i];
        if (i == poss || num <= 0) {
            continue;
        }

        for (int len = 1; len <= num; ++len) {
            if (poss >= i - len + 1 && poss <= i) {
                continue;
            }
            AINode one(len == 1 ? kCardType_Single : kCardType_Serial, i - len + 1, mainNum, len, subNum);
            bool flag = true;
            for (int val = i - len + 1; val <= i; ++val) {
                if (!collectNode(one, val, mainNum)) {
                    flag = false;
                    break;
                }
            }
            if (!flag) {
                continue;
            }

            one.merge(possNode);

            std::vector<AINode> arr;
            for (int j = kCard_Value3; j <= kCard_ValueJoker2; ++j) {
                if (cardsTable[0][j] >= subNum && j != poss && (j > i || j < i - len + 1)) {
                    AINode tmp(kCardType_Single, j, subNum, 1, 0);
                    if (containsFlower(j, subNum) || !collectNode(tmp, j, subNum)) {
                        continue;
                    }

                    arr.push_back(tmp);
                }
            }

            int N = (int)arr.size();
            int M = len * (mainNum == 4 ? 2 : 1) - 1;
            if (N < M) {
                continue;
            }

            if (M == 0) {
                OneHand left = calcPowerByRemoveNode(one);
                updateHandForNode(hand, left, one, 1);
            } else {
                PermutationCombine com(N, M);
                const std::vector<int> &vec = com.firstPerm();
                std::vector<int> orig = one.cards;
                do {
                    one.cards = orig;
                    for (int t = 0; t < M; t++) {
                        const AINode & other = arr[vec[t + 1]];
                        one.merge(other);
                    }

                    OneHand left = calcPowerByRemoveNode(one);
                    updateHandForNode(hand, left, one, 1);

                    com.nextPerm();
                } while (!com.isEnd());
            }
        }
    }
}

std::string LordCards::getKey(bool checkFlower, int &leastValue, int &maxCount) {
    int num = 0;
    char key[60] = {0};
    leastValue = 0;
    maxCount = 0;
    if (checkFlower) {
        for (std::vector<int>::iterator it = theCards.begin(); it!=theCards.end(); ++it) {
            key[num++] = char(*it & kCardMask_CardValue);
        }
    } else {
        for (int i=kCard_Value3; i<=kCard_ValueJoker2; ++i) {
            int cnt = this->cardsTable[0][i];
            if (cnt > 0) {
                key[num++] = char('A' + i);
                key[num++] = char('a' + cnt);

                if (cnt > 0) {
                    leastValue = i;
                    if (maxCount < cnt) {
                        maxCount = cnt;
                    }
                }
            }
        }
    }
    assert(num < 60);
    key[num] = 0;
    return key;
}

bool LordCards::containsFlower(int value, int num) {
    if (m_fillCards[value].size() < num) {
        return false;
    }

    for (int i=0; i<num; ++i) {
        int card = m_fillCards[value][i];
        if (isCardAnyMatch(card) || card == kCard_Flower) {
            return true;
        }
    }

    return false;
}

bool LordCards::collectNode(AINode & one, int value, int num) {
    if (m_fillCards[value].size() < num) {
        return false;
    }

    bool hasFlower = (one.subNum == 0 && num >= 4);
    for (int i=0; i<num; ++i) {
        one.cards.push_back(m_fillCards[value][i]);
    }

    return true;
}

OneHand  LordCards::calcPowerValue_noFlower() {
    OneHand hand;
    if (theCards.empty()) {
        hand.totalPower = 0;
        return hand;
    }

    int countAny = scanToTable();
    assert(countAny <= 0);

    int leastValue, maxCount;
    unordered_map<std::string, OneHand> & dict = *(theGame->powerOfCards);
    std::string key = this->getKey(false, leastValue, maxCount);
    unordered_map<std::string, OneHand>::iterator it = dict.find(key);
    if (it != dict.end()) {
        return it->second;
    }

    // check just current value;
    int i = leastValue;
    if (cardsTable[0][i] >= 1) {
        for (int len = 1; len <= cardsTable[1][i]; len = len + (len == 1 ? 4 : 1)) {
            this->checkSerial(key, hand, i, 1, len, 0);
        }

        if (maxCount >= 3) {
            this->checkSub(key, hand, 3, 1, i);
        }

        if (maxCount >= 4) {
            // this->checkSub(key, hand, 4, 1, i); //
        }
    }

    if (cardsTable[0][i] >= 2) {
        for (int len = 1; len <= cardsTable[2][i]; len = len + (len == 1 ? 2 : 1)) {
            this->checkSerial(key, hand, i, 2, len, 0);
        }

        if (maxCount >= 3) {
            this->checkSub(key, hand, 3, 2, i);
        }

        if (maxCount >= 4) {
            // this->checkSub(key, hand, 4, 2, i); //
        }
    }

    if (cardsTable[0][i] >= 3) {
        for (int len = 1; len <= cardsTable[3][i]; ++len) {
            this->checkSerial(key, hand, i, 3, len, 0);
            this->checkSerial(key, hand, i, 3, len, 1);
            this->checkSerial(key, hand, i, 3, len, 2);
        }
    }

    if (cardsTable[0][i] >= 4) {
        this->checkBomb4(key, hand, i);
        for (int len = 1; len <= cardsTable[4][i]; ++len) {
            // this->checkSerial(key, hand, i, 4, len, 1); //
            // this->checkSerial(key, hand, i, 4, len, 2); //
        }
    }

    dict[key] = hand;
    return hand;
}

OneHand LordCards::calcPowerValue_expandAny(int count, int cardIndex) {
    if (count <= 0) {
        return calcPowerValue_noFlower();
    }

    OneHand bestHand;
    std::vector<int> before = theCards;
    std::vector<int> trimed = before;
    do {
        std::vector<int>::iterator it = std::find(trimed.begin(), trimed.end(), (int)kCard_Flower);
        if (it != trimed.end()) {
            trimed.erase(it);
        } else {
            break;
        }
    } while (true);
    theCards = trimed;
    for (int card = cardIndex; card < kCard_ValueA; ++card) {
        if (LordCards::getCardValue(card) == kCard_Value2) {
            continue;
        }

        int one = getCardExpand(card);
        theCards.push_back(one);
        OneHand leftBest = calcPowerValue_expandAny(count - 1, card);
        if (bestHand.totalPower < leftBest.totalPower) {
            bestHand.totalPower = leftBest.totalPower;
            bestHand.handNum    = leftBest.handNum;
            bestHand.bestNode   = leftBest.bestNode;
        }

        theCards = trimed;
    }

    theCards = before;

    restoreAnyMatch(bestHand.bestNode.cards);
    return bestHand;
}

OneHand LordCards::calcPowerValue(bool checkFlower) {
    OneHand hand;
    if (theCards.empty()) {
        hand.totalPower = 0;
        return hand;
    }

    int countAny = scanToTable();
    int leastValue, maxCount;
    std::string key = this->getKey(checkFlower, leastValue, maxCount);
    unordered_map<std::string, OneHand> &powerOfCards = *theGame->powerOfCards;
    unordered_map<std::string, OneHand>::iterator it = powerOfCards.find(key);
    if (it != powerOfCards.end()) {
        return it->second;
    }

    if (cardsTable[0][kCard_ValueJoker2] > 0 && cardsTable[0][kCard_ValueJoker1] > 0) {
        this->checkRocket(key, hand);
    }

    int count = 0;
    std::vector<int> old = this->theCards;
    for (int i = (int)theCards.size()-1; count<countAny && i>=0; --i) {
        if (theCards[i] == kCard_Flower) {
            ++ count;
            theCards.erase(theCards.begin() + i);
        }
    }

    OneHand exp = calcPowerValue_expandAny(countAny, 1);
    if (exp.totalPower > hand.totalPower) {
        hand.totalPower = exp.totalPower;
        hand.handNum    = exp.handNum;
        hand.bestNode   = exp.bestNode;
    }
    theCards = old;

    powerOfCards[key] = hand;
    return hand;
}

AINode   LordCards::typeAndValueFind() {
    AINode node;
    std::vector<AINode> all = getNodesGreaterThan(node);
    for (int i=0; i<all.size(); ++i) {
        if (theCards.size() == all[i].cards.size()) {
            if (node.isStrictLessThan(all[i])) {
                node = all[i];
            }
        }
    }

    return node;
}

#pragma mark - calc AINode
void LordCards::collectAllNodes(std::set<AINode> &possNodes, AINode & node, int dup) {
    for (int val = node.value; val < node.value + node.seralNum; ++val) {
        if (!collectNode(node, val, node.mainNum)) {
            return;
        }
    }

    // now find sublings
    int maxSubCount = 0;
    if (node.subNum > 0) {
        maxSubCount = node.seralNum * dup;
    }
    if (maxSubCount > 0) {
        std::vector<AINode> sublings;
        for (int s = kCard_ValueLeast; s < kCard_ValueMax; ++s) {
            if (s >= node.value && s <= node.getTopValue()) {
                continue;
            }

            if (cardsTable[0][s] >= node.subNum) {
                AINode sub(kCardType_Single, s, node.subNum, 1, 0);
                if (!containsFlower(s, node.subNum) && collectNode(sub, s, node.subNum)) {
                    sublings.push_back(sub);
                }
            }
        }

        if (sublings.size() >= maxSubCount) {
            int N = (int)sublings.size(), M = maxSubCount;
            PermutationCombine com(N, M);

            std::vector<int> old = node.cards;
            const std::vector<int> &vec = com.firstPerm();
            do {
                node.cards = old;
                for(int i = 0; i < M; i++) {
                    const AINode & other = sublings[vec[i + 1]];
                    node.merge(other);
                }

                possNodes.insert(node);

                com.nextPerm();
            } while(!com.isEnd());
        }
    } else { // no sublings
        possNodes.insert(node);
    }
}

void LordCards::sortByFactorInNodes(std::vector<AINode> &allNodes, const AINode & prev, bool isDirect) {
    for (int i= (int)allNodes.size() - 1; i >= 0; --i) {
        AINode & one = allNodes[i];
        restoreAnyMatch(one.cards);
        if (one.cards.size() == 1 && one.cards[0] == kCard_Flower) {
            allNodes.erase(allNodes.begin() + i);
            continue;
        }

        if (!prev.isStrictLessThan(one)) {
            allNodes.erase(allNodes.begin() + i);
            continue;
        }

        LordCards other(theGame, theCards);
        other.removeSubset(one.cards);

        OneHand hand = other.calcPowerValue(true);
        one.aggregate = hand.totalPower;
//        if (one.mainNum >= 4 || one.isRocket()) {
//            if (isDirect) {
//                one.aggregate -= 0.3 * one.getPower();
//            } else if (one.isRocket()|| one.isBomb()) {
//                one.aggregate += 0.1 * one.getPower();
//            }
//        }
    }

    std::sort(allNodes.begin(), allNodes.end(), AINode_Compare_Aggregate_Reversed);
}

void  LordCards::getGreaterNodes_expandAny(int count,
                                           int cardIndex,
                                           std::set<AINode> &possNodes,
                                           const AINode &other)
{
    if (count <= 0) {
        getGreaterNodes_simple(possNodes, other);
        return;
    }

    std::vector<int> before = theCards;
    std::vector<int> trimed = before;
    do {
        std::vector<int>::iterator it = std::find(trimed.begin(), trimed.end(), (int)kCard_Flower);
        if (it != trimed.end()) {
            trimed.erase(it);
        } else {
            break;
        }
    } while (true);
    theCards = trimed;
    for (int card = cardIndex; card < kCard_ValueA; ++card) {
        if (LordCards::getCardValue(card) == kCard_Value2) {
            continue;
        }

        int one = getCardExpand(card);
        theCards.push_back(one);
        getGreaterNodes_expandAny(count - 1, card, possNodes, other);

        theCards = trimed;
    }

    theCards = before;
}

void LordCards::getGreaterNodes_possNode(std::set<AINode> &possNodes, const AINode &other) {
    if (other.isRocket()) {
        return;
    }

    int countAny = scanToTable();

    // at last, check if rockect.
    if (cardsTable[0][kCard_ValueJoker1] && cardsTable[0][kCard_ValueJoker2]) {
        AINode one(kCardType_Rocket, kCard_ValueJoker1, 1, 1, 0);
        one.fillJokers();
        possNodes.insert(one);
    }

    getGreaterNodes_expandAny(countAny, 1, possNodes, other);
}

std::vector<AINode>  LordCards::getNodesGreaterThan(const AINode & other) {
    // 收集所有可能性
    std::set<AINode> possNodes;
    getGreaterNodes_possNode(possNodes, other);

    // 根据aggregate调整各节点顺序
    std::vector<AINode> outNodes(possNodes.begin(), possNodes.end());
    possNodes.clear();

    sortByFactorInNodes(outNodes, other, true);
    size_t num = 0;
    for (size_t i=1; i<outNodes.size(); ++i) {
        const AINode & cur = outNodes[num];
        const AINode & nex = outNodes[i];
        if (fabs(nex.aggregate - cur.aggregate) < 0.00001 && (!(cur < nex) && !(nex < cur))) {
            // 太过相似，忽略重复
        } else {
            // 加入
            ++num;
            if (num != i) {
                outNodes[num] = outNodes[i];
            }
        }
    }
    if (!outNodes.empty()) {
        ++num;
        outNodes.resize(num);
    }

    return outNodes;
}

void LordCards::getGreaterNodes_simple(std::set<AINode> &possNodes, const AINode &other) {
    scanToTable();

    // find all possible moves;
    for (int value = kCard_ValueLeast; value < kCard_ValueMax; ++value){
        int maxNum = std::min(4, cardsTable[0][value]);
        for (int main=1; main<=maxNum; ++main) {
            int maxSub = getMaxSubNum(main);
            int dupNum = getDupSubNum(main);

            // 单独 或者跳到 顺子
            int enoughLen = getMinSerialLength(main);
            for (int len = 1; len <= cardsTable[main][value]; len=(len==1?enoughLen:len+1)){
                for (int s=0; s<=maxSub; ++s) {
                    AINode serial(len==1?kCardType_Single:kCardType_Serial, value - len + 1, main, len, s);
                    if (other.isStrictLessThan(serial)) {
                        collectAllNodes(possNodes, serial, dupNum);
                    }
                }
            }

        }
    }
}

#pragma mark - YunChengGame

void YunChengGame::init(int pair3BombLvl) {
    powerOfCards        = 0;
    pair3BombLevel      = pair3BombLvl;

    powerOfCards = new unordered_map<std::string, OneHand>();

    OneHand hand;
    hand.totalPower = 0.0f;
    (*powerOfCards)[""] = hand;

    masterSeatId = 0;
    curSeatId    = 0;
    std::vector<int> cards;
    for (int i=0; i<=kMaxPlayers; ++i) {
        seatHands[i] = new LordCards(this, cards);
    }
}

std::string YunChengGame::debugSnakeInfo(std::vector<int>&cards) {
    std::string str;
    static const char * desc[] = {
        " ", " ", "2", "3", "4", "5", "6", "7", "8", "9",
        "T", "J", "Q", "K", "A", "2", "🐟", "🐠", "🌹",
    };

    for (int i = 0; i<cards.size(); ++i) {
        int card = cards[i];
        if (card < kCard_Joker1) {
            int suit = LordCards::getCardSuit(card);
            str += cardSuits[suit];
        }

        card = LordCards::getCardValue(card);
        str += desc[card];
        str += " ";
    }

    return str;
}
