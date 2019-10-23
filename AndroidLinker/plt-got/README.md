## LLVM Command Guide

### 基本命令

```
llvm-as - LLVM assembler 汇编器
llvm-dis - LLVM disassembler 反汇编器
opt - LLVM optimizer 优化器
llc - LLVM static compiler 静态编译器
lli - directly execute programs from LLVM bitcode 直接执行LLVM 字节码
llvm-link - LLVM bitcode linker 字节码连接器
llvm-ar - LLVM archiver 归档器
llvm-nm -list LLVM bitcode and object file’s symbol table 列出LLVM字节码和目标文件中的符号表
llvm-config - Print LLVM compilation options 打印LLVM编译选项
llvm-diff - LLVM structual ‘diff’ LLVM结构上的diff
llvm-cov - emit coverage information 省略覆盖信息
llvm-stress - generate random .ll files 生成随机的.ll文件
llvm-symbolizer - convert addresses into source code locations 把地址值转换成源代码位置
```

### 调试工具

```
bugpoint - automatic test case reduction tool 自动测试用例下降工具
llvm-extract - extract a function from an LLVM module 从LLVM模块中抽取一个函数
llvm-bcanalyzer - LLVM bitcode analyzer LLVM字节码分析器
```

### 开发者工具

```
FileCheck - Flexible pattern matching file verifier 弹性模式匹配的文件验证器
tblgen - Target Description To C++ Code Generator 目标描述到C++代码生成器
lit - LLVM Integrated Tester LLVM集成的测试器
llvm-build - LLVM Project Build Utility LLVM项目生成工具
llvm-readobj - LLVM Object Reader LLVM目标文件阅读器
```

### examples

1.Assembly

aarch64-linux-android29-clang main.c -S -O0 -o -

```
print_banner:                           // @print_banner
// %bb.0:
	stp	x29, x30, [sp, #-16]!   // 16-byte Folded Spill
	mov	x29, sp
	adrp	x8, .L.str
	add	x8, x8, :lo12:.L.str
	mov	x0, x8
	bl	printf
	ldp	x29, x30, [sp], #16     // 16-byte Folded Reload
	ret
.Lfunc_end0:
	.size	print_banner, .Lfunc_end0-print_banner
                                        // -- End function
	.globl	main                    // -- Begin function main
	.p2align	2
	.type	main,@function
main:                                   // @main
// %bb.0:
	sub	sp, sp, #32             // =32
	stp	x29, x30, [sp, #16]     // 16-byte Folded Spill
	add	x29, sp, #16            // =16
	mov	w0, #0
	stur	wzr, [x29, #-4]
	str	w0, [sp, #8]            // 4-byte Folded Spill
	bl	print_banner
	ldr	w0, [sp, #8]            // 4-byte Folded Reload
	ldp	x29, x30, [sp, #16]     // 16-byte Folded Reload
	add	sp, sp, #32             // =32
	ret
```

print_banner函数内调用了printf函数，而printf函数位于glibc动态库内，所以在编译和链接阶段，链接器无法知知道进程运行起来之后printf函数的加载地址。故上述的**<printf函数地址>**一项是无法填充的，只有进程运运行后，printf函数的地址才能确定。

那么问题来了：进程运行起来之后，glibc动态库也装载了，printf函数地址亦已确定，上述bl指令如何修改（重定位）呢？

一个简单的方法就是将指令中的**<printf函数地址>**修改printf函数的真正地址即可。

但这个方案面临两个问题：

* 现代操作系统不允许修改代码段，只能修改数据段
* 如果print_banner函数是在一个动态库（.so对象）内，修改了代码段，那么它就无法做到系统内所有进程共享同一个动态库。

因此，printf函数地址只能回写到数据段内，而不能回写到代码段上。

注意：刚才谈到的回写，是指运行时修改，更专业的称谓应该是**运行时重定位**，与之相对应的还有**链接时重定位**。

2. Compile

```
aarch64-linux-android29-clang main.S -c -o main.o
aarch64-linux-android-objdump -d main.o
```

编译阶段是将.c源代码翻译成汇编指令的中间文件，比如上述的main.c文件，经过编译之后，生成main.o中间文件

