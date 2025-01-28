;*****************************************************************************
;* SSE2-optimized HEVC deblocking code
;*****************************************************************************
;* Copyright (C) 2013 VTT
;*
;* Authors: Seppo Tomperi <seppo.tomperi@vtt.fi>
;*
;* This file is part of FFmpeg.
;*
;* FFmpeg is free software; you can redistribute it and/or
;* modify it under the terms of the GNU Lesser General Public
;* License as published by the Free Software Foundation; either
;* version 2.1 of the License, or (at your option) any later version.
;*
;* FFmpeg is distributed in the hope that it will be useful,
;* but WITHOUT ANY WARRANTY; without even the implied warranty of
;* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;* Lesser General Public License for more details.
;*
;* You should have received a copy of the GNU Lesser General Public
;* License along with FFmpeg; if not, write to the Free Software
;* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
;******************************************************************************

; in: 8 rows of 4 bytes in %4..%11
; out: 4 rows of 8 words in m0..m3
%macro TRANSPOSE4x8B_LOAD 8
    movd             m0, %1
    movd             m2, %2
    movd             m1, %3
    movd             m3, %4

    punpcklbw        m0, m2
    punpcklbw        m1, m3
    punpcklwd        m0, m1

    movd             m4, %5
    movd             m6, %6
    movd             m5, %7
    movd             m3, %8

    punpcklbw        m4, m6
    punpcklbw        m5, m3
    punpcklwd        m4, m5

    punpckhdq        m2, m0, m4
    punpckldq        m0, m4

    pxor             m5, m5
    punpckhbw        m1, m0, m5
    punpcklbw        m0, m5
    punpckhbw        m3, m2, m5
    punpcklbw        m2, m5
%endmacro

; in: 4 rows of 8 words in m0..m3
; out: 8 rows of 4 bytes in %1..%8
%macro TRANSPOSE8x4B_STORE 8
    packuswb         m0, m2
    packuswb         m1, m3
    SBUTTERFLY bw, 0, 1, 2
    SBUTTERFLY wd, 0, 1, 2

    movd             %1, m0
    pshufd           m0, m0, 0x39
    movd             %2, m0
    pshufd           m0, m0, 0x39
    movd             %3, m0
    pshufd           m0, m0, 0x39
    movd             %4, m0

    movd             %5, m1
    pshufd           m1, m1, 0x39
    movd             %6, m1
    pshufd           m1, m1, 0x39
    movd             %7, m1
    pshufd           m1, m1, 0x39
    movd             %8, m1
%endmacro

; in: 8 rows of 4 words in %4..%11
; out: 4 rows of 8 words in m0..m3
%macro TRANSPOSE4x8W_LOAD 8
    movq             m0, %1
    movq             m2, %2
    movq             m1, %3
    movq             m3, %4

    punpcklwd        m0, m2
    punpcklwd        m1, m3
    punpckhdq        m2, m0, m1
    punpckldq        m0, m1

    movq             m4, %5
    movq             m6, %6
    movq             m5, %7
    movq             m3, %8

    punpcklwd        m4, m6
    punpcklwd        m5, m3
    punpckhdq        m6, m4, m5
    punpckldq        m4, m5

    punpckhqdq       m1, m0, m4
    punpcklqdq       m0, m4
    punpckhqdq       m3, m2, m6
    punpcklqdq       m2, m6

%endmacro

; in: 4 rows of 8 words in m0..m3
; out: 8 rows of 4 words in %1..%8
%macro TRANSPOSE8x4W_STORE 9
    TRANSPOSE4x4W     0, 1, 2, 3, 4

    pxor             m5, m5; zeros reg
    CLIPW            m0, m5, %9
    CLIPW            m1, m5, %9
    CLIPW            m2, m5, %9
    CLIPW            m3, m5, %9

    movq             %1, m0
    movhps           %2, m0
    movq             %3, m1
    movhps           %4, m1
    movq             %5, m2
    movhps           %6, m2
    movq             %7, m3
    movhps           %8, m3
%endmacro

