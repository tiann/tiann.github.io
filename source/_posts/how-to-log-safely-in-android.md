title: 如何安全地打印日志
date: 2015-10-19 20:28:02
tags:
- log
- android
---

如何打印日志？这不是很简单，直接使用`android.util.Log`这个类不就行了？然而，日志属于非常敏感的信息；逆向工程师在逆向你的程序的时候，本来需要捕捉你程序的各种输出，然后进行推测，顺藤摸瓜然后得到需要的信息；一旦你的日志泄漏，无异于门户洞开，破解你的程序如入无人之境。
安全的概念本来就是相对的，如果破解你程序的代价远远大于破解得到的价值，那么就可以认为程序是“安全的”；这里就分析一下，为了提高程序的安全性，在打印日志的时候应该注意什么。

<!-- more -->
首先看看绝大部分公司以及开发者的做法：
## 日志开关＋日志类
为了在release版本里面没有日志输出，一个最简单的想法是：把所有打印日志的语句放在一个`if(DEBUG)`的语句里面；在日常开发的时候，`DEBUG`开关打开，发布正式版本的时候关闭这个开关即可，大致思路如下：
```java
// LogUtil.java
public class LogUtil {
    private static boolean DEBUG = true;// 发布的时候修改为false
    
    public static void d(String tag, String msg) {
        if (DEBUG) android.util.Log.d(TAG, msg);
    }

    // 其他debug方法
}
```
接下来看一个真实的例子，国外的一个apk，名字叫做powerclean；包名：com.lionmobi.powerclean;我们安装这个包；发现很正常，没有任何日志输出；然后我们逆向这个apk；随便翻看几个类，发现很多地方有类似日志输出：
<img src="http://http://weishu1.dimensionalzone.com/markdown/1445243591752.png" width="552" alt="日志输出图片"/>
我们打开这个叫做x的类，虽然被混淆过了，但是意思很明白，跟我们上面的思路一样：
```java
package com.lionmobi.util;

import android.util.Log;

public class x {
    private static boolean a;

    static {
        x.a = false;
    }

    public static void d(String arg1, String arg2) {
        if(x.a) {
            Log.d(arg1, arg2);
        }
    }

    public static void e(String arg1, String arg2) {
        if(x.a) {
            Log.e(arg1, arg2);
        }
    }

    public static void i(String arg1, String arg2) {
        if(x.a) {
            Log.i(arg1, arg2);
        }
    }
}
```
这是一个真实的例子，而且这个app的用户还不少；接下来我们看看这种方式有什么问题。

## 静态反编译打开日志开关

上面的那种方式有一个问题：虽然在release版本里面，确实没有日志输出；但是**输出日志的代码依然存在，只是没有执行到！(if条件不成立)**所以，有没有办法让这些代码执行到呢？简单来说，就是能不能在release版本里面把这个`DEBUG`变量弄成`true`呢？当然可以！而且做法还非常简单。

我们使用`apktool`反编译得到这个apk的smali代码；然后上面的反编译告诉我们，这个日志类的位置是：`com.lionmobi.util.x`我们打开这个x.smali文件，内容如下：
```smali
.class public Lcom/lionmobi/util/x;
.super Ljava/lang/Object;


# static fields
.field private static a:Z


# direct methods
.method static constructor <clinit>()V
    .locals 1

    const/4 v0, 0x0 # 修改为0x1 (True)

    sput-boolean v0, Lcom/lionmobi/util/x;->a:Z #初始化位置

    return-void
.end method

.method public static d(Ljava/lang/String;Ljava/lang/String;)V
    .locals 1

    sget-boolean v0, Lcom/lionmobi/util/x;->a:Z

    if-eqz v0, :cond_0

    invoke-static {p0, p1}, Landroid/util/Log;->d(Ljava/lang/String;Ljava/lang/String;)I

    :cond_0
    return-void
.end method

.method public static e(Ljava/lang/String;Ljava/lang/String;)V
    .locals 1

    sget-boolean v0, Lcom/lionmobi/util/x;->a:Z

    if-eqz v0, :cond_0

    invoke-static {p0, p1}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;)I

    :cond_0
    return-void
.end method

.method public static i(Ljava/lang/String;Ljava/lang/String;)V
    .locals 1

    sget-boolean v0, Lcom/lionmobi/util/x;->a:Z

    if-eqz v0, :cond_0

    invoke-static {p0, p1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    :cond_0
    return-void
.end method

```
很明白，那个叫做`a`的静态变量就是我们的开关， 它的初始化在哪个静态代码块里面；新建了一个局部变量0x0然后赋值给了`a`；因此，我们**把这个0x0修改为0x1**就打开了这个开关。很简单吧，接下来我们把修改好的smali打包回去，然后签名得到一个新的可以运行的apk；运行一下看看结果。果然，一大堆的日志输出了出来，你的程序每一步在干什么都自己告诉别人了，都不需要去猜；我就随便截个图，感受下：
<img src="http://http://weishu1.dimensionalzone.com/markdown/1445245047558.png" width="1235" alt="泄漏的日志信息"/>