```
main.o:     file format elf64-littleaarch64


Disassembly of section .text:

0000000000000000 <print_banner>:
   0:	a9bf7bfd 	stp	x29, x30, [sp,#-16]!
   4:	910003fd 	mov	x29, sp
   8:	90000008 	adrp	x8, 0 <print_banner>
   c:	91000108 	add	x8, x8, #0x0
  10:	aa0803e0 	mov	x0, x8
  14:	94000000 	bl	0 <printf>
  18:	a8c17bfd 	ldp	x29, x30, [sp],#16
  1c:	d65f03c0 	ret

0000000000000020 <main>:
  20:	d10083ff 	sub	sp, sp, #0x20
  24:	a9017bfd 	stp	x29, x30, [sp,#16]
  28:	910043fd 	add	x29, sp, #0x10
  2c:	52800000 	mov	w0, #0x0                   	// #0
  30:	b81fc3bf 	stur	wzr, [x29,#-4]
  34:	b9000be0 	str	w0, [sp,#8]
  38:	97fffff2 	bl	0 <print_banner>
  3c:	b9400be0 	ldr	w0, [sp,#8]
  40:	a9417bfd 	ldp	x29, x30, [sp,#16]
  44:	910083ff 	add	sp, sp, #0x20
  48:	d65f03c0 	ret
```

是否注意到bl指令的操作数是0。这里应该存放printf函数的地址，但由于编译阶段无法知道printf函数的地址，所以预先放一个0在这里，然后用重定位项来描述：这个地址在链接时要修正，它的修正值是根据printf地址（更确切的叫法应该是符号，链接器眼中只有符号，没有所谓的函数和变量）来修正，它的修正方式按相对引用方式。

这个过程称为链接时重定位，与刚才提到的运行时重定位工作原理完全一样，只是修正时机不同。

3. Linker

```
aarch64-linux-android29-clang main.o -o a.out
aarch64-linux-android-objdump -d a.out
```

链接阶段是将一个或者多个中间文件（.o文件）通过链接器将它们链接成一个可执行文件，链接阶段主要完成以下事情：

* 各个中间文之间的同名section合并
* 对代码段，数据段以及各符号进行地址分配
* 链接时重定位修正

除了重定位过程，其它动作是无法修改中间文件中函数体内指令的，而重定位过程也只能是修改指令中的操作数，换句话说，链接过程无法修改编译过程生成的汇编指令。

那么问题来了：编译阶段怎么知道printf函数是在glibc运行库的，而不是定义在其它.o中?
答案往往令人失望：编译器是无法知道的

那么编译器只能老老实实地生成调用printf的汇编指令，printf是在glibc动态库定位，或者是在其它.o定义这两种情况下，它都能工作。如果是在其它.o中定义了printf函数，那在链接阶段，printf地址已经确定，可以直接重定位。如果printf定义在动态库内（链接阶段是可以知道printf在哪定义的，只是如果定义在动态库内不知道它的地址而已），链接阶段无法做重定位。

根据前面讨论，运行时重定位是无法修改代码段的，只能将printf重定位到数据段。那在编译阶段就已生成好的bl指令，怎么感知这个已重定位好的数据段内容呢？

答案是：链接器生成一段额外的小代码片段，通过这段代码支获取printf函数地址，并完成对它的调用。

```
a.out:     file format elf64-littleaarch64


Disassembly of section .plt:

0000000000000570 <printf@plt-0x20>:
 570:	a9bf7bf0 	stp	x16, x30, [sp,#-16]!
 574:	90000090 	adrp	x16, 10000 <main+0xf98c>
 578:	f947da11 	ldr	x17, [x16,#4016]
 57c:	913ec210 	add	x16, x16, #0xfb0
 580:	d61f0220 	br	x17
 584:	d503201f 	nop
 588:	d503201f 	nop
 58c:	d503201f 	nop

// 获取printf重定位之后的地址
0000000000000590 <printf@plt>:
 590:	90000090 	adrp	x16, 10000 <main+0xf98c>
 594:	f947de11 	ldr	x17, [x16,#4024]
 598:	913ee210 	add	x16, x16, #0xfb8
 59c:	d61f0220 	br	x17 // 跳过去执行printf函数

...

0000000000000654 <print_banner>:
 654:	a9bf7bfd 	stp	x29, x30, [sp,#-16]!
 658:	910003fd 	mov	x29, sp
 65c:	90000008 	adrp	x8, 0 <note_android_ident-0x218>
 660:	911a8108 	add	x8, x8, #0x6a0
 664:	aa0803e0 	mov	x0, x8
 668:	97ffffca 	bl	590 <printf@plt>
 66c:	a8c17bfd 	ldp	x29, x30, [sp],#16
 670:	d65f03c0 	ret

0000000000000674 <main>:
 674:	d10083ff 	sub	sp, sp, #0x20
 678:	a9017bfd 	stp	x29, x30, [sp,#16]
 67c:	910043fd 	add	x29, sp, #0x10
 680:	52800000 	mov	w0, #0x0                   	// #0
 684:	b81fc3bf 	stur	wzr, [x29,#-4]
 688:	b9000be0 	str	w0, [sp,#8]
 68c:	97fffff2 	bl	654 <print_banner>
 690:	b9400be0 	ldr	w0, [sp,#8]
 694:	a9417bfd 	ldp	x29, x30, [sp,#16]
 698:	910083ff 	add	sp, sp, #0x20
 69c:	d65f03c0 	ret
```

