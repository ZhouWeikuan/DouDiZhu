//
//  Settings.h
//
//  Created by art on 13-1-28.
//
//

#ifndef  __SETTINGS_H_
#define __SETTINGS_H_

#include <string>
#include "cocos2d.h"

USING_NS_CC;

class Settings : public Ref {
    static Settings * _sharedSettings;
public:
    static Settings * sharedSettings();

    static int getCoinNum();
    static void setCoinNum(int num);
    
    static int getLanguageIndex();
    static void loadLanguageDefault(int index);
    static std::string getLanguageSuffix();
    static void setLanguageSuffix(std::string & suffix);
    
    static std::string getLocalizedFileName(const char* baseName, const char* suffix);
    static std::string getUTF8LocaleString(const char * key); 
};

#endif

