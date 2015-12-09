title: "[译]厌倦了NullPointException？Optional拯救你！"
date: 2015-12-08 20:49:40
tags: 
  - java
  - optional
categories:
  - java
---

> I call it my billion-dollar mistake. It was the invention of the null reference in 1965. I couldn't resist the temptation to put in a null reference, simply because it was so easy to implement.
> —Tony Hoare

有人说，当你处理过了空指针异常才真正成为一个Java开发者。抛开玩笑话不谈，空指针确实是很多bug的根源。Java SE 8引入了一个新的叫做`java.util.Optional` 的类来缓解这个问题。

我们首先看看空指针有什么危险，`Computer`是一个嵌套的对象，如图：
![][1]

下面的代码有什么潜在的问题呢？
`String version = computer.getSoundcard().getUSB().getVersion();`

貌似可行，但是，很多电脑（比如 Raspberry Pi）并没有Soundcard，因此调用`getSoundcard`会发生什么？毫无疑问，结果自然是在运行时给你抛出一个`NullPointException`，然后终止程序的执行。

如何避免上面的空指针异常呢？一般的做法就是在调用方法之前进行检测：
<!--more-->

```java
String version = "UNKNOWN";
if(computer != null){
  Soundcard soundcard = computer.getSoundcard();
  if(soundcard != null){
    USB usb = soundcard.getUSB();
    if(usb != null){
      version = usb.getVersion();
    }
  }
}
```
但是，上面嵌套if检测的代码确实不怎么好看。但是没办法，我们需要很多这样死板的没什么意义的代码来避免碰到`NullPointException`。更恼火的是，这部分代码成了我们业务逻辑的一部分，还降低了代码的可读性。

万一我们忘记对某个可能为`null`的对象进行非空检测怎么办？**使用`null`来说明某个值缺失是一种错误的方式**, 下文将说明这个问题并给出更好的解决办法。

先看看别的编程语言是如何处理这个问题的。

## Null的替代物

Grovvy语言有一个`?.`的操作符，可以安全地处理潜在可能的空引用（C#即将包含这个特性，Java7曾被建议引入这个但是并没有发布。）它是这么用的：

```grovvy
String version = computer?.getSoundcard()?.getUSB()?.getVersion();
```

如果`getSoundcard()`,`getUSB()`,`getVersion`任意一个返回`null`，变量`version`就被赋值为`null`，不需要额外的复杂的嵌套检测。更好的是，Grovvy还有一个*Elvis*操作符:`?:`，可以给类似上面的表达式提供默认值。下面的表达式如果`?.` 返回了`null`那么变量`version`会被赋值为`"UNKNOW"`:
```grovvy
String version = computer?.getSoundcard()?.getUSB()?.getVersion() ?: "UNKNOWN";
```

其他的一些函数式编程语言，比如Haskell, Scala，使用了一种别的方式。Haskell有一个`Maybe`型态，这个型态代表了一种有可选值的类型。Maybe形态的值可能包含一个给定类型的值或者是Nothing(译者注：代表没有值)，完全没有空指针的概念。Scala有一种类似的叫做**Option[T]**的东西来代表类型T的某一个值存在或者没有。因此，你必须显式检测这个值是否存在，如果不存在就不能使用任何Option类型的操作符；这样由于Scala的类型系统，你永远也不会忘记对于空指针的检测。

貌似有点扯远了，那么，Java8给我们提供了什么呢？

## 果壳里的`Optional`
受到Haskell和Scala的启发，Java8引入了一个叫做`java.util.Optional<T>`的类，这一个包含一个可选值的类型，你可以把它当作包含单个值的容器——这个容器要么包含一个值要么什么都没有，如下图：

![Lift2][2]
我们在数据模型里面引入`Optional`：

```java
public class Computer {
  private Optional<Soundcard> soundcard;  
  public Optional<Soundcard> getSoundcard() { ... }
  ...
}

public class Soundcard {
  private Optional<USB> usb;
  public Optional<USB> getUSB() { ... }

}

public class USB{
  public String getVersion(){ ... }
}
```

