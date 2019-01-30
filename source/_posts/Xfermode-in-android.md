title: Xfermode in android
date: 2015-09-23 13:10:49
tags: 
- Xfermode
- 2D graphics
categories:
- Android
- UI
---
Xfermode有三个实现类：AvoidXfermode, PixelXorXfermode以及PorterDuffXfermode。
前两个类因为不支持硬件加速在API level 16被标记为Deprecated了，用也可以，但是需要关闭硬件加速，简单说下。

## AvoidXfermode
>  AvoidXfermode xfermode will draw the src everywhere except on top of the
>  opColor or, depending on the Mode, draw only on top of the opColor.

这话翻译成中文太别扭了，自己理解吧。举个栗子，如果你想对原来图像进行处理，把红色换成绿色，可以使用这个；或者，你想把不是红色的换成某个颜色，也行。这里有一个容差值的概念，比如红色是0xff0000 但是在一定范围内也都是红色，如果你设定一个容差值，那么“各种符合要求的红色”都会被处理。

<!--more-->
## PixelXorfermode
  文档都说这种模式对于操作混合色没有什么用，还不支持硬件加速，pass，说说重头戏。

## PoterDuffXfermode
### Porter-Duff的由来
说来说去，这个到处都是PorterDuff的玩意儿到底是什么意思？

