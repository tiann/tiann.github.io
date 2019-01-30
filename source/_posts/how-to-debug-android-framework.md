title: "如何调试Android Framework？"
date: 2016-05-30 17:26:05
tags:
- debug
- android
- framework
---

Linus有一句名言广为人知：Read the fucking source code. 但其实，要深入理解某个软件、框架或者系统的工作原理，仅仅「看」代码是远远不够的。就拿Android Framework来说，整个代码量非常大不说，那些个动辄几万行的类如何去理解？所以我今天要说的就是：

**Debug the fucking source code!!**

之前分享过一个答案：[大家遇到过什么 Android 兼容性问题？][1]，这里面的有一些非常诡异的问题，我相信光靠看代码你是永远定位不出来的。还有我写的一系列[Android插件框架原理][2]的文章，这里面涉及到大量Android Framework层的知识，有小伙伴会问，这些Framework层的原理，你是如何学习的呢，有诀窍吗？有！那就是调试。

Debug是一项非常非常重要的技能，毋庸多言。今天我就给大家分享一下「调试Android Framework」的经验，一旦掌握这项技能，那么Java层的任何问题都拦不住你了。

<!--more-->

## 概览

其实整个调试过程非常简单：
1. 在你要调试进程的合适位置打上断点
2. 跟踪代码（Step in/out/over等等）

在展开讲述这两方面之前，有必要先简单了解下调试的基础知识。Java平台的调试是有一个规范化的标准的，那就是JPDA（Java Platform Debugger Architecture）；通过 JPDA 提供的 API，开发人员可以方便灵活的搭建 Java 调试应用程序。 JPDA 主要由三个部分组成：Java 虚拟机工具接口（JVMTI），Java 调试线协议（JDWP），以及 Java 调试接口（JDI）。

Java程序的调试无非就是通过一个调试器（debugger）获取对应Java虚拟机的信息，上文所述的JDWP就是调试器与虚拟机通信的桥梁。在dalvik虚拟机内部有一个专门的jdwp线程，Android系统的adbd进程通过socket与各个虚拟机的jdwp线程进行通信，外部调试器通过adb工具与adbd通信进而完成与jdwp的通信。我们通常所说的「attach debugger」指的就是这个意思——连接到指定的需要调试的进程。

