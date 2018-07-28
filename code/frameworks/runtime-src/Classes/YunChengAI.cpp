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

// cardSpriteCmp2
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
    float score = 0.5f;
    return score;
}

bool LordCards::bigEnough() {
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

OneHand LordCards::calcPowerValue(bool checkFlower) {
    OneHand one;
    return one;
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

std::vector<AINode>  LordCards::getNodesGreaterThan(const AINode & other) {
    // 收集所有可能性
    std::set<AINode> possNodes;
    for (auto card : theCards) {
        int val = getCardValue(card);
        AINode one(kCardType_Single, val, 1, 1, 0);
        if (other.isStrictLessThan(one)) {
            one.cards.push_back(card);
            possNodes.insert(one);
        }
    }
    // 根据aggregate调整各节点顺序
    std::vector<AINode> outNodes(possNodes.begin(), possNodes.end());
    possNodes.clear();

    return outNodes;
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
