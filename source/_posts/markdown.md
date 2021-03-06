---
title: Hexo部署和Markdown使用
date: 2017-05-11 17:35:13
tags: [Hexo,Markdown]
---
  Hexo部署和Markdown标记的使用介绍
<!--more-->
# Hexo
## [创建一个新页面](https://hexo.io/docs/writing.html)
``` bash
$ hexo new "page"
```
## [启动服务](https://hexo.io/docs/server.html)
``` bash
$ hexo server
```
## [生产静态文件](https://hexo.io/docs/generating.html)
``` bash
$ hexo generate
```

## [静态文件发布](https://hexo.io/docs/deployment.html)
``` bash
$ hexo deploy
```

# Markdown标记使用

## 标题
使用=和-标记一级和二级标题。
```
一级标题
=========
二级标题
---------
使用#，可表示1-6级标题。
# 一级标题
## 二级标题
### 三级标题
#### 四级标题
##### 五级标题
###### 六级标题  
```

## 段落

  段落的前后要有空行，所谓的空行是指没有文字内容。  
  若想在段内强制换行的方式是使用两个以上空格加上回车（引用中换行省略回车）。

## 区块引用
在段落的每行或者只在第一行使用符号>,还可使用多个嵌套引用，如：  

>  区块引用
>>  嵌套引用

## 代码区块
代码区块的建立是在每行加上4个空格或者一个制表符（如同写代码一样）。如
普通段落：  

    void main()
    {
        printf("Hello, Markdown.");
    }
```
    void main()
    {
        printf("Hello, Markdown.");
    }
```
## 强调
在强调内容两侧分别加上*或者_，如：

*斜体*，_斜体_
**粗体**，__粗体__

## 列表

使用·、+、或-标记无序列表，如：

-（+*） 第一项 -（+*） 第二项 - （+*）第三项
- 第一项 
- 第二项 
- 第三项  

+ 第一项 
+ 第二项 
+ 第三项
* 第一项 
* 第二项 
* 第三项

1. vvvv
2. vvv
3. 第一项 
4. 第二项 
5. 第三项
```
注意：标记后面最少有一个_空格_或_制表符_。若不在引用区块中，必须和前方段落之间存在空行。
```
## 分割线
---
___
***
## 表格
| aaa | bbb | ccc |
| :-- | :-- | :-- |
| aaa | bbb | ccc |

| 采购时收到的发票类型 | 销售时开具的发票类型 | 交税逻辑 | 采购时收到的发票类型 | 销售时开具的发票类型 | 交税逻辑 |
| :---------------- | :---------- | :- | :- | :- | :- |
| 增票 | 增票| 销售增值税 - 采购增值税 |
| 增票 | 普票| 销售普票税 |
| 普票 | 普票| 销售普票税 |

## 链接

链接可以由两种形式生成：行内式和参考式。
行内式：

[younghz的Markdown库](https://github.com/younghz/Markdown "Markdown")。

参考式：

[younghz的Markdown库1][1]  
[younghz的Markdown库2][2]  

[1]:https://github.com/younghz/Markdown "Markdown" 
[2]:https://github.com/younghz/Markdown "Markdown" 

## 图片

添加图片的形式和链接相似，只需在链接的基础上前方加一个！。
![头像图片](/images/head.png "head pic")

## 反斜杠\

相当于反转义作用。使符号成为普通符号。\# sss

## 符号'`'

起到标记作用。如：
`ctrl+a`
