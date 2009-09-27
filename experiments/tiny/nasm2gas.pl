#!/usr/bin/perl -W
#
# nasm2gas.pl - Skrypt konwertujacy kod w skladni NASMa na kod w skladni GAS (GNU as)
# nasm2gas.pl - A script which converts NASM code to GAS (GNU as) code.
#
#	Copyright (C) 2006-2009 Bogdan 'bogdro' Drozdowski, http://rudy.mif.pg.gda.pl/~bogdro/inne/
#		(bogdandr AT op.pl, bogdro AT rudy.mif.pg.gda.pl)
#
#	Licencja / Licence:
#	Powszechna Licencja Publiczna GNU v3+ / GNU General Public Licence v3+
#
#	Ostatnia modyfikacja / Last modified : 2009-07-28
#
#	Sposob uzycia / Syntax:
#		./nasm2gas.pl xxx.[n]asm [yyy.s]
#
# Jesli nazwa pliku wyjsciowego nie zostanie podana, jest brana taka sama jak pliku
#	wejsciowego (tylko rozszerzenie sie zmieni na .s). Jesli za nazwe
#	pliku wejsciowego podano "-", czytane jest standardowe wejscie.
#	Jesli nazwa pliku wyjsciowego to "-" (lub nie ma jej, gdy wejscie to stdin),
#	wynik bedzie na standardowym wyjsciu.
#
# If there's no output filename, then it is assumed to be the same as the
#	input filename (only the extension will be changed to .s). If the
#	input filename is "-", standard input will be read. If the
#	output filename is "-" (or missing, when input is stdin),
#	the result will be written to the standard output.
#
#    Niniejszy program jest wolnym oprogramowaniem; mozesz go
#    rozprowadzac dalej i/lub modyfikowac na warunkach Powszechnej
#    Licencji Publicznej GNU, wydanej przez Fundacje Wolnego
#    Oprogramowania - wedlug wersji 3-ciej tej Licencji lub ktorejs
#    z pozniejszych wersji.
#
#    Niniejszy program rozpowszechniany jest z nadzieja, iz bedzie on
#    uzyteczny - jednak BEZ JAKIEJKOLWIEK GWARANCJI, nawet domyslnej
#    gwarancji PRZYDATNOSCI HANDLOWEJ albo PRZYDATNOSCI DO OKRESLONYCH
#    ZASTOSOWAN. W celu uzyskania blizszych informacji - Powszechna
#    Licencja Publiczna GNU.
#
#    Z pewnoscia wraz z niniejszym programem otrzymales tez egzemplarz
#    Powszechnej Licencji Publicznej GNU (GNU General Public License);
#    jesli nie - napisz do Free Software Foudation:
#		Free Software Foundation
#		51 Franklin Street, Fifth Floor
#		Boston, MA 02110-1301
#		USA
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foudation:
#		Free Software Foundation
#		51 Franklin Street, Fifth Floor
#		Boston, MA 02110-1301
#		USA

use strict;
use warnings;
use Getopt::Long;

my ($wyj, @instr, @regs, $context);
my ($a1, $a2, $a3, $a4);


# instrukcje do zmiany (instructions to be changed)
@instr = (
		'mov' , 'and' , 'or'  , 'not', 'xor', 'neg', 'cmp', 'add' ,
		'sub' , 'push', 'test', 'lea', 'pop', 'inc', 'dec', 'idiv',
		'imul', 'sbb' , 'sal' , 'shl', 'sar', 'shr'
		);

my @regs8 = (
		'al', 'bl', 'cl', 'dl', 'r8b', 'r9b', 'r10b', 'r11b',
		'r12b', 'r13b', 'r14b', 'r15b', 'sil', 'dil', 'spl', 'bpl',
		'ah', 'bh', 'ch', 'dh'
		);

my @regs16 = (
		'ax', 'bx', 'cx', 'dx', 'r8w', 'r9w', 'r10w', 'r11w',
		'r12w', 'r13w', 'r14w', 'r15w', 'si', 'di', 'sp', 'bp',
		'cs', 'ds', 'es', 'fs', 'gs', 'ss'
		);

my @regs32 = (
		'eax',	'ebx', 'ecx', 'edx', 'r8d', 'r8l', 'r9d', 'r9l',
		'r10d', 'r10l', 'r11d', 'r11l', 'r12d', 'r12l', 'r13d', 'r13l',
		'r14d', 'r14l', 'r15d', 'r15l', 'esi', 'edi', 'esp', 'ebp',
		'cr0', 'cr2', 'cr3', 'cr4',
		'dr0', 'dr1', 'dr2', 'dr3', 'dr6', 'dr7',
		'st0', 'st1', 'st2', 'st3', 'st4', 'st5', 'st6', 'st7',
		);

my @regs64 = (
		'rax', 'rbx', 'rcx', 'rdx', 'r8', 'r9', 'r10', 'r11',
		'r12', 'r13', 'r14', 'r15', 'rsi', 'rdi', 'rsp', 'rbp', 'rip'
		);

my @regmm = (
		'mm0', 'mm1', 'mm2', 'mm3', 'mm4', 'mm5', 'mm6', 'mm7',
		'xmm0', 'xmm1', 'xmm2', 'xmm3', 'xmm4', 'xmm5', 'xmm6', 'xmm7',
		'xmm8', 'xmm9', 'xmm10', 'xmm11', 'xmm12', 'xmm13', 'xmm14', 'xmm15'
		);

@regs = ( @regs8, @regs16, @regs32, @regs64, @regmm );

sub isreg {

	my $elem = shift;
	foreach(@regs) {
		return 1 if /\b$elem\b/i;
	}
	return 0;
}

sub isreg8 {

	my $elem = shift;
	foreach(@regs8) {
		return 1 if /\b$elem\b/i;
	}
	return 0;
}

sub isreg16 {

	my $elem = shift;
	foreach(@regs16) {
		return 1 if /\b$elem\b/i;
	}
	return 0;
}

sub isreg32 {

	my $elem = shift;
	foreach(@regs32) {
		return 1 if /\b$elem\b/i;
	}
	return 0;
}