用上面的代码，我们一眼就可以看出来一个computer有没有soundcard（他们是optioal，可选的），更进一步，一个声卡也有一个可选的USB端口；新的模型能清晰地反映出一个给定的值是有可能不存在的。这种做法在某些库里面也存在，比如**Guava**(译：Java5之后就可以使用，不过有局限)

我们能用*Optional*对象干什么？Optional对象包含了一些方法来显式地处理某个值是存在还是缺失，Optional类强制你思考值不存在的情况，这样就能避免潜在的空指针异常。

值得一提的是，设计Optional类的目的并不是完全取代`null`, 它的目的是设计更易理解的API。通过Optional，可以从方法签名就知道这个函数有可能返回一个缺失的值，这样强制你处理这些缺失值的情况。

## Optional的正确打开方式
废话扯了这么多，来点实际的例子吧！首先来看看如何使用Optional类来实现传统的空指针检测：

```java
String name = computer.flatMap(Computer::getSoundcard)
                          .flatMap(Soundcard::getUSB)
                          .map(USB::getVersion)
                          .orElse("UNKNOWN");
```

> 如果无法理解这段代码，可以复习Java8的lambda和方法引用,见[Java8 Lambdas][3] 以及stream pipelining概念,见[Processing Data with Java SE 8 Steams][4]

### 创建Optional对象
如何创建Optional对象呢，有下面几种方式：

1. 空的Optional

```java
Optional<Soundcard> sc = Optional.empty(); 
```
2. 包含非空值的Optional

```java
SoundCard soundcard = new Soundcard();
Optional<Soundcard> sc = Optional.of(soundcard); 
```
一旦`soundcard`是`null`，这段代码会立即抛出一个`NullPointException`（而不是等你以后你访问这个空的soundcard对象的时候)

3. 可能为空的Optional

```java
Optional<Soundcard> sc = Optional.ofNullable(soundcard); 
```
如果`soundcard`是`null`那么这个`Optional`将会是`empty`.

### 值存在的时候进行进一步的操作
现在你有了一个Optional对象，你可以显式地处理值存在或者不存在的情况，再也不用想这样如履薄冰地进行空指针检测了：

```java
SoundCard soundcard = ...;
if(soundcard != null){
  System.out.println(soundcard);
}
```
现在，可以使用`ifPresent()`方法，如下：

```java
Optional<Soundcard> soundcard = ...;
soundcard.ifPresent(System.out::println);
```
现在，你再也不用显示地进行非空检测了，类型系统帮你干了这件事。如果Optional是empty,上面的代码就不会执行打印了。

你也可以使用`isPresent()`方法检查某个值是否存在，另外，`get` 方法可以返回Optional容器里面包含的那个对象，如果没有这个对象，`get`方法会立即抛出一个`NoSuchElementException`，这两个方法可以结合起来：

```java
if(soundcard.isPresent()){
  System.out.println(soundcard.get());
}
```
但是，并不提倡这样使用Optional。（这么做跟`null`检测有什么区别？），下面有一些惯用手法，我们来看一下。

### 默认值和默认操作
在某个操作返回空的时候给出一个默认值也是一个典型的场景，通畅的做法是使用三目运算符(`?`):

```java
Soundcard soundcard = maybeSoundcard != null ? 
            maybeSoundcard : new Soundcard("basic_sound_card");
```
可以使用Optional对象的`ifElse`方法改进这个代码：

```java
Soundcard soundcard = maybeSoundcard.orElse(new Soundcard("defaut"));
```
如果你想在空值的时候抛出一个异常，可以使用`ifElseThrow`方法：

```java
Soundcard soundcard = 
  maybeSoundCard.orElseThrow(IllegalStateException::new);
```

### 使用`filter`过滤特定值
很多时候你需要调用某个对象的方法并且检查它的一些属性。例如：你可能需要检测一个USB的端口是否是一个特定的版本；如果需要避免空指针异常，通畅的方式是检测非空然后调用`getVersion`方法，如下：

