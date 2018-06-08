title: '一种绕过Android P对非SDK接口限制的简单方法'
date: 2018-06-07 21:14:29
tags:
 - android 
 - hook

---

众所周知，Android P 引入了[针对非 SDK 接口（俗称为隐藏API）的使用限制][1]。这是继 Android N上[针对 NDK 中私有库的链接限制][2]之后的又一次重大调整。从今以后，不论是native层的NDK还是 Java层的SDK，我们只能使用Google提供的、公开的标准接口。这对开发者以及用户乃至整个Android生态，当然是一件好事。但这也同时意味着Android上的各种黑科技有可能会逐渐走向消亡。

作为一个有追求的开发者，我们既要尊重并遵守规则，也要有能力在必要的时候突破规则的束缚，带着镣铐跳舞。恰好最近有人反馈 [VirtualXposed 在 Android P上无法运行][3]，那么今天就来探讨一下，如何突破Android P上针对非SDK接口调用的限制。

<!-- more -->

## 系统是如何实现这个限制的？

知己知彼，百战不殆。既然我们想要突破这个限制，自然先得弄清楚，系统是如何给我们施加这个限制的。


[文档][1] 中说，通过反射或者JNI访问非公开接口时会触发警告/异常等，那么不妨跟踪一下反射的流程，看看系统到底在哪一步做的限制（以下的源码分析大可以走马观花的看一下，需要的时候自己再仔细看）。我们从 `java.lang.Class.getDeclaredMethod(String)` 看起，这个方法在Java层[最终调用到][4]了 `getDeclaredMethodInternal` 这个native方法，看一下这个方法的源码：

```java
static jobject Class_getDeclaredMethodInternal(JNIEnv* env, jobject javaThis,
                                               jstring name, jobjectArray args) {
  ScopedFastNativeObjectAccess soa(env);
  StackHandleScope<1> hs(soa.Self());
  DCHECK_EQ(Runtime::Current()->GetClassLinker()->GetImagePointerSize(), kRuntimePointerSize);
  DCHECK(!Runtime::Current()->IsActiveTransaction());
  Handle<mirror::Method> result = hs.NewHandle(
      mirror::Class::GetDeclaredMethodInternal<kRuntimePointerSize, false>(
          soa.Self(),
          DecodeClass(soa, javaThis),
          soa.Decode<mirror::String>(name),
          soa.Decode<mirror::ObjectArray<mirror::Class>>(args)));
  if (result == nullptr || ShouldBlockAccessToMember(result->GetArtMethod(), soa.Self())) {
    return nullptr;
  }
  return soa.AddLocalReference<jobject>(result.Get());
}
```

注意那个 **ShouldBlockAccessToMember** 调用了吗？如果它返回false，那么直接返回`nullptr`，上层就会抛 `NoSuchMethodXXX` 异常；也就触发系统的限制了。于是我们继续跟踪这个方法，这个方法的实现在 [java_lang_Class.cc][5]，源码如下：

```java
ALWAYS_INLINE static bool ShouldBlockAccessToMember(T* member, Thread* self)
    REQUIRES_SHARED(Locks::mutator_lock_) {
  hiddenapi::Action action = hiddenapi::GetMemberAction(
      member, self, IsCallerTrusted, hiddenapi::kReflection);
  if (action != hiddenapi::kAllow) {
    hiddenapi::NotifyHiddenApiListener(member);
  }
  return action == hiddenapi::kDeny;
}
```

毫无疑问，我们应该继续看 [hidden_api.cc][10] 里面的 `GetMemberAction`方法 ：

```java
template<typename T>
inline Action GetMemberAction(T* member,
                              Thread* self,
                              std::function<bool(Thread*)> fn_caller_is_trusted,
                              AccessMethod access_method)
    REQUIRES_SHARED(Locks::mutator_lock_) {
  DCHECK(member != nullptr);
  // Decode hidden API access flags.
  // NB Multiple threads might try to access (and overwrite) these simultaneously,
  // causing a race. We only do that if access has not been denied, so the race
  // cannot change Java semantics. We should, however, decode the access flags
  // once and use it throughout this function, otherwise we may get inconsistent
  // results, e.g. print whitelist warnings (b/78327881).
  HiddenApiAccessFlags::ApiList api_list = member->GetHiddenApiAccessFlags();
  Action action = GetActionFromAccessFlags(member->GetHiddenApiAccessFlags());
  if (action == kAllow) {
    // Nothing to do.
    return action;
  }
  // Member is hidden. Invoke `fn_caller_in_platform` and find the origin of the access.
  // This can be *very* expensive. Save it for last.
  if (fn_caller_is_trusted(self)) {
    // Caller is trusted. Exit.
    return kAllow;
  }
  // Member is hidden and caller is not in the platform.
  return detail::GetMemberActionImpl(member, api_list, action, access_method);
}
```