; in: 8 rows of 8 bytes in %1..%8
; out: 8 rows of 8 words in m0..m7
%macro TRANSPOSE8x8B_LOAD 8
    movq             m7, %1
    movq             m2, %2
    movq             m1, %3
    movq             m3, %4

    punpcklbw        m7, m2
    punpcklbw        m1, m3
    punpcklwd        m3, m7, m1
    punpckhwd        m7, m1

    movq             m4, %5
    movq             m6, %6
    movq             m5, %7
    movq            m15, %8

    punpcklbw        m4, m6
    punpcklbw        m5, m15
    punpcklwd        m9, m4, m5
    punpckhwd        m4, m5

    punpckldq        m1, m3, m9;  0, 1
    punpckhdq        m3, m9;  2, 3

    punpckldq        m5, m7, m4;  4, 5
    punpckhdq        m7, m4;  6, 7

    pxor            m13, m13

    punpcklbw        m0, m1, m13; 0 in 16 bit
    punpckhbw        m1, m13; 1 in 16 bit

    punpcklbw        m2, m3, m13; 2
    punpckhbw        m3, m13; 3

    punpcklbw        m4, m5, m13; 4
    punpckhbw        m5, m13; 5

    punpcklbw        m6, m7, m13; 6
    punpckhbw        m7, m13; 7
%endmacro


; in: 8 rows of 8 words in m0..m8
; out: 8 rows of 8 bytes in %1..%8
%macro TRANSPOSE8x8B_STORE 8
    packuswb         m0, m4
    packuswb         m1, m5
    packuswb         m2, m6
    packuswb         m3, m7
    TRANSPOSE2x4x4B   0, 1, 2, 3, 4

    movq             %1, m0
    movhps           %2, m0
    movq             %3, m1
    movhps           %4, m1
    movq             %5, m2
    movhps           %6, m2
    movq             %7, m3
    movhps           %8, m3
%endmacro

; in: 8 rows of 8 words in %1..%8
; out: 8 rows of 8 words in m0..m7
%macro TRANSPOSE8x8W_LOAD 8
    movdqu           m0, %1
    movdqu           m1, %2
    movdqu           m2, %3
    movdqu           m3, %4
    movdqu           m4, %5
    movdqu           m5, %6
    movdqu           m6, %7
    movdqu           m7, %8
    TRANSPOSE8x8W     0, 1, 2, 3, 4, 5, 6, 7, 8
%endmacro

; in: 8 rows of 8 words in m0..m8
; out: 8 rows of 8 words in %1..%8
%macro TRANSPOSE8x8W_STORE 9
    TRANSPOSE8x8W     0, 1, 2, 3, 4, 5, 6, 7, 8

    pxor             m8, m8
    CLIPW            m0, m8, %9
    CLIPW            m1, m8, %9
    CLIPW            m2, m8, %9
    CLIPW            m3, m8, %9
    CLIPW            m4, m8, %9
    CLIPW            m5, m8, %9
    CLIPW            m6, m8, %9
    CLIPW            m7, m8, %9

    movdqu           %1, m0
    movdqu           %2, m1
    movdqu           %3, m2
    movdqu           %4, m3
    movdqu           %5, m4
    movdqu           %6, m5
    movdqu           %7, m6
    movdqu           %8, m7
%endmacro

; in: %2 clobbered
; out: %1
; mask in %3, will be clobbered
%macro MASKED_COPY2 3
%ifnum sizeof%1
    PBLENDVB         %1, %2, %3
%else
    vpmaskmovd       %1, %3, %2
%endif
%endmacro

; in: %2 clobbered
; out: %1
; mask in m11
%macro MASKED_COPY 2
    MASKED_COPY2 %1, %2, m11
%endmacro

%macro LUMA_LOAD_BETA 3
%ifidn %2, vvc
    movq            %1, [betaq];
    punpcklwd       %1, %1
    vpermilps       %1, %1, q2200
    %if %3 > 8
        psllw       %1, %3 - 8
    %endif
%else
    movd            %1, betad
    SPLATW          %1, %1, 0
%endif
%endmacro

%macro LUMA_LOAD_TC 4
    mov     %1d, %2
%ifidn %3, vvc
    %if %4 > 10
        shl      %1, %4 - 10
    %elif %4 < 10
        add      %1, 1 << (9 - %4)
        shr      %1, 10 - %4
    %endif
%else
    %if %4 > 8
        shl      %1, %4 - 8
    %endif
%endif
%endmacro

%macro LUMA_LOAD_TC 2
    LUMA_LOAD_TC       r11, [tcq], %1, %2
    movd                m8, r11d; tc0
    LUMA_LOAD_TC        r3, [tcq+4], %1, %2
    add                r11d, r3d; tc0 + tc1
%endmacro

