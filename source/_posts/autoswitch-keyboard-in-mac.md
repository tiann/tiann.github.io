title: mac下自动切换输入法
date: 2015-12-01 10:17:29
tags:
- mac
---

长久以来，输入法一直是困扰mac用户的一个问题；不过随着国内厂商的跟进，这种状况得到了极大的改善。不用自己去折腾什么**鼠须管**了，狼厂和企鹅都做的不错。

不过依然有一个问题没有完全解决：不同程序之间输入的自动切换。

相信大家一定有切换到`item2`输入两个命令发现是中文然后按`cmd + space`切换的尴尬；另外如果你如果使用vi或者emacs，那么就更蛋疼了。造成这种状况的根本原因在于：**输入法的状态是混乱的**，我无法明白现在自己处于哪一种输入环境，除非我开始打字或者看右上角输入法的图标。我希望`item2`,`Intellij IDEA`,`Alfred2`**永远**是英文输入状态，除非手动切换；其他的程序比如chrome浏览器，邮件客户端保持正常。

打个比方，使用`sublime`写代码，大多数情况下肯定是英文输入状态，写注释的时候可能手动切换到中文；但是这里有个问题，这时候如果我切换到其他程序，然后改变了输入的状态，再次回到`sublime`，fuck!怎么又成了中文!

目前解决方案有如下方式：

1. mac系统自带的设置-> 键盘 -> 输入源 -> 自动使用文稿的输入源
2. 一些输入法的类似*安静模式*的功能

<!--more-->
第一种方式，意思就是不同的程序保持独立的输入状态，不会出现你在另外一个程序切换了输入法的时候再次回来输入法状态就变了。这个开关很有用，我使用了一段时间，发现还是怪怪的，有时候并不符合预期，但是具体场景也搞不明白，反正是一头雾水，有时候依然会陷入困惑的状态。

第二种方式很有意思，应该可以满足很多非程序员的需求。这个*安静模式*，打个比方，鼠须管输入法；这种输入法其实有几种输入模式，如果对于`sublime`开启安静模式，那么在进入`sublime`程序的时候，会自动切换到英文输入模式；nice！不过问题就是：如果要切换到中文模式，需要按`ctrl`或者`shift`。如果使用一些IDE的话，肯定各种快捷键用的飞起，怎么少的了按`ctrl`和`shift`，这时候问题就来了，如果我们一不小心在使用某些快捷键的时候触发了这个输入法的模式切换功能，那么就蛋疼了：我们需要不停滴按`shift`切换确保自己处于正确的状态。更糟糕的是，如果你发现自己处于鼠须管的英文输入模式，想使用中文，然后按了`cmd + space` 切换，你有可能会切换到系统的英文输入法，打个字发现依然是英文！fuck！你不信邪，以为是没有按到，再猛敲几次`cmd + space`，最后你自己处于那个状态就晕了。

## 怎么正确配置输入法
经过这些折腾之后，可以得到输入法的这么几条最佳实践：

1. 最基本的原则是要很方便滴知道自己处于哪一种输入状态。如果任何时候清楚这个，那么就是简单的切换问题了。
2. 最好不要使用一个输入的两种模式，并使用`shift`或者`ctrl`切换；如上文，某些情况会陷入极度混乱，最好在输入法之间切换，模式简单。
3. 所有程序输入法状态应该有一个恒定的初始态，每次你重新进入这个程序，就会回到初始状态。

为什么需要一个恒定的初始状态呢？为了明确自己处于哪一种输入状态，只需要在每次进入这个程序的时候，不管之前做过什么，它的状态是确定的，姑且叫它初始态；然后基于原则2，每次你希望切换的时候`cmd + space`一下，需要的时候换回来，如果你去了别的程序再回来，状态重置为初始态。

好了分析了这么多，其实要解决的问题就是3一个，我们写一段小程序。

## 切换输入法实现
mac下如果使用objc或者swift切换输入法很简单，Apple提供了很详细的Text Input Service文档（现在这个文档403了，可以使用google的cache访问)；我希望使用python来调用这些接口，很遗憾的是，`pyobjc`没有封装`TIS`系列函数，手动使用`ctypes`模块来wrap一下：

