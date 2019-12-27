# linker

## kernel space (kernel exec)

当我们执行一个可执行程序的时候, 内核会list_for_each_entry遍历所有注册的linux_binfmt对象, 对其调用load_binrary方法来尝试加载, 直到加载成功为止。上面代码可以看倒，ELF中加载程序即为load_elf_binary，内核中已经注册的可运行文件结构linux_binfmt会让其所属的加载程序load_binary逐一前来认领需要运行的程序binary，如果某个格式的处理程序发现相符后，便执行该格式映像的装入和启动。

https://github.com/novelinux/linux-4.x.y/tree/master/fs/exec.c/sys_execve.md

```
$ readelf -l app_process32 

Elf file type is DYN (Shared object file)
Entry point 0x1739
There are 9 program headers, starting at offset 52

Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  PHDR           0x000034 0x00000034 0x00000034 0x00120 0x00120 R   0x4
  INTERP         0x000154 0x00000154 0x00000154 0x00013 0x00013 R   0x1
      [Requesting program interpreter: /system/bin/linker]
  LOAD           0x000000 0x00000000 0x00000000 0x05b87 0x05b87 R E 0x1000
  LOAD           0x005c98 0x00006c98 0x00006c98 0x00368 0x01205 RW  0x1000
  DYNAMIC        0x005d4c 0x00006d4c 0x00006d4c 0x00160 0x00160 RW  0x4
  NOTE           0x000168 0x00000168 0x00000168 0x00038 0x00038 R   0x4
  GNU_STACK      0x000000 0x00000000 0x00000000 0x00000 0x00000 RW  0x10
  EXIDX          0x0050ec 0x000050ec 0x000050ec 0x00220 0x00220 R   0x4
  GNU_RELRO      0x005c98 0x00006c98 0x00006c98 0x00368 0x00368 RW  0x4

 Section to Segment mapping:
  Segment Sections...
   00     
   01     .interp 
   02     .interp .note.android.ident .note.gnu.build-id .dynsym .dynstr .gnu.hash .gnu.version .gnu.version_r .rel.dyn .rel.plt .plt .text .ARM.exidx .ARM.extab .rodata 
   03     .preinit_array .init_array .fini_array .data.rel.ro .dynamic .got .bss 
   04     .dynamic 
   05     .note.android.ident .note.gnu.build-id 
   06     
   07     .ARM.exidx 
   08     .preinit_array .init_array .fini_array .data.rel.ro .dynamic .got 
```

前面的步骤已经完成了目标映像和解释器的加载，并且将目标程序的各个段家在近内存，但是，一个程序成功执行，操作系统还需要知道程序的入口地址，才能开始执行加载好的映像。如果需要动态链接，就通过load_elf_interp装入解释器映像, 并把将来进入用户空间的入口地址设置成load_elf_interp()的返回值，即解释器映像的入口地址。而若不需要装入解释器，那么这个入口地址就是目标映像本身的入口地址。

## user space (linker)

1.解释器（也可以叫动态链接器）首先检查可执行程序所依赖的共享库，并在需要的时候对其进行加载。ELF 文件有一个特别的节区： .dynamic，它存放了和动态链接相关的很多信息，例如动态链接器通过它找到该文件使用的动态链接库。找到动态链接库后，就可以将其加载到内存中。