; input in m0 ... m7, beta in r2 tcs in r3. Output in m1...m6
%macro H2656_LUMA_DEBLOCK_BODY 3
    psllw            m9, m2, 1; *2
    psubw           m10, m1, m9
    paddw           m10, m3
    ABS1            m10, m11 ; 0dp0, 0dp3 , 1dp0, 1dp3

    psllw            m9, m5, 1; *2
    psubw           m11, m6, m9
    paddw           m11, m4
    ABS1            m11, m13 ; 0dq0, 0dq3 , 1dq0, 1dq3

    ;beta calculations
%ifidn %1, hevc
    %if %2 > 8
        shl             betaq, %2 - 8
    %endif
%endif
    LUMA_LOAD_BETA  m13, %1, %2
    ;end beta calculations

    paddw            m9, m10, m11;   0d0, 0d3  ,  1d0, 1d3

    pshufhw         m14, m9, 0x0f ;0b00001111;  0d3 0d3 0d0 0d0 in high
    pshuflw         m14, m14, 0x0f ;0b00001111;  1d3 1d3 1d0 1d0 in low

    pshufhw          m9, m9, 0xf0 ;0b11110000; 0d0 0d0 0d3 0d3
    pshuflw          m9, m9, 0xf0 ;0b11110000; 1d0 1d0 1d3 1d3

    paddw           m14, m9; 0d0+0d3, 1d0+1d3

    ;compare
    pcmpgtw         m15, m13, m14
    movmskps        r13, m15 ;filtering mask 0d0 + 0d3 < beta0 (bit 2 or 3) , 1d0 + 1d3 < beta1 (bit 0 or 1)
    test            r13, r13
    je              .bypassluma

    ;weak / strong decision compare to beta_2
    psraw           m15, m13, 2;   beta >> 2
    psllw            m8, m9, 1;
    pcmpgtw         m15, m8; (d0 << 1) < beta_2, (d3 << 1) < beta_2
    movmskps        r6, m15;
    ;end weak / strong decision

    ; weak filter nd_p/q calculation
    pshufd           m8, m10, 0x31
    psrld            m8, 16
    paddw            m8, m10
    movd            r7d, m8
    pshufd           m8, m8, 0x4E
    movd            r8d, m8

    pshufd           m8, m11, 0x31
    psrld            m8, 16
    paddw            m8, m11
    movd            r9d, m8
    pshufd           m8, m8, 0x4E
    movd           r10d, m8
    ; end calc for weak filter

    ; filtering mask
    mov             r11, r13
    shr             r11, 3
    movd            m15, r11d
    and             r13, 1
    movd            m11, r13d
    shufps          m11, m15, 0
    shl             r11, 1
    or              r13, r11

    pcmpeqd         m11, [pd_1]; filtering mask

    ;decide between strong and weak filtering
    ;tc25 calculations
    LUMA_LOAD_TC     %1, %2
    jz             .bypassluma
    movd             m9, r3d; tc1
    punpcklwd        m8, m8
    punpcklwd        m9, m9
    shufps           m8, m9, 0; tc0, tc1
    mova             m9, m8
    psllw            m8, 2; tc << 2
    pavgw            m8, m9; tc25 = ((tc * 5 + 1) >> 1)
    ;end tc25 calculations

    ;----beta_3 comparison-----
    psubw           m12, m0, m3;      p3 - p0
    ABS1            m12, m14; abs(p3 - p0)

    psubw           m15, m7, m4;      q3 - q0
    ABS1            m15, m14; abs(q3 - q0)

    paddw           m12, m15; abs(p3 - p0) + abs(q3 - q0)

    pshufhw         m12, m12, 0xf0 ;0b11110000;
    pshuflw         m12, m12, 0xf0 ;0b11110000;

    psraw           m13, 3; beta >> 3
    pcmpgtw         m13, m12;
    movmskps        r11, m13;
    and             r6, r11; strong mask , beta_2 and beta_3 comparisons
    ;----beta_3 comparison end-----
    ;----tc25 comparison---
    psubw           m12, m3, m4;      p0 - q0
    ABS1            m12, m14; abs(p0 - q0)

    pshufhw         m12, m12, 0xf0 ;0b11110000;
    pshuflw         m12, m12, 0xf0 ;0b11110000;

    pcmpgtw          m8, m12; tc25 comparisons
    movmskps        r11, m8;
    and             r6, r11; strong mask, beta_2, beta_3 and tc25 comparisons
    ;----tc25 comparison end---
