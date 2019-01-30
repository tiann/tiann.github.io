title: 获取迅雷会员工作流
date: 2015-11-18 14:59:44
tags:
- alfred workflow
---

mac下的P2P下载工具目前只有迅雷了，可是大家都知道mac下只有“会员迅雷”才能下载，没会员就是个废物。对于冷门资源离线下载还是是非常非常有用的，高速下载对速度提升也是显而易见。

想必都不会为了临时下载一个资源去开一个会员，肯定有过上网搜迅雷会员的经历；这里教大家如何把这个过程变成一个自动化的工作。**如果长期使用迅雷的话，建议还是开会员去；本教程仅供学习使用，用完请于24小时之内删除**

先看看效果：
<img src="http://weishu1.dimensionalzone.com/markdownxunleivip.gif" alt='效果图' width="721" />

<!--more -->
## 获取免费迅雷账号的地址
随便百度一下，就能找到一堆免费迅雷会员分享的地址，具体就不指出了；然后把每天最新的账号分享信息抓取出来。

这里使用python，可以用`pyquery`来解析网页，然后一个正则匹配就拿到了结果：
```
#! /usr/bin/python
# encoding: utf-8

import sys, urllib, re
from pyquery import PyQuery as pq
from workflow import Workflow


_url = 'http://www.xunleihuiyuan.net/'

def main(wf):
    args = wf.args

    results = _get_from_web()
    map(lambda (x,y):wf.add_item(u'账号:%s' % x, u'密码:%s' % y, arg=u'%s %s' %(x,y), valid=True), results)
    wf.send_feedback()

def _get_today_url():
    home = urllib.urlopen(_url).read().decode('utf-8')
    return pq(home)('.cate1 .post-title a')[0].get('href')

def _get_from_web():
    page = urllib.urlopen(_get_today_url()).read().decode('utf-8')
    results = r = pq(page)('.formattext div').text()
    return re.findall(ur'\u8d26\u53f7(\S+)\u5bc6(\w+)', results)
```

## 用Alfred workflow展示出来
使用python的alfred workflow sdk的话非常简单，文档在[这里](http://alfredworkflow.readthedocs.org/en/develop/index.html)

这里要处理的一个问题是，账号和密码如何简单滴传递出来；一起放在剪切版肯定不太合适。幸好alfred自带剪切版历史的功能，我们分别两次把账号和密码复制到剪切版，要使用的时候，激活`cmd + option + c`然后从剪切版历史里面选择账号密码即可：效果如下：
<img src="http://weishu1.dimensionalzone.com/test/1447827801109.png" width="514" alt="alfred历史剪切版功能"/>
然后，按下`cmd + 2`得到账号，`cmd + 3`得到密码！具体代码比较简单：
```
import subprocess,time
query = "{query}"
def copy_osx(text):
        p = subprocess.Popen(['pbcopy', 'w'], stdin=subprocess.PIPE, close_fds=True)
        p.communicate(input=text.encode('utf-8'))
account, pwd = query.split()
copy_osx(account)
time.sleep(0.3)
copy_osx(pwd)
```

这样，一个简单的迅雷会员获取工作流就完成了！

