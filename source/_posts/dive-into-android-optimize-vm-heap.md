title: "Android性能优化之虚拟机调优"
date: 2016-12-23 22:53:09
tags:
 - android
 - vm
 - heap
 - performance
---


介绍完 [深入学习Android：虚拟机&运行时](https://zhuanlan.zhihu.com/p/24414378) 之后，很多小伙伴问我，你描述的这些知识结构看起来艰深晦涩高大上，实际工作中能有多大用途呢？今天我就简单举个例子。

众所周知，我们的Android App运行在Java虚拟机之上，而Java是一门带GC的语言。在虚拟机进行垃圾回收的时候，要做一件很形象的事叫做STW（stop the world）；也就是说，为了回收那些不再使用的对象，虚拟机必须要停止所有的线程来进行必要的工作。虽说这一点在ART运行时上得到了很大的改善，但是GC的存在对App运行时的性能始终有着微妙的影响。如果你观察过手机输入的日志，一定会看到类似如下的内容：

> 12-23 18:46:07.300 28643-28658/? I/art: Background sticky concurrent mark sweep GC freed 15442(1400KB) AllocSpace objects, 8(128KB) LOS objects, 4% free, 32MB/33MB, paused 10.356ms total 53.023ms at GCDaemon thread CareAboutPauseTimes 1
12-23 18:46:12.250 28643-28658/? I/art: Background partial concurrent mark sweep GC freed 28723(1856KB) AllocSpace objects, 6(92KB) LOS objects, 11% free, 31MB/35MB, paused 2.380ms **total 108.502ms** at GCDaemon thread CareAboutPauseTimes 1

上面的日志反映一个事实：GC是有代价的。有很多有关性能优化的文章提到GC，会花长篇大论讲述垃圾回收的过程以及原理，但所做的策略无非就是「不要创建不必要的对象」，「避免内存泄漏」最终就提到MAT，LeakCanary等工具的使用上去了；我只能说这很苍白无力——写出这样的代码、学会使用工具应该是基本要求。

<!--more-->

虽说Android也支持NDK开发，但是我们不可能把所有代码全用C++重写吧？那么，我们有没有办法能**影响GC的策略**，使得GC尽量减少呢？答案是肯定的。原理在于Android的进程机制——每一个App都有一个单独的虚拟机实例，在App自己的进程空间，我们有相当大的主动权。

我举个简单的例子。（下面的内容基于Android 5.1系统，所有的原理以及代码不保证能在其他系统版本甚至ROM上工作）

Android上所有的App进程都从Zygote进程fork而来，App子进程采用copy on write机制共享了Zygote进程的进程空间；其中Android虚拟机以及运行时的创建在Android系统启动，创建Zygote进程的时候已经完成了。垃圾回收机制是虚拟机的一部分，因此，我们先从Zygote进程的启动过程谈起。

我们知道，Android系统是基于Linux内核的，而在Linux系统中，所有的进程都是init进程的子孙进程，Zygote进程也不例外，它是在系统启动的过程，由init进程创建的。在系统启动脚本system/core/rootdir/init.rc文件中，我们可以看到启动Zygote进程的脚本命令：

> service zygote /system/bin/app_process -Xzygote /system/bin --zygote --start-system-server

也就是说init进程通过执行 /system/bin/app_process 这个可执行文件来创建zygote进程；app_process的源码可见 [这里](http://androidxref.com/5.1.1_r6/xref/frameworks/base/cmds/app_process/app_main.cpp)；在main函数的最后有这么一句话：

```c++
    if (zygote) {
        runtime.start("com.android.internal.os.ZygoteInit", args);
    } else if (className) {
```

最终调用到了[AndroidRuntime.cpp](http://androidxref.com/5.1.1_r6/xref/frameworks/base/core/jni/AndroidRuntime.cpp) 的`start`函数，而这个函数中最重要的一步就是启动虚拟机：

```c++
    JNIEnv* env;
    if (startVm(&mJavaVM, &env) != 0) {
        return;
    }
```

这个函数相当之长，不过都是解析虚拟机启动的参数，比如堆大小等等；[探究largeHeap](http://droidyue.com/blog/2015/08/01/dive-into-android-large-heap/index.html) 这篇文章对一些重要的参数做了说明，这些参数对虚拟机非常重要，后面我们会见到。解析参数完毕之后，最终调用`JNI_CreateJavaVM`来真正创建Java虚拟机。这个接口是Android虚拟机定义的三个接口这一，dalvik能切换到art很大程度上与这个有关。它的具体是现在 [jni_internal.cc](http://androidxref.com/5.1.1_r6/xref/art/runtime/jni_internal.cc)；JNI_CreateJavaVM 这个函数在拿到虚拟机的相关参数之后，就直接创建了Android运行时：

```c++
  if (!Runtime::Create(options, ignore_unrecognized)) {
    return JNI_ERR;
  }
```

Runtime的创建非常复杂，其中，跟GC相关的是，App的堆空间被创建出来了；Heap的构造函数接受了一大堆参数，这些参数对于GC有着重大的影响，如果要调整GC的策略，从这里入手，是比较靠谱的。

```c++
  heap_ = new gc::Heap(options->heap_initial_size_,
                       options->heap_growth_limit_,
                       options->heap_min_free_,
                       options->heap_max_free_,
                       options->heap_target_utilization_,
                       options->foreground_heap_growth_multiplier_,
                       options->heap_maximum_size_,
  // ...
```

其中 heap_initial_size_ 是堆的初始大小，heap_growth_limit_是堆增长的最大限制，heap_min_free_以及heap_max_free_ 是什么呢？详细的用途见 [Android ART GC之GrowForUtilization的分析](http://hello2mao.github.io/2015/12/16/Android_ART_GC_GrowForUtilization.html) 简单来说就是，Android系统为了保证堆的利用效率，减少堆中的内存碎片；每次执行GC回收到一些内存之后，会对堆大小进行调整。比如说你进入了一个图片非常多的页面，这时候申请了100M内存，当你退出这个页面的时候，这100M自然就被回收了，成为了空闲内存；但是系统为了防止浪费，并不会把这100M的空闲内存全部留给你，而是做一个调整。而具体调整到多大，则与   `heap_min_free_`, `heap_max_free_` 以及 `heap_target_utilization_` 相关。

说到这里，原理性的部分已经解释完了；除了流程稍微复杂，也没有什么难点。那么这个堆，跟我们的启动性能优化有什么关系呢？

在Android App的启动过程中，进程占用的内存在一段时间内是持续上涨的；假设堆的初始大小为8M，启动过程中的占用内存峰值30M；启动过程的进行中，伴随着大量临时对象的创建，它们朝生夕死，不久就被回收掉：

<img src="http://weishu.dimensionalzone.com/201601/1482494040946.png" width="446"/>

如上图，这是某次启动过程中某App的内存占用情况；我们看到了有很多小折线，专业术语叫做内存抖动；原因呢，也很明显——有大量的临时对象被创建。怎么解决？有人说，不要创建大量的临时对象。道理我都懂，可是做不到。对于很多大型App来说，启动的过程是相当复杂的，而很多操作也不能简单滴去掉。那么问题来了，30M并不是一个很大的数字，为什么系统如此恐慌，还需要不停滴回收内存呢？

有一种冷，叫做你妈妈觉得你冷。垃圾回收并不是说有垃圾了才去回收，而是只要系统觉得你需要回收垃圾就会进行。

那么，能不能在启动过程中让堆保持持续增长而不进行GC呢？毕竟，30M并不会造成什么OOM。是什么原因导致系统没有这么做？答案是空闲内存。比如说一开始堆有8M，随着启动过程的进行，堆增长到了24M；这时候执行了一次GC，回收掉了8M内存，也是堆回到了16M；我们还有8M的空闲内存。系统就会说，小伙子，你占这么多空闲内存干嘛呀？来妈妈帮你保管，于是你就只剩下2M的空闲内存了。但显然App使用的堆内存很快就会超过18M，于是又引发一系列GC以及堆大小调整，周而复始直至启动完成内存平稳。至此，我们的结论已经很明显：

**如果我们能够调整 heap_min_free_ 以及 heap_max_free_，就能很大程度上影响GC的过程**

如何调整这两个参数的大小呢？*拿到Heap对象的指针，找到这两个参数的偏移量，直接修改内存即可* 这里稍微需要一点C++内存布局的知识；至于如何拿到Heap对象的指针，只有去源码里面寻找答案了。这里我给出最终的实现代码：

```c++
void modifyHeap(unsigned size) {
   // JavaVMExt指针 可以从JNI_OnLoad中拿到 
	JavaVMExt * vmExt = (JavaVMExt *)g_javaVM;
	if (vmExt->runtime == NULL) {
		return;
	}
	char* runtime_ptr = (char*) vmExt->runtime;
    void** heap_pp = (void**)(runtime_ptr + 188);
    char* c_heap = (char*) (*heap_pp);

    char* min_free_offset = c_heap + 532;
    char* max_free_offset = min_free_offset + 4;
    char* target_utilization_offset = max_free_offset + 4;

    size_t* min_free_ = (size_t*) min_free_offset;
    size_t* max_free_ = (size_t*) max_free_offset;
    
    *min_free_ = 1024 * 1024 * 2;
    *max_free_ = 1024 * 1024 * 8;
}
```

修改之后启动过程中内存占用如下，可以看到我们的目的已经达到：

<img src="http://weishu.dimensionalzone.com/201601/1482496070927.png" width="452"/>

顺便说明一下，上面的代码没有考虑任何的可移植性和适配性，只起演示作用。真正投入使用是一个体力活：其一，我们依赖了某特定Android版本某个类的内存布局，其中的成员变量的偏移量可能不同版本不同；其二，这个 min_free_ 以及 max_free_ 具体调整为多大，跟手机的物理内存，App使用的内存，手机配置的初始堆大小等等因素密切相关；调整一个合适的参数需要花费一些时间，Android机型如此之多，这里需要一些小技巧。

不知道上面这个例子有木有让你感受到深入系统底层，那种呼风唤雨无所不能的快感？可能很多人觉得我们都是写写if else而已，调节面改动画写业务已经够了；但我想说明的是，深入学习系统原理是非常有好处的，它可以赋予你在应用层永远无法拥有的能力。

另外留个作业，我们上面提到观察GC的次数，除了使用debug模式下用工具观察，能不能用代码监听到呢？本文主要说明了虚拟机运行时等native层的重要性，而这个答案可以在Java Framework中找到 ^_^
