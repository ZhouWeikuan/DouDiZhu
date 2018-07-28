# 斗地主AI设计与实现

![宽立斗地主](http://www.cronlygames.com/image/landlord.png) [宽立斗地主](http://www.cronlygames.com/download/download.php?p=com.cronlygames.landlord) 是 [上海宽立信息技术有限公司](http://www.cronlygames.com/)出品的一款斗地主游戏，内置了基于权重的斗地主游戏AI算法。这种算法是我们过去几年在棋牌游戏上的经验体现，稍加修改，算法可以很容易的拓展到其他类似棋牌游戏上，如掼蛋，争上游，拖拉机等。本文将详细介绍从头开始，如何一步一步建立一个比较高智力的斗地主游戏算法。

This repository will talk about AI algorithms for a chinese famous card game - landlord or DouDiZhu, it is based on weights.

## 第0章、致敬BlueDJ
本人自2011年开始进入移动行业创业，开始做的是连连看，满天星等休闲小游戏，对棋牌游戏很感兴趣但一直无法入门。后来在网上找到一套开源的棋牌游戏大厅和客户端，即bluedj；经过一段时间的尝试，先在Linux平台上搭建好服务器，再花了一段时间把客户端从QT移植到iOS的ObjC下，终于踉踉跄跄开始棋牌游戏开发生涯。可以说，没有bluedj，很大可能上就没有本文的诞生。


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

* 下载最新的lua版本

我们的服务器是基于skynet，而skynet使用的lua版本为5.3。为了更好的复用lua代码，我们需要把cocos2d-x的lua版本也升级到[lua 5.3](http://www.lua.org/ftp/lua-5.3.4.tar.gz)。在code目录下新建3rd目录，并且下载lua后解压缩src到3rd/lua目录，去掉Makefile文件。结构如下:
    
    code/3rd/lua/
        ├── lapi.c
        ├── lapi.h
        ├── lauxlib.c
        ├── lauxlib.h
        ├── ...

提交所有lua文件，

    commit 9b55634bf0b799fb014aa3f05651bd86b482e4d9 (HEAD -> chap1_environment)
    Author: Zhou Weikuan <zhouweikuan@gmail.com>
    Date:   Tue May 22 13:31:52 2018 +0800

        增加lua 5.3文件，准备修改    

* 支持 64位

为了同时兼容64位和32位操作系统，我们把ldump.c, lundump.c里的的函数DumpHeader, checkHeader中所使用到的size_t改为int。iOS新版不再支持system命令，修改loslib.c，用-1去掉system函数调用。 

* 项目里加入lua 5.3 支持   

lua升级到5.3时，参考了网友的[心得](http://yestein.com/2015/06/09/%e5%b0%86cocos2dx%e9%87%8c%e7%9a%84lua%e5%8d%87%e7%ba%a7%e8%87%b35-3/)。我们只支持iOS和android，不考虑windows，步骤更简单

1. 删除 DouDiZhu/code/frameworks/cocos2d-x/external/lua 下的 lua目录和luajit目录
2. 修改 DouDiZhu/code/frameworks/cocos2d-x/external/lua/tolua 目录下的 tolua_event.c, tolua_map.c, tolua_push.c 这三个文件；主要是uservalue和fenv之间的替换
3. 修改 code/frameworks/cocos2d-x/cocos/scripting/lua-bindings/manual目录下的 CCLuaStack.cpp, lua_extensions.c, tolua_fix.cpp 这三个文件，也是与2.类似，替换成lua 5.3的语法
4. iOS下，修改所有的项目文件，cocos2d_lua_bindingds.xcodeproj里，加入lua目录作为group，并修改所有引用到的项目文件，修改lua的User Header Search Paths，去掉luajit，并加入新版lua的相对目录；修改Preprocessor Macros，加入LUA_COMPAT_5_1, LUA_COMPAT_APIINTCASTS，并把CC_ENABLE_CHIPMUNK_INTEGRATION=1改成CC_ENABLE_CHIPMUNK_INTEGRATION=0，因为根本用不到chipmunk
5. android下，修改 DouDiZhu/code/frameworks/cocos2d-x/cocos/scripting/lua-bindings/proj.android/Android.mk 文件，主要是把之前的旧版本lua和luajit换成新版本的位置和参数；编译时通不过，需要调整若干新版本lua的文件
6. DouDiZhu/code/frameworks/cocos2d-x/plugin 这个目录基本没用，删除！ 所有Deprecated的lua文件基本没用，删除！ lua 5.3有自己的位操作，以前的bitExtend也不要了！

以上修改提交信息如下:

    commit 2778dd451e94f5ce6a825bb89c28b4538dc1e101 (HEAD -> chap1_environment)
    Author: Zhou Weikuan <zhouweikuan@gmail.com>
    Date:   Tue May 22 16:08:16 2018 +0800

        升级 lua 5.3

### 加入protobuf
客户端与服务器交互时，使用的是protobuf，版本是2.x 。首先我们需要下载Google提供的protobuf，编译安装后得到protoc命令，用来编译.proto文件到.pb 。然后在lua里支持protobuf，我们用的是pbc这个库。从github上下载pbc后，放在 code/3rd/protobuf，针对lua5.3剪裁文件。

对于iOS，需要在项目里加入protobuf整个目录；对于android，需要把所有.c文件 和.h的路径 加入Android.mk，同时把脚本文件 protobuf.lua加入build.gradle，这样编译时就会自动拷贝到assets目录。

以上修改提交后显示如下:

    commit 624d8c8f0076b307e75baca7913660d4086c8476 (HEAD -> chap1_environment)
    Author: Zhou Weikuan <zhouweikuan@gmail.com>
    Date:   Tue May 22 17:22:44 2018 +0800

        加入protobuf相关文件

### 加入游戏资源
关于资源文件，我们用的是之前运城斗地主的资源，放在res目录下，子目录有:

    all         游戏中的背景图片和本地化字符串文件
    both        TexturePacker打包后的图片文件
    eff         游戏内的spine动画效果
    gift        与其他玩家互动的礼物效果
    music       不同场合下的背景音乐
    protos      protobuf的pb文件和本地的cfg游戏相关配置文件
    sounds      声音效果，包括男女音效和触发的场合音效等
    
以上资源文件版权归属上海宽立和周为宽共同所有，可以在本地学习使用，但不得再发布，更禁止在商业环境使用；版权所有，违法必究！

### 一些公用函数库
同时，游戏里也有一些公用的库和函数，这里列出如下：

    Algos       算法和数据结构
        \ -     NumArray.lua            可以获得元素个数的数值
        \ -     NumSet.lua              可以获得元素个数的集合
        \ -     PriorityQueue.lua       有优先级的队列
        \ -     Queue.lua               先进先出的队列
        \ -     SeatArray.lua           可以获得元素个数的座位

    Helpers
        \ -     DBHelper.lua            数据库处理
        \ -     DebugHelper.lua         调试打印信息
        \ -     FilterHelper.lua        过滤
        \ -     PacketHelper.lua        protobuf处理
        \ -     StringHelper.lua        字符串处理
        \ -     TableHelper.lua         处理lua的table
        
    Classes
        \ -     GameTable.lua           棋牌游戏的通用接口
        \ -     HallInterface.lua       通用游戏大厅的接口
        \ -     ProtoTypes.lua          通用的属性定义
        \ -     RoomInterface.lua       继承自HallInterface, 棋牌类游戏大厅的实现
        \ -     Const_YunCheng.lua      运城斗地主的通用常量定义
        \ -     Table_YunCheng.lua      运城斗地主的服务器端流程处理，继承自GameTable
        
    utils
        \ -     AIPlayer.lua            本地的人物属性
        \ -     Constants.lua           常量和UI通用函数 
        \ -     Settings.lua            保存本地数据
        \ -     SoundApp.lua            声音
        \ -     YunCheng_BotPlayer.lua  客户端回调处理


### 各场景划分
对于单机斗地主，场景比较少。游戏开始时，调用MainScene.lua显示启动界面，然后自动跳转到LineScene.lua，点击游客登录后，进入GameScene.lua，开始游戏。
GameScene.lua主要是初始化游戏玩家信息，实现一个周期性tick函数来驱动游戏流程，然后在CommonLayer.lua里显示界面。
CommonLayer.lua再调用ClockLayer.lua显示时钟倒计时，PlayerInfoLayer.lua显示玩家信息，SettingLayer.lua进行设置，UIHelper.lua辅助处理，MsgBox.lua显示弹窗等。

### C/C++相关文件
同时对code/frameworks/runtime-src/Classes下增加如下文件:

    AutoLock.h/cpp                  线程锁，防止多线程重入
    LuaCall.h/cpp                   向lua中注册c/cpp库
    luaproc.h/c                     lua异步线程库，避免AI算法太耗时，锁住UI线程
    PermutationCombine.h/cpp        从N个数中选M的算法 (M <= N)
    YunChengAI.h/cpp                斗地主的AI核心算法
    LuaYunCheng.h/cpp               斗地主的游戏流程包装，供lua调用

YunChengAI和LuaYunCheng中目前为空，或者被注释，我们下一章会先写一个最简化的游戏AI，然后再优化。

### 本章总结
由于本文主要内容是介绍单机斗地主的AI实现，本章介绍的是实现AI前的环境设置，告诉读者有哪些内容，需要哪些实现，但具体的实现细节和说明比较简略，以后有时间再完善。 本章最后提交信息如下:

    commit e48fdb66d4ca16dc7bf4b3b4345f5db397560c58 (HEAD -> chap1_environment)
    Author: Zhou Weikuan <zhouweikuan@gmail.com>
    Date:   Thu Jul 19 13:41:30 2018 +0800

        第一章，前提环境介绍完成



## 第二章、实现游戏的流程
由于之前的游戏是一个整体，我分拆移植到现在的项目后，目前仍然不能通过编译，无法运行。我们在本章将逐步完善YunChengAI.h/cpp，让它通过编译；并实现一个最简单版本的AI，即每次开始新一轮出牌时，只出一张手上有的最小的牌；跟牌时，也是出那张可以打过上次出牌的最小的那张牌。也就是说，本章完成后，会有一个AI最小化的运行版本。

### 文件功能说明
HallInterface.lua 实现了一个通用的棋牌游戏、休闲游戏的大厅接口；RoomInterface.lua继承自HallInterface.lua，实现棋牌游戏大厅内桌位的管理，换桌等功能。GameTable.lua则实现一个棋牌游戏桌与用户交户和游戏时的各种接口。ProtoTypes.lua则规定了所有游戏都通用的属性定义和通讯协议。

对于斗地主游戏，我们可以不用太多关注上面的实现细节，把主要精力放在 Const_YunCheng.lua, Table_YunCheng.lua, YunCheng_BotPlayer.lua 这三个文件上面。

### Const_YunCheng.lua 
本文件是对斗地主游戏的常量定义。

1. 首先设置const的metatable，避免引用到未定义的空值；
2. 然后定义游戏的ID和版本号；
3. 再定义游戏的特殊牌值和常量，以及面值和牌型等；
4. 然后是游戏客户端服务器端相互沟通时的协议数值，游戏桌的状态和各状态的等候时间; 
5. 再后是游戏的各种出错情况定义；
6. 再后是各种辅助函数；
7. 最后是等级说明。

### Table_YunCheng.lua
本文件是游戏的服务器核心模块。

玩家在加入游戏，进入桌子，等到足够的准备好的玩家后，游戏从本文件的gameStart函数正式开始。gameStart初始化整个游戏所需要的信息，并用gametrace发送给桌上的玩家，然后进入各种不同的等候状态。再等候时，接收玩家的输入并进行相关的处理，如果等候超时，会自动按默认输入处理。处理完成后，进入下一状态。如此循环往复，最后等某个玩家所有的牌出完，游戏终止，进入yunchengGameOver函数。

本文件的主要函数如下:

1. gameStart           游戏开始，初始化数据
2. yunchengGameOver    游戏结束，处理各玩家得分
3. yunchengGameTrace   接收用户输入，并进行相关处理
4. yunchengTimeout     各状态超时，自动处理

在游戏过程中，主要分成 发牌阶段，叫地主阶段，出牌阶段，结束阶段等。

### YunCheng_BotPlayer.lua
本文件主要是客户端的通讯处理和机器人AI部分。

主要包括收发包，发包的简单包装，对接收到的信息的进行处理，再判断服务的对象，是玩家通知UI更新，是机器人进行AI处理等。

由于AI比较耗时，为了不卡顿UI，我们用luaproc另起一个线程处理AI部分。主线程每隔一段时间检查luaproc结果，有结果再继续。对luaproc包装后，必须新建一个coroutine来调用 run_long_func，然后在主线程里调用check_long_func使得coroutine可以在有结果后继续进行。

### C库到lua的接口
LuaYunCheng.h/cpp 为整个游戏流程提供了来自C++的完整AI库。包括以下几个部分

1. 环境设置类

    updateSeats     更新地主和当前玩家
    
    addHistCards    出牌历史记录
    
    setHandCards    玩家具体的手牌
    
    getHandCards
    
    setHandCount    手牌设置，只知道别人的牌数
        
2. 牌面排序调试
    
    sortMyCards         手上的牌按面值排序
    
    removeSubset        根据子集，移除那部分手牌
    
    debugSnakeInfo      可视化输出手牌信息
    
3. 叫地主辅助

    getWinPossible      做地主的胜率猜测
    
    bigEnough           手牌太大？必须做地主！
    
4. 出牌提示

    getNodeType             之前所出牌的牌型
    
    calcPowerValue          计算手上所有牌的权重
    
    canPlayCards            选择的牌可以打过之前的牌吗？
    
    getDirectPrompts        直接出牌时的所有可能
    
    getFollowPrompts        跟打别人的牌的所有可能
    
5. 机器人出牌

    robotFirstPlay          机器人直接出牌
    
    robotFollowCards        机器人跟牌

值得注意的是，由于calcPowerValue, getDirectPrompts, getFollowPrompts, robotFirstPlay, robotFollowCards这些函数执行时有可能会花费比较长一点的时间，为了避免卡顿UI，我们可以使用luaproc另起一个线程。这个可以通过getLight函数获取YunChengGame的数据裸指针，在luaproc里调用相关函数执行。

### 简单的AI版
目前YunChengAI.h/cpp还是阉割版，只包括可以支持LuaYunCheng.h/cpp的最小代码。

为了方便介绍斗地主的AI如何实现，我们现在所写的代码只能按照一个最简单的逻辑来执行：每次出牌时，选择手牌里最小的那张可出牌，即如果是直接出牌，就选择面值最小的那张牌，如果是跟牌，选择可以打过对方的面值最小的牌，找不到的话就不出。

目前AI里实现的模块有:

1. 最基本的常量数值定义，包括基本的面值，和一些特殊的牌值，牌型等;
2. AINode，每次出手的牌型结构
3. OneHand, 计算手牌权重时的辅助结构
4. LordCards, 每个人的手牌
5. YunChengGame, 游戏的结构定义

### 目前游戏的整体情况
由于UI方面的lua代码基本没动，因此现在游戏可以正常运行，每人每次只出一张牌，打过上家；无牌可打时，上一轮的赢家开始下一轮，直到有人出完牌为止。现在AI的核心代码基本上达到了我们的预期，具体细节我们下一章再解释。

## 第三章、核心AI逻辑

### 牌型说明

### 牌型权重

### 手牌的拆分

### 出牌与跟牌

### 角色定位

### 尾牌打法

### 癞子算法

## 第四章、深度学习优化

### 使用模型获得牌型的权重

### 分清角色特征 地主 上家 下家 相互配合或者压制

### 自动根据牌局状况，调整出牌容忍度

### 平时的接牌，防止地主出牌，和最后尾牌阶段的拆牌，引诱，欺骗



