title: '另一种黑科技保活方法'
date: 2021-01-25 11:34:46
tags:
---

几个月前，我写了一篇[Android 黑科技保活实现原理揭秘](http://weishu.me/2020/01/16/a-keep-alive-method-on-android/)，当时我们提到，现在的进程保活基本上分为两类，一种是想尽办法提升进程的优先级，保证进程不会轻易被系统杀死；另一种是确保进程被杀死之后能通过各种方式复活。

[Android 黑科技保活实现原理揭秘](http://weishu.me/2020/01/16/a-keep-alive-method-on-android/) 中的进程永生术是第二种，它通过钻 Android 杀进程的空子实现了涅槃永生；不了解的同学可以参考一下 [PoC](https://github.com/tiann/Leoric)。归根结底，所谓的黑科技就是利用系统漏洞。那么，既然我们可以利用漏洞逃过追杀，那何不更进一步，利用系统漏洞提权？

<!-- more -->

实际上，在 Android 系统中，这样的漏洞广泛地存在着。Google 会在每个月初公布其更新的安全漏洞，这些漏洞各种各样。通常情况下，更受人关注的是那些 RCE 或者 EoP 类型的漏洞，它们要么可以远程控制系统，要么可以直接获取操作系统最高权限（Root）。不过，这种类型的漏洞利用起来往往比较困难，要稳定地运行不是一件容易事，而且由于他们危害大，往往很快就会被修复。

> 太极的少阳模式实际上就是使用这种方法，通过利用 1 Day 漏洞（如水滴，CVE-2020-0423等）直接获取系统最高权限，然后进行注入和拦截，这种方式不需要解锁和刷机就能实现太极阳的完整功能。

但是，如果想要实现保活，可以大大降低这个要求：只需要提权到 system 就可以为所欲为了。当然，我们也不一定要提权，比如说想办法让系统帮忙启动一个服务，比如骗系统帮我们提升进程优先级都是可以的。

接下来，我们介绍一下最近公布的有关 Android 前台服务的漏洞。他们的编号分别是 [CVE-2020-0108](https://android.googlesource.com/platform/frameworks/base/+/45a53e6cb8d3276126cfe0e717ad7ed486d39b24)，[CVE-2020-0313](https://cs.android.com/android/_/android/platform/frameworks/base/+/b740ed72b93e4671ced674456b2eaac26fda5ab9:services/core/java/com/android/server/notification/NotificationManagerService.java;dlc=95dbff5e7817b1b7e36c7d518b4818be5c23dc32)。

如果小伙伴们有印象的话，Android 上存在一个广为流传的灰色保活方法：创建两个 Service 来启动通知，最后可以创建一个没有通知栏的前台服务，从而提升进程的优先级。接下来要介绍的这个漏洞与此类似，实际上还有一个 CVE-2020-0313也是前台服务相关。。这块代码实在是写的稀烂，漏洞百出。好了回到正题，我们先介绍一下前台服务：

> 前台服务执行一些用户能注意到的操作。例如，音频应用会使用前台服务来播放音频曲目。前台服务必须显示通知。即使用户停止与应用的交互，前台服务仍会继续运行。

前台服务所在的进程优先级非常高，一般不会被系统轻易杀死；因此如果有条件创建一个前台服务，就可以实现保活。不过，Android 有一个很强的限制，那就是前台服务必须要显示一个通知；对那些既想要在后台偷偷地跑，又不想被人发现的 App 来说，这个限制实在是让人头大。有没有办法让系统既能启动一个前台服务，又不显示通知呢？

如果我们创建通知的时候，故意出错，系统会有什么反应？

以下是我们创建前台服务的样例代码：

```java
String CHANNEL_ID = "demo_channel";
NotificationManager manager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
NotificationChannel Channel = new NotificationChannel(CHANNEL_ID, getString(R.string.app_name), NotificationManager.IMPORTANCE_HIGH);
Channel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC); //设置锁屏可见 VISIBILITY_PUBLIC=可见
if (manager != null) {
    manager.createNotificationChannel(Channel);
}

Notification notification = new Notification.Builder(this, CHANNEL_ID)
        .setAutoCancel(false)
        .setContentTitle(getString(R.string.app_name))
        .setContentText("运行中...")
        .setWhen(System.currentTimeMillis())
        .setSmallIcon(R.mipmap.ic_launcher_round)
        .setLargeIcon(BitmapFactory.decodeResource(getResources(), R.mipmap.ic_launcher))
        .build();
startForeground(1, notification);
```

可以看到，我们创建前台服务的时候需要创建一个 NotificationChannel，如果我随便搞一个channel 或者干脆传递一个错误的或者压根不存在的 channel 给系统会咋样？我们简单跟踪一下系统的前台服务启动流程，在真正要创建通知的时候，是在 [ServiceRecord.postNotification](http://androidxref.com/9.0.0_r3/xref/frameworks/base/services/core/java/com/android/server/am/ServiceRecord.java#687)

```java
try {

    // 忽略..
    
    if (nm.getNotificationChannel(localPackageName, appUid,
            localForegroundNoti.getChannelId()) == null) {
        int targetSdkVersion = Build.VERSION_CODES.O_MR1;
        try {
            final ApplicationInfo applicationInfo =
                    ams.mContext.getPackageManager().getApplicationInfoAsUser(
                            appInfo.packageName, 0, userId);
            targetSdkVersion = applicationInfo.targetSdkVersion;
        } catch (PackageManager.NameNotFoundException e) {
        }
        if (targetSdkVersion >= Build.VERSION_CODES.O_MR1) {
            throw new RuntimeException(
                    "invalid channel for service notification: "
                            + foregroundNoti);
        }
    }

    // 忽略..

} catch (RuntimeException e) {
    ams.setServiceForeground(name, ServiceRecord.this,
            0, null, 0);
    ams.crashApplication(appUid, appPid, localPackageName, -1,
            "Bad notification for startForeground: " + e);
}

```

看到这里其实就知道，我们传递了一个不存在的 channel，系统`getNotificationChannel`会发现不对劲，然后直接抛出一个异常`invalid channel for service notification`，捕获了异常之后，系统会调用 `ams.crashApplication`，我们看一下这个 `ams.crashApplicaiton`，一路跟踪，我们会发现代码调用到了这里：

```java
void scheduleCrash(String message) {
    // Checking killedbyAm should keep it from showing the crash dialog if the process
    // was already dead for a good / normal reason.
    if (!killedByAm) {
        if (thread != null) {
            if (pid == Process.myPid()) {
                Slog.w(TAG, "scheduleCrash: trying to crash system process!");
                return;
            }
            long ident = Binder.clearCallingIdentity();
            try {
                thread.scheduleCrash(message);
            } catch (RemoteException e) {
                // If it's already dead our work is done. If it's wedged just kill it.
                // We won't get the crash dialog or the error reporting.
                kill("scheduleCrash for '" + message + "' failed", true);
            } finally {
                Binder.restoreCallingIdentity(ident);
            }
        }
    }
}
```

哇，我们的系统真的是太温柔了！系统要让咱们进程去死的时候，不是直接提刀把咱砍了，而是赐了一杯毒酒就不管了：爱卿，你自己去死吧。不过，要是咱们进程不听话，把毒就扔了不就逍遥法外了吗！！

这个过程就是 CVE-2020-0108 的原理：创建一个前台服务，但是在他需要前台通知的时候给它一个子虚乌有的 channel，这样前台服务实际上创建好了，不过系统发现不对劲会让咱去死，咱厚着脸皮不死，最终就拥有了一个**没有通知的前台服务**。

你以为到这就完了？No！这个前台服务代码 Bug 一堆，咱还有个别的姿势同样能达到目的。

我们的总体思路是创建前台服务的时候，给它传递非法的参数让系统创建失败；上面我们给了它一个不合法的 channel，我们实际上还可以在别的地方动手脚：创建通知的时候是可以自定义布局的，如果我们给系统一个错误的布局会咋样？废话不多说我们直接跟踪代码，最终会到这里:

```java
@Override
public void onNotificationError(int callingUid, int callingPid, String pkg, String tag, int id,
        int uid, int initialPid, String message, int userId) {
    cancelNotification(callingUid, callingPid, pkg, tag, id, 0, 0, false, userId,
            REASON_ERROR, null);
}
```

这里就更搞笑了，通知创建失败了，系统就是单纯把通知取消了；后面服务该咋运行还是咋运行，系统压根就不管！

好了写到这里，有关前台服务的漏洞我们已经介绍完了。Google 已经在 8 月份的安全更新中修复了这个漏洞；简单看一下修复办法：

```java
     void scheduleAppCrashLocked(int uid, int initialPid, String packageName, int userId,
-            String message) {
+            String message, boolean force) {
         ProcessRecord proc = null;
 
         // Figure out which process to kill.  We don't trust that initialPid
@@ -374,6 +378,14 @@
         }
 
         proc.scheduleCrash(message);
+        if (force) {
+            // If the app is responsive, the scheduled crash will happen as expected
+            // and then the delayed summary kill will be a no-op.
+            final ProcessRecord p = proc;
+            mService.mHandler.postDelayed(
+                    () -> killAppImmediateLocked(p, "forced", "killed for invalid state"),
+                    5000L);
+        }
     }
```

很好，系统现在在赐死之后，过了五秒钟回来看一下是不是真的死了，如果没有死了再自己动手砍一刀；这才是正常的赐死逻辑嘛，哈哈。

如果你是一个普通用户，很可能会觉得奇怪，使用这么广泛的 Android 系统竟然存在着这么多低级漏洞？是的，任何软件系统都不可能没有 BUG，这是没法避免的客观事实。我们唯一能做到的是：**如果手机有安全性更新，一定要及时更新!!**千万不要觉得旧系统不是挺好的嘛，越升级越难用；否则，如果这些公开的漏洞被人利用，后果不敢设想。另外， **千万不要选择那些万年不更新安全补丁的辣鸡手机！！**