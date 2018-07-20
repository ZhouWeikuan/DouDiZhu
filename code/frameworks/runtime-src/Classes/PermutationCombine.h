//
//  PermutationCombine.hpp
//  Test
//
//  Created by CronlyGames Inc. on 2017/2/15.
//  Copyright © 2017年 CronlyGames. All rights reserved.
//

#ifndef PermutationCombine_hpp
#define PermutationCombine_hpp

#include <vector>

#pragma mark - permutation
struct PermutationCombine {
    int N, M;
    std::vector<int> order;
    
    PermutationCombine(int all, int sel);
    
    const std::vector<int> & firstPerm();
    const std::vector<int> & nextPerm();
    
    bool isEnd() {
        return order[0] != -1;
    }
    
    int getEstimatedResultNum();
    
    void getResult();
};


#endif /* PermutationCombine_hpp */
