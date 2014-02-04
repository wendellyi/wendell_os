%include "pm.inc"
jmp LABEL_BEGIN
[SECTION .gdt]
LABEL_GDT:          DESCRIPTOR 0, 0, 0
LABEL_DESC_NORMAL:  DESCRIPTOR 0, 0xffff, DA_DRW
LABEL_DESC_CODE32:  DESCRIPTOR 0, seg_code_32_len-1, DA_C+DA_32
LABEL_DESC_CODE16:  DESCRIPTOR 0, 0xffff, DA_C
LABEL_DESC_DATA:    DESCRIPTOR 0, data_len-1, DA_DRW
LABEL_DESC_STACK:   DESCRIPTOR 0, top_of_stack, DA_DRWA+DA_32
LABEL_DESC_TEST:    DESCRIPTOR 0x500000, 0xffff, DA_DRW
LABEL_DESC_LDT:     DESCRIPTOR 0, ldt_len-1, DA_LDT
LABEL_DESC_VIDEO:   DESCRIPTOR 0xb8000, 0xffff, DA_DRW

gdt_len equ $-LABEL_GDT
gdt_ptr dw gdt_len-1
        dd 0

selector_normal equ LABEL_DESC_NORMAL-LABEL_GDT
selector_code_32 equ LABEL_DESC_CODE32-LABEL_GDT
selector_code_16 equ LABEL_DESC_CODE16-LABEL_GDT
selector_data equ LABEL_DESC_DATA-LABEL_GDT
selector_stack equ LABEL_DESC_STACK-LABEL_GDT
selector_test equ LABEL_DESC_TEST-LABEL_GDT
selector_ldt equ LABEL_DESC_LDT-LABEL_GDT
selector_video equ LABEL_DESC_VIDEO-LABEL_GDT

[SECTION .data0]
[BITS 16]
LABEL_DATA16:
cs_realmode: dw 0

[SECTION .data1]
ALIGN 32
[BITS 32]
LABEL_DATA:
sp_realmode: dw 0
pm_msg: db 'in protect mode now...', 0
pm_msg_offset equ pm_msg-$$
test_str: db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 0
test_str_offset equ test_str-$$
data_len equ $-LABEL_DATA

[SECTION .gs]
ALIGN 32
[BITS 32]
LABEL_STACK:
times 512 db 0
top_of_stack equ $-LABEL_STACK-1

[SECTION .s16]
[BITS 16]
LABEL_BEGIN:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x0100
    
    mov [cs_realmode], ax
    ;mov [LABEL_GO_BACK_TO_REAL_MODE+3], ax
    mov [sp_realmode], sp
    
    ; 初始化16位代码段描述符
    mov ax, cs
    movzx eax, ax
    shl eax, 4
    add eax, LABEL_SEG_CODE16
    mov word [LABEL_DESC_CODE16+2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE16+4], al
    mov byte [LABEL_DESC_CODE16+7], ah
    
    ; 初始化32位代码段描述符
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32
    mov word [LABEL_DESC_CODE32+2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32+4], al
    mov byte [LABEL_DESC_CODE32+7], ah
    
    ; 初始化数据段描述符
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_DATA
    mov word [LABEL_DESC_DATA+2], ax
    shr eax, 16
    mov byte [LABEL_DESC_DATA+4], al
    mov byte [LABEL_DESC_DATA+7], ah
    
    ; 初始化栈段描述符
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_STACK
    mov word [LABEL_DESC_STACK+2], ax
    shr eax, 16
    mov byte [LABEL_DESC_STACK+4], al
    mov byte [LABEL_DESC_STACK+7], ah
    
    ; 初始化gdt中ldt的描述符
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_LDT
    mov word [LABEL_DESC_LDT+2], ax
    shr eax, 16
    mov byte [LABEL_DESC_LDT+4], al
    mov byte [LABEL_DESC_LDT+7], ah
    
    ; 初始化ldt
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_CODE_A
    mov word [LABEL_LDT_DESC_CODEA+2], ax
    shr ea, 16
    mov byte [LABEL_LDT_DESC_CODEA+4], al
    mov byte [LABEL_LDT_DESC_CODEA+7], ah
    
    ; 进入保护模式
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_GDT
    mov dword [gdt_ptr+2], eax
    lgdt [gdt_ptr]
    cli
    in al, 0x92
    or al, 0x02
    out 0x92, al
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp dword selector_code_32:0
    
