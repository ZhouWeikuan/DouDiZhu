//
//  Settings.m
//
//  Created by art on 13-1-28.
//
//
#include "Constants.h"
#include "Settings.h"

#include <map>


#define keyLangSuffix				"com.cronlygames.language.suffix"

using namespace cocos2d;


#pragma mark - user rate
Settings * Settings::_sharedSettings = NULL;

Settings * Settings::sharedSettings() {
    if (_sharedSettings == NULL) {
        _sharedSettings = new Settings();
    }
    return _sharedSettings;
}

#define keyCoin "com.cronlygames.coin"
int Settings::getCoinNum() {
    int num = UserDefault::getInstance()->getIntegerForKey(keyCoin);
    return num;
}

void Settings::setCoinNum(int num) {
    UserDefault::getInstance()->setIntegerForKey(keyCoin, num);
    UserDefault::getInstance()->flush();
}

#pragma mark - languages
static int curLangIndex = 0;
static const char * langs[] = {
    "_EN",
    "_CN",
};
static const int kLangMax = sizeof(langs)/sizeof(langs[0]);

int Settings::getLanguageIndex() {
    if (curLangIndex < 0 || curLangIndex > kLangMax) {
        curLangIndex = 0;
    }
    return curLangIndex;
}

void Settings::loadLanguageDefault(int index) {
    if (index >= kLangMax || index < 0) {
        index = 0;
    }
    
    curLangIndex = index;
    std::string suffix = langs[curLangIndex];
    Settings::setLanguageSuffix(suffix);
}

std::string Settings::getLanguageSuffix() {
    return UserDefault::getInstance()->getStringForKey(keyLangSuffix);
}

void Settings::setLanguageSuffix(std::string & suffix) {
    UserDefault::getInstance()->setStringForKey(keyLangSuffix, suffix);
    UserDefault::getInstance()->flush();
}

std::string Settings::getLocalizedFileName(const char* baseName, const char* suffix) {
    std::string lang = Settings::getLanguageSuffix();
    std::string ret = StringUtils::format("%s%s.%s", baseName, lang.c_str(), suffix);
    return ret;
}

std::string Settings::getUTF8LocaleString(const char * key) {
    static ValueMap localeMap;
    if (localeMap.empty()) {
        std::string fileName = Settings::getLocalizedFileName("strings", "xml");
        std::string fullPath = FileUtils::getInstance()->fullPathForFilename(fileName);
        if (!FileUtils::getInstance()->isFileExist(fullPath.c_str())) {
            fullPath = FileUtils::getInstance()->fullPathForFilename("strings.xml");
        }
        if (!FileUtils::getInstance()->isFileExist(fullPath.c_str())) {
            CCAssert(false, "No strings.xml found!");
            return "";
        }
        
        localeMap = FileUtils::getInstance()->getValueMapFromFile(fullPath.c_str());
        if (localeMap.empty()) {
            CCAssert(false, "can not read file strings.xml!");
            return "";
        }
    }
    
    std::string ret = key;
    auto it = localeMap.find(key);
    if (it != localeMap.end()) {
        ret = it->second.asString();
    }
    
    if (ret == ""){
        ret = key;
    }
    
    return ret;
}