![调试器工作原理](http://http://weishu.dimensionalzone.com/201605/1464599537380.png)

## 如何在正确的地方下断点

「正确的地方」包含两个含义：首先，调试是以进程为单位进行的，如果你需要调试运行在进程A 中的代码，却把debugger attach到了B进程，那么这个断点压根儿就是牛头不对马嘴；另外呢，比如你想调试Android的多媒体框架，你得知道media相关的类在哪吧，也就是说需要在正确的函数里面下断点。

### 如何在合适的进程下断点？

如果是调试我们自己写的App，在Android Studio里面非常简单，在Run菜单de最后面有一个attach debugger to android process 的选项，点击之后会出现一个菜单，选择自己需要调试的进程即可；但是，如果需要调试Android Framework层的代码，这样做是达不到目的的——Framework层的代码通常运行在别的进程（比如ActivityManagerService运行在system_server进程），而这些进程通常情况下是不可调试的，也就是说在attach debugger to android process 的那个菜单里面不会有系统的进程，如下图：

![普通的无法调试的Android设备](http://http://weishu.dimensionalzone.com/201601/1464596347439.png)

为什么不可调试呢？上文我们简要讲述了调试器的工作原理，我们知道每一个虚拟机有一个jdwp线程，如果这个线程拒绝连接到调试器，你也就没办法对这个进程进行调试了。Android的所有App进程都是通过Zygote进程fork出来的，我们在`android.os.Process`这个类里面可以看到android进程的启动过程有这么一句：

```java
if ((debugFlags & Zygote.DEBUG_ENABLE_DEBUGGER) != 0) {
    argsForZygote.add("--enable-debugger");
}
```

也就是说，一个进程是否可以调试是由进程启动时候的参数决定的；普通的App进程如果是debug keystore默认是可以调试的，有或者你在AndroidManifest里面指定debuggable为true也是可以调试的。对系统进程，我们只有采取系统级别的手段：让整个系统可以调试——debug版或者编译参数debuggable为1的系统。

解决这个办法很简单：使用模拟器（真机也行，限Nexus系列刷原生Android系统，把系统启动的debuggable参数修改为1），我的Nexus 5 可以调试的进程如下：

![可调试任意进程的设备](http://http://weishu.dimensionalzone.com/201601/1464596367660.png)

这样，系统中所有的Android进程都可以调试了；这一点很重要，比如你要分析Activity的启动流程，相当多一部分代码是在ActivityManagerService所在的进程system_server执行的，如果你把断点打在别的进程，就会产生跟丢了的情况。在比如，你要调试ActivityThread的main函数，在main函数里面执行了一句attach，最终调用AMS的attachApplication的时候，代码就通过Binder IPC调用到了AMS的system_server进程。

明白你要执行的代码运行在哪一个进程相当重要，在Android中，由于Binder通信机制的存在，「进程迁移」使用的非常非常频繁，因此需要对binder机制有一定的了解；详细的话可以参考我的博客：[Binder学习指南][3]

### 如何在对应的代码处下断点？

假设我们现在把debugger attach到了正确的进程，那么断点应该下在哪里呢？直观来讲，就是说我需要导入所有的Android源码吗？如果不是应该导入哪些代码，怎么导入？

首先，如果你需要调试的类在sdk里面导出了，你压根儿就不需要再导入源码，Android Studio自动帮你关联了这部分代码（前提是你用SDK Manager下载了sdk的源码，如下图：

![SDK manager下载源码](http://http://weishu.dimensionalzone.com/201605/1464596414635.png)

比如你要调试ActivityManagerService类的attachApplication方法，那么很简单；创建一个空的Android项目，SDK版本选择与你要调试的模拟器/真机 的android相同（这很重要，下文会讲述）；然后attrach 到system_server进程（debugger显示的名字为system_process)，直接在attach_application上面打上断点；随便启动一个app，可以看到我们熟悉的调试界面：

![调试attachApplication](http://http://weishu.dimensionalzone.com/201605/1464596428584.png)

如果这部分类在sdk中没有导入（比如@hide)的，又或者压根儿不是SDK的类，（比如系统app的源码）那应该怎么办呢？直接导入这部分代码即可。不需要是Android项目，普通的Java项目即可；举个例子，假设你想调试原生Android系统的「系统设置」这个程序，该如何做呢？

根据上面的分析，我们首先得知道「系统设置˜」运行在哪一个进程，通常情况下进程名字就是包名；我们查出设置的包名即可，而包名是在源码的AndroidManifeist中声明的，因此，我们找到「系统设置」这个程序的源码即可；源码在 https://android.googlesource.com/ ，系统App的源码在/packages这个子目录下面，我们一个个找，最终可以确定「系统设置」的源码在 https://android.googlesource.com/platform/packages/apps/Settings/ ；然后我们把这部分代码git clone下来，导入Android Studio：

![调试Settings](http://http://weishu.dimensionalzone.com/201605/1464596441461.png)

我们去AndroidManifest中查到，「系统设置」的包名为：com.android.settings，这样我们attach到这个进程 ：

![attach setting进程](http://http://weishu.dimensionalzone.com/201605/1464596456242.png)

然后，我们随便打个断点玩一玩，比如进入设置主界面的时候，断下来；我们在AndroidManifest中查到设置程序的入口界面为：Settings，我们在这个类的onCreate里面打一个断点，然后进入设置程序，发现完美滴断下来了：

![在setting中断点成功](http://http://weishu.dimensionalzone.com/201605/1464596476109.png)

OK，到这里；应该学会如何在正确的位置打断点了：正确的进程，正确的位置。接下来，要完成调试，还需要一些技巧。

## 如何跟踪代码？

或许你会说，跟踪代码不就是step in/out/over么，这有什么难的？但其实事情并没有你想象的那么简单，要优雅滴调试，还是需要一些姿势的。

### 行号对应

跟踪代码一个首要的问题是行号对应。如果你在正确位置下了断点，但是跟踪的时候，单步调试，发现运行的代码和Android Studio里面的代码对不上号，那么就很蛋疼；要使得调试器的行号能够对应，必须保证设备上的代码和调试器的代码是同一份；简单来说，需要使用Android的原生系统（模拟器，Nexus系列真机），然后调试器里面使用的SDK版本，必须和设备的系统版本一致。

### 行号不对应怎么办？

一定要注意行号对应这一点，这会使调试过程简单很多；如果没有办法，行号对不上，那该如何调试呢？

行号不对应带来的一个首要问题就是，下断点的时候都有可能出现问题；比如你在TestClass的第100行下了一个断点，但是由于行号不对应，有可能真正执行的代码第100行是没有意义的空行或者是在下一个函数里面，这样断点就没有起到应有的作用了。

要解决行好对应的问题，必须使用**方法断点**；我们直接在某个函数的入口设置断点，这样即使行号对不上，也能在正确的入口出断下来，这一点非常重要。

解决了如何下断点的问题，那么行号不对应，怎么知道执行到哪了，怎么查看局部变量？

**观察栈桢**

在Android Studio的调试器的左边，显示了每一个线程执行的栈桢，栈桢里面包含了当前线程丰富的信息：

<img src="http://http://weishu.dimensionalzone.com/201605/1464598434021.png" width="292"/>

看到没，真正运行的代码在哪一行，当前运行的是什么函数一目了然；接下来你在step into/out的时候，不能以源代码的行数为准，而应该以这个栈桢所显示的代码行数为准。

### 熟练使用断点

OK，现在不论行号是否能对应，我们都能正确滴下断点调试了。断点有很多种类型，方法断点，watch point，条件断点都能够很好滴辅助我们调试；如果你连这几个名词都没有听说过，一定要恶补一下；可以参阅我的博客：[Android Studio你不知道的调试技巧][4]；我就不再复述了。

如果你仔细看完了本文和我给出的链接，那么应该对Debug技术不再陌生了；接下来你可以选择Framework层的代码，手动调试一下加深理解；在日后的工作过程中，不断滴加强debug技术的练习，让它称为你解决复杂问题的条件反射，一定会事半功倍！还有记住：

> Debug the fucking source code.

[1]: https://www.zhihu.com/question/40300713/answer/86706105
[2]: http://weishu.me/2016/01/28/understand-plugin-framework-overview/
[3]: http://weishu.me/2016/01/12/binder-index-for-newer/
[4]: http://weishu.me/2015/12/21/android-studio-debug-tips-you-may-not-know/