my @instrukcje = (
	'aaa', 'aad', 'aam', 'aas', 'adc', 'add', 'addpd', 'addps', 'addsd', 'addss', 'addsubpd',
	'addsubps', 'aesdec', 'aesdeclast', 'aesenc', 'aesenclast', 'aesimc', 'aeskeygenassist',
	'and', 'andnpd', 'andnps', 'andpd', 'andps', 'arpl', 'bb0_reset', 'bb1_reset', 'blendpd',
	'blendps', 'blendvpd', 'blendvps', 'bound', 'bsf', 'bsr', 'bswap', 'bt', 'btc', 'btr',
	'bts', 'call', 'cbw', 'cdq', 'cdqe', 'clc', 'cld', 'clflush', 'clgi', 'cli', 'clts',
	'cmc', 'cmova', 'cmovae', 'cmovb', 'cmovbe', 'cmovc', 'cmove', 'cmovg', 'cmovge',
	'cmovl', 'cmovle', 'cmovna', 'cmovnae', 'cmovnb', 'cmovnbe', 'cmovnc',
	'cmovne', 'cmovng', 'cmovnge', 'cmovnl', 'cmovnle', 'cmovno', 'cmovnp',
	'cmovns', 'cmovnz', 'cmovo', 'cmovp', 'cmovpe', 'cmovpo', 'cmovs', 'cmovz',
	'cmp', 'cmpeqpd', 'cmpeqps', 'cmpeqsd', 'cmpeqss', 'cmplepd', 'cmpleps', 'cmplesd', 'cmpless',
	'cmpltpd', 'cmpltps', 'cmpltsd', 'cmpltss', 'cmpneqpd', 'cmpneqps', 'cmpneqsd', 'cmpneqss',
	'cmpnlepd', 'cmpnleps', 'cmpnlesd', 'cmpnless', 'cmpnltpd', 'cmpnltps', 'cmpnltsd',
	'cmpnltss', 'cmpordpd', 'cmpordps', 'cmpordsd', 'cmpordss', 'cmppd', 'cmpps', 'cmpsb',
	'cmpsd', 'cmpsq', 'cmpss', 'cmpsw', 'cmpunordpd', 'cmpunordps', 'cmpunordsd', 'cmpunordss',
	'cmpxchg', 'cmpxchg16b', 'cmpxchg486', 'cmpxchg8b', 'comeqpd', 'comeqps', 'comeqsd',
	'comeqss', 'comfalsepd', 'comfalseps', 'comfalsesd', 'comfalsess', 'comisd', 'comiss',
	'comlepd', 'comleps', 'comlesd', 'comless', 'comltpd', 'comltps', 'comltsd', 'comltss',
	'comneqpd', 'comneqps', 'comneqsd', 'comneqss', 'comnlepd', 'comnleps', 'comnlesd', 'comnless',
	'comnltpd', 'comnltps', 'comnltsd', 'comnltss', 'comordpd', 'comordps', 'comordsd',
	'comordss', 'compd', 'comps', 'comsd', 'comss', 'comtruepd', 'comtrueps', 'comtruesd',
	'comtruess', 'comueqpd', 'comueqps', 'comueqsd', 'comueqss', 'comulepd', 'comuleps', 'comulesd',
	'comuless', 'comultpd', 'comultps', 'comultsd', 'comultss', 'comuneqpd', 'comuneqps', 'comuneqsd',
	'comuneqss', 'comunlepd', 'comunleps', 'comunlesd', 'comunless', 'comunltpd', 'comunltps',
	'comunltsd', 'comunltss', 'comunordpd', 'comunordps', 'comunordsd', 'comunordss', 'cpuid',
	'cpu_read', 'cpu_write', 'cqo', 'crc32', 'cvtdq2pd', 'cvtdq2ps', 'cvtpd2dq', 'cvtpd2pi',
	'cvtpd2ps', 'cvtph2ps', 'cvtpi2pd', 'cvtpi2ps', 'cvtps2dq', 'cvtps2pd', 'cvtps2ph',
	'cvtps2pi', 'cvtsd2si', 'cvtsd2ss', 'cvtsi2sd', 'cvtsi2ss', 'cvtss2sd', 'cvtss2si', 'cvttpd2dq',
	'cvttpd2pi', 'cvttps2dq', 'cvttps2pi', 'cvttsd2si', 'cvttss2si', 'cwd', 'cwde', 'daa', 'das',
	'dec', 'div', 'divpd', 'divps', 'divsd', 'divss', 'dmint', 'dppd', 'dpps', 'emms', 'enter',
	'equ', 'extractps', 'extrq', 'f2xm1', 'fabs', 'fadd', 'faddp', 'fbld', 'fbstp', 'fchs', 'fclex',
	'fcmovb', 'fcmovbe', 'fcmove', 'fcmovnb', 'fcmovnbe', 'fcmovne', 'fcmovnu', 'fcmovu', 'fcom',
	'fcomi', 'fcomip', 'fcomp', 'fcompp', 'fcos', 'fdecstp', 'fdisi', 'fdiv', 'fdivp', 'fdivr',
	'fdivrp', 'femms', 'feni', 'ffree', 'ffreep', 'fiadd', 'ficom', 'ficomp', 'fidiv', 'fidivr',
	'fild', 'fimul', 'fincstp', 'finit', 'fist', 'fistp', 'fisttp', 'fisub', 'fisubr', 'fld',
	'fld1', 'fldcw', 'fldenv', 'fldl2e', 'fldl2t', 'fldlg2', 'fldln2', 'fldpi', 'fldz', 'fmaddpd',
	'fmaddps', 'fmaddsd', 'fmaddss', 'fmsubpd', 'fmsubps', 'fmsubsd', 'fmsubss', 'fmul', 'fmulp',
	'fnclex', 'fndisi','fneni', 'fninit', 'fnmaddpd', 'fnmaddps', 'fnmaddsd', 'fnmaddss', 'fnmsubpd',
	'fnmsubps', 'fnmsubsd', 'fnmsubss', 'fnop', 'fnsave', 'fnstcw', 'fnstenv', 'fnstsw', 'fpatan',
	'fprem', 'fprem1', 'fptan', 'frczpd', 'frczps', 'frczsd', 'frczss', 'frndint', 'frstor', 'fsave',
	'fscale', 'fsetpm', 'fsin', 'fsincos', 'fsqrt', 'fst', 'fstcw', 'fstenv', 'fstp', 'fstsw',
	'fsub', 'fsubp', 'fsubr', 'fsubrp', 'ftst', 'fucom', 'fucomi', 'fucomip', 'fucomp', 'fucompp',
	'fwait', 'fxam', 'fxch', 'fxrstor', 'fxsave', 'fxtract', 'fyl2x', 'fyl2xp1', 'getsec', 'haddpd',
	'haddps', 'hint_nop0', 'hint_nop1', 'hint_nop10', 'hint_nop11', 'hint_nop12', 'hint_nop13',
	'hint_nop14','hint_nop15', 'hint_nop16', 'hint_nop17', 'hint_nop18', 'hint_nop19', 'hint_nop2',
	'hint_nop20', 'hint_nop21', 'hint_nop22', 'hint_nop23', 'hint_nop24', 'hint_nop25', 'hint_nop26',
	'hint_nop27', 'hint_nop28', 'hint_nop29', 'hint_nop3', 'hint_nop30', 'hint_nop31', 'hint_nop32',
	'hint_nop33', 'hint_nop34', 'hint_nop35', 'hint_nop36', 'hint_nop37', 'hint_nop38', 'hint_nop39',
	'hint_nop4', 'hint_nop40', 'hint_nop41', 'hint_nop42', 'hint_nop43', 'hint_nop44', 'hint_nop45',
	'hint_nop46', 'hint_nop47', 'hint_nop48', 'hint_nop49', 'hint_nop5', 'hint_nop50', 'hint_nop51',
	'hint_nop52', 'hint_nop53', 'hint_nop54', 'hint_nop55', 'hint_nop56', 'hint_nop57', 'hint_nop58',
	'hint_nop59', 'hint_nop6', 'hint_nop60', 'hint_nop61', 'hint_nop62', 'hint_nop63', 'hint_nop7',
	'hint_nop8', 'hint_nop9', 'hlt', 'hsubpd', 'hsubps', 'ibts', 'icebp', 'idiv', 'imul', 'in',
	'inc', 'incbin', 'insb', 'insd', 'insertps', 'insertq', 'insw', 'int', 'int01', 'int03',
	'int1', 'int3', 'into', 'invd', 'invept', 'invlpg', 'invlpga', 'invvpid', 'iret', 'iretd',
	'iretq', 'iretw', 'ja', 'jae', 'jb', 'jbe', 'jc', 'jcxz', 'je', 'jecxz', 'jg', 'jge', 'jl',
	'jle', 'jmp', 'jmpe', 'jna', 'jnae', 'jnb', 'jnbe', 'jnc', 'jne', 'jng', 'jnge', 'jnl',
	'jnle', 'jno', 'jnp', 'jns', 'jnz', 'jo', 'jp', 'jpe', 'jpo', 'jrcxz', 'js', 'jz',
	'lahf', 'lar', 'lddqu', 'ldmxcsr', 'lds', 'lea', 'leave', 'les', 'lfence', 'lfs', 'lgdt',
	'lgs', 'lidt', 'lldt', 'lmsw', 'loadall', 'loadall286', 'lodsb', 'lodsd', 'lodsq', 'lodsw',
	'loop', 'loope', 'loopne', 'loopnz', 'loopz', 'lsl', 'lss', 'ltr', 'lzcnt', 'maskmovdqu',
	'maskmovq', 'maxpd', 'maxps', 'maxsd', 'maxss', 'mfence', 'minpd', 'minps', 'minsd',
	'minss', 'monitor', 'montmul', 'mov', 'movapd', 'movaps', 'movbe', 'movd', 'movddup', 'movdq2q',
	'movdqa', 'movdqu', 'movhlps', 'movhpd', 'movhps', 'movlhps', 'movlpd', 'movlps', 'movmskpd',
	'movmskps', 'movntdq', 'movntdqa', 'movnti', 'movntpd', 'movntps', 'movntq', 'movntsd',
	'movntss', 'movq', 'movq2dq', 'movsb', 'movsd', 'movshdup', 'movsldup', 'movsq', 'movss',
	'movsw', 'movsx', 'movsxd', 'movupd', 'movups', 'movzx', 'mpsadbw', 'mul', 'mulpd', 'mulps',
	'mulsd', 'mulss', 'mwait', 'neg', 'nop', 'not', 'or', 'orpd', 'orps', 'out', 'outsb', 'outsd',
	'outsw', 'pabsb', 'pabsd', 'pabsw', 'packssdw', 'packsswb', 'packusdw', 'packuswb', 'paddb',
	'paddd', 'paddq', 'paddsb', 'paddsiw', 'paddsw', 'paddusb', 'paddusw', 'paddw', 'palignr',
	'pand', 'pandn', 'pause', 'paveb', 'pavgb', 'pavgusb', 'pavgw', 'pblendvb', 'pblendw',
	'pclmulhqhqdq', 'pclmulhqlqdq', 'pclmullqhqdq', 'pclmullqlqdq', 'pclmulqdq', 'pcmov',
	'pcmpeqb', 'pcmpeqd', 'pcmpeqq', 'pcmpeqw', 'pcmpestri', 'pcmpestrm', 'pcmpgtb', 'pcmpgtd',
	'pcmpgtq', 'pcmpgtw', 'pcmpistri', 'pcmpistrm', 'pcomb', 'pcomd', 'pcomeqb', 'pcomeqd',
	'pcomeqq', 'pcomequb', 'pcomequd', 'pcomequq', 'pcomequw', 'pcomeqw', 'pcomfalseb',
	'pcomfalsed', 'pcomfalseq', 'pcomfalseub', 'pcomfalseud', 'pcomfalseuq', 'pcomfalseuw',
	'pcomfalsew', 'pcomgeb', 'pcomged', 'pcomgeq', 'pcomgeub', 'pcomgeud', 'pcomgeuq', 'pcomgeuw',
	'pcomgew', 'pcomgtb', 'pcomgtd', 'pcomgtq', 'pcomgtub', 'pcomgtud', 'pcomgtuq', 'pcomgtuw',
	'pcomgtw', 'pcomleb', 'pcomled', 'pcomleq', 'pcomleub', 'pcomleud', 'pcomleuq', 'pcomleuw',
	'pcomlew', 'pcomltb', 'pcomltd', 'pcomltq', 'pcomltub', 'pcomltud', 'pcomltuq', 'pcomltuw',
	'pcomltw', 'pcomneqb', 'pcomneqd', 'pcomneqq', 'pcomnequb', 'pcomnequd', 'pcomnequq',
	'pcomnequw', 'pcomneqw', 'pcomq', 'pcomtrueb', 'pcomtrued', 'pcomtrueq', 'pcomtrueub',
	'pcomtrueud', 'pcomtrueuq', 'pcomtrueuw', 'pcomtruew', 'pcomub', 'pcomud', 'pcomuq', 'pcomuw',
	'pcomw', 'pdistib', 'permpd', 'permps', 'pextrb', 'pextrd', 'pextrq', 'pextrw', 'pf2id',
	'pf2iw', 'pfacc', 'pfadd', 'pfcmpeq', 'pfcmpge', 'pfcmpgt', 'pfmax', 'pfmin', 'pfmul',
	'pfnacc', 'pfpnacc', 'pfrcp', 'pfrcpit1', 'pfrcpit2', 'pfrcpv', 'pfrsqit1', 'pfrsqrt',
	'pfrsqrtv', 'pfsub', 'pfsubr', 'phaddbd', 'phaddbq', 'phaddbw', 'phaddd', 'phadddq', 'phaddsw',
	'phaddubd', 'phaddubq', 'phaddubw', 'phaddudq', 'phadduwd', 'phadduwq', 'phaddw', 'phaddwd',
	'phaddwq', 'phminposuw', 'phsubbw', 'phsubd', 'phsubdq', 'phsubsw', 'phsubw', 'phsubwd',
	'pi2fd', 'pi2fw', 'pinsrb', 'pinsrd', 'pinsrq', 'pinsrw', 'pmachriw', 'pmacsdd', 'pmacsdqh',
	'pmacsdql', 'pmacssdd', 'pmacssdqh', 'pmacssdql', 'pmacsswd', 'pmacssww', 'pmacswd',
	'pmacsww', 'pmadcsswd', 'pmadcswd', 'pmaddubsw', 'pmaddwd', 'pmagw', 'pmaxsb', 'pmaxsd',
	'pmaxsw', 'pmaxub', 'pmaxud', 'pmaxuw', 'pminsb', 'pminsd', 'pminsw', 'pminub', 'pminud',
	'pminuw', 'pmovmskb', 'pmovsxbd', 'pmovsxbq', 'pmovsxbw', 'pmovsxdq', 'pmovsxwd', 'pmovsxwq',
	'pmovzxbd', 'pmovzxbq', 'pmovzxbw', 'pmovzxdq', 'pmovzxwd', 'pmovzxwq', 'pmuldq', 'pmulhriw',
	'pmulhrsw', 'pmulhrwa', 'pmulhrwc', 'pmulhuw', 'pmulhw', 'pmulld', 'pmullw', 'pmuludq',
	'pmvgezb', 'pmvlzb', 'pmvnzb', 'pmvzb', 'pop', 'popa', 'popad', 'popaw', 'popcnt', 'popf',
	'popfd', 'popfq', 'popfw', 'por', 'pperm', 'prefetch', 'prefetchnta', 'prefetcht0',
	'prefetcht1', 'prefetcht2', 'prefetchw', 'protb', 'protd', 'protq', 'protw', 'psadbw',
	'pshab', 'pshad', 'pshaq', 'pshaw', 'pshlb', 'pshld', 'pshlq', 'pshlw', 'pshufb', 'pshufd',
	'pshufhw', 'pshuflw', 'pshufw', 'psignb', 'psignd', 'psignw', 'pslld', 'pslldq', 'psllq',
	'psllw', 'psrad', 'psraw', 'psrld', 'psrldq', 'psrlq', 'psrlw', 'psubb', 'psubd', 'psubq',
	'psubsb', 'psubsiw', 'psubsw', 'psubusb', 'psubusw', 'psubw', 'pswapd', 'ptest', 'punpckhbw',
	'punpckhdq', 'punpckhqdq', 'punpckhwd', 'punpcklbw', 'punpckldq', 'punpcklqdq', 'punpcklwd',
	'push', 'pusha', 'pushad', 'pushaw', 'pushf', 'pushfd', 'pushfq', 'pushfw', 'pxor', 'rcl',
	'rcpps', 'rcpss', 'rcr', 'rdm', 'rdmsr', 'rdpmc', 'rdshr', 'rdtsc', 'rdtscp', 'rep', 'ret', 'retf',
	'retn', 'rol', 'ror', 'roundpd', 'roundps', 'roundsd', 'roundss', 'rsdc', 'rsldt', 'rsm',
	'rsqrtps', 'rsqrtss', 'rsts', 'sahf', 'sal', 'salc', 'sar', 'sbb', 'scasb', 'scasd', 'scasq',
	'scasw', 'seta', 'setae', 'setb', 'setbe', 'setc', 'sete', 'setg', 'setge', 'setl',
	'setle', 'setna', 'setnae', 'setnb', 'setnbe', 'setnc', 'setne', 'setng', 'setnge',
	'setnl', 'setnle', 'setno', 'setnp', 'setns', 'setnz', 'seto', 'setp', 'setpe', 'setpo',
	'sets', 'setz', 'sfence', 'sgdt', 'shl', 'shld', 'shr', 'shrd', 'shufpd', 'shufps', 'sidt',
	'skinit', 'sldt', 'smi', 'smint', 'smintold', 'smsw', 'sqrtpd', 'sqrtps', 'sqrtsd', 'sqrtss',
	'stc', 'std', 'stgi', 'sti', 'stmxcsr', 'stosb', 'stosd', 'stosq', 'stosw', 'str', 'sub',
	'subpd', 'subps', 'subsd', 'subss', 'svdc', 'svldt', 'svts', 'swapgs', 'syscall', 'sysenter',
	'sysexit', 'sysret', 'test', 'ucomisd', 'ucomiss', 'ud0', 'ud1', 'ud2', 'ud2a', 'ud2b', 'umov',
	'unpckhpd', 'unpckhps', 'unpcklpd', 'unpcklps', 'vaddpd', 'vaddps', 'vaddsd', 'vaddss',
	'vaddsubpd', 'vaddsubps', 'vaesdec', 'vaesdeclast', 'vaesenc', 'vaesenclast', 'vaesimc',
	'vaeskeygenassist', 'vandnpd', 'vandnps', 'vandpd', 'vandps', 'vblendpd', 'vblendps',
	'vblendvpd', 'vblendvps', 'vbroadcastf128', 'vbroadcastsd', 'vbroadcastss', 'vcmpeqpd',
	'vcmpeqps', 'vcmpeqsd', 'vcmpeqss', 'vcmpeq_ospd', 'vcmpeq_osps', 'vcmpeq_ossd',
	'vcmpeq_osss', 'vcmpeq_uqpd', 'vcmpeq_uqps', 'vcmpeq_uqsd', 'vcmpeq_uqss', 'vcmpeq_uspd',
	'vcmpeq_usps', 'vcmpeq_ussd', 'vcmpeq_usss', 'vcmpfalsepd', 'vcmpfalseps', 'vcmpfalsesd',
	'vcmpfalsess', 'vcmpfalse_ospd', 'vcmpfalse_osps', 'vcmpfalse_ossd', 'vcmpfalse_osss',
	'vcmpgepd', 'vcmpgeps', 'vcmpgesd', 'vcmpgess', 'vcmpge_oqpd', 'vcmpge_oqps', 'vcmpge_oqsd',
	'vcmpge_oqss', 'vcmpgtpd', 'vcmpgtps', 'vcmpgtsd', 'vcmpgtss', 'vcmpgt_oqpd', 'vcmpgt_oqps',
	'vcmpgt_oqsd', 'vcmpgt_oqss', 'vcmplepd', 'vcmpleps', 'vcmplesd', 'vcmpless', 'vcmple_oqpd',
	'vcmple_oqps', 'vcmple_oqsd', 'vcmple_oqss', 'vcmpltpd', 'vcmpltps', 'vcmpltsd', 'vcmpltss',
	'vcmplt_oqpd', 'vcmplt_oqps', 'vcmplt_oqsd', 'vcmplt_oqss', 'vcmpneqpd', 'vcmpneqps',
	'vcmpneqsd', 'vcmpneqss', 'vcmpneq_oqpd', 'vcmpneq_oqps', 'vcmpneq_oqsd', 'vcmpneq_oqss',
	'vcmpneq_ospd', 'vcmpneq_osps', 'vcmpneq_ossd', 'vcmpneq_osss', 'vcmpneq_uspd', 'vcmpneq_usps',
	'vcmpneq_ussd', 'vcmpneq_usss', 'vcmpngepd', 'vcmpngeps', 'vcmpngesd', 'vcmpngess', 'vcmpnge_uqpd',
	'vcmpnge_uqps', 'vcmpnge_uqsd', 'vcmpnge_uqss', 'vcmpngtpd', 'vcmpngtps', 'vcmpngtsd', 'vcmpngtss',
	'vcmpngt_uqpd', 'vcmpngt_uqps', 'vcmpngt_uqsd', 'vcmpngt_uqss', 'vcmpnlepd', 'vcmpnleps',
	'vcmpnlesd', 'vcmpnless', 'vcmpnle_uqpd', 'vcmpnle_uqps', 'vcmpnle_uqsd', 'vcmpnle_uqss',
	'vcmpnltpd', 'vcmpnltps', 'vcmpnltsd', 'vcmpnltss', 'vcmpnlt_uqpd', 'vcmpnlt_uqps', 'vcmpnlt_uqsd',
	'vcmpnlt_uqss', 'vcmpordpd', 'vcmpordps', 'vcmpordsd', 'vcmpordss', 'vcmpord_spd', 'vcmpord_sps',
	'vcmpord_ssd', 'vcmpord_sss', 'vcmppd', 'vcmpps', 'vcmpsd', 'vcmpss', 'vcmptruepd', 'vcmptrueps',
	'vcmptruesd', 'vcmptruess', 'vcmptrue_uspd', 'vcmptrue_usps', 'vcmptrue_ussd', 'vcmptrue_usss',
	'vcmpunordpd', 'vcmpunordps', 'vcmpunordsd', 'vcmpunordss', 'vcmpunord_spd', 'vcmpunord_sps',
	'vcmpunord_ssd', 'vcmpunord_sss', 'vcomisd', 'vcomiss', 'vcvtdq2pd', 'vcvtdq2ps', 'vcvtpd2dq',
	'vcvtpd2ps', 'vcvtph2ps', 'vcvtps2dq', 'vcvtps2pd', 'vcvtps2ph', 'vcvtsd2si', 'vcvtsd2ss',
	'vcvtsi2sd', 'vcvtsi2ss', 'vcvtss2sd', 'vcvtss2si', 'vcvttpd2dq', 'vcvttps2dq', 'vcvttsd2si',
	'vcvttss2si', 'vdivpd', 'vdivps', 'vdivsd', 'vdivss', 'vdppd', 'vdpps', 'verr', 'verw',
	'vextractf128', 'vextractps', 'vfmadd123pd', 'vfmadd123ps', 'vfmadd123sd', 'vfmadd123ss',
	'vfmadd132pd', 'vfmadd132ps', 'vfmadd132sd', 'vfmadd132ss', 'vfmadd213pd', 'vfmadd213ps',
	'vfmadd213sd', 'vfmadd213ss', 'vfmadd231pd', 'vfmadd231ps', 'vfmadd231sd', 'vfmadd231ss',
	'vfmadd312pd', 'vfmadd312ps', 'vfmadd312sd', 'vfmadd312ss', 'vfmadd321pd', 'vfmadd321ps',
	'vfmadd321sd', 'vfmadd321ss', 'vfmaddpd', 'vfmaddps', 'vfmaddsd', 'vfmaddss', 'vfmaddsub123pd',
	'vfmaddsub123ps', 'vfmaddsub132pd', 'vfmaddsub132ps', 'vfmaddsub213pd', 'vfmaddsub213ps',
	'vfmaddsub231pd', 'vfmaddsub231ps', 'vfmaddsub312pd', 'vfmaddsub312ps', 'vfmaddsub321pd',
	'vfmaddsub321ps', 'vfmaddsubpd', 'vfmaddsubps', 'vfmsub123pd', 'vfmsub123ps',
	'vfmsub123sd', 'vfmsub123ss', 'vfmsub132pd', 'vfmsub132ps', 'vfmsub132sd',
	'vfmsub132ss', 'vfmsub213pd', 'vfmsub213ps', 'vfmsub213sd', 'vfmsub213ss',
	'vfmsub231pd', 'vfmsub231ps', 'vfmsub231sd', 'vfmsub231ss', 'vfmsub312pd',
	'vfmsub312ps', 'vfmsub312sd', 'vfmsub312ss', 'vfmsub321pd', 'vfmsub321ps',
	'vfmsub321sd', 'vfmsub321ss', 'vfmsubadd123pd', 'vfmsubadd123ps', 'vfmsubadd132pd',
	'vfmsubadd132ps', 'vfmsubadd213pd', 'vfmsubadd213ps', 'vfmsubadd231pd', 'vfmsubadd231ps',
	'vfmsubadd312pd', 'vfmsubadd312ps', 'vfmsubadd321pd', 'vfmsubadd321ps', 'vfmsubaddpd',
	'vfmsubaddps', 'vfmsubpd', 'vfmsubps', 'vfmsubsd', 'vfmsubss', 'vfnmadd123pd', 'vfnmadd123ps',
	'vfnmadd123sd', 'vfnmadd123ss', 'vfnmadd132pd', 'vfnmadd132ps', 'vfnmadd132sd', 'vfnmadd132ss',
	'vfnmadd213pd', 'vfnmadd213ps', 'vfnmadd213sd', 'vfnmadd213ss', 'vfnmadd231pd',
	'vfnmadd231ps', 'vfnmadd231sd', 'vfnmadd231ss', 'vfnmadd312pd', 'vfnmadd312ps',
	'vfnmadd312sd', 'vfnmadd312ss', 'vfnmadd321pd', 'vfnmadd321ps', 'vfnmadd321sd',
	'vfnmadd321ss', 'vfnmaddpd', 'vfnmaddps', 'vfnmaddsd', 'vfnmaddss', 'vfnmsub123pd',
	'vfnmsub123ps', 'vfnmsub123sd', 'vfnmsub123ss', 'vfnmsub132pd', 'vfnmsub132ps',
	'vfnmsub132sd', 'vfnmsub132ss', 'vfnmsub213pd', 'vfnmsub213ps', 'vfnmsub213sd',
	'vfnmsub213ss', 'vfnmsub231pd', 'vfnmsub231ps', 'vfnmsub231sd', 'vfnmsub231ss',
	'vfnmsub312pd', 'vfnmsub312ps', 'vfnmsub312sd', 'vfnmsub312ss', 'vfnmsub321pd',
	'vfnmsub321ps', 'vfnmsub321sd', 'vfnmsub321ss', 'vfnmsubpd', 'vfnmsubps', 'vfnmsubsd',
	'vfnmsubss', 'vfrczpd', 'vfrczps', 'vfrczsd', 'vfrczss', 'vhaddpd', 'vhaddps', 'vhsubpd',
	'vhsubps', 'vinsertf128', 'vinsertps', 'vlddqu', 'vldmxcsr', 'vldqqu', 'vmaskmovdqu',
	'vmaskmovpd', 'vmaskmovps', 'vmaxpd', 'vmaxps', 'vmaxsd', 'vmaxss', 'vmcall', 'vmclear',
	'vminpd', 'vminps', 'vminsd', 'vminss', 'vmlaunch', 'vmload', 'vmmcall', 'vmovapd', 'vmovaps',
	'vmovd', 'vmovddup', 'vmovdqa', 'vmovdqu', 'vmovhlps', 'vmovhpd', 'vmovhps', 'vmovlhps',
	'vmovlpd', 'vmovlps', 'vmovmskpd', 'vmovmskps', 'vmovntdq', 'vmovntdqa', 'vmovntpd',
	'vmovntps', 'vmovntqq', 'vmovq', 'vmovqqa', 'vmovqqu', 'vmovsd', 'vmovshdup', 'vmovsldup',
	'vmovss', 'vmovupd', 'vmovups',  'vmpsadbw', 'vmptrld', 'vmptrst', 'vmread', 'vmresume',
	'vmrun', 'vmsave', 'vmulpd', 'vmulps', 'vmulsd', 'vmulss', 'vmwrite', 'vmxoff', 'vmxon',
	'vorpd', 'vorps', 'vpabsb', 'vpabsd', 'vpabsw', 'vpackssdw', 'vpacksswb', 'vpackusdw',
	'vpackuswb', 'vpaddb', 'vpaddd', 'vpaddq', 'vpaddsb', 'vpaddsw', 'vpaddusb',
	'vpaddusw', 'vpaddw', 'vpalignr', 'vpand', 'vpandn', 'vpavgb', 'vpavgw', 'vpblendvb',
	'vpblendw', 'vpclmulhqhqdq', 'vpclmulhqlqdq', 'vpclmullqhqdq', 'vpclmullqlqdq',
	'vpclmulqdq', 'vpcmov', 'vpcmpeqb', 'vpcmpeqd', 'vpcmpeqq', 'vpcmpeqw', 'vpcmpestri',
	'vpcmpestrm', 'vpcmpgtb', 'vpcmpgtd', 'vpcmpgtq', 'vpcmpgtw', 'vpcmpistri', 'vpcmpistrm',
	'vpcomb', 'vpcomd', 'vpcomq', 'vpcomub', 'vpcomud', 'vpcomuq', 'vpcomuw', 'vpcomw',
	'vperm2f128', 'vpermil2pd', 'vpermil2ps', 'vpermilmo2pd', 'vpermilmo2ps', 'vpermilmz2pd',
	'vpermilmz2ps', 'vpermilpd', 'vpermilps', 'vpermiltd2pd', 'vpermiltd2ps', 'vpextrb',
	'vpextrd', 'vpextrq', 'vpextrw', 'vphaddbd', 'vphaddbq', 'vphaddbw', 'vphaddd',
	'vphadddq', 'vphaddsw', 'vphaddubd', 'vphaddubq', 'vphaddubwd', 'vphaddudq',
	'vphadduwd', 'vphadduwq', 'vphaddw', 'vphaddwd', 'vphaddwq', 'vphminposuw',
	'vphsubbw', 'vphsubd', 'vphsubdq', 'vphsubsw', 'vphsubw', 'vphsubwd', 'vpinsrb',
	'vpinsrd', 'vpinsrq', 'vpinsrw', 'vpmacsdd', 'vpmacsdqh', 'vpmacsdql', 'vpmacssdd',
	'vpmacssdqh', 'vpmacssdql', 'vpmacsswd', 'vpmacssww', 'vpmacswd', 'vpmacsww',
	'vpmadcsswd', 'vpmadcswd', 'vpmaddubsw', 'vpmaddwd', 'vpmaxsb', 'vpmaxsd', 'vpmaxsw',
	'vpmaxub', 'vpmaxud', 'vpmaxuw', 'vpminsb', 'vpminsd', 'vpminsw', 'vpminub',
	'vpminud', 'vpminuw', 'vpmovmskb', 'vpmovsxbd', 'vpmovsxbq', 'vpmovsxbw', 'vpmovsxdq',
	'vpmovsxwd', 'vpmovsxwq', 'vpmovzxbd', 'vpmovzxbq', 'vpmovzxbw', 'vpmovzxdq',
	'vpmovzxwd', 'vpmovzxwq', 'vpmuldq', 'vpmulhrsw', 'vpmulhuw', 'vpmulhw', 'vpmulld',
	'vpmullw', 'vpmuludq', 'vpor', 'vpperm', 'vprotb', 'vprotd', 'vprotq', 'vprotw',
	'vpsadbw', 'vpshab', 'vpshad', 'vpshaq', 'vpshaw', 'vpshlb', 'vpshld', 'vpshlq',
	'vpshlw', 'vpshufb', 'vpshufd', 'vpshufhw', 'vpshuflw', 'vpsignb', 'vpsignd', 'vpsignw',
	'vpslld', 'vpslldq', 'vpsllq', 'vpsllw', 'vpsrad', 'vpsraw', 'vpsrld', 'vpsrldq',
	'vpsrlq', 'vpsrlw', 'vpsubb', 'vpsubd', 'vpsubq', 'vpsubsb', 'vpsubsw', 'vpsubusb',
	'vpsubusw', 'vpsubw', 'vptest', 'vpunpckhbw', 'vpunpckhdq', 'vpunpckhqdq', 'vpunpckhwd',
	'vpunpcklbw', 'vpunpckldq', 'vpunpcklqdq', 'vpunpcklwd', 'vpxor', 'vrcpps', 'vrcpss',
	'vroundpd', 'vroundps', 'vroundsd', 'vroundss', 'vrsqrtps', 'vrsqrtss', 'vshufpd',
	'vshufps', 'vsqrtpd', 'vsqrtps', 'vsqrtsd', 'vsqrtss', 'vstmxcsr', 'vsubpd',
	'vsubps', 'vsubsd', 'vsubss', 'vtestpd', 'vtestps', 'vucomisd', 'vucomiss', 'vunpckhpd',
	'vunpckhps', 'vunpcklpd', 'vunpcklps', 'vxorpd', 'vxorps', 'vzeroall', 'vzeroupper',
	'wbinvd', 'wrmsr', 'wrshr', 'xadd', 'xbts', 'xchg', 'xcryptcbc', 'xcryptcfb',
	'xcryptctr', 'xcryptecb', 'xcryptofb', 'xgetbv', 'xlat', 'xlatb', 'xor', 'xorpd',
	'xorps', 'xrstor', 'xsave', 'xsetbv', 'xsha1', 'xsha256', 'xstore'
);