LABEL_REAL_ENTRY:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    
    call print_msg
    
    mov sp, [sp_realmode]
    in al, 0x92
    and al, 11111101b
    out 0x92, al
    sti
    
print_msg:
    mov ax, MSGSEG
	mov bp, ax
	mov cx, MSGSEG_END-MSGSEG
	mov ax, 0x1301
	mov bx, 0x000c
	;mov dl, 0
	int 0x10
	ret
    
MSGSEG:
    db 'now we in real mode again ...'
MSGSEG_END:

; 保护模式由此开始执行
[SECTION .s32]
[BITS 32]
LABEL_SEG_CODE32:
    ; 各个段初始化方式都不太一样了
    mov ax, selector_data
    mov ds, ax
    mov ax, selector_test
    mov es, ax
    mov ax, selector_video
    mov gs, ax
    mov ax, selector_stack
    mov ss, ax
    mov esp, top_of_stack   ; 指向栈底
    
    mov ah, 0x0c            ; 设置打印的颜色
    xor esi, esi
    xor edi, edi
    mov esi, pm_msg_offset  ; 在数据段中的偏移
    mov edi, (80*10+0)*2    ; 在第10行开始
    cld
    
; 开始显示保护模式下的字符串
.1:
    lodsb
    test al, al
    jz .2
    mov [gs:edi], ax
    add edi, 2
    jmp .1
    
.2:

    mov ax, selector_ldt
    lldt ax
    
    jmp selector_ldt_code_a:0   ; 跳入局部任务
    
; 读取8个字节
test_read:
    xor esi, esi
    mov ecx, 8
    
.loop:
    mov al, [es:esi]
    call display_al
    inc esi
    loop .loop
    call display_return
    ret
    
; 写入一串字符
test_write:
    push esi
    push edi
    xor esi, esi
    xor edi, edi
    mov esi, test_str_offset
    cld
    
.1:
    lodsb
    test al, al
    jz .2
    mov [es:edi], al
    inc edi
    jmp .1
    
.2:
    pop edi
    pop esi
    ret
    
display_al:
    push ecx
    push edx
    mov ah, 0x0c
    mov dl, al
    shr al, 4
    mov ecx, 2
    
.begin:
    and al, 0x0f
    cmp al, 9
    ja .1
    add al, '0'
    jmp .2
.1:
    sub al, 0x0a    ; 转换成ascii吗
    add al, 'A'
    
.2:
    mov [gs:edi], ax
    add edi, 2
    mov al, dl
    loop .begin
    add edi, 2
    pop edx
    pop ecx
    ret
    
display_return:
    push eax
    push ebx
    mov eax, edi
    mov bl, 160
    div bl
    add eax, 0xff
    inc eax
    mov bl, 160
    mul bl
    mov edi, eax
    pop ebx
    pop eax
    ret
    
seg_code_32_len equ $-LABEL_SEG_CODE32

[SECTION .ldt]
ALIGN 32
LABEL_LDT:
LABEL_LDT_DESC_CODEA: DESCRIPTOR 0, code_a_len-1, DA_C+DA_32
ldt_len equ $-LABEL_LDT

selector_ldt_code_a equ LABEL_LDT_DESC_CODEA-LABEL_LDT+SA_TIL

[SECTION .la]
ALIGN 32
[BITS 32]
LABEL_CODE_A:
    mov ax, selector_video
    mov gs, ax
    mov edi, (80*12+0)*2
    mov ah, 0x0c
    mov al, 'L'
    mov [gs:edi], ax
    jmp selector_code_16:0
    
code_a_len equ $-LABEL_CODE_A

[SECTION .s16code]
ALIGN 32
[BITS 16]
LABEL_SEG_CODE16:
    mov ax, selector_normal
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; 返回实模式
    mov eax, cr0
    and al, 11111110b
    mov cr0, eax
    
LABEL_GO_BACK_TO_REAL_MODE:
    jmp 0:LABEL_REAL_ENTRY
    
code_16_len equ $-LABEL_SEG_CODE16