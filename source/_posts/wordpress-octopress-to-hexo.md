title: 'wordpress&octopress to hexo'
date: 2015-09-22 18:58:30
tags: 
- hexo 
---
纠结了一晚上，终究是打算从octopress切换到hexo了；平心而论，octopress没有什么不好；总结一下为什么切换：

1. 默认主题不好看，第三方主题没有想要的好的；自己定制了两天，在mac上效果不错，但是看到windows上渣显示效果瞬间放弃。总结起来，博客清晰简洁，最好不要图片，特别是大图；在高清显示器会很舒服，在渣渣显示器上就是一坨翔；最好使用颜色搭配简单动画；其次是越简洁越好，什么酷炫高大上看多了都是浮夸；
2. 虽然hexo在github上star比octopress少，但是hexo 提交次数将近三倍，然后octopress几年不更新了，最近要出3.0不知道什么鬼；hexo的主题star比octopress多得多；而且我看到的几个都简洁大方，很是喜欢
3. octopress用ruby渲染，hexo用nodejs；以前不知道什么原因不喜欢js，但是学一学也是好的，刚好最近facebook开源了Android版本的react native，借这个机会顺带装一下nodejs也算好；至于ruby，已经会了一门类似的python，但是拓宽一下知识面比较好；另外，时间肯定严重不够。

<!--more-->
4. 虽然学习node比ruby对于我肯定时间多，但是第三方主题好意味着我不需要花太多时间定制，反而节省了时间。

另外，附上一片[octopress-vs-hexo/](http://www.techelex.org/octopress-vs-hexo/)

## 开始
好了，开搞。按照官方[教程](https://hexo.io/zh-cn/docs/)。

sock5协议在shell里面 http代理是否有效？curl与wget 协议支持情况？浏览器能下载，shell无法curl。

### 准备
需要安装git以及nodejs；
1. git的话mac安装xcode-tools即可。

#### nodejs安装
1. nvm 管理nodejs版本的，避免把你的电脑搞乱，跟rbenv以及python virtualenv差不多。装这个下载脚本的那个需要翻墙。
2. 用nvm安装nodejs。可以使用七牛的镜像。注意的是hexo推荐的是**0.10**这个版本，我尝试了最近的4.1，执行hexo命令直接出错。有了nvm我们可以多装几个版本无所谓，反正能切换。
3. 注意，node安装之后重启shell  npm无法找到，原因是nvm不知道那个💺默认的node版本，所以  `nvm alias default stable`即可。

### hexo安装
没什么，一条命令。想到之前用octopress的蛋疼，简直官方文档说安装命令 `npm install -g hexo-cli`通过淘宝镜像的cli可以猜到，这个是需要服务器同步然后安装的，我用了第三方的镜像，去掉这个cli即可。

至此，环境搭建完成。

## 改造

### 主题
个人喜欢两个主题：
1. [next](https://github.com/iissnan/hexo-theme-next)简洁大方，非常nice；更新频繁，维护者众多，有保障。
2. [huno](https://github.com/someus/huno)还是对这种侧边栏有某种情结，但实际上有一些问题我暂时还解决不了静态博客也不擅长这个；那就是侧边栏如果有头像或者图片背景的时候，跳转页面不可避免地导致页面刷新和闪动，极不自然。

另外有个主题[yilia](https://github.com/litten/hexo-theme-yilia)也不错。但是个人还是感觉有点乱，不够简约。不过移动端适配做的挺好的，可以试试。

最终选择next，开启mist效果。

### 头像
2. 使用头像，起名  Zygote 在Android里面是天字号进程，又意为受精卵，象征着生命和希望。
3. 往上找了一只萌猫的图就当作头像了，我是猫系男生嘛～

### 字体
放弃了，windows上 main字体不好看，显示器的原因。在mac那些个Open Sans，Manaco什么的都很漂亮；Windows配个渣渣显示屏那真的是肉眼看到一坨坨像素。估计是被Retina惯坏了，哎，，勿黑。

默认的还可以。要修改的话见这里https://github.com/iissnan/hexo-theme-next/issues/111

### 自定义页面
添加tags页面，什么关于页面嘛，现在不太好意思加～以后再说。个人不喜欢什么SNS，搞了也不活跃，一个人安安静静地写博客，多好。

### 评论&统计
添加评论系统 多说。天朝嘛，你懂的。

站点统计  我晕，百度统计那个id我找半天。原来是插入代码里面。里面那个 ?  后面的一个md5串。

## 部署
    8. 部署到git上需要安装插件  `cnpm install hexo-deployer-git --save`
    9. 同时部署到github以及gitcafe见[issue](https://github.com/hexojs/hexo/issues/893) 注意push到哪个分支。然后，分支名字与逗号之间不能有空格，不然出错哦。最后的代码如下：
```yaml
deploy:
  type: git
  repo:
    github: git@github.com:tiann/tiann.github.io.git,master
    gitcafe: git@gitcafe.com:tiann/tiann.git,gitcafe-pages
```
    1. 把原始博客文件放在source分支。

## 优化
### 访问加速
### 
---