> Porter-Duff 操作是 1 组 12 项用于描述数字图像合成的基本手法，包括
> Clear、Source Only、Destination Only、Source Over、Source In、Source
> Out、Source Atop、Destination Over、Destination In、Destination
> Out、Destination Atop、XOR。通过组合使用 Porter-Duff 操作，可完成任意 2D
> 图像的合成。 
> Thomas Porter 和 Tom Duff 发表于 1984年原始论文的扫描[版本](http://keithp.com/~keithp/porterduff/p253-porter.pdf)

看到没！可以完成任意2D图像的合成，理论支撑，所以说是核武器～

###对文档的解释
如果去查阅文档这个模式怎么用，相信你一定会fuck：
```
    public enum Mode {
        /** [0, 0] */
        CLEAR       (0),
        /** [Sa, Sc] */
        SRC         (1),
        /** [Da, Dc] */
        DST         (2),
        /** [Sa + (1 - Sa)*Da, Rc = Sc + (1 - Sa)*Dc] */
        SRC_OVER    (3),
        /** [Sa + (1 - Sa)*Da, Rc = Dc + (1 - Da)*Sc] */
        DST_OVER    (4),
        /** [Sa * Da, Sc * Da] */
        SRC_IN      (5),
        /** [Sa * Da, Sa * Dc] */
        DST_IN      (6),
        // ...以下省略    
```
这尼玛是什么意思。。好了，别慌。如果懂些图形学，大致就知道：
Sa = Source alpha 
Da = Dest alpha
Sc = Source color
Dc = Dst color
如果用叠加的形式看，Dst是下面的图，也就是先画的图；Source是上面的图，也就是后面要画的图。

要说明的是，使用porterduffxfermode绘制的时候，由于窗口时透明的，如果出现**黑色结果**，那么就是这个原因，stackoberflow上有很多这样的[问题](http://stackoverflow.com/questions/18387814/drawing-on-canvas-porterduff-mode-clear-draws-black-why)答案说需要之前画一个bitmap，原因是对的，但是不应该这么处理，使用layer保存图层即可。
```
int count = canvas.saveLayer
paint.setXfermode()
canvas.drawXXX
canvas.restoreLayer()
```

### 实际效果测试以及mode含义
往上很多对于Xfermode的解释，使用API demo望文生义，并没有考虑到alpha通道的情况，实际上是错误的。典型的解释类似这种：
>4.PorterDuff.Mode.SRC_OVER
>  正常绘制显示，上下层绘制叠盖。
>5.PorterDuff.Mode.DST_OVER
> 上下层都显示。下层居上显示。
>6.PorterDuff.Mode.SRC_IN
>   取两层绘制交集。显示上层。
>7.PorterDuff.Mode.DST_IN
>  取两层绘制交集。显示下层。

只能说太肤浅了，我们根据上面的图像学的解释，alpha通道的存在意味着事情没那么简单，我们用实际的例子验证一下。
验证的代码如下：
```
@Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        // draw background
        canvas.drawColor(Color.WHITE);
        int count = canvas.saveLayer(0, 0, width, height, p, Canvas.ALL_SAVE_FLAG);
        canvas.save();
        canvas.scale(0.5f, 0.5f, width / 2, height / 2);

        canvas.drawBitmap(mDst, 0, 0, p);
        p.setXfermode(xfermode);
        canvas.drawBitmap(mSrc, 0, 0, p);
        p.setXfermode(null);
        canvas.restore();

        canvas.restoreToCount(count);
    }
```

这里的mSrc以及mDst分别对应我们绘制的SRC bitmap以及DST bitmap；理论已经解释过了，DST代表先画的，下层图像；SRC是后画的上层图像。测试的图像用代码画出来的：
```
@Override
    protected void onSizeChanged(int w, int h, int oldw, int oldh) {
        super.onSizeChanged(w, h, oldw, oldh);
        width = w;
        height = h;
        float halfWidth = width / 2;

        // DST Rect
        Paint p = new Paint(Paint.ANTI_ALIAS_FLAG);
        mSrc = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);
        mDst = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);

        Canvas canvas = new Canvas(mDst);
        p.setColor(Color.RED);
        canvas.drawRect(0, 0, halfWidth, height, p);
        p.setAlpha(1 << 7);
        canvas.drawRect(halfWidth, 0, width, height, p);

        canvas = new Canvas(mSrc);
        // SRC circle
        p.setColor(Color.BLUE);
        p.setAlpha((1 << 8) - 1);

        float radius = Math.min(height, width) / 2;
        mSrcRect.set(width / 2 - radius, height / 2 - radius, width / 2 + radius, height / 2 + radius);
        canvas.drawArc(mSrcRect, 0, 180, true, p);
        p.setAlpha(1 << 7);
        canvas.drawArc(mSrcRect, 180, 180, true, p);
    }
```

注意到，每一个图都有半透明和全透明的两周状态，画出来，肉眼看到效果如下：
![Src](http://http://weishu1.dimensionalzone.com/markdown/bdea3ba636d6818d213404e2b8715141.png?imageMogr2/thumbnail/!50p)![DST](http://http://weishu1.dimensionalzone.com/markdown/b1b7ff836a928e412a92425cfbac872d.png?imageMogr2/thumbnail/!50p)

#### SRC和DST
这个就不是解释了，SRC - [Sa, Sc]只有源图像的alpha和颜色，因此只保留源图像；DST也是一样。

####SRC_OVER 
 [ Sa +(1-Sa) * Da , Rc = Sc +( 1- Sa ) * Dc ]。从名字上看，从DST上面绘制SRC图像（透明度的叠加）：
![SRC_OVER](http://http://weishu1.dimensionalzone.com/markdown/44464b24373b955088f469bc0123348e.png?imageMogr2/thumbnail/!50p)

####DST_OVER 
[Sa + ( 1 - Sa ) * Da ,Rc = Dc + ( 1 - Da ) * Sc ]。与上面情况差不多，看看效果：
![DST_OVER](http://http://weishu1.dimensionalzone.com/markdown/d48a3385baf33b1e1eda1e68d65a6be5.png?imageMogr2/thumbnail/!50p)

#### SRC_IN
[ Sa * Da , Sc * Da ]。注意，alpha通道是SRC和DSTalpha的乘法叠加；颜色是SRC颜色与DSTalpha通道的叠加；考虑一下，我们的图像应该是个什么样子；首先确定图像范围。什么时候才会有图像呢，rgb应该有分量，alpha不能为0；所以rgb分量里面只有SRC，说明图像里面区域里面只有源图像；alpha通道只有DST，当DSTalpha为0的地方没有图像（这句话有两个意思，在DST完全透明的地方不存在源图像）简而言之，就是在相交的地方绘制源图像；但是绘制的alpha通道受DST影响：
![SRC_IN](http://http://weishu1.dimensionalzone.com/markdown/ae37f07bc86754f334dc4f509cf6acc6.png?imageMogr2/thumbnail/!50p)

#### DST_IN
[ Sa * Da , Sa * Dc ]。按照上面的理解。在相交的地方绘制DST，但是alpha受SRC影响：
![DST_IN](http://http://weishu1.dimensionalzone.com/markdown/323dbf2cb54e951a4a9d307ee4d53eb4.png?imageMogr2/thumbnail/!50p)

#### SRC_OUT
很多地方解释说：
>取上层绘制非交集部分。
>在不相交的地方绘制 源图像。

我们看看是不是这样：
![SRC_OUT](http://http://weishu1.dimensionalzone.com/markdown/a98043e9bdb9c64ce845dffc27bea020.png?imageMogr2/thumbnail/!50p)
说好的在不相交的地方绘制源图像呢？如果是这个意思，因为DST包含SRC，那么应该整个应该是什么都没有（待商榷，下面说）。为什么相交的地方还是有源图像？

看看这个porterduff公式：[ Sa * ( 1 - Da ) , Sc * ( 1 - Da ) ]
这里对应的rgb是`Sc * (1 - Da)`,
1. 在不相交的地方Da肯定是0，那么不相交的地方就是Sc也就是完全是SRC图像；
2. 在相交的地方是`Sc * (1 - Da)`也就是虽然是SRC的颜色，但是受到DST的alpha通道的影响。
3. 在相交地方的特殊情况，如果DST完全不透明，那么Da ＝ 1；这时候这个表达式值就是0；也就是通常的解释“绘制非交集部分（交集部分没有图像）”

总结一下，这种模式应该是：**在不相交的地方绘制源图像，在相交处根据DST的alpha进行过滤；**特殊情况下相交处DST不透明，那么相交处没有颜色，如果完全透明（相当于没有DST图像）

#### DST_OUT
 [ Da * ( 1 - Sa ) , Dc * ( 1 - Sa ) ] 与上面解释类似，不赘述。
 ![DST_OUT](http://http://weishu1.dimensionalzone.com/markdown/ce26aec4b49f6acfe068b34b01624816.png?imageMogr2/thumbnail/!50p)

#### SRC_ATOP
 [ Da , Sc * Da + ( 1 - Sa ) * Dc ]。与上面两种模式解释差不多，有一点不同。
 **源图像和目标图像相交处绘制源图像，不相交的地方绘制目标图像，并且相交处的效果会受到源图像和目标图像alpha的影响；**
 ![SRC_ATOP](http://http://weishu1.dimensionalzone.com/markdown/615a9819236eff103e67f66a5eeec253.png?imageMogr2/thumbnail/!50p)

#### DST_ATOP
[ Sa , Sa * Dc + Sc * ( 1 - Da ) ]，直接上解释。
**源图像和目标图像相交处绘制目标图像，不相交的地方绘制源图像，并且相交处的效果会受到源图像和目标图像alpha的影响；**
![DST_ATOP](http://http://weishu1.dimensionalzone.com/markdown/8f684c7abec84b009050626104a60047.png?imageMogr2/thumbnail/!50p)

#### XOR 
[ Sa + Da - 2 * Sa * Da, Sc * ( 1 - Da ) + ( 1 - Sa ) * Dc ]
**在不相交的地方按原样绘制源图像和目标图像，相交的地方受到对应alpha和色值影响。**按上面公式进行计算，如果都完全不透明则相交处完全不绘制；
![XOR](http://http://weishu1.dimensionalzone.com/markdown/6c6f1660106e7b28493e1b0d133fb65c.png?imageMogr2/thumbnail/!50p)

#### DARKEN 
[ Sa + Da - Sa * Da , Sc * ( 1 - Da ) + Dc * ( 1 - Sa ) + min(Sc , Dc) ]
从算法上看，alpha值变大，色值上如果都不透明则取较暗值，非完全不透明情况下使用上面算法进行计算，受到源图和目标图对应色值和alpha值影响；正如名字所说，会感觉效果变暗，即进行对应像素的比较，取较暗值，如果色值相同则进行混合；
![DSARKEN](http://http://weishu1.dimensionalzone.com/markdown/9f5083ff696b21876730d751ba59cd9b.png?imageMogr2/thumbnail/!50p)

####LIGHTEN
 [ Sa + Da - Sa * Da , Sc * ( 1 -Da ) + Dc * ( 1 - Sa ) + max ( Sc , Dc ) ]
 与DARKEN相反，LIGHTEN 的目的则是变亮，如果在均完全不透明的情况下 ，色值取源色值和目标色值中的较大值，否则按上面算法进行计算；
 ![LIGHTEN](http://http://weishu1.dimensionalzone.com/markdown/32bf36e760b74332bb1e901df98e8334.png?imageMogr2/thumbnail/!50p)

接下来四种 **MULTIFY**，**SCREEN**，**ADD**，**OVERLAY**就不说了，产生的结果不太确定。自己查阅文档吧。
emphasized text

