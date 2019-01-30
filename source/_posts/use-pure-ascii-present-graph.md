title: ASCII Art：使用纯文本流程图
date: 2016-01-03 23:17:24
tags:
---

我们使用纯文本写代码，有了Markdown又可以使用纯文本写文档，那么对于更直观的信息表达方式——图片，能不能使用纯文本描述呢？

另外，你是否见到过这样的注释：

<img src="http://weishu.dimensionalzone.com/201512/1451834573842.png" alt="ASCII art图像" width="463"/>

没错，这种逼格极高的ASCII图片注释方式就是我们要讨论的话题。

<!--more-->
使用纯ASCII文本表达图像的方式有什么好处呢？大致有下面几点：

1. 装B；没啥好解释的。
2. 可以在代码注释里面用图像充分表达信息；没图say个jb？一图胜千言。迄今为止好像没有什么IDE可以支持直接在代码编辑里面放图片的，在另外一些纯文本的场合也是如此。比如RFC的文档都是txt，里面很多图都是纯ASCII表达。
3. 你以为仅仅是一个纯文本图片这么简单？它可以转换为普通的诸如png格式的真正的图片，还支持SVG矢量图！

好了，也许有人说markdown的一些拓展格式不也是支持流程图的吗？它使用的`flowchart.js` 确实可以很好滴完成一些漂亮的流程图，还有 `plantuml`和图片DSL语言 `dot`及它的软件包`graphviz`等；没错，它们可以使用纯文本表达图像，但它们不是真正的图像；无法嵌入文本代码中，只有在经过渲染之后才能直观地看到图。

又有人说，我知道 `asciiflow` 这个网站，可以绘制这种流程图，完美解决我的需求。但是，你在手动绘制的时候，是不是要考虑图像的各种细节？大小，放置位置，对齐方式？我们关注的应该是图像本身，而不是如何绘制这个图。markdown为什么这么易用？就是因为我们不用关心文档的格式，不用考虑什么字体，几级标题等等繁琐的格式，可以专注于创作本身。

姑且你已经认同了这种使用ASCII表达图像方式的优点，但是...这种图难道要使用手一个个字符地敲出来吗？？如果真的这么做，简直不要太麻烦！光在前面添加一个空格，后面的所有行都需要改；我们需要一个自动化工具。

## Graph::Easy
**Graph::Easy** 就是今天要介绍的主角；它是 `perl`的一个软件包，可以使用`perl`代码直接描述图像；当然，我们肯定不会为了画个图专门去学习`perl`;

这个软件包的强大之处在于: 它定义了一套非常简单易用的专门用来描述图像的DSL（领域专用语言）,我们可以像写代码一样表达我们需要描述的图像（放心，这个语法非常简单）；不用关心图像里面如何布局；这种语言经过处理可以得到ASCII图像，直接放在代码注释中；如果需要还可以转换成png或者矢量图等格式。

先举个简单的例子，感受一下:

```asciidoc
[ Bonn ] --> [ Koblenz ] --> [ Frankfurt ] --> [ Dresden ]

[ Koblenz ] --> [ Trier ] { origin: Koblenz; offset: 2, 2; }
  --> [ Frankfurt ]
```
这种DSL经过渲染之后得到的ASCII图是这样的：

```asciidoc
+------+     +---------+                   +-----------+     +---------+
| Bonn | --> | Koblenz | ----------------> | Frankfurt | --> | Dresden |
+------+     +---------+                   +-----------+     +---------+
               |                             ^
               |                             |
               |                             |
               |             +-------+       |
               +-----------> | Trier | ------+
                             +-------+
```

## 安装

1. 首先需要安装 `graphviz` 软件包，可以在[graphviz官网][1]下载；mac用户可以 `brew install graphviz`；其他linux发行版参考[官网][1]。
2. 安装`perl`；mac和linux用户可以略过；一般系统自带，没有的话和windows一起去[perl官网][2]查询如何安装; 据说windows下有傻瓜包`activeperl`；请自行搜索。
3. 安装`cpan`; 这个是`perl`的软件包管理，类似`npm`, `pip`, `apt-get`; mac下直接在命令行输入 `cpan` 命令，一路next即可。其他系统参考[cpan官网][3]
4. 安装`Graph::Easy` ;这一步就很容易了；在命令行输入`cpan`进入cpan shell；然后输入 `install Graph::Easy`即可。

