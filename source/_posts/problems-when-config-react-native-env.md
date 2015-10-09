title: react-native环境搭建的正确姿势
date: 2015-10-08 17:20:14
tags:
- react-native
---
上个月Facebook开源了Android版的react-native，react-native为何物就不多介绍，个人认为虽然取代不了native，但是确实有可能是移动端的未来。

用这个新的工具最开始自然是需要搭建一个开发环境；官网说的可是简单：装好`git`, `nvm`等工具，两条命令解决：
> `npm install -g react-native-cli`
> `react-native init AwesomeProject`

但是对于生活在水深火热的天朝的程序员，事情远没有那么简单。接下来给出正确的安装姿势，最后说说我安装过程中遇到的问题。

<!-- more -->
##  正确的安装姿势
### 准备工作
准备工作包括`git, node`等工具的安装；安装node的话最好使用一个版本管理工具比如`nvm`；这个很简单：
1. `brew install nvm` react-native仅支持mac平台，直接brew
2. `nvm install node && nvm alias default node`

如果上面这两步执行失败，那么需要科学上网；去弄一个VPN或者代理吧，没有的话可以联系我给一个shadowsocks账号。

然后清理一下环境：`npm cache clean`

注意，接下来的安装步骤，如果安装过程中断，最好执行上面的命令**清除缓存**；然后如果是初始化工程失败，最好**删除整个工程目录**重新开始。实际的下载安装过程不会超过十分钟；如果超过说明网络有问题，或者下面的步骤没有正确的配置。

### 手动下载node-gyp需要的源码
官方文档并没有提到这个gyp，那么[node-gyp][4]是什么？
> Node.js native addon build tool

我们使用npm安装的有些module依赖一些用c/c++编写的模块，这些模块需要本地编译安装；`node-gyp`就是一个编译工具。
为什么要手动安装呢？因为`node-gyp`编译需要node的源码，第一次使用的时候需要把它下载下来；但是官方的源码源速度非常慢，基本下载不了；这样会导致编译某些模块的时候卡住，我们可以使用国内的镜像手动下载。运行下面的脚本即可：
```sh
# js 版本号
NODE_VERSION=`node -v | cut -d'v' -f 2`

# 下载源码包(使用镜像)
wget http://npm.taobao.org/mirrors/node/v$NODE_VERSION/node-v$NODE_VERSION.tar.gz

# 删除现有内容不完整的目录
rm -rf ~/.node-gyp
mkdir ~/.node-gyp

# 解压缩并重命名到正确格式
tar zxf node-v$NODE_VERSION.tar.gz -C ~/.node-gyp
mv ~/.node-gyp/node-v$NODE_VERSION ~/.node-gyp/$NODE_VERSION

# 创建一个标记文件
printf "9\n">~/.node-gyp/$NODE_VERSION/installVersion
```

### 替换npm镜像
npm官方的源不稳定，我们可以使用国内淘宝的源http://registry.npm.taobao.org/ ；执行下面的命令即可：
`npm config set registry=http://registry.npm.taobao.org/`

### 配置git代理
不能科学上网还是不行的；在安装模块的时候，不仅需要下载模块，还需要下载node源代码；有的还是使用git管理的，而这些库，很有可能就访问不了。
如果全部使用代理的话，那么访问国内的镜像也使用了代理，这样会导致速度下降；因此我们只对git设置代理：
`git config --global http.proxy=http://<url>:<port>`

这些配置完成，那么就可以初始化工程了；一句命令完成：
`react-native init AwesomeProject`
安装完毕之后，可以使用`npm ls`看一下，这个工程依赖的node模块是有多么复杂，差不多就能理解为什么在天朝配置这个环境有多么麻烦了。

接下来纪录一下我安装过程中遇到的一些问题，不感兴趣可以略过。
## 遇到的问题
### 代理和VPN

VPN和代理最大的区别是，VPN对于应用程序就相当于VPN躺在了TCP/IP协议栈里面，所有的网络请求都会通过VPN访问；而代理呢，我们需要给每个要用到代理的程序单独设置代理访问；大多数程序会检测诸如`HTTP_PROXY`的环境变量来自动使用代理，但是**不是所有的程序都这么乖**。

所以，如果你通过某种方式给系统设置了代理，并不意味着你的每一个程序都会通过代理访问；假如你设置了环境变量`HTTP_PROXY`那么，系统只是告诉程序有代理可用，至于用不用，是程序自己的问题；如果是VPN，那么程序就算什么都没干，它也是通过VPN访问网络的。

代理这么麻烦，还有一些程序不听话，要是像vpn那样就好了。解决方案自然是有，google`Proxifier`或者`proxycap`就行了。

### mac系统设置是全局代理吗
之所以提到mac，是因为react-native官方文档第一条：
> OS X - Only OS X is currently supported

那么，我们打开**系统偏好设置——网络——高级——代理** 这个设置，然后配置好代理信息，对我们的安装有帮助吗？

事实上，**终端以及一些基于命令行的工具，不会理会系统的代理设置**；具体可以看看[这里][1]或者[这里][2]

所以，在系统这里设置代理对我们没有什么作用。

### 环境变量的问题
既然命令行工具不认系统代理设置，那么我们可以在终端手动设置环境变量：
```sh
export HTTP_PROXY=http://<proxy_url>:<port>
export http_proxy=http://<proxy_url>:<port>
export HTTPS_PROXY=http://<proxy_url>:<port>
export https_proxy=http://<proxy_url>:<port>
```
注意两点：
1. 有的工具（没错，说的就是`wget,curl`！！）对于这个环境变量，是**大小写敏感的！！**，所以最好大写小写都设置。
2. https的代理url不带https头。

很不幸，即使这么做了，依然会出现有一些包下载不下来。看了官方文档才知道，`npm`设置代理不是这个样子的。要么在一个配置文件`.npmrc`里面设置，要么通过命令`npm config set XXX`设置。具体可以参考[这篇文章][3]

这是怎么一个奇葩的设计啊。看文章可仔细点，设置代理名字跟环境变量不一样！

### gyp的问题
你以为到这里就结束了？！ 实际上，我们使用的很多npm的包，用到了一些c/c++的模块，需要编译安装。这个时候，需要依赖node的源代码。但是，由于这个源本身的问题，有了代理速度还是乌龟一般。没有办法，我们只有使用国内的淘宝镜像，先手动安装`gyp`。

### openssl的问题
拜GFW所赐，使用https协议的话很有可能根本没法认证，所以最好吧官方的那个源换成http的；然后设置一下这个选项：
`npm config set strict-ssl false`

### git协议无法clone的问题
在公司的网络环境下，很多端口被屏蔽了；git也是一样，因此使用git协议的clone的话很有可能失败，因此我们需要用https协议替代git协议；具体设置可以参考[这里][5]
OK，这些问题全部解决的话，应该能顺利安装上react-native。

[1]: https://discussions.apple.com/thread/2204147?tstart=0
[2]: http://superuser.com/questions/598869/mac-terminal-couldnt-access-network
[3]: http://wil.boayue.com/blog/2013/06/14/using-npm-behind-a-proxy/
[4]: https://github.com/nodejs/node-gyp
[5]: http://stackoverflow.com/questions/15669091/bower-install-using-only-https