```
$ arm-linux-androideabi-readelf -S app_process32 
There are 27 section headers, starting at offset 0x6d38:

Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            00000000 000000 000000 00      0   0  0
  [ 1] .interp           PROGBITS        00000154 000154 000013 00   A  0   0  1
  [ 2] .note.android.ide NOTE            00000168 000168 000018 00   A  0   0  4
  [ 3] .note.gnu.build-i NOTE            00000180 000180 000020 00   A  0   0  4
  [ 4] .dynsym           DYNSYM          000001a0 0001a0 000550 10   A  5   1  4
  [ 5] .dynstr           STRTAB          000006f0 0006f0 0007e5 00   A  0   0  1
  [ 6] .gnu.hash         GNU_HASH        00000ed8 000ed8 000048 04   A  4   0  4
  [ 7] .gnu.version      VERSYM          00000f20 000f20 0000aa 02   A  4   0  2
  [ 8] .gnu.version_r    VERNEED         00000fcc 000fcc 000060 00   A  5   2  4
  [ 9] .rel.dyn          REL             0000102c 00102c 000158 08   A  4   0  4
  [10] .rel.plt          REL             00001184 001184 000240 08  AI  4  21  4
  [11] .plt              PROGBITS        000013c4 0013c4 000374 00  AX  0   0  4
  [12] .text             PROGBITS        00001738 001738 0039b1 00  AX  0   0  4
  [13] .ARM.exidx        ARM_EXIDX       000050ec 0050ec 000220 08  AL 12   0  4
  [14] .ARM.extab        PROGBITS        0000530c 00530c 000030 00   A  0   0  4
  [15] .rodata           PROGBITS        00005340 005340 000847 00   A  0   0  8
  [16] .preinit_array    PREINIT_ARRAY   00006c98 005c98 000008 04  WA  0   0  4
  [17] .init_array       INIT_ARRAY      00006ca0 005ca0 00000c 04  WA  0   0  4
  [18] .fini_array       FINI_ARRAY      00006cac 005cac 000008 04  WA  0   0  4
  [19] .data.rel.ro      PROGBITS        00006cb4 005cb4 000098 00  WA  0   0  4
  [20] .dynamic          DYNAMIC         00006d4c 005d4c 000160 08  WA  5   0  4
  [21] .got              PROGBITS        00006eac 005eac 000154 00  WA  0   0  4
  [22] .bss              NOBITS          00007000 006000 000e9d 00  WA  0   0 16
  [23] .note.gnu.gold-ve NOTE            00000000 006000 00001c 00      0   0  4
  [24] .ARM.attributes   ARM_ATTRIBUTES  00000000 00601c 000040 00      0   0  1
  [25] .gnu_debugdata    PROGBITS        00000000 00605c 000bb8 00      0   0  1
  [26] .shstrtab         STRTAB          00000000 006c14 000123 00      0   0  1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings)
  I (info), L (link order), G (group), T (TLS), E (exclude), x (unknown)
  O (extra OS processing required) o (OS specific), p (processor specific)
```

2.解释器对程序的外部引用进行重定位，并告诉程序其引用的外部变量/函数的地址，此地址位于共享库被加载在内存的区间内。动态链接还有一个延迟定位的特性，即只有在“真正”需要引用符号时才重定位，这对提高程序运行效率有极大帮助。（如果设置了 LD_BIND_NOW 环境变量，这个动作就会直接进行）下面具体说明符号重定位的过程。

首先了解几个概念。 符号，也就是可执行程序代码段中的变量名、函数名等。重定位是将符号引用与符号定义进行链接的过程，对符号的引用本质是对其在内存中具体地址的引用，所以本质上来说，符号重定位要解决的是当前编译单元如何访问「外部」符号这个问题。动态链接是在程序运行时对符号进行重定位，也叫运行时重定位（而静态链接则是在编译时进行，也叫链接时重定位）现代操作系统中，二进制映像的代码段不允许被修改，而数据段能被修改。

但对于动态链接来说，有两个不同的地方：

*（1）因为不允许对可执行文件的代码段进行加载时符号重定位，因此如果可执行文件引用了动态库中的数据符号，则在该可执行文件内对符号的重定位必须在链接阶段完成，为做到这一点，链接器在构建可执行文件的时候，会在当前可执行文件的数据段里分配出相应的空间来作为该符号真正的内存地址，等到运行时加载动态库后，再在动态库中对该符号的引用进行重定位：把对该符号的引用指向可执行文件数据段里相应的区域。

