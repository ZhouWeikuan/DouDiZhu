# 斗地主AI设计与实现

![宽立斗地主](http://www.cronlygames.com/image/landlord.png) [宽立斗地主](http://www.cronlygames.com/download/download.php?p=com.cronlygames.landlord) 是 [上海宽立信息技术有限公司](http://www.cronlygames.com/)出品的一款斗地主游戏，内置了基于权重的斗地主游戏AI算法。这种算法是我们过去几年在棋牌游戏上的经验体现，稍加修改，算法可以很容易的拓展到其他类似棋牌游戏上，如掼蛋，争上游，拖拉机等。
This repository will talk about AI algorithms for a chinese famous card game - landlord or DouDiZhu, it is based on weights.


## 第一章、环境初始化

### 建立DouDiZhu项目
### 升级lua到5.3
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