### 动态链接姐妹花PLT与GOT

前面由一个简单的例子说明动态链接需要考虑的各种因素，但实际总结起来说两点：

* 需要存放外部函数的数据段
* 获取数据段存放函数地址的一小段额外代码
* 如果可执行文件中调用多个动态库函数，那每个函数都需要这两样东西，这样每样东西就形成一个表，每个函数使用中的一项。

总不能每次都叫这个表那个表，于是得正名。存放函数地址的数据表，称为重局偏移表（GOT, Global Offset Table），而那个额外代码段表，称为程序链接表（PLT，Procedure Link Table）。它们两姐妹各司其职，联合出手上演这一出运行时重定位好戏。

那么PLT和GOT长得什么样子呢？前面已有一些说明，下面以一个例子和简单的示意图来说明PLT/GOT是如何运行的。

假设最开始的示例代码main.c增加一个write_file函数，在该函数里面调用glibc的write实现写文件操作。根据前面讨论的PLT和GOT原理，test在运行过程中，调用方（如print_banner和write_file)是如何通过PLT和GOT穿针引线之后，最终调用到glibc的printf和write函数的？

PLT和GOT雏形图:
[PLT@GOT](./plt-got.jpeg)

动态库函数调用使用GOT表技术，然后PLT从GOT中获取地址并完成调用。这个前提是GOT必须在PLT执行之前，所有函数都已完成运行时重定位。

然而在Linux的世界里面，几乎所有可能的事情，都尽可能地延迟推后，直至无法退避时，才做最后的修正工作。典型的案例有：

* fork之后父子进程内存的写时拷贝机制
* Linux用户态内存空间分配与物理内存分配机制
* C++库的string类写时拷贝机制

### 延迟重定位

如果可执行文件调用的动态库函数很多时，那在进程初始化时都对这些函数做地址解析和重定位工作，大大增加进程的启动时间。所以Linux提出延迟重定位机制，只有动态库函数在被调用时，才会地址解析和重定位工作。

进程启动时，先不对GOT表项做重定位，等到要调用该函数时才做重定位工作。要实现这个机制必须要有一个状态描述该GOT表项是否已完重定位。

一个显而易见的方案是在GOT中增加一个状态位，描述一个GOT表项是否已完成重定位，那么每个函数就有两个GOT表项了。相应的PLT伪代码如何：

```
void printf@plt()
{
    if (printf@got[0] ！= RELOCATED) { // 如果没完成重定位
        调用重定位函数
        printf@got[1] = 地址解析发现的printf地址;
        printf@got[0] = RELOCATED;
    }

    jmp *printf@got[1];
}
```

这个方案每个函数使用两个GOT表项，占用内存明显增长了一倍。但仔细观察GOT表项中的状态位和真实地址项，这两项在任何时候都不会同时使用，那么这两个变量能复用一个GOT项来实现呢？答案是可以的，Linux动态链接器就使用类似的巧妙方案，将这两个GOT表项合二为一。

具体怎么做呢？很简单，先将上面的代码倒过来写：

```
void printf@plt()
{
address_good:
    jmp *printf@got        // 链接器将printf@got填成下一语句lookup_printf的地址
lookup_printf:
    goto address_good;     // 调用重定位函数查找printf地址，并写到printf@got
}
```

在链接成可执行文件a.out时，链接器将printf@got表项的内容填写lookup_printf标签的地址。也即是程序第一次调用printf时，通过printf@got表项引导到查找printf的plt指令的后半部分。在后半部分中跳到动态链接器中将printf址解析出来，并重定位回printf@got项内。那么神奇的作用来，第二次调用printf时，通过printf@got直接跳到printf函数执行了

最后所有plt都跳转到.plt中执行，这是动态链接做符号解析和重定位的公共入口，而不是每个plt表都有重复的一份指令。为了减少PLT指令条数，Linux提炼成了公共函数。


原文链接：https://blog.csdn.net/linyt/article/details/51636753