```java
USB usb = ...;
if(usb != null && "3.0".equals(usb.getVersion())){
  System.out.println("ok");
}
```
使用Optional的`filter`可以这么干：

```java
Optional<USB> maybeUSB = ...;
maybeUSB.filter(usb -> "3.0".equals(usb.getVersion())
                    .ifPresent(() -> System.out.println("ok"));
```
`filter`方法带有一个`Predicate`的参数，如果Optional容器里面的对象存在并且满足这个predicate,那么`filter`返回那个对象，否则就返回`empty`的Optional。（跟`Stream`接口的`filter`类似）

### 使用`map`转换值
另外一个比较常见的场景是需要从某个对象里面提取出特定的值。例如：从一个`Soundcard`对象里面取出一个`USB`对象然后检测这个usb对象是否是正确的版本。通常可以这么写：

```java
if(soundcard != null){
  USB usb = soundcard.getUSB();
  if(usb != null && "3.0".equals(usb.getVersion()){
    System.out.println("ok");
  }
}
```
使用Optional的`map`方法，如下：

```java
Optional<USB> usb = maybeSoundcard.map(Soundcard::getUSB);
```
Optional容器里面的值被某个函数（这里是USB的方法引用）作为参数“转换”了，如果Optional是`empty`那么就什么也不会发生。

结合使用`map`和`filter`可以检测某个声卡是否有USB 3.0的接口：

```java
maybeSoundcard.map(Soundcard::getUSB)
      .filter(usb -> "3.0".equals(usb.getVersion())
      .ifPresent(() -> System.out.println("ok"));
```
现在我们的代码看起来比较像是在描述问题了！而且没有任何非空检测，太酷了！

### 使用`flatMap`级联Optional
我们已经有一些常见的模式可以通过`Optional`重构了，那么我们如何用一种安全的方式重构下面的代码呢？

```java
String version = computer.getSoundcard().getUSB().getVersion();
```

上面的代码都是从一个对象里面取出另外一个对象， 这不正是上文介绍的`map`吗？我们改写Computer模型对象，让它拥有一个`Optional<Soundcard>`和一个`Optional<USB>`，然后就可以把代码改成这样：

```java
String version = computer.map(Computer::getSoundcard)
                  .map(Soundcard::getUSB)
                  .map(USB::getVersion)
                  .orElse("UNKNOWN");
```
但是，这段代码并不能通过编译。为什么？

`computer`变量类型是`Optional<Computer>`，因此它调用`map`方法没有任何问题；但是，`getSoundcard()`方法的返回类型是`Optional<Soundcard>`这意味着`map`操作结果的类型是`Optional<Optional<Soundcard>>`,因此`getUsb`这个调用是非法的：外面的那个Optional包含的值是另外一个Optional，自然就没有`getUsb`方法，下图是这个调用的结构：

![two level Optional][5]
如何解决这个问题呢？Optional类提供了一个`flapMap`的方法。这个方法可以对一个Optional使用一个函数转换为一个Optional然后把结果（两个Optional)flatten为一个单个Optional，下图给出了`map`和`flatMap`的区别：

![map and flatMap][6]
用`flatMap`重写我们的代码：

```java
String version = computer.flatMap(Computer::getSoundcard)
                   .flatMap(Soundcard::getUSB)
                   .map(USB::getVersion)
                   .orElse("UNKNOWN");
```
第一个`flatMap`确保返回一个`Optioan<Soundcard>`而不是`Optional<<Optional<Soundcard>>`，第二个`flatMap`确保返回一个`Optional<USB>`；接着第三次调用着需要一个`map`即可，因为`getVersion`返回一个`String`而非`Optional`方法。

Cool！现在我们可以抛弃痛苦的嵌套非空检测了，使用Optional可以写出声明式的，更可读的代码，并且永远不会有空指针异常！