*（2）ELF 文件对调用动态库中的函数采用了所谓的"延迟绑定"(lazy binding)策略, 只有当该函数在其第一次被调用发生时才最终被确认其真正的地址，因此我们不需要在调用动态库函数的地方直接填上假的地址，而是使用了一些跳转地址作为替换，这样一来连修改动态库和可执行程序中的相应代码都不需要进行了，当然延迟绑定的目的不是为了这个，具体先不细说。

可执行程序对符号的访问又分为模块内和模块间的访问，这里只介绍模块间的访问，也就是访问动态链接库中的符号。

### dynamic

[dynamic](./dynamic/README.md)

### PLT

PLT就是程序链接表（Procedure Link Table），属于代码段。用于把位置独立的函数调用重定向到绝对位置。每个动态链接的程序和共享库都有一个PLT，PLT表的每一项都是一小段代码，从对应的GOT表项中读取目标函数地址。程序对某个函数的第一次访问都被调整为对 PLT入口也就是PLT0的访问，也就是说所有的PLT首次执行时，最后都会跳转到第一个PLT中执行。PLT0是一段访问动态链接器的特殊代码，是动态链接做符号解析和重定位的公共入口。这样做的好处是不用每个PLT表都有重复的一份指令，可以减少PLT指令条数。

PLT表结构如下图所示

```
0000142c <strncmp@plt>:
    142c:	e28fc600 	add	ip, pc, #0, 12
    1430:	e28cca05 	add	ip, ip, #20480	; 0x5000
    1434:	e5bcfac8 	ldr	pc, [ip, #2760]!	; 0xac8

00001438 <strlen@plt>:
    1438:	e28fc600 	add	ip, pc, #0, 12
    143c:	e28cca05 	add	ip, ip, #20480	; 0x5000
    1440:	e5bcfac0 	ldr	pc, [ip, #2752]!	; 0xac0
```

### GOT

可以看到，PLT会先执行ldr pc指令跳转到某一个地址，而这个地址就对应的GOT表项。

GOT就是全局偏移表(Global Offset Table)，属于数据段。为了能使得代码段里对数据及函数的引用与具体地址无关，只能再作一层跳转，ELF 的做法是在动态库的数据段中加一个表项，也就是GOT 。GOT表格中放的是数据全局符号的地址，该表项在动态库被加载后由动态加载器进行初始化，动态库内所有对数据全局符号的访问都到该表中来取出相应的地址，即可做到与具体地址了，而该表作为动态库的一部分，访问起来与访问模块内的数据是一样的。


### linker logs