##  让release版本里面不包含日志代码
从上面的分析我们得到一个结论：**如果需要程序是“日志安全的”，那么release版本里面不应该存在输出日志的代码**。

如何做到这一点呢？我们可以做一个工具，开发的时候，正常打印日志；一旦需要发布版本，把所有打印日志的语句代码，全部删除掉。代码很简单，用一些正则表达式就可以做到。

事实上，我们也可以使用一些别的工具，来实现这个类似的功能；那就是`proguard`；提到这个工具，很多认只是觉得他是一个代码混淆的工具，实际上，**它还可以帮你剔除无用代码！**什么样的代码是无用代码呢？
```java
if (true) {
    // statement;
}
```
类似于这样，静态编译的时候被认为“永远不会执行的代码”，就被认为是无用代码，会被这个工具直接优化掉，生成的class文件里面，这个if语句直接就没有了。这个功能，完美符合我们的需求；我们只需要把输出日志的代码用这样的if语句包围起来，然后release的时候肯定会用这个工具混淆；然后，在release版本里面，所有的输出日志的代码全部都没有了！不会像以前一样，留下一个影子，只是不做事。

## 正确的做法
最终，我们所有打印日志的语句应该如下：
```java
private static final boolean DEBUG = true; // 必须是static final 也就是常量，这样才能在编译器优化；删除if块

if (DEBUG) {
    android.util.Log.d(TAG, "msg to print");
}
```
然后，使用proguard优化代码即可。
看起来简单，好像也与最初的“日志开关”没有什么区别，仔细分析一下：

### 日志开关必须是静态常量
对比一下正确的做法与最开始的日志开关，一个是一个**静态变量**，一个是**静态常量**；如果是**常量**的话，那么就是永远不变的，那么当`DEBUG`变量为`False`的时候proguard可以理所当然地认为，这一部分代码时绝对不会被执行的，这样，打印日志的语句就会被优化（删除）掉；如果是一个变量，那么在运行期间就有可能改变它的值（private仅仅是对于程序员的改变，对于编译器以及运行时，没有什么改不了），这样proguard就会置之不理，这样你的日志代码就暴露出来了，一字之差，失之千里。

### 抛弃日志类
假设我们使用了静态常量代码块以及proguard优化代码的技术；但是依然采用上面的日志类的技术，会发生什么呢？
```java
public class LogUtil {
    private static final boolean DEBUG = false;

    public static void d(String tag, String msg) {
        if (DEBUG) android.util.Log.d(tag, msg);
    }
}
```
我写了一个demo，自己打包然后反编译，得到这个日志类如下（为了方便看，没有混淆）：
```
package com.example.test.app;

public class LogUtil {
    private static final boolean DEBUG;

    public LogUtil() {
        super();
    }

    public static void d(String tag, String msg) {
    }
}
```
我们看到，if代码块已经没有了，确实不会输出任何日志；但是，我们看看调用这个类的地方！
<img src="http://http://weishu1.dimensionalzone.com/markdown/1445247504072.png" width="575" alt="掩耳盗铃的日志"/>

这个`LogUtil.d`的调用，无异于掩耳盗铃；虽然破解者没办法让`android.util.Log`这个类输出任何日志，但是你这里的这个调用还是告诉了别人你在干什么；所以，要屏蔽日志的输出，必须使用if代码块直接包含要被剔除的日志。上面的那个日志类，要被优化掉，那就是：
```java
if (DEBUG) {
    LogUtil.d(TAG, "msg");
}
```
这里，不是多此一举吗，写一个日志类就是想不想重复地写`if (DEBUG) `，这里为了使这一句隐藏，还是逃不掉；但是很抱歉，逃得了和尚逃不了庙，这种方法没办法做到完全隐藏信息；**必须抛弃日志类包裹日志代码的做法！**

### 解放双手的补充
也许有人说，为了这个所谓的日志安全，每次输出日志都的写一个if语句，那不麻烦死；简直反人类，我懒！实际上，要少写几行代码，我们可以选择复用（代码级别，比如上面的日志类），也可以选择**生成**（直接生成代码）；在支持元编程的语言里面，生成代码是很常见的事情，比如C＋＋的模版元编程以及ruby吹嘘的`DSL`能力；这里没有那么高大上，用代码生成代码，我们直接借助编辑器帮助我们少写几行代码万事。

#### IDEA/Android Studio
可以使用live template的功能；比如我的做法是，写一个`ifd`的template，每次我输入`ifd`然后自动展开成if语句，光标停在最中间：
<img src="http://http://weishu1.dimensionalzone.com/markdown1445258458.gif"  width="402" alt="使用live template简化输入"/>

#### vim/emacs
可以使用宏录制的功能，实现上面的live template。