## 总结
本文介绍了如何使用Java SE 8的`java.util.Optional<T>`。`Optional`的目的不是替换你代码里面的每个`null`，它可以帮助你设计出更好的API，使用者通过方法签名就能知道是否有一个可选的值。另外，Optional通过强迫主动处理空指针情况，可以保护代码不出现`NullPointException`。

## 译后感
嵌套的非空检测确实是个很头大的问题，虽然有一些静态代码检测工具可以检测到这些异常，但是这样无聊的检测代码很是让人失望。Java 8引入的`Optional`确实可以部分缓解这部分问题；但是依然存在局限性，比如，如果某个特定的方法调用出了别的运行时异常怎么办？对于?Haskell Maybe Monad只吸收了一部分，不过已经很不错了，期待什么时候能引入Grovvy的`?.`操作符，在处理空指针问题上，`?.`更加简洁有力。

`Optional`虽好，但是Java 8目前并不普及，Android 就不用想了。虽然有[retrolambda][10]项目支持在Java 6里面使用lambda，但是它更多地是提供了语法糖：
1. lambda的实现使用的是匿名内部类而不是`invokedynamic`, 见[深入探索Java 8 Lambda表达式][11]
2. 方法引用是lambda的语法糖，实现相同
3. 接口默认方法实际上给接口生成了一个抽象方法，然后给所有接口的实现者添加了这个默认实现
4. 接口静态方法，实际上把静态方法放在另外一个类里面，然后把所有对接口静态方法的调用更换为对新生成类里面方法的调用

鉴于以上种种原因，在生产环境基本上不可能使用*retrolambda*了，大型系统还是老实一点吧。

虽然Grava项目也有一个`Optional`类，但是没有函数式接口，我们所能做的不过是把`if (obj == null)`替换为`if (opt.isPresend())`罢了；虽说能提高类型安全性，但是还是得写一堆shit一样的嵌套检测。

对于Android开发，想使用这个是没有希望了。但愿**Kotlin**能给我们惊喜。

## 参考
1. Chapter 9, "Optional: a better alternative to null," [from Java 8 in Action: Lambdas, Streams, and Functional-style Programming][7]
2. "[Monadic Java][8]" by Mario Fusco
3. [Processing Data with Java SE 8 Streams][9]

## 致谢
Thanks to Alan Mycroft and Mario Fusco for going through the adventure of writing Java 8 in Action: Lambdas, Streams, and Functional-style Programming with me.

## 关于作者
Raoul-Gabriel Urma (@raoulUK) is currently completing a PhD in computer science at the University of Cambridge, where he does research in programming languages. He's a coauthor of the upcoming book Java 8 in Action: Lambdas, Streams, and Functional-style Programming, published by Manning. He is also a regular speaker at major Java conferences (for example, Devoxx and Fosdem) and an instructor. In addition, he has worked at several well-known companies—including Google's Python team, Oracle's Java Platform group, eBay, and Goldman Sachs—as well as for several startup projects.

**原文**：http://www.oracle.com/technetwork/articles/java/java8-optional-2175753.html

[1]: http://7sbqce.com1.z0.glb.clouddn.com/blog2015-12-9-1.gif
[2]: http://7sbqce.com1.z0.glb.clouddn.com/blog2015-12-9-2.gif
[3]: http://www.oracle.com/technetwork/articles/java/architect-lambdas-part1-2080972.html
[4]: http://www.oraclejavamagazine-digital.com/javamagazine_open/20140304#pg51
[5]: http://7sbqce.com1.z0.glb.clouddn.com/blog2015-12-9-3.gif
[6]: http://7sbqce.com1.z0.glb.clouddn.com/blog2015-12-9-4.gif
[7]: http://www.manning.com/urma/
[8]: http://www.slideshare.net/mariofusco/monadic-java
[9]: http://www.oraclejavamagazine-digital.com/javamagazine_open/20140304#pg51
[10]: https://github.com/orfjackal/retrolambda
[11]: http://www.infoq.com/cn/articles/Java-8-Lambdas-A-Peek-Under-the-Hood