sub is_instr {

	my $elem = shift;
	foreach(@instrukcje) {
		return 1 if /\b$elem\b/i;
	}
	return 0;
}

sub bezplusa {

	my $elem = shift;
	$elem =~ s/^\s*\++//;
	if ( $elem eq "" ) { $elem = "+"; }
	return $elem;
}

my ($help, $lic, $help_msg, $lic_msg);

$help_msg = "$0: Konwerter z NASMa do GNU as / NASM-to-GNU as converter.\nAutor/Author: Bogdan Drozdowski, ".
	"http://rudy.mif.pg.gda.pl/~bogdro/inne/\n".
	"Skladnia/Syntax: $0 [--help] [--license] xxx.[n]asm [yyy.s]\n\n
 Jesli nazwa pliku wyjsciowego nie zostanie podana, jest brana taka sama jak
pliku wejsciowego (tylko rozszerzenie sie zmieni na .s). Jesli za nazwe
pliku wejsciowego podano \"-\", czytane jest standardowe wejscie.
 Jesli nazwa pliku wyjsciowego to \"-\" (lub nie ma jej, gdy wejscie to stdin),
wynik bedzie na standardowym wyjsciu.

 If there's no output filename, then it is assumed to be the same as the
input filename (only the extension will be changed to .s). If the
input filename is \"-\", standard input will be read.
 If the output filename is \"-\" (or missing, when input is stdin),
