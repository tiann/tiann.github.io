title: '从一次日志丢失所想到的'
date: 2020-10-30 10:29:07
tags:
---

最近我在编写一个 Android 上的驱动程序，这个驱动程序的某些部分用到了 Unix domain socket，守护进程和客户端进程使用 C/S 模式进行通信。在调试程序的时候发现一个非常奇怪的问题：如果客户端开启若干个线程连上 socket，send/recv 若干消息之后立即退出进程，从日志上看，server 端有 10% 左右的概率无法正常回收资源。

一开始我以为是我自己程序写的有问题，毕竟这个驱动是使用纯 C 语言实现的，并且用到了 epoll 的 [ET 模式](https://linux.die.net/man/7/epoll)，这种非阻塞的编程模型的确有许多微妙的地方，一不小心就容易出错。我排查了很久都没有发现问题所在，更有趣的是，虽然看起来我的程序无法回收资源，但是在压力测试下他也能正常工作，完全没有资源泄漏的迹象；实在没办法，我就祭出了大杀器 [strace](https://linux.die.net/man/1/strace)。不看不知道，一看就好笑：strace 显示，我的程序逻辑是正常的，它正确地调用了相关的资源释放函数！但是，logcat 中没有相关的日志，在客户端退出之后 server 端的日志就戛然而止了。看起来，好像不是我程序的问题，而是系统的 logcat 丢失了日志？

<!-- more -->

出于好奇，我就去简单看了下 Android 上 logcat 的实现。原来，logcat 也用了 C/S 模式，有个 logd 的守护进程工作在 server 端，各个进程通过 Log.d 等方法输出日志的时候，实际上也是通过一个 socket 以异步的方式传递给了 logd，logd 再把日志输出到 logcat。当我看到客户端连接 logd 的代码的时候，就立马明白了。。我们看代码：

```c++
int LogListener::GetLogSocket() {
    static const char socketName[] = "logdw";
    int sock = android_get_control_socket(socketName);

    if (sock < 0) {  // logd started up in init.sh
        sock = socket_local_server(
            socketName, ANDROID_SOCKET_NAMESPACE_RESERVED, SOCK_DGRAM);

        int on = 1;
        if (setsockopt(sock, SOL_SOCKET, SO_PASSCRED, &on, sizeof(on))) {
            return -1;
        }
    }
    return sock;
}
```

> 以上代码摘自 [AOSP master 分支](https://cs.android.com/android/platform/superproject/+/master:system/logging/logd/LogListener.cpp;l=129;bpv=0;bpt=1)

原来我们的 logcat 的 socket 使用的是 UDP ！

> UDP 是User Datagram Protocol的简称， 中文名是用户数据报协议，是OSI（Open System Interconnection，开放式系统互联） 参考模型中一种无连接的传输层协议，提供面向事务的简单不可靠信息传送服务，IETF RFC 768 [1]  是UDP的正式规范。UDP在IP报文的协议号是17。(摘自百度百科）

与 TCP 不同，UDP 是不保证可靠传输的。我的程序用的 TCP，因此在 send/recv 完数据之后即使进程退出，内核也会保证数据能正确地发送到对端（在对端正常的情况下）；而 logcat 使用的 UDP，一旦进程退出，数据包是有可能无法送达 logd 的。顺便一提，除了这种丢日志的情形之外，还有一种更常见的情况，就是 logcat 觉得你的日志太频繁把你阉割了，这种情况下我们会在日志中看到 "chatty" 等字样，只需要[设置 logcat 的相关属性](https://stackoverflow.com/questions/37006087/can-we-turn-off-chatty-in-logcat)就可以解决了。

这不禁让我想起好几年前我在知乎上回答的一个问题： [JAVA中：String的equals方法会不会因为恶劣的环境（海啸地震、外星人入侵等）导致运行出错？](https://www.zhihu.com/question/41159482/answer/89836828)

还有，我之前在写太极的时候，发现有个 App 无论如何也注入不进去；后来发现是因为这个 App 把应用的日志全部重定向到了 /dev/null，使得我们无法看到任何日志，然后误以为是程序逻辑没有执行。

实际上，除了代码之外，我们经常会遇到类似的问题。归根结底，就是我们眼睛看到的东西看起来跟“事实”不一致。很多时候，我们会无意识地相信眼睛看到的，毕竟，「眼见为实」嘛！不过，如果“亲眼所见” 最终得出荒谬结论的时候，一定要想想是不是“看到的”有问题。

真实世界中没有鬼，如果有，也只能代表眼睛看到了鬼。