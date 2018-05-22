# 斗地主AI设计与实现

![宽立斗地主](http://www.cronlygames.com/image/landlord.png) [宽立斗地主](http://www.cronlygames.com/download/download.php?p=com.cronlygames.landlord) 是 [上海宽立信息技术有限公司](http://www.cronlygames.com/)出品的一款斗地主游戏，内置了基于权重的斗地主游戏AI算法。这种算法是我们过去几年在棋牌游戏上的经验体现，稍加修改，算法可以很容易的拓展到其他类似棋牌游戏上，如掼蛋，争上游，拖拉机等。

This repository will talk about AI algorithms for a chinese famous card game - landlord or DouDiZhu, it is based on weights.


## 第一章、环境初始化
为了演示斗地主算法的内容，我们需要创建好一个相关的cocos2d-x项目，并加入相关的代码，声音，图片等。与斗地主客户端对应的服务器端是基于skynet写的一个分布式游戏框架，为了代码复用方便和网络通讯需要，我们需要把lua升级到5.3，并在本地加入protobuf相关的解析库(我们使用的是pbc)。有些通用的函数库是游戏中必不可少的，我们也需要加入。

本游戏中所使用的代码遵守Apache License 2.0，所使用的声音图片等艺术类资源为本公司[上海宽立信息技术有限公司](www.cronlygames.com)和本文作者周为宽共同所有，可以下载学习，但请勿在商业环境下使用！

### 建立DouDiZhu项目
* 初始化项目

目前cocos2d-x的官方最新版本为3.16，可以在[cocos2d-x官网](http://www.cocos2d-x.org)上自由下载使用。按照官方使用的Readme.md或其它资料完成配置后，可以使用以下命令创建项目：

    cocos new DouDiZhu -p com.cronlygames.landlord -l lua -d projects

创建后，再把DouDiZhu这个项目的目录移动到github库DouDiZhu下，并改名为code 。为了使用和理解方便，github库DouDiZhu是放在Desktop这个目录里
    
    CronlyGames@MacBook-Pro-15 DouDiZhu $ pwd
    /Users/CronlyGames/Desktop/DouDiZhu

本目录下所有内容为:

    CronlyGames@MacBook-Pro-15 DouDiZhu $ tree -L 2
    .
    ├── LICENSE
    ├── README.md
    ├── images
    └── code
        ├── config.json
        ├── frameworks
        ├── res
        ├── runtime
        └── src

    5 directories, 3 files

其中code目录就是刚才用 cocos new 所创建DouDiZhu项目，images目录存放本文中所使用到的所有图片。
git commit 提交改动，

    commit 3787c58f9d7cb74c4d8e576e3f3947b81f3f1882 (HEAD -> chap1_environment)
    Author: Zhou Weikuan <zhouweikuan@gmail.com>
    Date:   Tue May 22 10:47:32 2018 +0800

    add the original DouDiZhu project, and rename the directory to code
    
* iOS & android 运行成功

对于iOS项目，在MacOS下点击 DouDiZhu/code/frameworks/runtime-src/proj.ios_mac/DouDiZhu.xcodeproj，编译运行即可。同时我们需要更新图标，产品名称等。
对于android项目，我们使用的是Android Studio，导入目录DouDiZhu/code/frameworks/runtime-src/proj.android-studio 。由于环境和参数不同，编译时有很多错误。根据当前环境修改gradle.build，多个properties文件和AndroidManifest.xml，更新图标等，最终保证可以编译成功，并运行在测试机器上。

此时提交改动:

    commit acc5f9ef24e4f608f22a331e8bfcbc2cb392d48f (HEAD -> chap1_environment)
    Author: Zhou Weikuan <zhouweikuan@gmail.com>
    Date:   Tue May 22 13:22:01 2018 +0800

        更改图标，产品名称，保证可以运行在iOS & android上; 使用的是Android Studio

### 升级lua到5.3

我们的服务器是基于skynet，而skynet使用的lua版本为5.3。为了更好的复用lua代码，我们需要把cocos2d-x的lua版本也升级到[lua 5.3](http://www.lua.org/ftp/lua-5.3.4.tar.gz)。在code目录下新建3rd目录，并且下载lua后解压缩src到3rd/lua目录，去掉Makefile文件。结构如下:
    
    code/3rd/lua/
        ├── lapi.c
        ├── lapi.h
        ├── lauxlib.c
        ├── lauxlib.h
        ├── ...

提交所有lua文件，    
    
### 加入protobuf
### 加入游戏资源
### 一些公用函数库
### 各场景划分

## 第二章、实现游戏的流程

### 联网版本的接口
### C库到lua的接口
### 手牌的一些规定
### 游戏的基本流程
### 完成简单AI版的整个游戏

## 第三章、核心AI逻辑

### 牌型说明
### 牌型权重
### 手牌的拆分
### 出牌与跟牌
### 角色定位
### 尾牌打法

## 第四章、深度学习畅想

### 使用模型获得牌型的权重
### 分清角色特征 地主 上家 下家 相互配合或者压制
### 自动根据牌局状况，调整出牌容忍度
### 最后尾牌阶段的拆牌，引诱，欺骗