the result will be written to the standard output.\n";

$lic_msg = "$0: Konwerter z NASMa do GNU as / NASM-to-GNU as converter.\nAutor/Author: Bogdan Drozdowski, ".
	"http://rudy.mif.pg.gda.pl/~bogdro/inne/\n\n".
	"    Niniejszy program jest wolnym oprogramowaniem; mozesz go
    rozprowadzac dalej i/lub modyfikowac na warunkach Powszechnej
    Licencji Publicznej GNU, wydanej przez Fundacje Wolnego
    Oprogramowania - wedlug wersji 2-giej tej Licencji lub ktorejs
    z pozniejszych wersji.

    Niniejszy program rozpowszechniany jest z nadzieja, iz bedzie on
    uzyteczny - jednak BEZ JAKIEJKOLWIEK GWARANCJI, nawet domyslnej
    gwarancji PRZYDATNOSCI HANDLOWEJ albo PRZYDATNOSCI DO OKRESLONYCH
    ZASTOSOWAN. W celu uzyskania blizszych informacji - Powszechna
    Licencja Publiczna GNU.

    Z pewnoscia wraz z niniejszym programem otrzymales tez egzemplarz
    Powszechnej Licencji Publicznej GNU (GNU General Public License);
    jesli nie - napisz do Free Software Foudation:
		Free Software Foundation
		51 Franklin Street, Fifth Floor
		Boston, MA 02110-1301
		USA

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software Foudation:
		Free Software Foundation
		51 Franklin Street, Fifth Floor
		Boston, MA 02110-1301
		USA\n";