可以看到，关键来了。此方法有三个return语句，如果我们能干涉这几个语句的返回值，那么就能影响到系统对隐藏API的判断；进而欺骗系统，绕过限制。

## 应对之策

在分析这三个条件之前，我们再思考一下，在调用一个方法/获取一个成员的时候，除了反射(JNI也算)就没有别的办法了吗？看起来系统只是把反射这条路堵死了，那如果我不走这条路呢？

首先，很显然，除了反射，我们还能直接调用。打个比方，我们要调用 ActivityThread.currentActivityThread()这个方法，除了使用反射；我们还可以把 Android 源码中的 ActivityThread 这个类copy到我们的项目中，然后使用 provided 依赖，这样就能像系统一样直接调用了。至此，我们得到了第一个信息：public类的public方法，可以通过直接调用的方式访问；当然，private的就都不行了。

其次，我们要访问一个类的成员，除了直接访问，反射调用/JNI就没有别的方法了吗？当然不是。如果你了解ART的实现原理，知道对象布局，那么这个问题就太简单了。所有的Java对象在内存中其实就是一个结构体，这份内存在 native 层和Java层是对应的，因此如果我们拿到这份内存的头指针，**直接通过偏移量就能访问成员**。你问我方法怎么访问？ART的对象模型采用的类似Java的 klass-oop方式，方法是存储在 `java.lang.Class`对象中的，它们是**Class对象的成员**，因此访问方法最终就是访问成员。（后续我会专门介绍ART的对象模型，解释 ArtMethod/java.lang.Method/jmethodId之间的关系）。

思考完毕，我们会到反射调用的流程；仔细分析一下这三个条件。

### 第一个条件

先看第一个return语句，`GetActionFromAccessFlags`，看方法名貌似是根据 Method/Field 的 `access_flag` 来判断，具体看下代码：

```java
inline Action GetActionFromAccessFlags(HiddenApiAccessFlags::ApiList api_list) {
  if (api_list == HiddenApiAccessFlags::kWhitelist) {
    return kAllow;
  }
  EnforcementPolicy policy = Runtime::Current()->GetHiddenApiEnforcementPolicy();
  if (policy == EnforcementPolicy::kNoChecks) {
    // Exit early. Nothing to enforce.
    return kAllow;
  }
  // if policy is "just warn", always warn. We returned above for whitelist APIs.
  if (policy == EnforcementPolicy::kJustWarn) {
    return kAllowButWarn;
  }
  // 略。。。
}
```

首先，如果 Method/Field 是白名单，那么直接允许访问。我们再往前看，发现这个 `api_list` 其实是存储在 Method/Field 的 `access_flag`中的。

也就是说，所有的Method/Field的access_flag 中存储了hidden_api 的信息，如果有办法把这个flag直接设置为 kAllow，那么系统就认为它不是隐藏API了。但是，如果要修改 Method/Field 的 `access_flag`这个成员变量，我们首先得拿到这个 Method/Field 的引用，然而 Android P上就是限制了我们拿这个引用的过程，似乎死循环了；前面我们提到可以通过偏移量的方式修改，但实际上这个场景还有别限制（比如压根拿不到Class对象）；因此这个条件看似可以达到，实际上比较麻烦，于是我们暂且放下。

继续观察这个方法，接下来 调用了 `GetHiddenApiEnforcementPolicy` 方法获取限制策略，如果是 `kNoChecks` 直接允许；那 GetHiddenApiEnforcementPolicy 这个方法是啥样呢？在 [runtime.h][7] 中，如下：

```java
hiddenapi::EnforcementPolicy GetHiddenApiEnforcementPolicy() const {
    return hidden_api_policy_;
}
```

也就是说，返回的是 runtime 这个对象的一个成员。**如果我们直接修改内存，把这个成员设置为 kNoChecks**，那么不就达到目标了吗？