## 使用

使用分为两步

1. 使用Graph::Easy DSL的语法描述图像，存为文本文件，比如 `simple.txt`
2. 使用 `graph-easy` 命令处理这个文件： `graph-easy simple.txt`

最简单的使用方式就是这样；当然，`Graph::Easy` 不仅仅支持自己的DSL语法，它还支持诸如`dot` 这种较为通用的图像描述语言；可以直接读取`dot` 格式的输入，产生其他的诸如 ascii，png，svg格式的图像。

### 语法
#### 注释

注释用 `#` 表达；注意 `#` 之后，一定需要加空格；由于历史原因；Graph::Easy的颜色也使用了 `#` ，不加空格会解析失败。
```asciidoc
##############################################################
# 合法的注释

##############################################################
#有问题的注释

node { label: \#5; }	  # 注意转义！
edge { color: #aabbcc; }  # 可以使用颜色值
```

#### 空格

空格通常没有什么影响，多个空字符会合并成一个，换行的空字符会忽略；下面的表述是等价的。

```asciidoc
[A]->[B][C]->[D]
```

```asciidoc
[ A ] -> [ B ]
[ C ] -> [ D ]
```

#### 节点(Node)
用中括号括起来的就是节点，我们简单可以理解为一些形状；比如流程图里面的矩形，圆等；

```asciidoc
[ Single node ]
[ Node A ] --> [ Node B ]
```
可以用逗号分割多个节点：

```asciidoc
[ A ], [ B ], [ C ] --> [ D ]
```
上面的代码图像如下：

```asciidoc
+---+     +---+     +---+
| A | --> | D | <-- | C |
+---+     +---+     +---+
            ^
            |
            |
          +---+
          | B |
          +---+
```

#### 边(Edges)
将节点连接起来的就是边；Graph::Easy 的DSL支持这几种风格的边：
```asciidoc
        ->              实线
        =>              双实线
        .>              点线
        ~>              波浪线
        - >             虚线
        .->             点虚线
        ..->            dot-dot-dash
        = >             double-dash
```
可以给边加标签，如下：

```asciidoc
[ client ] - request -> [ server ]
``` 
结果如下：

```asciidoc
+--------+  request   +--------+
| client | ---------> | server |
+--------+            +--------+
```

#### 属性(Attributes)

可以给节点和边添加属性；比如标签，方向等；使用大括号 `{}`表示，里面的内容类似css，`attribute: value`。

```asciidoc
[ "Monitor Size" ] --> { label: 21"; } [ Big ] { label: "Huge"; }
```
上面的DSL输入如下：
```asciidoc
+----------------+  21"   +------+
| "Monitor Size" | -----> | Huge |
+----------------+        +------+
```

Graph::Easy提供了非常多的属性; 另外，`Graph::Easy`的[文档][4]非常详细，建议通读一遍；了解其中的原理和细节，对于绘图和布局有巨大帮助。目前正在翻译，文档[地址][5].

## 实例

语法是不是非常简单？有了这些知识，我们就可以建立自己的流程图了；Have a try！来个MVP模式的示意图试试～

1. 新建文件，`vi mvp.txt`; 输入以下代码：

```asciidoc
[ View ] {rows:3} - Parse calls to -> [ Presenter ] {flow: south; rows: 3} - Manipulates -> [ Model ]
[ Presenter ] - Updates -> [ View ]
```
2. 保存然后退出；命令行执行 `graph-easy mvp.txt`, 输入效果如下：

```asciidoc
+------+  Parse calls to   +--------------+
|      | ----------------> |              |
| View |                   |  Presenter   |
|      |  Updates          |              |
|      | <---------------- |              |
+------+                   +--------------+
                             |
                             | Manipulates
                             v
                           +--------------+
                           |    Model     |
                           +--------------+
```

两行代码就搞定了！自动对齐，调整位置，箭头，标签等等；我们完全不用管具体图形应该如何绘制，注意力集中在描述图像本身；还在等什么！赶紧试一试吧！！

原文：http://weishu.me/2016/01/03/use-pure-ascii-present-graph/

[1]: http://www.graphviz.org/
[2]: http://www.perl.org
[3]: http://www.cpan.org/modules/INSTALL.html
[4]: http://bloodgate.com/perl/graph/manual/index.html
[5]: https://www.gitbook.com/book/weishu/graph-easy-cn/details
