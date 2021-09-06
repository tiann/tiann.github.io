title: "另一种绕过 Android P以上非公开API限制的办法"
date: 2019-03-16 16:34:45
tags:
 - Android
 - Framework
---

去年发布的 Android P上引入了针对非公开API的限制，对开发者来说，这绝对是有史以来最重大的变化之一。前天 Google 发布了 Android Q 的 Beta 版，越来越多的 API 被加入了黑名单，而且 Google 要求下半年 APP 必须 target 28，这意味着现在的深灰名单也会生效；可以预见，在不久的将来，我们要跟大量的 API 说再见了。

去年我给出了[一种绕过Android P对非SDK接口限制的简单方法](http://weishu.me/2018/06/07/free-reflection-above-android-p/)，经验证，这办法在 Android Q 的 Beta 版上依然能正常使用。虽然这个方法需要进行内存搜索，理论上有可能失败，但实际上它曾在 VirtualXposed 和 太极 中得到了较为广泛的验证，从未收到过由于反射失败而导致问题的反馈。而且据我所知，有若干用户量不少的 APP 在线上使用了我提供的 [FreeReflection](https://github.com/tiann/FreeReflection/) 库，想来应该也是没有问题的吧。

不过今天，我打算给出另外一种绕过限制的办法。这个办法目前来说是最优方案，我个人使用了一个多月，不存在任何问题。

<!--more-->

上次[分析系统是如何施加这个限制](http://weishu.me/2018/06/07/free-reflection-above-android-p/) 的时候，我们提到了几种方式，最终给出了一种修改 runtime flag 的办法；其中我们提到，系统有一个 `fn_caller_is_trusted` 条件：**如果调用者是系统类，那么就允许被调用**。这是显而易见的，毕竟这些私有 API 就是给系统用的，如果系统自己都被拒绝了，这是在玩锤子呢？

也就是说，如果我们能**以系统类的身份去反射，那么就能畅通无阻**。问题是，我们如何以「系统的身份去反射」呢？一种最常见的办法是，我们自己写一个类，然后通过某种途径把这个类的 ClassLoader 设置为系统的 ClassLoader，再借助这个类去反射其他类。但是这里的「通过某种途径」依然要使用一些黑科技才能实现，与修改 flags / inline hook 无本质区别。

**以系统类的身份去反射** 有两个意思，1. 直接把我们自己变成系统类；2. 借助系统类去调用反射。我们一个个分析。

「直接把我们自己变成系统类」这个方式有童鞋可能觉得天方夜谭，APP 的类怎么可能成为系统类？但是，一定不要被自己的固有思维给局限，一切皆有可能！我们知道，对APP来说，所谓的系统类就是被 BootstrapClassLoader 加载的类，这个 ClassLoader 并非普通的 DexClassLoader，因此我们无法通过插入 dex path的方式注入类。但是，Android 的 ART 在 Android O 上引入了 JVMTI，JVMTI 提供了将某一个类转换为 BootstrapClassLoader 中的类的方法！具体来说，我们写一个类暴露反射相关的接口，然后通过 JVMTI 提供的 `AddToBootstrapClassLoaderSearch`将此类加入 BootstrapClassLoader 就实现目的了。不过，JVMTI 要在 release 版本的 APP 上运行依然需要 Hack，所以这种途径与其他的黑科技无本质区别。 

第二种方法，「借助系统的类去反射」也就是说，如果系统有一个方法`systemMethod`，这个`systemMethod` 去调用反射相反的方法，那么`systemMethod`毋庸置疑会反射成功。但是，我们从哪去找到这么一个方法给我们用？事实上，我们不仅能找到这样的方法，而且这个方法能帮助我们调用任意的函数，那就是**反射本身！**可能你已经绕晕了，我解释一下：

1. 首先，我们通过反射 API 拿到 `getDeclaredMethod` 方法。`getDeclaredMethod` 是 public 的，不存在问题；这个通过反射拿到的方法我们称之为**元反射方法**。
2. 然后，我们通过刚刚反射拿到**元反射方法**去反射调用 `getDeclardMethod`。这里我们就实现了**以系统身份去反射**的目的——反射相关的 API 都是系统类，因此我们的元反射方法也是被系统类加载的方法；所以我们的元反射方法调用的 `getDeclardMethod` 会被认为是系统调用的，可以反射任意的方法。

伪代码如下：

```java
Method metaGetDeclaredMethod =
        Class.class.getDeclaredMethod("getDeclardMethod"); // 公开API，无问题
Method hiddenMethod = metaGetDeclaredMethod.invoke(hiddenClass,
        "hiddenMethod", "hiddenMethod参数列表"); // 系统类通过反射使用隐藏 API，检查直接通过。
hiddenMethod.invoke // 正确找到 Method 直接反射调用
```

到这里，我们已经能通过「元反射」的方式去任意获取隐藏方法或者隐藏 Field 了。但是，如果我们所有使用的隐藏方法都要这么干，那还有点小麻烦。在 [上文](http://weishu.me/2018/06/07/free-reflection-above-android-p)中，我们后来发现，隐藏 API 调用还有「豁免」条件，具体代码如下：

```java
if (shouldWarn || action == kDeny) {
    if (member_signature.IsExempted(runtime->GetHiddenApiExemptions())) {
      action = kAllow;
      // Avoid re-examining the exemption list next time.
      // Note this results in no warning for the member, which seems like what one would expect.
      // Exemptions effectively adds new members to the whitelist.
      MaybeWhitelistMember(runtime, member);
      return kAllow;
    }
    // 略    
}
```

只要 `IsExempted` 方法返回 true，就算这个方法在黑名单中，依然会被放行然后允许被调用。我们再观察一下`IsExempted`方法：

```java
bool MemberSignature::IsExempted(const std::vector<std::string>& exemptions) {
  for (const std::string& exemption : exemptions) {
    if (DoesPrefixMatch(exemption)) {
      return true;
    }
  }
  return false;
}
```

继续跟踪传递进来的参数 `runtime->GetHiddenApiExemptions()` 发现这玩意儿也是 runtime 里面的一个参数，既然如此，我们可以一不做二不休，仿照修改 runtime flag 的方式直接修改 `hidden_api_exemptions_` 也能绕过去。但如果我们继续跟踪下去，会有个有趣的发现：这个API 竟然是暴露到 Java 层的，有一个对应的 [VMRuntime.setHiddenApiExemptions](http://androidxref.com/9.0.0_r3/xref/libcore/libart/src/main/java/dalvik/system/VMRuntime.java#278)  Java方法；也就是说，只要我们通过 `VMRuntime.setHiddenApiExemptions` 设置下豁免条件，我们就能愉快滴使用反射了。

再结合上面这个方法，我们只需要通过 「元反射」来反射调用 `VMRuntime.setHiddenApiExemptions` 就能将我们自己要使用的隐藏 API 全部都豁免掉了。更进一步，如果我们再观察下上面的 `IsExempted` 方法里面调用的 `DoesPrefixMatch`，发现这玩意儿在对方法签名进行前缀匹配；童鞋们，我们所有Java方法类的签名都是以 **L**开头啊！如果我们把直接传个 `L`进去，所有的隐藏API全部被赦免了！

详细代码在这里：https://github.com/tiann/FreeReflection

理论上讲，这个方案不存在兼容性问题。即使 ROM 删掉了 `setHiddenApiExemptions` 方法，我们依然可以用「元反射」的方式去反射隐藏API，并且所有的代码加起来不超过30行！当然，如果 Google 继续改进验证隐藏API调用的方法，这个方式可能会失效；但是目前的机制没有问题。

文章的最后，我想说的是，本文的目的不是刻意去绕过限制。不给思维设限、不给人生设限，才会有更多可能。