if ( @ARGV == 0 ) {
	print $help_msg;
	exit 1;
}

Getopt::Long::Configure("ignore_case", "ignore_case_always");

if ( ! GetOptions(
	'h|help|?'		=>	\$help,
	'license|licence|L'	=>	\$lic
	)
   ) {

	print $help_msg;
	exit 1;
}

if ( $lic ) {
	print $lic_msg;
	exit 1;
}

if ( @ARGV == 0 || $help ) {
	print $help_msg;
	exit 1;
}

if ( @ARGV > 1 && $ARGV[0] ne "-" && $ARGV[0] eq $ARGV[1] ) {

	print "$0: Plik wejsciowy i wyjsciowy NIE moga byc takie same.\n";
	print "$0: Input file and output file must NOT be the same.\n";
	exit 4;
}

##########################################################
# Otwieranie plikow (opening the files)

my ($we, $wy);

if ( !open ( $we, $ARGV[0] ) ) {
#	$! jest trescia bledu. ($! is the error message)
	print "$0: $ARGV[0]: $!\n";
	exit 2;
}

if ( @ARGV > 1 )  {
	$wyj = $ARGV[1];

} else {
	# bierzemy tylko nazwe pliku (take only the filename)
	($wyj = $ARGV[0]) =~ s/.*\/([^\/]+)/$1/;
# 	Zmieniamy rozszerzenie z .[n]asm na .s (change the extension from .[n]asm to .s)
	$wyj =~ s/\.n?asm$/\.s/io;
#	Zmieniamy spacje na podkreslenia (change spaces to underlines)
	$wyj =~ s/\s+/_/go;

	if ( $wyj eq $ARGV[0] && $wyj ne "-" ) { $wyj .= ".s"; }
}

if ( !open ( $wy, "> $wyj" ) ) {
	print "$0: $wyj: $!\n";
	close $we;
	exit 3;
}

##########################################################
# Przetwarzanie (processing):

