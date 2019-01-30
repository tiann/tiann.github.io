title: "Android Studio你不知道的快捷键(一)"
date: 2015-12-11 13:42:33
tags:
- android
categories:
- 实用技巧
---

一般来说键盘用的越多鼠标用的越少，那么写起代码来效率就越高；常见的快捷键想必大家都已经掌握，接下来我就分享一些你可能不知道的但确非常实用的快捷键。

> 下文所有快捷键基于如下keymap
> Windows: Default
> Linux: Default
> OSX: Mac OSX 10.5+

## 自动补全的时候是Enter还是Tab？

<img src="http://http://weishu1.dimensionalzone.com/blog2015-12-11-1.gif" alt="自动补全enter和tab区别" width="252"/>
在使用自动补全的时候`Enter`和`Tab`的行为还是有一些细微的区别的：
<!-- more -->
1. 使用`Enter`会补全你选择的语句
2. 使用`Tab`的话，会替换掉你之前在这里的内容（删除后面的语句直到遇到点号，逗号，分号）

这种情况我们还是会经常遇到的，比如要替换一个资源的ID（R.id.a_xxx_xxx)，想必大多数人都是先选择`a.xxx_xxx`删除，然后输入新的内容，或者相反；其实这时候，用`Tab`才是最优雅的方式。

快捷键：（在补全的时候)**`Enter/Tab`**

## 返回编辑器窗口

<img src="http://http://weishu1.dimensionalzone.com/blog2015-12-11-2.gif" alt="返回编辑器窗口" width="550" />
正在写代码的时候，很多操作会让焦点脱离编辑器；比如*Find Usage*, *Logcat*, 切换到项目结构视图，类型继承树等；如果视图切换了如何快速切回编辑器继续写代码呢？简单的鼠标点一下编辑器就可以了，但其实还有两种选择：
1. `Esc`: 让编辑器窗口获取焦点，这时候就可以输入代码了
2. `Shift + Esc`: 这个会让编辑器获取焦点，并且顺手帮你把刚刚打开的窗口关闭了。

个人喜欢第二种；Find Usage完毕了，`Shift + Esc`, 优雅～

1. `Esc`: 返回编辑器
2. `Shift + Esc`: 返回编辑器并关闭当前窗口

## 返回上次打开的工具窗口

<img src="http://http://weishu1.dimensionalzone.com/blog2015-12-11-3.gif" alt="返回最后打开的工具窗口" width="495" />
接上面那个功能，如果你`Shift + Esc` 写了一会儿代码，发现又需要打开刚刚的窗口怎么办？这种场景通常发生在*Logcat*这个Tol Window上，看完了日志，写代码，写完代码看日志；如何快速切换？

快捷键：`F12`

## 快捷打开窗口

<img src="http://http://weishu1.dimensionalzone.com/blog2015-12-11-4.gif" alt="使用数字快捷打开窗口" width="567" />
有木有发现有的窗口上面有个数字？这样的窗口（工具窗）我们可以快捷打开！

- Mac: `Cmd + 数字`
- windows/Linux: `Alt + 数字`

## 任意窗口切换

<img src="http://http://weishu1.dimensionalzone.com/blog2015-12-11-5.gif" alt="窗口切换" width="532" />
上面的切换还是无法满足你的要求？记得Mac的`Cmd + Tab`，Windows的`Alt/Win + Tab`吗？Android Studio也有这个类似的功能，可以让你切换到任意窗口！

在这个切换窗口打开的时候，你可以直接按数字切换到对应的工具窗口，或者输入字母搜索右边的编辑器窗口，如果你需要关闭某个窗口，在上面按`BackSpace`即可。

快捷键：`Ctrl + Tab`

## 隐藏所有窗口

<img src="http://http://weishu1.dimensionalzone.com/blog2015-12-11-6.gif" alt="隐藏所有窗口" width="566" /> 
好了学了那么多打开窗口的技能，如果你想关闭那些乱七八糟的窗口，安安静静写代码应该怎么办？

- Mac: `CMD + Shift + F12`
- windows/Linux: `Ctrl + shift + F12`

如果需要恢复所有窗口，再按一次这个快捷键即可。

## 参数提示

<img src="http://http://weishu1.dimensionalzone.com/blog2015-12-11-7.gif" alt="参数提示" width="472" />
这个功能估计很多人知道了，但是还是提一下。在自动补全以后，如果某个方法参数超级长，你不知道参数是什么怎么办？可以试试这个。

- Mac: `CMD + P`
- win/Linux: `Ctrl + P`


