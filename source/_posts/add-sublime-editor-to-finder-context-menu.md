title: "把Sublime添加到Mac右键菜单"
date: 2015-12-31 14:53:20
tags:
- mac
- sublime
---

虽然大部分的时候是使用命令行，但是有些时候我们需要在`Finder`里面编辑某些文件的时候，如果还是拘泥于这样，就必须打开 `iTerm` （幸好有Profile可以一键打开终端）切换目录，编辑；这时候，类似Windows系统的右键菜单就比较方便了。

如果Mac系统识别出这是一个文本文件，右键菜单的 **打开方式** 可能还有点用，如果识别不出来，那么手动选择应用程序就比较麻烦了：

<img src="http://7xp3xc.com1.z0.glb.clouddn.com/201512/1451545353007.png" width="385"/>

其实Mac系统的 **AutoMator** 是可以完成这个功能的；接下来说一下操作步骤。

<!--more-->

- 打开 `Automator` 这个程序（可以使用Spotlight或者Alfred直接搜索），在弹出的菜单中选择 **服务**
<img src="http://7xp3xc.com1.z0.glb.clouddn.com/201512/1451545516628.png" width="545"/>

- 在左上角的搜索框搜索 `Finder` 然后在结果里面选择 `打开Finder项目`
；然后把它拖到右边：

<img src="http://7xp3xc.com1.z0.glb.clouddn.com/201512/1451545618554.png" width="832"/>

- 拖到右边之后，设置打开方式为「Sublime Text 2」，上面设定为“服务”收到选定的「文件或文件夹」位于「Finder」；

<img src="http://7xp3xc.com1.z0.glb.clouddn.com/201512/1451545743958.png" width="616"/>

- 然后保存项目 (Cmd + S), 写上这个操作的名字，比如 *Open in Sublime Text*

<img src="http://7xp3xc.com1.z0.glb.clouddn.com/201512/1451545891571.png" width="390"/>

这时候，进入 `Finder` 选择一个文件或者文件夹，点击右键：

<img src="http://7xp3xc.com1.z0.glb.clouddn.com/201512/1451545999524.png" width="228"/>

OK，大功告成！如果想添加别的编辑器，按照类似的操作即可。

但是，还有几个问题说明一下：

- 右键菜单没有，出现在**服务**二级菜单

有的童鞋按照这一步设置完毕之后，发现并没有直接在右键菜单出现，而是出现在服务二级菜单！这样每次都需要多点击一次，很不爽！如下图：

<img src="http://7xp3xc.com1.z0.glb.clouddn.com/201512%2F1451546296324.png" width="443"/>

这时候，其实是服务菜单里面内容太多了，因此Mac系统自动把菜单收缩到了二级菜单。可以到「系统偏好设置…」-「键盘」-「服务」中去掉不需要的选项。

<img src="http://7xp3xc.com1.z0.glb.clouddn.com/201512/1451546545636.png" width="620"/>

- 如何删除

如果弄错了，想删除掉；直接去 `~/Library/Services` 删除对应的目录即可。

