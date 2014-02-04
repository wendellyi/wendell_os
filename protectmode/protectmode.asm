%include "pm.inc"

jmp LABEL_BEGIN

[SECTION .gdt]
LABEL_GDT_BEGIN:    DESCRIPTOR 0,       0,                  0
LABEL_DESC_CODE32:  DESCRIPTOR 0,       seg_code_32_len-1,  DA_C+DA_32
LABEL_DESC_VIDEO:   DESCRIPTOR 0xb8000, 0xffff,             DA_DRW

gdt_len equ $ - LABEL_GDT_BEGIN
gdt_ptr dw gdt_len-1
        dd 0

sector_code_32 equ LABEL_DESC_CODE32 - LABEL_GDT_BEGIN
sector_video equ LABEL_DESC_VIDEO - LABEL_GDT_BEGIN

[SECTION .s16]
[BITS 16]

LABEL_BEGIN:
    ; 初始化代码段、数据段和栈段
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x0200

    ; 初始化32位代码段描述符中的基地址
    ; 第一步是得到基地址，先将cs乘16，然后加上
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32
    mov word [LABEL_DESC_CODE32+2], ax  ; 低16位
    shr eax, 16
    mov byte [LABEL_DESC_CODE32+4], al  ; 中间8位
    mov byte [LABEL_DESC_CODE32+7], ah  ; 高8位
    
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_GDT_BEGIN
    mov dword [gdt_ptr+2], eax

    lgdt [gdt_ptr]  ; 载入gdt
    cli             ; 关中断
    in al, 0x92     ; 开a20
    or al, 0x02
    out 0x92, al

    mov eax, cr0    ; 进入保护模式
    or eax, 0x00000001
    mov cr0, eax

    jmp dword sector_code_32:0

[SECTION .s32]
[BITS 32]

LABEL_SEG_CODE32:
    mov ax, sector_video
    mov gs, ax
    mov edi, (80*11+40)*2   ; 视频缓冲区的偏移地址
    mov ah, 0x0c             ; 黑底红字
    mov al, 'p'
    mov [gs:edi], ax
    jmp $

seg_code_32_len equ $ - LABEL_SEG_CODE32

times 510-($-$$) db 0
dw 0xaa55