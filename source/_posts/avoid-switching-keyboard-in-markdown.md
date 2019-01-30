title: 提升markdown的中文输入效率
date: 2016-02-01 16:15:56
tags:
- markdown
categories:
- 实用技巧
---

Markdown这种格式的出现大大提升了写作的效率，但是它对于非英文的用户其实并不友好：每当我们需要使用`#[-`等标志符的时候，需要不断地切换输入法。

首先，切换输入法(就算是按`shift`键)让我们的思维不连贯；其次，一旦中间有一次切换出错，那么又有撤销的成本；我相信每一个非英文markdown的使用者都有这种困惑；实际想要达到的效果如下：

![效果图](http://http://weishu.dimensionalzone.com/201602markdown_keymap_remapping.gif)

<!--more-->
避免输入法切换最简单的办法就是把markdown使用的那些特定字符`!-[]#*()`，直接使用半角符号代替全角符号；完成这个功能最好的角色是输入法；但目前除了可以定制的鼠须管等能完成，其他的国产输入以及系统输入法都不支持；在第三方输入法支持这个功能之前，我这里给出一个简单的方案。

### 如果你使用鼠须管

鼠须管/小狼嚎 输入法是可以定制的，如果你是这种输入法的用户，那么恭喜你，实现方式非常简单；修改一下配置即可，具体做法见[调整「鼠须管」实现高效的Markdown输入][1]

### 如果你使用Mac

如果你使用第三方输入法或者mac的系统输入法，那么我们可以通过修改键盘映射来解决这个问题：把全角的markdown映射为半角符号。具体做法如下：

##### 安装Karabiner软件

下载地址点[这里][2]；按照步骤安装，注意开启之后需要在系统设置里面给它使用辅助功能权限

##### 设置键盘映射

首先，打开Karabiner软件，选择`Misc&Uninstall`选项卡，如下图：

<img src="http://http://weishu.dimensionalzone.com/201601/1454310098796.png" width="740"/>

然后，点击上图标识的`open private.xml`那个按钮，用文本编辑器打开这个文件：

<img src="http://http://weishu.dimensionalzone.com/201601/1454310263101.png" width="574"/>

接着去 [gist][3]上把`markdown_keyboard_remapping.xml`里面的代码copy到这个文件里面，全部替换即可(代码有点长，我就不贴了，自行[下载][3])：

最后，打开Karabiner软件的第一个选项卡，重新加载配置就完成了，如下图：

<img src="http://http://weishu.dimensionalzone.com/201601/1454310388700.png" width="771"/>

### 如果你使用Windows

Windows下面有神器`AutoHotKey`，解决这个完全不在话下；与Mac下面简单粗暴地直接把全角符号替换为半角符号不同，AHK可以保留原来的方案，用`alt ＋ 符号`来输入需要的半角符号；这样两种可以共存。

1. 首先，安装AHK软件，下载点[这里][3]
2. 然后下载文件[markdown_keyboard_remapping.ahk][3]

接着双击这个文件，整个过程就完成了；最好把这个文件加入开机启动，这样每次开机就能用了。

Windows下面的使用方法是`alt ＋ 数字键/符号键`；比如想输入`[`，可以在任何输入法下直接使用`alt ＋ [`；如果想输入`#`，可以直接使用`alt ＋ 3`。

通过这种设置，我们使用markdown写作的时候就流畅多了!避免了繁琐的各种切换，真正享受到markdown格式的好处，Have Fun!

[1]: http://irising.me/2013/07/17627/
[2]: https://pqrs.org/osx/karabiner/
[3]: https://gist.github.com/tiann/9068fd34f44337e8dcfb
