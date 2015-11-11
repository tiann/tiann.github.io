title: Java高效分割字符串
date: 2015-11-10 18:52:34
tags:
- split
---

最近优化一段代码的调用时间，发现性能瓶颈居然是io和split！io操作慢情有可原，那么对于split有没有更高效的方法呢？

## 一般方法
再java里面，一般的split 字符串解决方案有三种：
1. 直接用split函数
2. 使用StingTokenizer类
3. 用`indexOf,subString`实现；

在JDK6的实现中，String类的split直接使用了正则表达式；不得不说，真是杀鸡焉用牛刀。
```java
public String[] split(String regex, int limit) {
        return Pattern.compile(regex).split(this, limit);
}
```
在Android VM(Android 4.0以上系统源码如此)里面，对这个方法做了一定的优化：
<!-- more -->
```java
 public String[] split(String regularExpression, int limit) {
        String[] result = java.util.regex.Splitter.fastSplit(regularExpression, this, limit);
        return result != null ? result : Pattern.compile(regularExpression).split(this, limit);
    }
```
使用正则的话，效率肯定是有问题的；具体我们看一看就知道了。`StringTokenizer`是一个流式解析类，虽然JDK已经deprecated很久了，但是还是无法阻止大量的开源库使用这个类，效果自然得到了广泛的认可；另外呢，对于简单的分隔符，比如空格，单个字符等，可以直接使用`indexOf`得到索引，然后用`subString`得到字串；在这种情况下，理论上效率比上述两种高出很多；首先`indexOf`这个查找操作肯定是`o(logn)`，然后，求字串最多也是线性操作。具体效率如何，测试一下就知道了。

## 测试
我们选择的测试字符串对象，是`ps`得到的输出，然后，写一个测试类，然后在Android下面运行：
```java
package com.example.test.app;

import java.util.ArrayList;
import java.util.List;
import java.util.StringTokenizer;

public class TestSplitter {
		private static final String line =
            "root      1     0     572    436   c014bbc4 00011304 S /init";

    private static final int RUNS = 1000000;// 000000;

    private static final int COLUMNS = 9;

    private static String[] splitBySplit() {
        return line.split("\\s+");
    }

    private static List<String> splitByIndex() {
        List<String> l = new ArrayList<String>(16);

        int[] lp = getPsLinePos(line);
        for (int i1 = 1; i1 < COLUMNS - 1; i1++) {
            l.add(line.substring(lp[i1 - 1], lp[i1]));
        }
        l.add(line.substring(lp[COLUMNS - 1]));
        return l;
    }

    static int[] sPos;

    private static List<String> splitByIndex2() {
        List<String> l = new ArrayList<String>(16);

        if (sPos == null) {
            sPos = getPsLinePos(line);
        }
        for (int i1 = 1; i1 < COLUMNS - 1; i1++) {
            l.add(line.substring(sPos[i1 - 1], sPos[i1]));
        }
        l.add(line.substring(sPos[COLUMNS - 1]));
        return l;
    }

    private static int[] getPsLinePos(String line) {
        // 以下是为了得到每一列的pos;不在循环里面判空,节省调用
        int[] lp = new int[COLUMNS];
        lp[0] = 0; // 第一个起点是开始
        int index = 0;
        char lastChar;
        char curChar;

        int length = line.length();
        for (int j = 1; j < length; j++) {
            lastChar = line.charAt(j - 1);
            curChar = line.charAt(j);

            if (index + 1 >= COLUMNS) {
                break;
            }

            if (lastChar == ' ' && curChar != ' ') {
                // 如果是从空格突变为非空格,那么就是起始点
                lp[++index] = j;
            }
        }
        return lp;
    }

    private static List<String> splitByTokenizer() {
        List<String> l = new ArrayList<String>(16);
        StringTokenizer st = new StringTokenizer(line);
        while (st.hasMoreTokens()) {
            l.add(st.nextToken());
        }
        return l;
    }

    private static void test(Test test) {
        long start = System.currentTimeMillis();
        for (int i = 0; i < RUNS; i++) {
            test.run();
        }
        System.out.println(String.format("%s use time: %s(ms)", test.tag, System.currentTimeMillis() - start));
    }

    public static void main() {
        Test split = new Test("Split") {
            @Override
            void run() {
                splitBySplit();
            }
        };

        Test string = new Test("StringTokenizer") {
            @Override
            void run() {
                splitByTokenizer();
            }
        };

        Test index = new Test("indexOf") {
            @Override
            void run() {
                splitByIndex();
            }
        };

        Test index2 = new Test("indexOf2") {
            @Override
            void run() {
                splitByIndex2();
            }
        };

        test(split);
        test(string);
        test(index);
        test(index2);

    }

    abstract static class Test {

        String tag;

        Test(String tag) {
            this.tag = tag;
        }

        abstract void run();

    }
}
```

