//
//  PermutationCombine.cpp
//  Test
//
//  Created by CronlyGames Inc. on 2017/2/15.
//  Copyright © 2017年 CronlyGames. All rights reserved.
//

#include <stdio.h>
#include "PermutationCombine.h"

#pragma mark - permutation
PermutationCombine::PermutationCombine(int all, int sel) {
    if (sel < 1)  sel = 1;
    if (all < sel) all = sel;
    
    N = all;
    M = sel;
    order.resize(M + 1);
}

const std::vector<int> & PermutationCombine::firstPerm() {
    for(int i=0; i<=M; i++) {
        order[i] = i-1;            // 注意这里order[0]=-1用来作为循环判断标识
    }
    
    return order;
}

const std::vector<int> & PermutationCombine::nextPerm() {
    int k = M;
    bool flag = false;
    
    while (!flag && k >= 0 && k <= M) {
        order.at(k)++;                // 在当前位置选择新的数字
        if(order.at(k) == N)          // 当前位置已无数字可选，回溯
        {
            order.at(k--) = 0;
            continue;
        }
        
        if(k < M)                  // 更新当前位置的下一位置的数字
        {
            ++k;
            order.at(k) = order.at(k-1);
            continue;
        }
        
        if (k == M) {
            flag = true;
        }
    }
    
    return order;
}

int gcd(int a, int b){
    int t;
    if( a < b){
        t = a; a = b; b = t;
    }
    while(b > 0){
        t = a % b;
        a = b;
        b = t;
    }
    return a;
}

int PermutationCombine::getEstimatedResultNum() {
    uint64_t sum = 1, down = 1;
    for (int i=1; i <= N; ++i) {
        sum *= i;
        if (i <= M) {
            down *= i;
        }
        if (i <= N - M) {
            down *= i;
        }
        
        int g = (int)(long)gcd((int)(long)sum, (int)(long)down);
        sum /= g;
        down /= g;
    }
    
    sum/=down;
    int ret = (int)(long)sum;
    return ret;
}

void PermutationCombine::getResult() {
    const std::vector<int> &vec = firstPerm();
    do {
        for(int i = 0; i < M; i++) {
            printf("%d ", vec[i+1]);
        }
        printf("\n");
        
        nextPerm();
    } while(!isEnd());
    
}
