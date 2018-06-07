title: "史上最简单Android源码编译环境搭建方法"
date: 2016-12-30 01:08:41
tags:
- android source
- compile
---

有史以来，Android源码编译环境的搭建始终是一件麻烦事儿。网上有数不清的文章介绍如何编译Android源代码，但是他们要么方法复杂、步骤太多；要么自称解决了一些编译问题（需要修改头文件，系统配置等），让人对其可信度产生质疑。有的童鞋硬着头皮照做了，但是由于伟大的GFW，大部分都死在了第一步——repo脚本都下载不下来，就算下载过了过不了gerrit那一关。另外，就算你具备科学上网的能力，下载时间又成为了拦路虎；普通的VPN通常需要下载七八个小时，简直就是痛不欲生。久而久之，很多人对下载编译Android源码望而却步。

今天，我给大家提供一个极其简单、稳定的方案，来解决Android源码的下载编译问题。

首先，下载问题可以通过镜像解决；[清华镜像](https://mirrors.tuna.tsinghua.edu.cn/help/AOSP/) 和 [科大镜像](https://lug.ustc.edu.cn/wiki/mirrors/help/aosp) 都是非常不错的选择，正常情况下一到两个小时即可下载完一个Android源码分支。

然后就是编译环境问题。由于Android源码庞大，依赖复杂；一旦使用的编译工具链有细微的不同就可能引发编译失败。[官方文档](https://source.android.com/source/initializing.html) 推荐使用Ubuntu 14.04进行编译。如果我们用Windows或者Mac系统，传统方式是使用虚拟机；但是在今天，我们完全可以使用 **Docker** 替代！！借助Docker，我们可以不用担心编译环境问题；不论我们的开发机是什么系统，可以使用Docker创建Ubuntu Image，并且直接在这个Ubuntu系统环境中创建编译所需要的工具链（JDK，ubuntu系统的依赖库等等）；而且，Docker运行的Ubuntu的系统开销比虚拟机低得多，这样下载以及编译速度就有了质的提升。更重要的是，这个环境可以作为一个Image打包发布！这样，你在不同的开发机，还有你与你的同事之间有了同一套编译环境，这会省去很多不必要的麻烦。关于Docker的更多内容，见 [Docker官网](http://www.docker.com/)

<!--more-->

当然，这个伟大的创举并不是我完成的，而是 [kylemanna/docker-aosp](https://github.com/kylemanna/docker-aosp)！我针对Docker以及天朝的网络环境做了一部分修改，fork了一份 [tiann/docker-aosp](https://github.com/tiann/docker-aosp)。

废话不多说，我们看看具体如何使用，以及怎么个简单法。

## 使用步骤
### 安装Docker

Docker的下载地址见 [Docker下载](https://www.docker.com/products/overview) ；下载完毕安装即可。

### 准备工作

如果你不是Mac系统，可以直接略过这一步。

Mac的文件系统默认不区分大小写，这不满足Android源码编译系统的要求（编译的时候直接Error）；因此需要单独创建一个大小写敏感的磁盘映像。步骤如下：

1. 打开Mac的系统软件：**磁盘工具**
2. CMD + N，创建新的磁盘映像，参数设置如下图：

    <img src="http://7xp3xc.com1.z0.glb.clouddn.com/201601/1483019239159.png" width="430"/>
    
    其中磁盘大小设置为 50~100G合适，**格式一定要选择带区分大小写标志的。**
 
### 开始下载编译

真正的下载编译过程相当简单，脚本会自动完成；步骤如下：

1. 设置Android源码下载存放的目录；如果是Mac系统，这一步必须设置为一个大小写敏感的目录；不然后面编译的时候会失败。如果不设置这一步，那么源码会下载到 `~/aosp-root` 目录；设置过程如下：

    `export AOSP_VOL=/Volume/Android/`
    
2. 下载wrapper脚本；如果需要下载其他系统版本，直接修改下载完毕后的build-nougat.sh文件的 android-4.4.4_r2.0.1改成你需要的分支即可，分支的信息见 [分支列表](https://source.android.com/source/build-numbers.html#source-code-tags-and-builds)

    `curl -O https://raw.githubusercontent.com/kylemanna/docker-aosp/master/tests/build-nougat.sh`
    
3. 运行脚本，开始自动下载安装过程；Windows系统可以使用 [Bash for Windows](https://msdn.microsoft.com/en-us/commandline/wsl/about) 或者cygwin。

    `bash ./build-nougat.sh`

这样，所有的工作就都做完了。只需静静等待即可；时间视下载速度而定，清华的镜像速度还可以，笔者使用不到2小时就完成了下载编译过程。

三步完成，是不是灰常简单？赶紧下载编译安装属于你的Android系统吧 ^_^