%ifidn %1, vvc
    ;----max_len comparison end---
    mov            r11q, r6mp
    pinsrw          m12, [r11q], 0; max_len_p
    mov            r11q, r7mp
    pinsrw          m12, [r11q], 1; max_len_q
    pxor            m13, m13
    punpcklbw       m12, m13
    pshuflw         m12, m12, q3120
    punpcklwd       m12, m12
    pcmpgtw         m12, [pw_2]; max_len comparisons
    movmskps        r11, m12
    and              r6, r11; strong mask, beta_2, beta_3 and tc25 and max_len_{q, p} comparisons
    ;----max_len comparison end---
%endif
    mov             r11, r6;
    shr             r11, 1;
    and             r6, r11; strong mask, bits 2 and 0

%ifidn %1, hevc
    pmullw          m14, m9, [pw_m2]; -tc * 2
    paddw            m9, m9
%endif

    and             r6, 5; 0b101
    mov             r11, r6; strong mask
    shr             r6, 2;
    movd            m12, r6d; store to xmm for mask generation
    shl             r6, 1
    and             r11, 1
    movd            m10, r11d; store to xmm for mask generation
    or              r6, r11; final strong mask, bits 1 and 0
    jz      .weakfilter

    shufps          m10, m12, 0
    pcmpeqd         m10, [pd_1]; strong mask

%ifidn %1, vvc
    mova            m15, m9
    psllw            m9, 2;          4*tc
    psubw           m14, m15, m9;   -3*tc
    psubw            m9, m15;        3*tc
%endif

    mova            m13, [pw_4]; 4 in every cell
    pand            m11, m10; combine filtering mask and strong mask
    paddw           m12, m2, m3;          p1 +   p0
    paddw           m12, m4;          p1 +   p0 +   q0
    mova            m10, m12; copy
    paddw           m12, m12;       2*p1 + 2*p0 + 2*q0
    paddw           m12, m1;   p2 + 2*p1 + 2*p0 + 2*q0
    paddw           m12, m5;   p2 + 2*p1 + 2*p0 + 2*q0 + q1
    paddw           m12, m13;  p2 + 2*p1 + 2*p0 + 2*q0 + q1 + 4
    psraw           m12, 3;  ((p2 + 2*p1 + 2*p0 + 2*q0 + q1 + 4) >> 3)
    psubw           m12, m3; ((p2 + 2*p1 + 2*p0 + 2*q0 + q1 + 4) >> 3) - p0
    CLIPW           m12, m14, m9; hevc:av_clip( , -2 * tc, 2 * tc), vvc:av_clip( , -3 * tc, 3 * tc)
    paddw           m12, m3; p0'

%ifidn %1, vvc
    paddw           m14, m15;  -2*tc
    psubw            m9, m15;   2*tc
%endif

    paddw           m15, m1, m10; p2 + p1 + p0 + q0
    psrlw           m13, 1; 2 in every cell
    paddw           m15, m13; p2 + p1 + p0 + q0 + 2
    psraw           m15, 2;  (p2 + p1 + p0 + q0 + 2) >> 2
    psubw           m15, m2;((p2 + p1 + p0 + q0 + 2) >> 2) - p1
    CLIPW           m15, m14, m9; av_clip( , -2 * tc, 2 * tc)
    paddw           m15, m2; p1'

%ifidn %1, vvc
    psraw            m9, 1;      tc
    psraw           m14, 1;     -tc
%endif

    paddw            m8, m1, m0;     p3 +   p2
    paddw            m8, m8;   2*p3 + 2*p2
    paddw            m8, m1;   2*p3 + 3*p2
    paddw            m8, m10;  2*p3 + 3*p2 + p1 + p0 + q0
    paddw           m13, m13
    paddw            m8, m13;  2*p3 + 3*p2 + p1 + p0 + q0 + 4
    psraw            m8, 3;   (2*p3 + 3*p2 + p1 + p0 + q0 + 4) >> 3
    psubw            m8, m1; ((2*p3 + 3*p2 + p1 + p0 + q0 + 4) >> 3) - p2
    CLIPW            m8, m14, m9; hevc:av_clip( , -2 * tc, 2 * tc), vvc:av_clip( , -tc, tc)
    paddw            m8, m1; p2'
    MASKED_COPY      m1, m8