#### 获取runtime指针

既然需要修改runtime对象的内存，那么首先得拿到runtime对象的指针。本来这个过程需要去分析 ART runtime的启动过程，但如果完全写出来那就又是几篇文章了；这里直接给出结论：

在JNI中，我们可以通过 JNIEnv指针拿到 JavaVM指针，这个JavaVM指针实际上是一个 `JavaVMExt`对象，runtime是 JavaVMExt结构体的成员。说起来比较绕，实际上你看看代码就明白了：

```cpp
JavaVM *javaVM;
env->GetJavaVM(&javaVM);
JavaVMExt *javaVMExt = (JavaVMExt *) javaVM;
void *runtime = javaVMExt->runtime;
```

感兴趣的可以自己去分析为什么可以这么做。

#### 搜索内存

我们已经拿到了 runtime指针，也就是这个对象的起始位置；如果要修改对象的成员，必须要知道偏移量。如何知道这个偏移量呢？直接硬编码写死也是可行的，但是一旦厂商做一点修改，那就完蛋了；你程序的结果就没法预期。因此，我们采用一种**动态搜索**的办法。

runtime是一个很大的结构体，里面的成员不计其数；如果我们要精准定位里面的某一个成员，需要找一些参照物；然后通过这些参照物进一步定位。我们先来观察一下这个结构体：

```cpp
struct Runtime {
	// 64 bit so that we can share the same asm offsets for both 32 and 64 bits.
	uint64_t callee_save_methods_[kCalleeSaveSize];
	// Pre-allocated exceptions (see Runtime::Init).
	GcRoot<mirror::Throwable> pre_allocated_OutOfMemoryError_when_throwing_exception_;
	GcRoot<mirror::Throwable> pre_allocated_OutOfMemoryError_when_throwing_oome_;
	GcRoot<mirror::Throwable> pre_allocated_OutOfMemoryError_when_handling_stack_overflow_;
	GcRoot<mirror::Throwable> pre_allocated_NoClassDefFoundError_;

	// ... （省略大量成员)

	std::unique_ptr<JavaVMExt> java_vm_;

	// ... （省略大量成员)

	// Specifies target SDK version to allow workarounds for certain API levels.
  	int32_t target_sdk_version_;

  	// ... （省略大量成员)

		  bool is_low_memory_mode_;
	// Whether or not we use MADV_RANDOM on files that are thought to have random access patterns.
	// This is beneficial for low RAM devices since it reduces page cache thrashing.
	bool madvise_random_access_;
	// Whether the application should run in safe mode, that is, interpreter only.
	bool safe_mode_;

	// ... （省略大量成员)
}
```

这个结构体非常大，可以直接去看源码 [runtime.h][6]，上面我们挑出了一些我们能够使用的参照物，辅助进行内存定位：

- java_vm_ ：我们很熟悉的JavaVM对象，上面我们已经通过 JNIEnv 获取了，是个已知值。
- target_sdk_version: 这个是我们APP的 targetSdkVersion，我们可以提前知道。
- safe_mode：safe_mode 是 AndroidManifest 中的配置，已知值。

因此结合这三个条件，我们对runtime指针执行线性搜索，首先找到 JavaVM指针，然后找到target_sdk_version，最后直达目标；顺便用 safe_mode, java_debuggable 等成员验证正确性。

找到目标 `hidden_api_policy_`之后，直接修改内存，就能达到目的。用伪代码表示就是：

```cpp
nt unseal(JNIEnv *env, jint targetSdkVersion) {

    JavaVM *javaVM;
    env->GetJavaVM(&javaVM);
    JavaVMExt *javaVMExt = (JavaVMExt *) javaVM;
    void *runtime = javaVMExt->runtime;

    const int MAX = 1000;
    int offsetOfVmExt = findOffset(runtime, 0, MAX, (size_t) javaVMExt);
    int targetSdkVersionOffset = findOffset(runtime, offsetOfVmExt, MAX, targetSdkVersion);
    PartialRuntime *partialRuntime = (PartialRuntime *) ((char *) runtime + targetSdkVersionOffset);
    EnforcementPolicy policy = partialRuntime->hidden_api_policy_;
    partialRuntime->hidden_api_policy_ = EnforcementPolicy::kNoChecks;

    return 0;
}
```

