%include "../pm.inc"

page_dir_base equ 0x200000
page_tab_base equ 0x201000

jmp LABEL_BEGIN                 ; 直接跳转到开始处

[SECTION .gdt]
LABEL_GDT:              DESCRIPTOR 0, 0, 0
LABEL_DESC_CODE32:      DESCRIPTOR 0, seg_code32_len-1, DA_C+DA_32
LABEL_DESC_CODE16:      DESCRIPTOR 0, 0xffff, DA_C
LABEL_DESC_CODE_RING3:  DESCRIPTOR 0, seg_code_ring3_len-1, DA_C+DA_32+DA_DPL3
LABEL_DESC_DATA:        DESCRIPTOR 0, data_len-1, DA_DRW
LABEL_DESC_STACK:       DESCRIPTOR 0, bottom_of_stack, DA_DRWA+DA_32
LABEL_DESC_STACK_RING3: DESCRIPTOR 0, bottom_of_stack_ring3, DA_DRWA+DA_32+DA_DPL3
LABEL_DESC_VIDEO:       DESCRIPTOR 0xb8000, 0xffff, DA_DRW+DA_DPL3
LABEL_DESC_LDT:         DESCRIPTOR 0, seg_ldt_len, DA_LDT
LABEL_DESC_NORMAL:      DESCRIPTOR 0, 0xffff, DA_DRW
LABEL_DESC_TSS:         DESCRIPTOR 0, seg_tss_len-1, DA_386TSS
LABEL_CALL_GATE:        GATE selector_code_dst, 0, 0, DA_386CALLGATE+DA_DPL3
LABEL_DESC_CODE_DST:    DESCRIPTOR 0, seg_code_dst_len-1, DA_C+DA_32
LABEL_DESC_PAGE_DIR:    DESCRIPTOR page_dir_base, 4095, DA_DRW
LABEL_DESC_PAGE_TAB:    DESCRIPTOR page_tab_base, 1023, DA_DRW | DA_LIMIT_4K

gdt_len equ $-LABEL_GDT
gdt_ptr:    dw gdt_len-1
            dd 0

selector_code32 equ LABEL_DESC_CODE32-LABEL_GDT
selector_code16 equ LABEL_DESC_CODE16-LABEL_GDT
selector_code_ring3 equ LABEL_DESC_CODE_RING3-LABEL_GDT+SA_RPL3
selector_data equ LABEL_DESC_DATA-LABEL_GDT
selector_stack equ LABEL_DESC_STACK-LABEL_GDT
selector_stack_ring3 equ LABEL_DESC_STACK_RING3-LABEL_GDT+SA_RPL3
selector_video equ LABEL_DESC_VIDEO-LABEL_GDT
selector_ldt equ LABEL_DESC_LDT-LABEL_GDT
selector_normal equ LABEL_DESC_NORMAL-LABEL_GDT
selector_tss equ LABEL_DESC_TSS-LABEL_GDT
selector_call_gate equ LABEL_CALL_GATE-LABEL_GDT+SA_RPL3
selector_code_dst equ LABEL_DESC_CODE_DST-LABEL_GDT
selector_page_dir equ LABEL_DESC_PAGE_DIR-LABEL_GDT
selector_page_tab equ LABEL_DESC_PAGE_TAB-LABEL_GDT

[SECTION .data]
ALIGN 32
[BITS 32]
LABEL_DATA:
sp_in_real_mode dw 0
pm_msg: db "in protect mode now ...", 0
pm_msg_offset equ pm_msg-$$
rm_msg: db "in real mode again ..."
rm_msg_len equ $-rm_msg
test_string: db "ABCDEFGHIGKLMNOPQRSTUVWXYZ", 0
test_string_offset equ test_string-$$
data_len equ $-LABEL_DATA

[SECTION .gs]
ALIGN 32
[BITS 32]
LABEL_STACK:
times 512 db 0

bottom_of_stack equ $-LABEL_STACK-1

[SECTION .s3]
ALIGN 32
[BITS 32]
LABEL_STACK_RING3:
    times 512 db 0

bottom_of_stack_ring3 equ $-LABEL_STACK_RING3-1

[SECTION .tss]
ALIGN 32
[BITS 32]
LABEL_TSS:
    dd 0
    dd bottom_of_stack      ; 特权级0栈
    dd selector_stack
    dd 0                    ; 特权级1栈
    dd 0
    dd 0                    ; 特权级2栈
    dd 0
    dd 0                    ; cr3
    dd 0                    ; eip
    dd 0                    ; eflags
    dd 0                    ; eax
    dd 0                    ; ecx
    dd 0                    ; edx
    dd 0                    ; ebx
    dd 0                    ; esp
    dd 0                    ; ebp
    dd 0                    ; esi
    dd 0                    ; edi
    dd 0                    ; es
    dd 0                    ; cs
    dd 0                    ; ss
    dd 0                    ; ds
    dd 0                    ; fs
    dd 0                    ; gs
    dd 0                    ; ldt
    dw 0                    ; 调试陷阱标志
    dw $-LABEL_TSS+2        ; i/o位图基址
    dw 0xff                 ; i/o位图标志
    
seg_tss_len equ $-LABEL_TSS

