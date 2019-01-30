title: 让Alfred支持拼音搜索
date: 2015-12-07 04:39:49
tags:
- alfred
- python
---

Alfred是个好东西，不过检索程序的时候不支持拼音搜索；我在论坛看到有人给作者反馈过，无奈作者说支持中文，他不知道拼音是什么，于是就不了了之了。举个例子：我想打开`网易云音乐`,可是当我输入`wangyiyunyinyue`的时候却是这样的结果:

<img src="http://weishu1.dimensionalzone.com/test/1449431593204.png" width="536" alt="不支持拼音的搜索结果"/>

要么我知道这个App的名字叫做`NeteaseMusic`，要么我就需要用中文输入`网易云音乐`打开了；如果恰巧输入法是英文输入状态，那么就会遇到上图的情况；这时候再把已经输入的删除然后切换输入法打开，效率无疑大大折扣。

<!-- more -->
就算这里搜索这个App可以使用英文名字解决，可是对于某些系统程序比如邮件可能还知道是`Mail`，那么备忘录呢？便签呢？还有一些别的中文程序没有英文名的比如马克飞象？如果Alfred能支持拼音搜索，这些问题全部都没了！而且，Alfred可以强制使用英文输入，直接使用字母检索，不用切换输入法了。

## 原理
经过简单的观察之后，发现Alfred检索程序不仅仅是检索名字，还收集了一些额外的信息；在Alfred作者的帮助下，知道它利用了Mac文件系统的一个**拓展信息**的字段；如果你发现某些目录后面有`@`那么就是有拓展信息了：

```
drwxr-xr-x+  3 root    wheel  102  9 10  2014 Stickies.app/
drwxr-xr-x@  3 weishu  admin  102  3 26  2015 Sublime Text.app/
```
可以借助命令行工具`xattr`进行操作；具体使用可以`man xattr`.

所以，我们可以通过**把拼音信息添加到文件的拓展信息里面**去，这样Alfred就能借助这些信息帮助拼音检索了。

## 实现

### 获取程序名
程序名不仅仅是一个文件名这么简单，Mac软件有一个叫做*localization*的概念，大致就是国际化吧；程序结构把国际化的字段存放在不同的文件里面，在程序本地化之后自动load.

我们要使用的那个字段是`CFBundleName`存放在`/<App>/Contents/Resources/<language>/InfoPlist.strings`这个文件里面；我们把这个名字读取出来即可。

尝试过使用`objc`的接口`NSBundle.localizedInfoDiction`来获取本地化的字段，无奈拿到的永远是英文字段；只好手工解析中文字段了（不会Objc 😭）；使用的命令行工具`plutil`:

```python
def _get_localized_name(abs_path):
    '''get the localized name of given app'''
    bundle = NSBundle.new()
    bundle.initWithPath_(abs_path)
    localizations = bundle.localizations()
    chinese = ('zh_CN', 'zh_Hans')

    b = any(map(lambda x: x in localizations, chinese))
    if not b: return 

    for ch in chinese:
        path = bundle.pathForResource_ofType_inDirectory_forLanguage_('InfoPlist', 'strings', None, ch)
        if not path: continue
        # the path must surround with "", there may be space characters
        json_str = subprocess.check_output(u'plutil -convert json -o - "%s"' % path, shell=True)
        # print json_str
        json_res = json.loads(json_str, encoding='utf8')
        name = json_res.get('CFBundleName')
        if name: return name
```
### 转换为拼音
可以直接使用python的拼音转换库[pypinyin][1],借助这个工具，一行代码搞定：

```python
def _get_app_pinyin_name(app_name):
    reduce(lambda x, y: x + y, lazy_pinyin(app_name, errors='ignore'))
```
### 添加拼音信息
拼音信息被添加到文件的拓展信息里面，直接使用`xattr`添加即可：

```python
def _add_meta_data(app_pinyin_name, app_path):
    ''' add meta data(comments) to the app, which can help Alfred or SpotLight find it'''
    subprocess.check_call('xattr -w com.apple.metadata:kMDItemFinderComment %s %s' % (app_pinyin_name, app_path), shell=True)
```

好了，把这些代码整合起来，就能得到最终的结果了，完整的代码在[这里][2]。

```python
def main():
    pattern = re.compile(r'^[\w\s.]+$')

    workspace = NSWorkspace.sharedWorkspace()

    for app_dir in APP_DIRECTORYS:
        if not os.path.exists(app_dir): continue

        for root, dirs, files in os.walk(app_dir, topdown=True):
            remove_list = []
            for directory in dirs:
                # print type(directory), root, directory
                full_path = os.path.join(root, directory)
                if not _is_application(workspace, full_path): continue

                remove_list.append(directory)
                
                localized_name =  _get_localized_name(full_path)
                app_name = localized_name if localized_name else directory.rsplit(r'.')[0]

                if pattern.match(app_name): 
                    continue
                
                _add_meta_data(_get_app_pinyin_name(app_name), full_path)

            # if this directory is already a Application
            # do not traverse this; some app may be very large 
            # and there won't be any other app inside it
            dirs[:] = [d for d in dirs if d not in remove_list]
```

最后，我们执行这一段脚本即可`sudo python main.py`。之所以需要**sudo**是因为某些系统程序（比如家计算器），直接使用是没有权限的。

最后看效果：

<img src="http://weishu1.dimensionalzone.com/markdownalfredpinyin.gif" width="1104" alt="支持拼音搜索效果图"/>
[1]: https://github.com/mozillazg/python-pinyin
[2]: https://gist.github.com/tiann/35fb758c18036d7f8640