%ifidn %1, vvc
    mova            m10, m9
    psllw            m9, 2;          4*tc
    psubw           m14, m10, m9;   -3*tc
    psubw            m9, m10;        3*tc
%endif

    paddw            m8, m3, m4;         p0 +   q0
    paddw            m8, m5;         p0 +   q0 +   q1
    paddw            m8, m8;       2*p0 + 2*q0 + 2*q1
    paddw            m8, m2;  p1 + 2*p0 + 2*q0 + 2*q1
    paddw            m8, m6;  p1 + 2*p0 + 2*q0 + 2*q1 + q2
    paddw            m8, m13; p1 + 2*p0 + 2*q0 + 2*q1 + q2 + 4
    psraw            m8, 3;  (p1 + 2*p0 + 2*q0 + 2*q1 + q2 + 4) >>3
    psubw            m8, m4;
    CLIPW            m8, m14, m9; hevc:av_clip( , -2 * tc, 2 * tc), vvc:av_clip( , -3 * tc, 3 * tc)
    paddw            m8, m4; q0'
    MASKED_COPY      m2, m15

%ifidn %1, vvc
    paddw           m14, m10;  -2*tc
    psubw            m9, m10;   2*tc
%endif

    paddw           m15, m3, m4;   p0 + q0
    paddw           m15, m5;   p0 + q0 + q1
    mova            m10, m15;
    paddw           m15, m6;   p0 + q0 + q1 + q2
    psrlw           m13, 1; 2 in every cell
    paddw           m15, m13;  p0 + q0 + q1 + q2 + 2
    psraw           m15, 2;   (p0 + q0 + q1 + q2 + 2) >> 2
    psubw           m15, m5; ((p0 + q0 + q1 + q2 + 2) >> 2) - q1
    CLIPW           m15, m14, m9; av_clip( , -2 * tc, 2 * tc)
    paddw           m15, m5; q1'

%ifidn %1, vvc
    psraw            m9, 1;      tc
    psraw           m14, 1;     -tc
%endif

    paddw           m13, m7;      q3 + 2
    paddw           m13, m6;      q3 +  q2 + 2
    paddw           m13, m13;   2*q3 + 2*q2 + 4
    paddw           m13, m6;    2*q3 + 3*q2 + 4
    paddw           m13, m10;   2*q3 + 3*q2 + q1 + q0 + p0 + 4
    psraw           m13, 3;    (2*q3 + 3*q2 + q1 + q0 + p0 + 4) >> 3
    psubw           m13, m6;  ((2*q3 + 3*q2 + q1 + q0 + p0 + 4) >> 3) - q2
    CLIPW           m13, m14, m9; hevc:av_clip( , -2 * tc, 2 * tc), vvc:av_clip( , -tc, tc)
    paddw           m13, m6; q2'

    MASKED_COPY      m6, m13
    MASKED_COPY      m5, m15
    MASKED_COPY      m4, m8
    MASKED_COPY      m3, m12

.weakfilter:
%ifidn %1, vvc
    pmullw          m14, m9, [pw_m2]; -tc * 2
    paddw            m9, m9
%endif

    not             r6; strong mask -> weak mask
    and             r6, r13; final weak filtering mask, bits 0 and 1
    jz             .store

    ; weak filtering mask
    mov             r11, r6
    shr             r11, 1
    movd            m12, r11d
    and             r6, 1
    movd            m11, r6d
    shufps          m11, m12, 0
    pcmpeqd         m11, [pd_1]; filtering mask

%ifidn %1, hevc
    mov             r13, betaq
    shr             r13, 1;
    add             betaq, r13
    shr             betaq, 3; ((beta + (beta >> 1)) >> 3))
%endif

    psubw           m12, m4, m3 ; q0 - p0
    paddw           m10, m12, m12
    paddw           m12, m10 ; 3 * (q0 - p0)
    psubw           m10, m5, m2 ; q1 - p1
    psubw           m12, m10 ; 3 * (q0 - p0) - (q1 - p1)
%if %2 < 12
    paddw           m10, m12, m12
    paddw           m12, [pw_8]; + 8
    paddw           m12, m10 ; 9 * (q0 - p0) - 3 * ( q1 - p1 )
    psraw           m12, 4; >> 4 , delta0
    PABSW           m13, m12; abs(delta0)