CZYTAJ: while ( <$we> ) {

	#	puste linie przepisujemy (empty lines go without change)
	if ( /^\s*$/o ) {
		print $wy "\n";
		next;
	}

	# sprawdzamy, czy komentarz jest jedyny na linii (check if a comment is the only thing on this line)
	if ( /^\s*;.*$/o ) { &komen(1); next; }

	# przetwarzanie dyrektyw kompilacji warunkowej (processing of conditional compiling directives)
	&kom_war(0);

	# zmiana liczb heksadecymalnych na postac 0x... (changing hexadecimal numbers to 0x... form):
	s/\b([[:xdigit:]]+)h/0x$1/gi;
	s/\b\$([[:xdigit:]]+)/0x$1/gi;

	# ==================== Etykiety (labels)

	# jesli sama w wierszu (if the only thing on a line)
	if ( /^\s*([\w\.]+)\s*:\s*$/o )	{ s/\s*(\w+)\s*:\s*$/$1:\n/; print $wy "$_"; next; }

	# jesli za nia cos jest (if there's something following it)
	s/^\s*([\w\.]+)\s*:\s*(.*)$/$1:\n\t$2/;

	# ==================== Dyrektywy (directives)

	if ( /^\s*absolute/io )		{ next; }

	if ( /^\s*cpu/io )		{ next; }

	if ( /^\s*common/io )		{ next; }

	if ( /^\s*\%(arg|stacksize|local|line|!|push|pop|repl)/io ) { next; }

	if ( /^\s*bits/io )		{ s/^\s*bits\s*(.*)/\.code$1/i; print $wy "$_"; next; }

	if ( /^\s*global\b/io )	 	{ s/^\s*public\s*(.*)/\.globl\t$1/i; print $wy "$_"; next; }

	if ( /^\s*\%include\b/io ) 	{ s/^\s*\%include\s*(.*)/\.include\t$1/i; print $wy "$_"; next; }

	if ( /^\s*\w+\s+equ\b/io ) 	{ s/^\s*(\w+)\s+equ(.*)/\.equ $1, $2/i; print $wy "$_"; next; }

	if ( /^\s*alignb?\b/io ) 	{ s/^\s*alignb?\s+(\d+)/\.align $1/i; print $wy "$_"; next; }

	if ( /^\s*extern\b/io ) 	{ s/^\s*extern\s*(.*)/\.extern\t$1/i; print $wy "$_"; next; }

	if ( /^\s*org\b/io )		{ s/^\s*org(.*)(,.*)?$/\.org\t$1/i; print $wy "$_"; next; }

	if ( /^\s*\%macro\b/io )	{

		my $argnum = "";
		my $a1 = 0;
		my $linia = "";
		s/^\s*\%macro\s+(\w+)\s+(\d+(-(\d+|\*))?)([\w,\s]+)?/\.macro $1/i and $a1 = $2;

		if ( /\d+-(\d+)/o ) {
			($argnum = $a1) =~ s/\d+-(\d+|\*)/$1/;
		} else {
			$argnum = $a1;
		}

		$argnum =~ s/\%//go;
		my $argex ="\t.equ \%0, $argnum\n";

		for ( my $i=0; $i < $argnum; $i++ ) {

			$linia .= "arg$i ";
			$argex .= "\t .equ \%$i, arg$i\n";
		}

		s/^\s*\.macro\s+(\w+).*/\.macro\t$1\t$linia\n$argex/i;
		print $wy "$_";
		next;
	}

	if ( /^\s*\%endmacro\b/io )	{

		s/^\s*\%endmacro(.*)/\.endm$1\n/i;
		print $wy "$_";
		next;
	}

	if ( /^\s*struc/io )		{

		while ( <$we> && ! /^\s*endstruc/io ) {};
		$context = "struc";
		next;
	}

	# ==================== Sekcje (sections)

	if ( /^\s*(section|segment)/io )	{

		if ( /^\s*(section|segment)\s+['"].text['"]/io || /^\s*\.(section|segment).*exec/io  ) { print $wy ".text\n"; next; }
		if ( /^\s*(section|segment)\s+['"].data['"]/io || /^\s*\.(section|segment).*write/io ) { print $wy ".data\n"; next; }
		if ( /^\s*(section|segment)\s+['"].bss['"]/io ) { print $wy ".bss"; next; }

		if ( /^\s*(section|segment)\s+['"](.+)['"](.*)/io ) { print $wy "\.section $2\n"; next; }

		if ( /^\s*(section|segment) \.*read/io ) { print $wy ".data\n"; next; }
	}

	# ==================== Dane (data)

	if ( /^[^;]*\bdb\b/io )		{

		if ( ! /"/o && ! /'/o ) {
			s/\bdb\b(.*)/\.byte $1/i;
		} else {

			s/^[^;]*\bdb\b//io;
			s/""\s*,?\s*//go;
			s/''//go;
			s/^\s*([^"']+)/\n.byte $1/gi;
			s/\"([^"]*)\"/\n\.ascii "$1"\n/gi;
			s/\'([^']*)\'/\n\.ascii "$1"\n/gi;
			s/\n[^\.\s]/\n.byte/gio;

			s/,\s*$/\n/go;
			s/,\s*\./\n\./go;

		}
		print $wy "$_";
		next;
	}
	if ( /^[^;]*\bd[wu]\b/io )	{ s/\bd[wu]\b(.*)/\.word $1/i; print $wy "$_"; next; }
	if ( /^[^;]*\bdd\b/io )		{
		# float?
		if ( /\d+\./o ) {
			s/\bdd\b(.*)/\.float $1/i;
			print $wy "$_";
			next;
		} else {
			s/\bdd\b(.*)/\.long $1/i;
			print $wy "$_";
			next;
		}
	}
	if ( /^[^;]*\bd[pf]\b/io )	{ s/\bd[pf]\b(.*)/\.quad $1/i; print $wy "$_"; next; }
	if ( /^[^;]*\bdq\b/io )		{
		# float?
		if ( /\d+\./o ) {
			s/^\bdq\b(.*)/\.double $1/i;
			print $wy "$_";
			next;
		} else {
			s/\bdq\b(.*)/\.quad $1/i;
			print $wy "$_";
			next;
		}
	}
	if ( /^[^;]*\bdt\b/io )		{ s/\bdt\b(.*)/\.tfloat $1/i; print $wy "$_"; next; }

	# times:
	if ( /^[^;]*\btimes\b/io )		{

		my $rozmiar = 1;
		if ( /times\s+(\w+)\s+[rd][wu]\b/io ) { $rozmiar = 2; }
		if ( /times\s+(\w+)\s+[rd]d\b/io ) { $rozmiar = 4; }
		if ( /times\s+(\w+)\s+[rd][pf]\b/io ) { $rozmiar = 6; }
		if ( /times\s+(\w+)\s+[rd]q\b/io ) { $rozmiar = 8; }
		if ( /times\s+(\w+)\s+[rd]t\b/io ) { $rozmiar = 10; }
		s/times\s+(\w+)\s+\w+\s+(.*)/\.fill $1, $rozmiar, $2\n/i;
		print $wy "$_";
		next;
	}

	# ==================== Instrukcje (instructions)

	# dodajemy sufiks (add the suffix)
	foreach my $i (@instr) {

		if ( /^\s*$i\s+([^,]+)/i ) {

			($a1 = $1) =~ s/\s+$//o;
			if ( /[^;]+\bbyte\b/io )     { s/^\s*$i\b/\t${i}b/i; }
			elsif ( /[^;]+\bword\b/io )  { s/^\s*$i\b/\t${i}w/i; }
			elsif ( /[^;]+\bdword\b/io ) { s/^\s*$i\b/\t${i}l/i; }
			elsif ( /^\s*$i\s+([^,]+)\s*,\s*([^,]+)/i ) {

				($a2 = $2) =~ s/\s+$//o;
				if ( $a2 !~ /\[.*\]/o ) {

					if ( isreg8 ($a2) )    { s/^\s*$i\b/\t${i}b/i; }
					elsif ( isreg16($a2) ) { s/^\s*$i\b/\t${i}w/i; }
					elsif ( isreg32($a2) ) { s/^\s*$i\b/\t${i}l/i; }
					elsif ( /^\s*$i\s+([^\[\],]+)\s*,\s*([^,]+)/i ) {
						$a1 = $1;
						$a2 = $2;
						$a1 =~ s/\s+$//o;
						$a2 =~ s/\s+$//o;
						if ( isreg8 ($a1) )    { s/^\s*$i\b/\t${i}b/i; }
						elsif ( isreg16($a1) ) { s/^\s*$i\b/\t${i}w/i; }
						elsif ( isreg32($a1) ) { s/^\s*$i\b/\t${i}l/i; }
						else { s/^\s*$i\b/\t${i}l/i; }
					}
				} elsif ( /^\s*$i\s+([^\[\],]+)\s*,\s*([^,]+)/i ) {

					$a1 = $1;
					$a2 = $2;
					$a1 =~ s/\s+$//o;
					$a2 =~ s/\s+$//o;
					if ( isreg8 ($a1) )    { s/^\s*$i\b/\t${i}b/i; }
					elsif ( isreg16($a1) ) { s/^\s*$i\b/\t${i}w/i; }
					elsif ( isreg32($a1) ) { s/^\s*$i\b/\t${i}l/i; }
					else { s/^\s*$i\b/\t${i}l/i; }
				} else {
					# domyslny: long (default: long)
					s/^\s*$i\b/\t${i}l/i;
				}
			} else {
				# domyslny: long (default: long)
				s/^\s*$i\b/\t${i}l/i;
			}
			last;
		}
	}

	# zmiana kolejnosci argumentow (changing operands' order):
	if ( 		 /^\s*(\w+)\s+(\[?[:\.\w\*\+\-\s\(\)]+\]?)\s*,\s*(\[?[:\.\w\*\+\-\s\(\)]+\]?)\s*,\s*(\[?[:\.\w\*\+\-\s\(\)]+\]?)/o ) {
		if ( is_instr($1) ) {
			s/^\s*(\w+)\s+(\[?[:\.\w\*\+\-\s\(\)]+\]?)\s*,\s*(\[?[:\.\w\*\+\-\s\(\)]+\]?)\s*,\s*(\[?[:\.\w\*\+\-\s\(\)]+\]?)/\t$1\t$4, $3, $2/;
		}
	}
	if ( 		 /^\s*(\w+)\s+(\[?[:\.\w\*\+\-\s\(\)]+\]?)\s*,\s*(\[?[:\.\w\*\+\-\s\(\)]+\]?)([^,]*(;.*)?)$/o ) {
		if ( is_instr($1) ) {
			s/^\s*(\w+)\s+(\[?[:\.\w\*\+\-\s\(\)]+\]?)\s*,\s*(\[?[:\.\w\*\+\-\s\(\)]+\]?)([^,]*(;.*)?)$/\t$1\t$3, $2$4\n/;
		}
	}
	if ( 		 /^\s*(\w+)\s+(\[?[:\.\w\*\+\-\s\(\)]+\]?)([^,]*(;.*)?)$/o ) {
		if ( is_instr($1) ) {
			s/^\s*(\w+)\s+(\[?[:\.\w\*\+\-\s\(\)]+\]?)([^,]*(;.*)?)$/\t$1\t$2$3\n/;
		}
	}

	if ( 		 /^\s*(\w+)\s+((t?byte|[dqpft]?word)\s*\[?[\.\w\*\+\-\s\(\)]+\]?)\s*,\s*(\[?[\.\w\*\+\-\s\(\)]+\]?)\s*,\s*(\[?[\.\w\*\+\-\s\(\)]+\]?)/o ) {
		if ( is_instr($1) ) {
			s/^\s*(\w+)\s+((t?byte|[dqpft]?word)\s*\[?[\.\w\*\+\-\s\(\)]+\]?)\s*,\s*(\[?[\.\w\*\+\-\s\(\)]+\]?)\s*,\s*(\[?[\.\w\*\+\-\s\(\)]+\]?)/\t$1\t$5, $4, $2/;
		}
	}
	if ( 		 /^\s*(\w+)\s+((t?byte|[dqpft]?word)\s*\[?[\.\w\*\+\-\s\(\)]+\]?)\s*,\s*(\[?[\.\w\*\+\-\s\(\)]+\]?)([^,]*(;.*)?)$/o ) {
		if ( is_instr($1) ) {
			s/^\s*(\w+)\s+((t?byte|[dqpft]?word)\s*\[?[\.\w\*\+\-\s\(\)]+\]?)\s*,\s*(\[?[\.\w\*\+\-\s\(\)]+\]?)([^,]*(;.*)?)$/\t$1\t$4, $2$5\n/;
		}
	}
	if ( 		 /^\s*(\w+)\s+((t?byte|[dqpft]?word)\s*\[?[\.\w\*\+\-\s\(\)]+\]?)([^,]*(;.*)?)$/o ) {
		if ( is_instr($1) ) {
			s/^\s*(\w+)\s+((t?byte|[dqpft]?word)\s*\[?[\.\w\*\+\-\s\(\)]+\]?)([^,]*(;.*)?)$/\t$1\t$2$4\n/;
		}
	}

	# instrukcje FPU (FPU instructions)
	s/^\s*fi(\w+)\s+word\s*(.*)/\tfi${1}s\t$2/i;
	s/^\s*fi(\w+)\s+dword\s*(.*)/\tfi${1}l\t$2/i;
	s/^\s*fi(\w+)\s+qword\s*(.*)/\tfi${1}q\t$2/i;

	s/^\s*f([^iI]\w+)\s+dword\s*(.*)/\tf${1}s\t$2/i;
	s/^\s*f([^iI]\w+)\s+qword\s*(.*)/\tf${1}l\t$2/i;
	s/^\s*f([^iI]\w+)\s+t(word|byte)\s*(.*)/\tf${1}t\t$3/i;


	# zamiana "xxx" na "$xxx", jesli nie ma "[]" (change "xxx" to "$xxx", if there are no "[]")
	# nie ruszamy "call/jmp xxx" (don't touch "call/jmp xxx")
	if ( ! /^\s*(j[a-z]+|call)/io ) {

		if ( /^\s*(\w+)\s+([^,]+)\s*,\s*([^,]+)\s*,\s*([^,]+)\s*/gio ) {


			$a1 = $1;
			$a2 = $2;
			$a3 = $3;
			$a4 = $4;
			$a1 =~ s/\s+$//o;
			$a2 =~ s/\s+$//o;
			$a3 =~ s/\s+$//o;
			$a4 =~ s/\s+$//o;
			$a2 =~ s/(t?byte|[dqpft]?word)//io;
			$a3 =~ s/(t?byte|[dqpft]?word)//io;
			$a4 =~ s/(t?byte|[dqpft]?word)//io;
			$a2 =~ s/^\s+//o;
			$a3 =~ s/^\s+//o;
			$a4 =~ s/^\s+//o;

			if ( $a2 !~ /\[/o && !isreg($a2) ) { $a2 = "\$$a2"; }
			if ( $a3 !~ /\[/o && !isreg($a3) ) { $a3 = "\$$a3"; }
			if ( $a4 !~ /\[/o && !isreg($a4) ) { $a4 = "\$$a4"; }

			$_ = "\t$a1\t$a2, $a3, $a4\n";

		} elsif ( /^\s*(\w+)\s+([^,]+)\s*,\s*([^,]+)\s*/gio ) {

			$a1 = $1;
			$a2 = $2;
			$a3 = $3;
			$a1 =~ s/\s+$//o;
			$a2 =~ s/\s+$//o;
			$a3 =~ s/\s+$//o;
			$a2 =~ s/(t?byte|[dqpft]?word)//io;
			$a3 =~ s/(t?byte|[dqpft]?word)//io;
			$a2 =~ s/^\s+//o;
			$a3 =~ s/^\s+//o;

			if ( $a2 !~ /\[/o && !isreg($a2) ) { $a2 = "\$$a2"; }
			if ( $a3 !~ /\[/o && !isreg($a3) ) { $a3 = "\$$a3"; }

			$_ = "\t$a1\t$a2, $a3\n";

		} elsif ( /^\s*(\w+)\s+([^,]+)\s*/gio ) {

			$a1 = $1;
			$a2 = $2;
			$a1 =~ s/\s+$//o;
			$a2 =~ s/\s+$//o;
			$a2 =~ s/(t?byte|[dqpft]?word)//io;
			$a2 =~ s/^\s+//o;

			if ( $a2 !~ /\[/o && !isreg($a2) ) { $a2 = "\$$a2"; }

			$_ = "\t$a1\t$a2\n";

		}
	}

	my ($z1, $z2, $z3);
	# Dodanie sufiksow do instrukcji MOVSX/MOVZX
	# (add suffixes to MOVSX/MOVZX instructions)
	if ( /^\s*(mov[sz])x\s+([^,]+)\s*,\s*([^,]+)(.*)/io ) {

		my ($inst, $arg1, $arg2, $reszta);
		$inst = $1;
		$z1 = $2;
		$z2 = $3;
		$reszta = $4;
		($arg1 = $z1) =~ s/\s*$//o;
		($arg2 = $z2) =~ s/\s*$//o;
		if ( (/\bbyte\b/io || isreg8($arg2) ) && isreg32($arg1) ) {
			$_ = "\t${inst}bl\t$arg1, $arg2 $reszta\n";
		} elsif ( (/\bbyte\b/io || isreg8($arg2) ) && isreg16($arg1) ) {
			$_ = "\t${inst}bw\t$arg1, $arg2 $reszta\n";
		} elsif ( /\bword\b/io || isreg16($arg2) || isreg32($arg1)  ) {
			$_ = "\t${inst}wl\t$arg1, $arg2 $reszta\n";
		}
	}

	s/^\s*cbw\b/\tcbtw/io;
	s/^\s*cwde\b/\tcwtl/io;
	s/^\s*cwd\b/\tcwtd/io;
	s/^\s*cdq\b/\tcltd/io;

	# dodawanie znakow gwiazdki (adding asterisk chars)
	s/^\s*(jmp|call)\s+([dp]word|word|near|far|short)?\s*(\[[\w\*\+\-\s]+\])/\t$1\t*$3/i;
	s/^\s*(jmp|call)\s+([dp]word|word|near|far|short)?\s*((0x)?\d+h?)/\t$1\t*$3/i;
	s/^\s*(jmp|call)\s+([dp]word|word|near|far|short)?\s*([\w\*\+\-\s]+)/\t$1\t$3/i;
	s/^\s*(jmp|call)\s+([^:]+)\s*:\s*([^:]+)/\tl$1\t$2, $3/i;
	s/^\s*retf\s+(.*)$/\tlret\t$1/i;

	# Zmiana odnoszenia sie do pamieci (changing memory references):

	# seg: disp(base, index, scale)
	# [seg:base+index*scale+disp]
	if ( 		 /\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $2;
		$a2 = $4;
		$a3 = $7;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		$z3 = bezplusa($a3);
		if ( isreg($3) && isreg($5) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z3$8)$9($3,$5,$6)/;
		} elsif ( isreg($3) && isreg($6) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z3$8)$9($3,$6,$5)/;
		} elsif ( isreg($5) && isreg($8) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3)$9($8,$5,$6)/;
		} elsif ( isreg($6) && isreg($8) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3)$9($8,$6,$5)/;
		} elsif ( isreg($3) && isreg($8) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z2$5*$6)$9($3,$8)/;
		} elsif ( isreg($3) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z3$8$z2$5*$6)$9($3)/;
		} elsif ( isreg($5) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z3$8$z1$3)$9(,$5,$6)/;
		} elsif ( isreg($6) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z3$8$z1$3)$9(,$6,$5)/;
		} elsif ( isreg($8) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3$z2$5*$6)$9($8)/;
		} else {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3$z2$5*$6$z3$8)$9(,1)/;
		}
	}
	elsif ( 	 /\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $2;
		$a2 = $4;
		$a3 = $6;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		$z3 = bezplusa($a3);
		if ( isreg($3) && isreg($5) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z3$7*$8)$9($3,$5)/;
		} elsif ( isreg($5) && isreg($7) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3)$9($5,$7,$8)/;
		} elsif ( isreg($5) && isreg($8) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3)$9($5,$8,$7)/;
		} elsif ( isreg($3) && isreg($7) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z2$5)$9($3,$7,$8)/;
		} elsif ( isreg($3) && isreg($8) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z2$5)$9($3,$8,$7)/;
		} elsif ( isreg($3) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z2$5$z3$7*$8)$9($3)/;
		} elsif ( isreg($5) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3$z3$7*$8)$9($5)/;
		} elsif ( isreg($7) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3$z2$5)$9(,$7,$8)/;
		} elsif ( isreg($8) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3$z2$5)$9(,$8,$7)/;
		} else {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3$z2$5$z3$7*$8)$9(,1)/;
		}
	}
	elsif ( 	 /\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $2;
		$a2 = $5;
		$a3 = $7;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		$z3 = bezplusa($a3);
		if ( isreg($3) && isreg($6) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z3$8)$9($6,$3,$4)/;
		} elsif ( isreg($4) && isreg($6) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z3$8)$9($6,$4,$3)/;
		} elsif ( isreg($6) && isreg($8) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3*$4)$9($6,$8)/;
		} elsif ( isreg($3) && isreg($8) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z2$6)$9($8,$3,$4)/;
		} elsif ( isreg($4) && isreg($8) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z2$6)$9($8,$4,$3)/;
		} elsif ( isreg($3) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z2$6$z3$8)$9(,$3,$4)/;
		} elsif ( isreg($4) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z2$6$z3$8)$9(,$4,$3)/;
		} elsif ( isreg($6) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3*$4$z3$8)$9($6)/;
		} elsif ( isreg($8) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3*$4$z2$6)$9($8)/;
		} else {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3*$4$z2$6$z3$8)$9(,1)/;
		}
	}
	elsif ( 	 /\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $2;
		$a2 = $4;
		$a3 = $6;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		$z3 = bezplusa($a3);
		if ( isreg($3) && isreg($5) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z3$7)$8($3,$5,)/;
		} elsif ( isreg($3) && isreg($7) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z2$5)$8($3,$7,)/;
		} elsif ( isreg($5) && isreg($7) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3)$8($7,$5,)/;
		} elsif ( isreg($3) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$5$z3$7)$8($3)/;
		} elsif ( isreg($5) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3$z3$7)$8($5)/;
		} elsif ( isreg($7) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3$z2$5)$8($7)/;
		} else {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3$z2$5$z3$7)$8(,1)/;
		}
	}
	elsif ( 	 /\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $2;
		$a2 = $4;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		if ( isreg($3) && isreg($5) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($3,$5,$6)/;
		} elsif ( isreg($3) && isreg($6) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($3,$6,$5)/;
		} elsif ( isreg($3) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z2$5*$6)$7($3)/;
		} elsif ( isreg($5) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3)$7(,$5,$6)/;
		} elsif ( isreg($6) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3)$7(,$6,$5)/;
		} else {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3$z2$5*$6)$7(,1)/;
		}
	}
	elsif ( 	 /\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $2;
		$a2 = $4;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		if ( isreg($3) && isreg($5) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($3,$5,)/;
		} elsif ( isreg($3) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z2$5)$6($3)/;
		} elsif ( isreg($5) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3)$6($5)/;
		} else {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3$z2$5)$6(,1)/;
		}
	}
	elsif ( 	 /\[\s*(\w+)\s*:\s*(\w+)\s*\]/o ) {
		if ( isreg($2) ) {
			s/\[\s*(\w+)\s*:\s*(\w+)\s*\]/$1:($2)/;
		} else {
			s/\[\s*(\w+)\s*:\s*(\w+)\s*\]/$1:$2(,1)/;
		}
	}
	elsif ( 	 /\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $2;
		$a2 = $5;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		if ( isreg($3) && isreg($6) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($6,$3,$4)/;
		} elsif ( isreg($4) && isreg($6) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($6,$4,$3)/;
		} elsif ( isreg($3) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z2$6)$7(,$3,$4)/;
		} elsif ( isreg($4) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z2$6)$7(,$4,$3)/;
		} elsif ( isreg($6) ) {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3*$4)$7($6)/;
		} else {
			s/\[\s*(\w+)\s*:\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/$1:($z1$3*$4$z2$6)$7(,1)/;
		}
	}

	# disp(base, index, scale)
	elsif ( 	 /\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $1;
		$a2 = $3;
		$a3 = $6;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		$z3 = bezplusa($a3);
		if ( isreg($2) && isreg($4) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z3$7)$8($2,$4,$5)/;
		} elsif ( isreg($2) && isreg($5) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z3$7)$8($2,$5,$4)/;
		} elsif ( isreg($2) && isreg($7) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z2$4*$5)$8($2,$7)/;
		} elsif ( isreg($4) && isreg($7) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2)$8($7,$4,$5)/;
		} elsif ( isreg($5) && isreg($7) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2)$8($7,$5,$4)/;
		} elsif ( isreg($2) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z3$7$z2$4*$5)$8($2)/;
		} elsif ( isreg($4) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z3$7+$z1$2)$8(,$4,$5)/;
		} elsif ( isreg($5) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z3$7+$z1$2)$8(,$5,$4)/;
		} elsif ( isreg($7) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2$z2$4*$5)$8($7)/;
		} else {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2$z2$4*$5$z3$7)$8(,1)/;
		}
	}
	elsif ( 	 /\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $1;
		$a2 = $4;
		$a3 = $6;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		$z3 = bezplusa($a3);
		if ( isreg($2) && isreg($5) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z3$7)$8($5,$2,$3)/;
		} elsif ( isreg($3) && isreg($5) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z3$7)$8($5,$3,$2)/;
		} elsif ( isreg($2) && isreg($7) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z2$5)$8($7,$2,$3)/;
		} elsif ( isreg($3) && isreg($7) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z2$5)$8($7,$3,$2)/;
		} elsif ( isreg($5) && isreg($7) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2*$3)$8($5,$7)/;
		} elsif ( isreg($2) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z2$5z3$7)$8(,$2,$3)/;
		} elsif ( isreg($3) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z2$5z3$7)$8(,$3,$2)/;
		} elsif ( isreg($5) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2*$3$z3$7)$8($5)/;
		} elsif ( isreg($7) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2*$3$z2$5)$8($7)/;
		} else {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2*$3$z2$5$z3$7)$8(,1)/;
		}
	}
	elsif ( 	 /\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $1;
		$a2 = $3;
		$a3 = $5;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		$z3 = bezplusa($a3);
		if ( isreg($2) && isreg($4) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z3$6*$7)$8($2,$4)/;
		} elsif ( isreg($2) && isreg($6) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z2$4)$8($2,$6,$7)/;
		} elsif ( isreg($2) && isreg($7) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z2$4)$8($2,$7,$6)/;
		} elsif ( isreg($4) && isreg($6) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z1$2)$8($4,$6,$7)/;
		} elsif ( isreg($4) && isreg($7) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z1$2)$8($4,$7,$6)/;
		} elsif ( isreg($2) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z2$4$z3$6*$7)$8($2)/;
		} elsif ( isreg($4) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z3$6*$7$z1$2)$8($4)/;
		} elsif ( isreg($6) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z1$2$z2$4)$8(,$6,$7)/;
		} elsif ( isreg($7) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z1$2$z2$4)$8(,$7,$6)/;
		} else {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z1$2$z2$4$z3$6*$7)$8(,1)/;
		}
	}
	elsif ( 	 /\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $1;
		$a2 = $3;
		$a3 = $5;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		$z3 = bezplusa($a3);
		if ( isreg($2) && isreg($4) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z3$6)$7($2,$4)/;
		} elsif ( isreg($2) && isreg($6) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z2$4)$7($2,$6)/;
		} elsif ( isreg($4) && isreg($6) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2)$7($4,$6)/;
		} elsif ( isreg($2) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z3$6$z2$4)$7($2)/;
		} elsif ( isreg($4) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z3$6+$z1$2)$7($4)/;
		} elsif ( isreg($6) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2$z2$4)$7($6)/;
		} else {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2$z2$4$z3$6)$7(,1)/;
		}
	}
	elsif ( 	 /\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $1;
		$a2 = $3;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		if ( isreg($2) && isreg($4) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($2,$4,$5)/;
		} elsif ( isreg($2) && isreg($5) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($2,$5,$4)/;
		} elsif ( isreg($2) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z2$4*$5)$6($2)/;
		} elsif ( isreg($4) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z1$2)$6(,$4,$5)/;
		} elsif ( isreg($5) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z1$2)$6(,$5,$4)/;
		} else {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*\*\s*(\w+)\s*(\)*)\s*\]/($z1$2$z2$4*$5)$6(,1)/;
		}
	}
	elsif ( 	 /\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $1;
		$a2 = $3;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		if ( isreg($2) && isreg($4) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($2,$4)/;
		} elsif ( isreg($2) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z2$4)$5($2)/;
		} elsif ( isreg($4) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2)$5($4)/;
		} else {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($2$z2$4)$5(,1)/;
		}
	}
	elsif ( 	 /\[\s*(\w+)\s*\]/o ) {
		if ( isreg($1) ) {
			# disp(base)
			s/\[\s*(\w+)\s*\]/($1)/;
		} else {
			s/\[\s*(\w+)\s*\]/$1(,1)/;
		}
	}
	elsif ( 	 /\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/o ) {
		$a1 = $1;
		$a2 = $4;
		$z1 = bezplusa($a1);
		$z2 = bezplusa($a2);
		if ( isreg($2) && isreg($5) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($5,$2,$3)/;
		} elsif ( isreg($3) && isreg($5) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($5,$3,$2)/;
		} elsif ( isreg($2) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z2$5)$6(,$2,$3)/;
		} elsif ( isreg($3) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z2$5)$6(,$3,$2)/;
		} elsif ( isreg($5) ) {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2*$3)$6($5)/;
		} else {
			s/\[\s*([\+\-\(\)]*)\s*(\w+)\s*\*\s*(\w+)\s*([\+\-\(\)]+)\s*(\w+)\s*(\)*)\s*\]/($z1$2*$3$z2$5)$6(,1)/;
		}
	}


	# zmiana "stN" na "st(N)" (changing "stN" to "st(N)")
	s/\bst(\d)\b/\%st($1)/g;


	# Dodawanie znakow procenta (adding percent chars)
	foreach my $r (@regs) {

		s/\b$r\b/\%$r/gi;
	}

	# REP**: dodajemy znak konca linii (REP**: adding the end of line char)
	s/^\s*(rep[enz]{0,2})\s+/\t$1\n\t/i;


	# zmiana komentarzy (change the comments)
	&komen(0);

	print $wy "$_";

}


