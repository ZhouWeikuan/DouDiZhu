//
//  AutoLock.cpp
//  ludox
//
//  Created by Weikuan Zhou on 12-11-19.
//  Copyright (c) 2012年 CronlyGames. All rights reserved.
//

#include <pthread.h>
#include "AutoLock.h"

static pthread_mutex_t s_globalMutex;
static bool mutexInited = false;

AutoLock::AutoLock() {
    if (mutexInited == false) {
        pthread_mutexattr_t attr;
        pthread_mutexattr_init(&attr);
        
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&s_globalMutex, &attr);
        pthread_mutexattr_destroy(&attr);
        
        // CCLOG("mutex init returned %d", ip);
        
        mutexInited = true;
    }
    
    pthread_mutex_lock(&s_globalMutex);
}

AutoLock::~AutoLock() {
    pthread_mutex_unlock(&s_globalMutex);
}