[SECTION .s16]
[BITS 16]
LABEL_BEGIN:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x0100
    
    mov [LABEL_RETURN_TO_REAL_MODE+3], ax
    mov [sp_in_real_mode], sp
    
    ; 在实模式下初始化所有描述符
    INIT_DESCRIPTOR LABEL_DESC_CODE32, LABEL_SEG_CODE32
    INIT_DESCRIPTOR LABEL_DESC_CODE16, LABEL_SEG_CODE16
    INIT_DESCRIPTOR LABEL_DESC_DATA, LABEL_DATA
    INIT_DESCRIPTOR LABEL_DESC_STACK, LABEL_STACK
    INIT_DESCRIPTOR LABEL_DESC_STACK_RING3, LABEL_STACK_RING3
    INIT_DESCRIPTOR LABEL_DESC_CODE_RING3, LABEL_SEG_CODE_RING3
    INIT_DESCRIPTOR LABEL_DESC_LDT, LABEL_LDT
    INIT_DESCRIPTOR LABEL_LDT_DESC_CODE_A, LABEL_SEG_LDT_CODE_A
    INIT_DESCRIPTOR LABEL_DESC_TSS, LABEL_TSS
    INIT_DESCRIPTOR LABEL_DESC_CODE_DST, LABEL_SEG_CODE_DST

    
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
    jmp word selector_code32:0
    
LABEL_REAL_MODE_ENTRY:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, [sp_in_real_mode]
    in al, 0x92
    and al, 11111110b
    out 0x92, al
    sti
    
    mov ax, rm_msg
	mov bp, ax
	mov cx, rm_msg_len
	mov ax, 0x1301
	mov bx, 0x000c
    mov dh, 2
	mov dl, 0
	int 0x10
    jmp $
    
[SECTION .s32]
[BITS 32]
LABEL_SEG_CODE32:
    call start_paging

    mov ax, selector_data
    mov ds, ax
    mov ax, selector_video
    mov gs, ax
    mov ax, selector_stack
    mov ss, ax
    mov esp, bottom_of_stack
    
    mov ah, 0x0c
    xor esi, esi
    xor edi, edi
    mov esi, pm_msg_offset
    mov edi, (80*1+0)*2
    cld
    
; 打印提示信息
.1:
    lodsb
    test al, al
    jz .2
    mov [gs:edi], ax
    add edi, 2
    jmp .1
.2:
    call display_return
    
    ; 加载tss
    mov ax, selector_tss
    ltr ax
    push selector_stack_ring3
    push bottom_of_stack_ring3
    push selector_code_ring3
    push 0
    jmp $                   ; 分页开启时，下面这条语句执行会引起异常
    retf
    
display_return:
    push eax
    push ebx
    mov eax, edi
    mov bl, 160
    div bl
    and eax, 0xff
    inc eax
    mov bl, 160
    mul bl
    mov edi, eax
    pop ebx
    pop eax
    ret
    
start_paging:    
    ; 初始化分页数据结构
    mov ax, selector_page_dir
    mov es, ax
    mov ecx, 1024
    xor edi, edi
    xor eax, eax
    mov eax, page_tab_base | PG_P | PG_USU | PG_RWW
    
.1:
    stosd
    add eax, 4096
    loop .1
    
    mov ax, selector_page_tab
    mov es, ax
    mov ecx, 1024*1024
    xor edi, edi
    xor eax, eax
    mov eax, PG_P | PG_USU | PG_RWW
.2:
    stosd
    add eax, 4096
    loop .2
    
    mov eax, page_dir_base
    mov cr3, eax
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax
    jmp short .3
.3:
    nop
    ret

seg_code32_len equ $-LABEL_SEG_CODE32

[SECTION .s16]
[BITS 16]
LABEL_SEG_CODE16:
    mov ax, selector_normal
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    mov eax, cr0
    and al, 11111110b
    mov cr0, eax
    
LABEL_RETURN_TO_REAL_MODE:
    jmp 0:LABEL_REAL_MODE_ENTRY
    
seg_code16_len equ $-LABEL_SEG_CODE16

[SECTION .ldt]
ALIGN 32
LABEL_LDT:
LABEL_LDT_DESC_CODE_A:      DESCRIPTOR 0, seg_ldt_code_a_len-1, DA_C+DA_32
seg_ldt_len equ $-LABEL_LDT

selector_ldt_code_a equ LABEL_LDT_DESC_CODE_A-LABEL_LDT+SA_TIL

; 特权级为3的代码段，向屏幕的第14行打印3
[SECTION .ring3]
ALIGN 32
[BITS 32]
LABEL_SEG_CODE_RING3:
    mov ax, selector_video
    mov gs, ax
    mov edi, (80*14+0)*2
    mov ah, 0x0c
    mov al, '3'
    mov [gs:edi], ax
    
    ; 现在是特权级3，需要调用特权级0的过程
    ; 所以需要tss和调用门参与
    call selector_call_gate:0
    
seg_code_ring3_len equ $-LABEL_SEG_CODE_RING3

[SECTION .sdst]
[BITS 32]
LABEL_SEG_CODE_DST:
    mov ax, selector_video
    mov gs, ax
    
    mov edi, (80*12+0)*2
    mov ah, 0x0c
    mov al, 'C'
    mov [gs:edi], ax
    
    add edi, 2
    mov al, 'G'
    mov [gs:edi], ax
    
    mov ax, selector_ldt
    lldt ax
    jmp selector_ldt_code_a:0   ; 跳入局部任务
    
seg_code_dst_len equ $-LABEL_SEG_CODE_DST

[SECTION .ldt_code_a]
[BITS 32]
LABEL_SEG_LDT_CODE_A:
    mov ax, selector_video
    mov gs, ax
    
    mov ah, 0x0c
    mov al, 'L'
    mov edi, (80*13+0)*2    
    mov [gs:edi], ax
    
    add edi, 2
    mov al, 'A'
    mov [gs:edi], ax
    
    jmp selector_code16:0
    
seg_ldt_code_a_len equ $-LABEL_SEG_LDT_CODE_A