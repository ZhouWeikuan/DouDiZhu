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
    for (int i=kCard_Value4; i<=kCard_ValueA; ++i) {
        score += (cardsTable[0][i] >= 4) * 6;
    }

    if (theGame->pair3BombLevel >= kPair3Bomb_DiffColor) {
        score += (cardsTable[0][kCard_Value3] / 2) * 6;
    } else if (theGame->pair3BombLevel >= kPair3Bomb_SameColor) {
        count = (bomb3[0] + bomb3[3]) >= 2;
        count += (bomb3[1] + bomb3[2]) >= 2;
        score += count * 6;
    } else {
        score += (cardsTable[0][kCard_Value3] >= 4) * 6;
    }

    const float maxValue = 30.0f;
    if (score > maxValue) {
        score = maxValue;
    }
    score /= maxValue;

    return score;
}

bool LordCards::bigEnough() {
    int count = this->scanToTable();

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