## 结果
代码有点长，能用lambda就简洁了，这时后话；看一看性能表现如何（以下使用的是Htc x920e 4.4.2系统测试的）：
```
I/System.out﹕ Split use time: 2267(ms)
I/System.out﹕ StringTokenizer use time: 326(ms)
I/System.out﹕ indexOf use time: 218(ms)
I/System.out﹕ indexOf2 use time: 157(ms)
```

这下体会到split有多么慢了吧！`StringTokenizer`与`indexOf`时间在一个数量级，优化后的indexOf稍微好点，大致快一倍。

## 结论

1. 在split需要被大量调用的场合，在现有的Android VM里面，`String`类的`split`方法**肯定是不符合要求的**
2. `StringTokenizer`是最廉价的替换split的方法，简单修改成这个实现之后，花费时间能提升一个数量级；
3. `indexOf`结合`subString`经过充分的优化，对于**结构化**特别是**表格类**的数据，效率是最快的，对于特定场合，可以考虑使用这种方法，速度大致提升一倍。

## 题外话
### JDK8
自己的mac上面装的是jdk8，我看了一下String在上面的实现，如下：
```
public String[] split(String regex, int limit) {
        /* fastpath if the regex is a
         (1)one-char String and this character is not one of the
            RegEx's meta characters ".$|()[{^?*+\\", or
         (2)two-char String and the first char is the backslash and
            the second is not the ascii digit or ascii letter.
         */
        char ch = 0;
        if (((regex.value.length == 1 &&
             ".$|()[{^?*+\\".indexOf(ch = regex.charAt(0)) == -1) ||
             (regex.length() == 2 &&
              regex.charAt(0) == '\\' &&
              (((ch = regex.charAt(1))-'0')|('9'-ch)) < 0 &&
              ((ch-'a')|('z'-ch)) < 0 &&
              ((ch-'A')|('Z'-ch)) < 0)) &&
            (ch < Character.MIN_HIGH_SURROGATE ||
             ch > Character.MAX_LOW_SURROGATE))
        {
            int off = 0;
            int next = 0;
            boolean limited = limit > 0;
            ArrayList<String> list = new ArrayList<>();
            while ((next = indexOf(ch, off)) != -1) {
                if (!limited || list.size() < limit - 1) {
                    list.add(substring(off, next));
                    off = next + 1;
                } else {    // last one
                    //assert (list.size() == limit - 1);
                    list.add(substring(off, value.length));
                    off = value.length;
                    break;
                }
            }
            // If no match was found, return this
            if (off == 0)
                return new String[]{this};

            // Add remaining segment
            if (!limited || list.size() < limit)
                list.add(substring(off, value.length));

            // Construct result
            int resultSize = list.size();
            if (limit == 0) {
                while (resultSize > 0 && list.get(resultSize - 1).length() == 0) {
                    resultSize--;
                }
            }
            String[] result = new String[resultSize];
            return list.subList(0, resultSize).toArray(result);
        }
        return Pattern.compile(regex).split(this, limit);
    }
```
上面的实现可以看到：**对于单个字符或者两个字符（后面限制条件不翻译了）作为分割的时候，JDK对它进行了优化！**，看一看在JDK8上面的结论：（需要把那个正则替换成空格）
```
Split use time: 43(ms)
StringTokenizer use time: 15(ms)
indexOf use time: 14(ms)
indexOf2 use time: 7(ms)
```
效果惊人！！硬生生拉到了一个数量级！所以说，**没事升级下JDK还是很有必要的，免费的午餐不过如此**。