代码我已经放到 github 上了：[FreeReflection][8]，使用起来非常简单，添加依赖；一步调用即可。觉得好用别忘了 star 哦～

看起来我们已经达到目标了，但是不要慌；还有2个条件呢，我们继续，说不定有新发现。

###  第二个条件

然后看第二个return语句，`fn_caller_is_trusted`，这里面的代码我就不分析了，直接给结论：这个方法通过回溯调用栈，通过调用者的Class来判断是否是系统代码的调用（所有系统的代码都通过BootClassLoader加载，判断ClassLoader即可），如果是系统代码，那么就允许调用（系统自己的API肯定得让它调）。这里我们又发现一个判断条件：`caller.classloader == BootClassLoader`。因此，如果能把这个调用类的ClassLoader修改为 BootClassLoader，那么问题不就解决了吗？

那么问题来了，如何修改Class的classloader？我们看看Class 类的结构：

```java
public final class Class<T> implements java.io.Serializable,
                              GenericDeclaration,
                              Type,
                              AnnotatedElement {

    /** defining class loader, or null for the "bootstrap" system loader. */
    private transient ClassLoader classLoader;
    
    // 略 
}
```

classloader实际上是Class类的第一个成员，而这个`java.lang.Class`我们肯定是能拿到的，因此我们可以通过上面提到的**修改偏移的方式直接修改ClassLoader**，进而绕过限制。

但是需要注意一下这个偏移量。虽然 Class 声明没有继承任何东西，但实际上它继承自 Object。我们看下 `java.lang.Object`：

```java
public class Object {

    private transient Class<?> shadow$_klass_;
    private transient int shadow$_monitor_;
    
}
```

因此，Class对象在内存中实际上是这样：

```cpp
struct Class {
    Class<?> shadow$_klass_;
    int shadow$_monitor_;
    ClassLoader classLoader;
}
```

JVM规范中，一个int占4字节；在ART实现中，一个Java对象的引用占用4字节（不论是32位还是64位），因此 **classloader的偏移量为8**；我们拿到调用者的Class对象，在JNI层拿到对象的内存表示，直接把偏移量为8处置空（BootClassLoader在为null）即可。当然，如果你不想用JNI，Unsafe也能满足这个需求。

看起来我们已经有好几种办法达到目的了，别着急；我们继续看第三个条件。

### 第三个条件

当代码流程走到这里，那个action已经不可能是 kAllow了；不要放弃治疗，说不定还能复活。观察代码：

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

果然有“豁免”条件：GetHiddenApiExemptions()。跟踪这个方法之后，你会发现解决办法跟上面两种是一样的。要么去修改 runtime 的内存，要么修改signature；我就不赘述啦。

### 剑走偏锋

上面我们分析了系统的源代码，结合各种条件来实现绕过对非SDK API调用的检测；但实际上所有这些方式我们的目的都是一样的—— **通过某种方式修改函数的执行流程**；而达到这个目标最直接的方法就是 **inline hook**！！由于inline hook太强大，你只需要找到一个关键的执行流程，hook其中的某个函数，修改他的返回值就OK了；这里我也没啥好分析的，只能给大家推荐一个 inline hook 库了，名字叫 [HookZz][9]，代码非常优秀，值得一看。

## 后记

本来真的只是打算介绍那个简单方法的，结果一不小心全写完啦 ：）

文章可能有疏漏，也可能有更优秀的办法；欢迎交流讨论～

[1]: https://developer.android.com/preview/restrictions-non-sdk-interfaces?hl=zh-cn
[2]: https://developer.android.com/about/versions/nougat/android-7.0-changes?hl=zh-cn
[3]: https://github.com/android-hacker/VirtualXposed/issues/115
[4]: https://android.googlesource.com/platform/libcore/+/android-p-preview-2/ojluni/src/main/java/java/lang/Class.java
[5]: https://android.googlesource.com/platform/art/+/master/runtime/native/java_lang_Class.cc
[6]: https://android.googlesource.com/platform/art/+/master/runtime/runtime.cc
[7]: https://android.googlesource.com/platform/art/+/master/runtime/runtime.h
[8]: https://github.com/tiann/FreeReflection
[9]: https://github.com/jmpews/HookZz
[10]: https://android.googlesource.com/platform/art/+/master/runtime/hidden_api.cc