```python
import ctypes
import ctypes.util
import objc
import CoreFoundation

_objc = ctypes.PyDLL(objc._objc.__file__)

# PyObject *PyObjCObject_New(id objc_object, int flags, int retain)
_objc.PyObjCObject_New.restype = ctypes.py_object
_objc.PyObjCObject_New.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]

def objc_object(id):
    return _objc.PyObjCObject_New(id, 0, 1)

# kTISPropertyLocalizedName
kTISPropertyUnicodeKeyLayoutData_p = ctypes.c_void_p.in_dll(carbon, 'kTISPropertyInputSourceIsEnabled')
kTISPropertyInputSourceLanguages_p = ctypes.c_void_p.in_dll(carbon, 'kTISPropertyInputSourceLanguages')
kTISPropertyInputSourceType_p = ctypes.c_void_p.in_dll(carbon, 'kTISPropertyInputSourceType')
kTISPropertyLocalizedName_p = ctypes.c_void_p.in_dll(carbon, 'kTISPropertyLocalizedName')
# kTISPropertyInputSourceLanguages_p = ctypes.c_void_p.in_dll(carbon, 'kTISPropertyInputSourceLanguages')

kTISPropertyInputSourceCategory = objc_object(ctypes.c_void_p.in_dll(carbon, 'kTISPropertyInputSourceCategory'))
kTISCategoryKeyboardInputSource = objc_object(ctypes.c_void_p.in_dll(carbon, 'kTISCategoryKeyboardInputSource'))


# TISCreateInputSourceList
carbon.TISCreateInputSourceList.restype = ctypes.c_void_p
carbon.TISCreateInputSourceList.argtypes = [ctypes.c_void_p, ctypes.c_bool]

carbon.TISSelectInputSource.restype = ctypes.c_void_p
carbon.TISSelectInputSource.argtypes = [ctypes.c_void_p]

carbon.TISGetInputSourceProperty.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
carbon.TISGetInputSourceProperty.restype = ctypes.c_void_p

carbon.TISCopyInputSourceForLanguage.argtypes = [ctypes.c_void_p]
carbon.TISCopyInputSourceForLanguage.restype = ctypes.c_void_p

def get_avaliable_languages():
    single_langs = filter(lambda x: x.count() == 1, \
        map(lambda x: objc_object(carbon.TISGetInputSourceProperty(CoreFoundation.CFArrayGetValueAtIndex(objc_object(s), x).__c_void_p__(), kTISPropertyInputSourceLanguages_p)), \
            range(CoreFoundation.CFArrayGetCount(objc_object(carbon.TISCreateInputSourceList(None, 0))))))
    res = set()
    map(lambda y: res.add(y[0]), single_langs)
    return res

def select_kb(lang):
    cur = carbon.TISCopyInputSourceForLanguage(CoreFoundation.CFSTR(lang).__c_void_p__())
    carbon.TISSelectInputSource(cur)
```

切换输入法主要是`TISSelectInputSource`方法，简单滴调用这个方法就可以了。使用`ctypes`包装这个方法有两个地方可以借鉴：

### pyobjc 转ctypes兼容类型
pyobjc提供的对象是不能直接传递给ctypes要包装的函数使用的，需要转换成可以识别的类型。每一个pyobjc提供的对象都有一个`__c_void_p__()`方法，对它调用这个方法就可以把这个对象转换成一个`c_void_p`类型

### ctypes指针构造出pyobjc对象
简单包装一下`objc`runtime里面的new方法，然后可以直接根据指针new一个对象出来。正如以上代码的`PyObjCObject_New`。（新版的pyobjc模块貌似已经包装了这个方法）

PS：本人第一次包装objc接口，对于objc以及pyobjc均不熟悉，可能有更优雅的方法，请批评指正。

## 如何自动切换？
要想实现输入法自动切换，自然是需要在某程序切换到前台的时候，帮它更改一下输入法的状态；如果知道一个程序是不是在前台呢？最笨的办法当然就是轮询，但是不够优雅。幸运的是，新的mac系统提供了这个回调。

```python
class Observer(NSObject):
    def handle_(self, noti):
        info = noti.userInfo().objectForKey_(NSWorkspaceApplicationKey)
        bundleIdentifier = info.bundleIdentifier()
        if bundleIdentifier in ignore_list:
            print "found: %s active" % bundleIdentifier
            select_kb(u'en')


def main():
    nc = NSWorkspace.sharedWorkspace().notificationCenter()
    observer = Observer.new()
    nc.addObserver_selector_name_object_(
        observer,
        "handle:",
        NSWorkspaceDidActivateApplicationNotification,
        None
    )
    AppHelper.runConsoleEventLoop(installInterrupt=True)
```
这一段代码可以拿到最前台运行的application，而且是回调通知。有两个地方需要注意：

1. Observer对象需要先new出来，（我直接在函数参数里面调用，直接就是segement fault，不知道原因）不能使用python的构造对象方式。需要调用new方法。
2. 需要使用AppHelper.runConsoleEventLoop 才能接收到事件，至于为什么见[参考][1]。

## 成果
好了，把上面两段代码整合起来；就能实现每次在打开某些程序的时候，自动切换到某个输入法了！完整的代码见[auto_switch_kb.py][2]

每次我切换到`IDEA`敲代码，输入法状态永远都是英文；就算我切换到其他回个邮件，发个消息切换到了中文，再次回来依然是英文；我手动切换到了中文被打断了去做了别的事情，再次回来，依然是英文状态。我永远都知道自己处于什么输入模式，如果不满足条件，`cmd + space` 切换即可。

最后，你可以使用`supervisor`之类的东西把它加入开机自动运行，这样，困惑已久的输入法问题终于得到解决。

[1]: http://stackoverflow.com/questions/8348627/what-is-the-correct-way-to-identify-the-currently-active-application-in-osx-10
[2]: https://gist.github.com/tiann/f85e89bef4b6e9b83f2a