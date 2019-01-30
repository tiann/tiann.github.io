title: "Android插件化原理解析——剧终"
date: 2018-08-27 12:59:21
tags:
---

从我写下 [Android插件化原理解析](http://weishu.me/2016/01/28/understand-plugin-framework-overview/) 系列第一篇文章至今，已经过去了两年时间。这期间，插件化技术也得到了长足的发展；与此同时，React Native，PWA，App Bundle，以及最近的Flutter也如火如荼。由于实现插件化需要太多的黑科技，它给项目的维护成本和稳定性增加了诸多不确定性；我个人认为，2017年手淘Atlas插件化项目的开源标志着插件化的落幕，2018年Android 9.0上私有API的限制几乎称得上是盖棺定论了——曾经波澜壮阔的插件化进程必将要退出历史主流。如今的插件化技术朝两个方向发展：其一，插件化的工程特性：模块化/解耦被抽离，逐渐演进为稳定、务实的的组件化方案；其二，插件化的黑科技特性被进一步发掘，inline hook/method hook大行其道，走向双开，虚拟环境等等。

虽然插件化终将落幕，但是它背后的技术原理包罗万象，值得每一个希望深入Android的小伙伴们学习。

很遗憾曾经的系列文章没有写完，现在已经没机会甚至可以说不可能去把它完结了；不过幸运的是，我的良师益友包老师（我习惯称呼他为包哥）写了一本关于插件化的书——《Android插件化开发指南》，书中讲述了过去数年浩浩荡荡的插件化历程以及插件技术的方方面面；有兴趣的小伙伴可以买一本看看。

<!--more-->

[![点击购买](http://http://weishu.dimensionalzone.com/201605/1535348090511.png)][1]


[1]: https://item.m.jd.com/product/31188356430.html?utm_source=iosapp&utm_medium=appshare&utm_campaign=t_335139774&utm_term=Wxfriends