%elif cpuflag(ssse3)
    pabsw           m13, m12
    paddw           m10, m13, m13
    paddw           m13, [pw_8]
    paddw           m13, m10 ; abs(9 * (q0 - p0) - 3 * ( q1 - p1 ))
    pxor            m10, m10
    pcmpgtw         m10, m12
    paddw           m13, m10
    psrlw           m13, 4; >> 4, abs(delta0)
    psignw          m10, m13, m12
    SWAP             10, 12
%else
    pxor            m10, m10
    pcmpgtw         m10, m12
    pxor            m12, m10
    psubw           m12, m10 ; abs()
    paddw           m13, m12, m12
    paddw           m12, [pw_8]
    paddw           m13, m12 ; 3*abs(m12)
    paddw           m13, m10
    psrlw           m13, 4
    pxor            m12, m13, m10
    psubw           m12, m10
%endif

    psllw           m10, m9, 2; 8 * tc
    paddw           m10, m9; 10 * tc
    pcmpgtw         m10, m13
    pand            m11, m10

    psraw            m9, 1;   tc * 2 -> tc
    psraw           m14, 1; -tc * 2 -> -tc

    CLIPW           m12, m14, m9;  av_clip(delta0, -tc, tc)

    psraw            m9, 1;   tc -> tc / 2
%if cpuflag(ssse3)
    psignw          m14, m9, [pw_m1]; -tc / 2
%else
    pmullw          m14, m9, [pw_m1]; -tc / 2
%endif

    pavgw           m15, m1, m3;   (p2 + p0 + 1) >> 1
    psubw           m15, m2;  ((p2 + p0 + 1) >> 1) - p1
    paddw           m15, m12; ((p2 + p0 + 1) >> 1) - p1 + delta0
    psraw           m15, 1;   (((p2 + p0 + 1) >> 1) - p1 + delta0) >> 1
    CLIPW           m15, m14, m9; av_clip(deltap1, -tc/2, tc/2)
    paddw           m15, m2; p1'

    ;beta calculations
    LUMA_LOAD_BETA  m10, %1, %2
%ifidn %1, vvc
    psrlw           m13, m10, 1
    paddw           m10, m13
    psrlw           m10, m10, 3
%endif

    movd            m13, r7d; 1dp0 + 1dp3
    movd             m8, r8d; 0dp0 + 0dp3
    punpcklwd        m8, m8
    punpcklwd       m13, m13
    shufps          m13, m8, 0;
    pcmpgtw          m8, m10, m13
    pand             m8, m11
    ;end beta calculations
    MASKED_COPY2     m2, m15, m8; write p1'

    pavgw            m8, m6, m4;   (q2 + q0 + 1) >> 1
    psubw            m8, m5;  ((q2 + q0 + 1) >> 1) - q1
    psubw            m8, m12; ((q2 + q0 + 1) >> 1) - q1 - delta0)
    psraw            m8, 1;   ((q2 + q0 + 1) >> 1) - q1 - delta0) >> 1
    CLIPW            m8, m14, m9; av_clip(deltaq1, -tc/2, tc/2)
    paddw            m8, m5; q1'

    movd            m13, r9d;
    movd            m15, r10d;
    punpcklwd       m15, m15
    punpcklwd       m13, m13
    shufps          m13, m15, 0; dq0 + dq3

    pcmpgtw         m10, m13; compare to ((beta+(beta>>1))>>3)
    pand            m10, m11
    MASKED_COPY2     m5, m8, m10; write q1'

    paddw           m15, m3, m12 ; p0 + delta0
    MASKED_COPY      m3, m15

    psubw            m8, m4, m12 ; q0 - delta0
    MASKED_COPY      m4, m8
%endmacro

; (%1 + 4) >> 3
%macro H2656_CHROMA_ROUND 1 ;(dst/src)
%if cpuflag(sse2)
    paddw           %1, [pw_4];
    psraw           %1, 3
%else
    pmulhrsw        %1, [pw_4096]
%endif
%endmacro

%macro H2656_CHROMA_DEBLOCK 10 ;(dst0, dst1, p1, p0, q0, q1, -tc, tc, tmp1, tmp2)
    psubw                %9, %5, %4; q0 - p0
    psubw               %10, %3, %6; p1 - q1
    psllw                %9, 2; << 2
    paddw               %10, %9;

    H2656_CHROMA_ROUND  %10

    CLIPW               %10, %7, %8
    paddw                %1, %4, %10; p0 + delta0
    psubw                %2, %5, %10; q0 - delta0
%endmacro