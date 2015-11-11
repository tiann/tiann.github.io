title: 简化markdown写作中的贴图流程
date: 2015-10-16 14:15:09
tags:
- workflow
- markdown
---
markdown写作的时候，图片插入是一件比较麻烦的事情。常见的流程如下：
1.  用截图工具截图；
2.  将截图保存到某个地方
3.  修改截图文件名
4.  上传截图到某个图床（如果不用“围脖是个好图床”这样的工具，还得用客户端登陆）
5.  拿到图床上的截图的链接；然后用markdown格式插入图片

这么复杂的流程，让人简直没有了插入图片的欲望；但是大量的文字没有图片，必然让人疲惫；

要是能**随便截个图，然后直接粘贴就成了markdown格式**就好了；自然是能够做到！懒就是生产力～
<!-- more -->

## 图片上传
### 准备工作
首先要做的是，简化上传图片到图床这个手工的过程，甚至连拖动图片到浏览器插件都省略；这里就自然少不了使用图床的SDK，用代码来帮助我们完成上传操作；

这里选择七牛的图床，各种语言的SDK都有，还有免费10G空间，每个月10G流量，业界良心！注册点[这里][1]

然后新建一个空间，比如我的叫做booluimg，然后点击空间设置里面的域名设置，看看域名是什么，那么以后我的图片就会上传到 http://7sbqce.com1.z0.glb.clouddn.com/

### 用SDK上传图片
使用七牛提供的python SDK，下面的代码可以将一个文件上传到七牛的空间：
```py
# -*- coding: utf-8 -*-

import os
from qiniu import Auth, put_file

access_key = '你的Access key' # AK
secret_key = '你的Secret Key' # SK

bucket_name = 'booluimg' # 七牛空间名

q = Auth(access_key, secret_key)

def upload_qiniu(path):
    ''' upload file to qiniu'''
    dirname, filename = os.path.split(path)
    key = 'markdown/%s' % filename # upload to qiniu's markdown dir

    token = q.upload_token(bucket_name, key)
    ret, info = put_file(token, key, path, check_crc=True)
    return ret != None and ret['key'] == key
```

## 访问剪切版
如果我们进行截图或者复制图片，那么图片是存储在系统的剪切版里面的；要将这个图片上传，必需先从剪切版里面弄出来。
### mac
mac访问剪切版比较简单，如果是文本类型，那么可以直接使用`pbcopy, pbpaste`这两个命令解决；如果访问其他的多媒体类型，可以使用系统内置的python与objc的访问接口`PyObjC`;具体关于剪切版的文档可以参考[PyObjC文档][2]，[Objc剪切版文档][3](不会objc没关系，能看懂)

如下：
```py
# -*- coding: utf-8 -*-
# clipboard.py
import time
from AppKit import NSPasteboard, NSPasteboardTypePNG, NSPasteboardTypeTIFF

def get_paste_img_file():
    pb = NSPasteboard.generalPasteboard()
    data_type = pb.types()
    # if img file
    print data_type
    now = int(time.time() * 1000) # used for filename
    if NSPasteboardTypePNG in data_type:
        # png
        data = pb.dataForType_(NSPasteboardTypePNG)
        filename = '%s.png' % now
        filepath = '/tmp/%s' % filename
        ret = data.writeToFile_atomically_(filepath, False)
        if ret:
            return filepath
    elif NSPasteboardTypeTIFF in data_type:
        # tiff
        data = pb.dataForType_(NSPasteboardTypeTIFF)
        filename = '%s.tiff' % now
        filepath = '/tmp/%s' % filename
        ret = data.writeToFile_atomically_(filepath, False)
        if ret:
            return filepath
    elif NSPasteboardTypeString in data_type:
        # string todo, recognise url of png & jpg
        pass
```
### Windows
windows下，可以装个pywin32然后使用win32api直接访问，具体如何操作自己解决。

## 自动化流程
先阐述一下要达到的理想状态：用截图工具截图（图片默认保存在剪切版），然后在编辑器按下某个类似于粘贴的快捷键，得到一个上传好了到七牛的marddown格式的图片；

如何达到这个要求呢？上传图片以及到从剪切版获取图片都已经完成，接下来就是这个按键的自动化操作了；在mac上，可以使用Alfred工作流，Windows上，可以使用Autohotkey。

### mac下使用alfred工作流
使用Alfred新建一个空白的工作流，然后新建一个trigger，快捷键绑定为“ctrl + cmd + v”;然后新建一个run script，选择python;然后填上如下代码：
```python
query = "{query}"
from clipboard import get_paste_img_file
from upload import upload_qiniu
import os

url = "http://7sbqce.com1.z0.glb.clouddn.com/markdown"

img_file = get_paste_img_file()
if img_file:
    # has file
    ret = upload_qiniu(img_file)
    if ret:
        # upload success
        name = os.path.split(img_file)[1]
        markdown_url = "![](%s/%s?imageMogr2/thumbnail/!50p/quality/100!)" % (url, name)
        # make it to clipboard
        os.system("echo '%s' | pbcopy" % markdown_url)
        os.system('osascript -e \'tell application "System Events" to keystroke "v" using command down\'')
    else: print "upload_failed"
else:
    print "get img file failed"
```
其中，复制到剪切版以及按下cmd ＋ v复制这个功能，使用的系统命令`pbcopy, osascript`这体现了python作为胶水语言的强大之处！

这样，这个workflow就完成了，用系统截图工具`cmd + option +ctrl + 4`截个图，然后在一个编辑器里面按下`cmd + ctrl + v`看看是什么效果～

有Alfred的童鞋可以直接用我打包好了的workflow：http://yunpan.cn/cFczYRjnJbKVK （提取码：ff1c）
另外有个问题是，mac的retina屏幕截图如果直接使用的话，会是原来的两倍大，我用了七牛的API将图片缩小了一半，但是质量却不太好，不知道有什么办法。

更新：使用mac自带的`sips`工具得到图片的尺寸；然后使用`img`标签替代markdown格式的图片；然后使用css属性控制这个图片的宽度。
更新2: 使用mac通知中心在上传图片失败的时候给出提醒 github地址：https://github.com/tiann/markdown-img-upload

### windows下使用autohotkey
windows下面没有Alfred，但是有强大的AutoHotKey，出发快捷键以及按下ctrl ＋ v完全可以用这个实现；有兴趣的可以自己实现，非常简单。

最后，我们看看最终的效果：
按下cmd ＋ ctrl ＋ v
![效果图](http://7sbqce.com1.z0.glb.clouddn.com/markdownUntitled.gif)


[1]: https://portal.qiniu.com/signup?code=3ldifp9oti442
[2]: https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSPasteboard_Class/index.html#//apple_ref/occ/instm/NSPasteboard/dataForType
[3]: https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSData_Class/#//apple_ref/occ/instm/NSData/writeToFile:atomically:
