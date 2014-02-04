%include "../pm.inc"

jmp LABEL_BEGIN                 ; 直接跳转到开始处

[SECTION .gdt]
LABEL_GDT:              DESCRIPTOR 0, 0, 0
LABEL_DESC_NORMAL:      DESCRIPTOR 0, 0xffff, DA_DRW
LABEL_DESC_CODE32:      DESCRIPTOR 0, seg_code32_len-1, DA_C+DA_32
LABEL_DESC_CODE16:      DESCRIPTOR 0, 0xffff, DA_C
LABEL_DESC_CODE_DEST:   DESCRIPTOR 0, seg_code_dest_len-1, DA_C+DA_32
LABEL_DESC_CODE_RING3:  DESCRIPTOR 0, seg_code_ring3_len-1, DA_C+DA_32+DA_DPL3
LABEL_DESC_DATA:        DESCRIPTOR 0, data_len-1, DA_DRW
LABEL_DESC_STACK:       DESCRIPTOR 0, bottom_of_stack, DA_DRWA+DA_32
LABEL_DESC_STACK_RING3: DESCRIPTOR 0, bottom_of_stack_ring3, DA_DRWA+DA_32+DA_DPL3
LABEL_DESC_LDT:         DESCRIPTOR 0, ldt_len-1, DA_LDT
LABEL_DESC_VIDEO:       DESCRIPTOR 0xb8000, 0xffff, DA_DRW+DA_DPL3
LABEL_CALL_GATE:        GATE selector_code_dest, 0, 0, DA_386CALLGATE+DA_DPL0

gdt_len equ $-LABEL_GDT
gdt_ptr:    dw gdt_len-1
            dd 0

selector_normal equ LABEL_DESC_NORMAL-LABEL_GDT
selector_code32 equ LABEL_DESC_CODE32-LABEL_GDT
selector_code16 equ LABEL_DESC_CODE16-LABEL_GDT
selector_code_dest equ LABEL_DESC_CODE_DEST-LABEL_GDT
selector_code_ring3 equ LABEL_DESC_CODE_RING3-LABLE_GDT
selector_data equ LABEL_DESC_DATA-LABEL_GDT
selector_stack equ LABEL_DESC_STACK-LABEL_GDT
selector_stack_ring3 equ LABEL_DESC_STACK_RING3-LABEL_GDT
selector_ldt equ LABEL_DESC_LDT-LABEL_GDT
selector_video equ LABEL_DESC_VIDEO-LABEL_GDT
selector_call_gate equ LABEL_CALL_GATE-LABEL_GDT

[SECTION .data]
ALIGN 32
[BITS 32]
LABEL_DATA:
sp_in_real_mode dw 0
pm_msg: db "in protect mode now ...", 0
pm_msg_offset: equ pm_msg-$$
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

[SECTION .s16]
[BITS 16]
LABEL_BEGIN:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x0100
    
    mov [LABEL_RETURN_REAL_MODE+3], ax
    mov [sp_in_real_mode], sp
    
    ; 初始化描述符
    INIT_DESCRIPTOR LABEL_DESC_CODE16, LABEL_SEG_CODE16
    INIT_DESCRIPTOR LABEL_DESC_CODE32, LABEL_SEG_CODE32
    INIT_DESCRIPTOR LABEL_DESC_CODE_DEST, LABEL_SEG_CODE_DEST
    INIT_DESCRIPTOR LABEL_DESC_DATA, LABEL_DATA
    INIT_DESCRIPTOR LABEL_DESC_STACK, LABEL_STACK
    INIT_DESCRIPTOR LABEL_DESC_STACK_RING3, LABEL_STACK_RING3
    INIT_DESCRIPTOR LABEL_DESC_LDT, LABEL_LDT
    INIT_DESCRIPTOR LABEL_LDT_DESC_CODE_A, LABEL_SEG_CODE_A    
    INIT_DESCRIPTOR LABEL_DESC_CODE_RING3, LABEL_SEG_CODE_RING3
    
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
    and al, 11111101b
    out 0x92, al
    sti
    
[SECTION .s32]
[BITS 32]
LABEL_SEG_CODE32:
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
    mov edi, (80*10+0)*2
    cld
.1:
    lodsb
    test al, al
    jz .2
    mov [gs:edi], ax
    add edi, 2
    jmp .1
.2:
    call display_return
    push selector_stack_ring3
    push bottom_of_stack_ring3
    push selector_code_ring3
    push 0
    retf
    
    call selector_call_gate:0
    mov ax, selector_ldt
    lldt ax
    jmp selector_ldt_code_a:0
    
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
    
seg_code32_len equ $-LABEL_SEG_CODE32

[SECTION .sdest]
[BITS 32]
LABEL_SEG_CODE_DEST:
    mov ax, selector_video
    mov gs, ax
    mov edi, (80*12+0)*2
    mov ah, 0x0c
    mov al, 'C'
    mov [gs:edi], ax
    retf
    
seg_code_dest_len equ $-LABEL_SEG_CODE_DEST

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
    
    mov eax, cr0
    and al, 11111110b
    mov cr0, eax
    
LABEL_RETURN_REAL_MODE:
    jmp 0:LABEL_REAL_MODE_ENTRY
    
code16_len equ $-LABEL_SEG_CODE16

[SECTION .ldt]
ALIGN 32
LABEL_LDT:
LABEL_LDT_DESC_CODE_A:  DESCRIPTOR 0, code_a_len-1, DA_C+DA_32
ldt_len equ $-LABEL_LDT

selector_ldt_code_a equ LABEL_LDT_DESC_CODE_A-LABEL_LDT+SA_TIL

[SECTION .la]
ALIGN 32
[BITS 32]
LABEL_CODE_A:
    mov ax, selector_video
    mov gs, ax
    mov edi, (80*13+0)*2
    mov ah, 0x0c
    mov al, 'L'
    mov [gs:edi], ax
    jmp selector_code16:0
    
code_a_len equ $-LABEL_CODE_A

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
    jmp $
    
seg_code_ring3_len equ $-LABEL_SEG_CODE_RING3