##########################################################
# Zmiana komentarzy (changing the comments).
# GAS ma takie same komentarze, jak C (GAS has the same comments as C)

sub	komen {

	# parametr = 0 => nie ma drukowania (when the parameter is 0, there will be no printing)
	my $drukuj = shift;

	s/;(.*)/\/\* $1 \*\//;

	print $wy "$_" if $drukuj;
}

##########################################################
# Kompilacja warunkowa (conditional compiling)

sub	kom_war {

	# parametr = 0 => nie ma drukowania (when the parameter is 0, there will be no printing)
	my $drukuj = shift;

	# sklejanie argumentow: (concatenating arguments:)
	s/\%\+/,/go;

	# pomijamy makra (skip over macros)
	if ( /^\s*\%\s*[ix]{0,2}define\s+\w+\s*\(/io )	{ return; }


	# rep:
	if ( /^\s*\%rep/io )	{

		s/^\s*\%rep\s+(\d+)/.rept $1\n/i;
		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	# %endrep:
	if ( /^\s*\%\s*endrep/io )	{

		s/^\s*\%\s*endrep/\.endr\t$1/i;
		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	#	Definicje stalych #define (definitions of #define constants)
	if ( /^\s*\%\s*[ix]{0,2}define\s+/io ) {

		s/^\s*\%\s*[ix]{0,2}define\s+(\w+)\s+([\w\"\|\&\<\>\(\)\-\+]*)/\.equ\t$1, $2/i;

		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	#	Kompilacja warunkowa (conditional compiling)
	if ( /^\s*\%if(def|macro)/io ) {

		s/^\s*\%if(def|macro)(.*)$/\.ifdef $2/i;
		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	if ( /^\s*\%ifndef/io ) {

		s/^\s*\%ifndef(.*)$/\.ifndef $1/i;
		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	if ( /^\s*\%endif/io ) {

		s/^\s*\%endif.*$/\.endif/io;
		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	if ( /^\s*\%elif/io ) {

		s/^\s*\%elif(.*)$/\.elseif $1/i;

		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	if ( /^\s*\%else/io ) {

		s/^\s*\%else(.*)$/\.else $1/i;
		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	if ( /^\s*\%if/io ) {

		s/^\s*\%if(.*)$/\.if $1/i;

		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	if ( /^\s*\%error/io ) {

		s/^\s*\%error(.*)$/\.err "$2"/i;
		if ( $drukuj ) { print $wy "$_"; }
	}

	# %substr:
	if ( /^\s*\%\s*substr/io )	{

#		s/^\s*\%\s*substr\s+(\w+)\s+([\w\s\"\'\`]+)\s+(\d+)/$1 = $2[$3]/i;
		if ( $drukuj ) { print $wy "\.err \"WARNING: skipped \%substr\""; }
		return;
	}

	# %strlen:
	if ( /^\s*\%\s*strlen/io )	{

#		s/^\s*\%\s*strlen\s+(\w+)\s+([\w\s\"\'\`]+)/\@\@: db $2\n$1 = \$-\@b/i;
		if ( $drukuj ) { print $wy "\.err \"WARNING: skipped \%strlen\""; }
		return;
	}

	# %assign:
	if ( /^\s*\%\s*assign/io )	{

		s/^\s*\%\s*assign\s+(\w+)\s+(\w+)/\.equ\t$1, $2/i;
		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	# %rotate:
	if ( /^\s*\%\s*rotate/io )	{

		s/^\s*\%\s*rotate\s+(\w+)//io;
		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	# %undef:
	if ( /^\s*\%\s*undef/io )	{

		s/^\s*\%\s*undef\s+(\w+)/\.equ $1, /i;
		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	# identycznosc napisow (identity of strings)
	if ( /^\s*\%\s*ifidni?/io ) {

		s/^\s*\%\s*ifidni?\s+([\w+\'\"\`]+)\s+([\w+\'\"\`]+)/\.if $1 = $2/i;
		if ( $drukuj ) { print $wy "$_"; }
		return;
	}

	# sprawdzanie typu (type checking)
	if ( /^\s*\%\s*if(id|num|str)/io ) {

		if ( $drukuj ) { print $wy "\n"; }
		return;
	}



}


##########################################################
# Koniec (the end):

close $wy;
close $we;