```
12-27 14:28:15.652 14098 14098 D linker  : dlopen(name="/data/app/com.ss.android.ugc.aweme-ZgFDboAF0nTs1aOAUv9vUw==/oat/arm/base.odex", flags=0x0, extinfo=[flags=0xc0, reserved_addr=0x0, reserved_size=0x0, relro_fd=0, library_fd=0, library_fd_offset=0x0, library_namespace=(n/a)@0x0], caller="/system/lib/libart.so", caller_ns=(default)@0xf58aa2e0) ...
12-27 14:28:15.657 14098 14098 D linker  : ... dlopen calling constructors: realpath="/data/app/com.ss.android.ugc.aweme-ZgFDboAF0nTs1aOAUv9vUw==/oat/arm/base.odex", soname="base.odex", handle=0x821850fb
12-27 14:28:15.657 14098 14098 D linker  : ... dlopen successful: realpath="/data/app/com.ss.android.ugc.aweme-ZgFDboAF0nTs1aOAUv9vUw==/oat/arm/base.odex", soname="base.odex", handle=0x821850fb
12-27 14:28:15.657 14098 14098 D linker  : dlsym(handle=0x821850fb("/data/app/com.ss.android.ugc.aweme-ZgFDboAF0nTs1aOAUv9vUw==/oat/arm/base.odex"), sym_name="oatdata", sym_ver="(null)", caller="/system/lib/libart.so", caller_ns=(default)@0xf58aa2e0) ...
12-27 14:28:15.657 14098 14098 D linker  : ... dlsym successful: sym_name="oatdata", sym_ver="(null)", found in="base.odex", address=0xd09c1000
12-27 14:28:15.657 14098 14098 D linker  : dlsym(handle=0x821850fb("/data/app/com.ss.android.ugc.aweme-ZgFDboAF0nTs1aOAUv9vUw==/oat/arm/base.odex"), sym_name="oatlastword", sym_ver="(null)", caller="/system/lib/libart.so", caller_ns=(default)@0xf58aa2e0) ...
12-27 14:28:15.657 14098 14098 D linker  : ... dlsym successful: sym_name="oatlastword", sym_ver="(null)", found in="base.odex", address=0xd1c88ffc
12-27 14:28:15.657 14098 14098 D linker  : dlsym(handle=0x821850fb("/data/app/com.ss.android.ugc.aweme-ZgFDboAF0nTs1aOAUv9vUw==/oat/arm/base.odex"), sym_name="oatbss", sym_ver="(null)", caller="/system/lib/libart.so", caller_ns=(default)@0xf58aa2e0) ...
12-27 14:28:15.657 14098 14098 D linker  : ... dlsym successful: sym_name="oatbss", sym_ver="(null)", found in="base.odex", address=0xd1c89000
12-27 14:28:15.657 14098 14098 D linker  : dlsym(handle=0x821850fb("/data/app/com.ss.android.ugc.aweme-ZgFDboAF0nTs1aOAUv9vUw==/oat/arm/base.odex"), sym_name="oatbsslastword", sym_ver="(null)", caller="/system/lib/libart.so", caller_ns=(default)@0xf58aa2e0) ...
12-27 14:28:15.657 14098 14098 D linker  : ... dlsym successful: sym_name="oatbsslastword", sym_ver="(null)", found in="base.odex", address=0xd1ca5e1c
12-27 14:28:15.657 14098 14098 D linker  : dlsym(handle=0x821850fb("/data/app/com.ss.android.ugc.aweme-ZgFDboAF0nTs1aOAUv9vUw==/oat/arm/base.odex"), sym_name="oatbssmethods", sym_ver="(null)", caller="/system/lib/libart.so", caller_ns=(default)@0xf58aa2e0) ...
12-27 14:28:15.657 14098 14098 D linker  : ... dlsym successful: sym_name="oatbssmethods", sym_ver="(null)", found in="base.odex", address=0xd1c89000
12-27 14:28:15.657 14098 14098 D linker  : dlsym(handle=0x821850fb("/data/app/com.ss.android.ugc.aweme-ZgFDboAF0nTs1aOAUv9vUw==/oat/arm/base.odex"), sym_name="oatbssroots", sym_ver="(null)", caller="/system/lib/libart.so", caller_ns=(default)@0xf58aa2e0) ...
12-27 14:28:15.657 14098 14098 D linker  : ... dlsym successful: sym_name="oatbssroots", sym_ver="(null)", found in="base.odex", address=0xd1c91a58
12-27 14:28:15.657 14098 14098 D linker  : dlsym(handle=0x821850fb("/data/app/com.ss.android.ugc.aweme-ZgFDboAF0nTs1aOAUv9vUw==/oat/arm/base.odex"), sym_name="oatdex", sym_ver="(null)", caller="/system/lib/libart.so", caller_ns=(default)@0xf58aa2e0) ...
12-27 14:28:15.657 14098 14098 D linker  : ... dlsym successful: sym_name="oatdex", sym_ver="(null)", found in="base.odex", address=0xd1ca6000
12-27 14:28:15.657 14098 14098 D linker  : dlsym(handle=0x821850fb("/data/app/com.ss.android.ugc.aweme-ZgFDboAF0nTs1aOAUv9vUw==/oat/arm/base.odex"), sym_name="oatdexlastword", sym_ver="(null)", caller="/system/lib/libart.so", caller_ns=(default)@0xf58aa2e0) ...
```

### 开启linker的log

```
setprop debug.ld.app.com.android.browser dlopen,dlerror 表示开启chrome的log
setprop debug.ld.all dlopen,dlerror 表示开启所有应用的log
```
