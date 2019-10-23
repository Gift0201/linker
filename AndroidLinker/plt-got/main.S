	.text
	.file	"main.c"
	.globl	print_banner            // -- Begin function print_banner
	.p2align	2
	.type	print_banner,@function
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
.Lfunc_end1:
	.size	main, .Lfunc_end1-main
                                        // -- End function
	.type	.L.str,@object          // @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"PLT and GOT\n"
	.size	.L.str, 13


	.ident	"Android (5220042 based on r346389c) clang version 8.0.7 (https://android.googlesource.com/toolchain/clang b55f2d4ebfd35bf643d27dbca1bb228957008617) (https://android.googlesource.com/toolchain/llvm 3c393fe7a7e13b0fba4ac75a01aa683d7a5b11cd) (based on LLVM 8.0.7svn)"
	.section	".note.GNU-stack","",@progbits
