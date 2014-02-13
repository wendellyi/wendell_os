%include "../pm.inc"

page_dir_base equ 0x200000
page_tab_base equ 0x201000

jmp LABEL_BEGIN                 ; 直接跳转到开始处

[SECTION .gdt]
LABEL_GDT:              DESCRIPTOR 0, 0, 0
LABEL_DESC_CODE32:      DESCRIPTOR 0, seg_code32_len-1, DA_C+DA_32
LABEL_DESC_DATA:        DESCRIPTOR 0, data_len-1, DA_DRW
LABEL_DESC_STACK:       DESCRIPTOR 0, bottom_of_stack, DA_DRWA+DA_32
LABEL_DESC_VIDEO:       DESCRIPTOR 0xb8000, 0xffff, DA_DRW+DA_DPL3
LABEL_DESC_PAGE_DIR:    DESCRIPTOR page_dir_base, 4095, DA_DRW
LABEL_DESC_PAGE_TAB:    DESCRIPTOR page_tab_base, 1023, DA_DRW | DA_LIMIT_4K

gdt_len equ $-LABEL_GDT
gdt_ptr:    dw gdt_len-1
            dd 0

selector_code32 equ LABEL_DESC_CODE32-LABEL_GDT
selector_data equ LABEL_DESC_DATA-LABEL_GDT
selector_stack equ LABEL_DESC_STACK-LABEL_GDT
selector_video equ LABEL_DESC_VIDEO-LABEL_GDT
selector_page_dir equ LABEL_DESC_PAGE_DIR-LABEL_GDT
selector_page_tab equ LABEL_DESC_PAGE_TAB-LABEL_GDT

[SECTION .data]
ALIGN 32
[BITS 32]
LABEL_DATA:
_pm_msg: db "in protect mode now ...", 0x0a, 0x0a, 0
_mem_chk_title: db "base_addr_low base_addr_hig length_low length_hig type", 0x0a, 0
_ram_size_prifix: db "ram size: ", 0
_return_string: db 0x0a, 0

_sp_in_real_mode: dw 0
_mem_chk_result: dd 0
_display_position: dd (80*6+0)*2            ; 显示信息的位置
_mem_size: dd 0
_ard_struct:
    _base_addr_low: dd 0
    _base_addr_hig: dd 0
    _length_low: dd 0
    _length_hig: dd 0
    _ard_type: dd 0
ard_struct_size equ $-_ard_struct
    
_mem_chk_buffer: times 256 db 0

pm_msg equ _pm_msg-$$
mem_chk_title equ _mem_chk_title-$$
ram_size_prefix equ _ram_size_prifix-$$
return_string equ _return_string-$$
display_position equ _display_position-$$
mem_size equ _mem_size-$$
mem_chk_result equ _mem_chk_result-$$
ard_struct equ _ard_struct-$$
    base_addr_low equ _base_addr_low-$$
    base_addr_hig equ _base_addr_hig-$$
    length_low equ _length_low-$$
    length_hig equ _length_hig-$$
    ard_type equ _ard_type-$$
mem_chk_buffer equ _mem_chk_buffer-$$
data_len equ $-LABEL_DATA

[SECTION .gs]
ALIGN 32
[BITS 32]
LABEL_STACK:
times 512 db 0

bottom_of_stack equ $-LABEL_STACK-1

[SECTION .s16]
[BITS 16]
LABEL_BEGIN:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x1000                       ; 使用更大的栈空间，如果使用0x0100 int 0x15会有问题
    
    ; 获取内存信息，现在是在实模式下
    mov ebx, 0
    mov di, _mem_chk_buffer
.loop:    
    mov eax, 0xe820
    mov ecx, ard_struct_size
    mov edx, 0x534d4150
    int 0x15
    jc LABEL_MEM_CHK_FAILED         ; 有进位，表示出错了
    add di, ard_struct_size
    inc dword [_mem_chk_result]
    cmp ebx, 0                     ; 判断有无后续数据需要处理
    jne .loop
    jmp LABEL_MEM_CHK_OK
LABEL_MEM_CHK_FAILED:
    mov dword [_mem_chk_result], 0
LABEL_MEM_CHK_OK:
    
    ; 在实模式下初始化所有描述符
    INIT_DESCRIPTOR LABEL_DESC_CODE32, LABEL_SEG_CODE32
    INIT_DESCRIPTOR LABEL_DESC_DATA, LABEL_DATA
    INIT_DESCRIPTOR LABEL_DESC_STACK, LABEL_STACK
    
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
    
[SECTION .s32]
[BITS 32]
LABEL_SEG_CODE32:
    mov ax, selector_data
    mov ds, ax
    mov es, ax
    mov ax, selector_video
    mov gs, ax
    mov ax, selector_stack
    mov ss, ax
    mov esp, bottom_of_stack
        
    ; 显示进入保护模式信息
    push pm_msg
    call display_string
    add esp, 4
    
    ; 显示表头
    push mem_chk_title
    call display_string
    add esp, 4
    
    ; 显示内存分布信息
    call display_mem_size
    call start_paging
    jmp $
    
start_paging:    
    ; 根据内存大小计算需要初始化的页目录数目和页表数目
    xor edx, edx
    mov eax, [mem_size]
    mov ebx, 0x400000       ; 一个页表能表示4M的内存
    div ebx
    mov ecx, eax            ; eax为商
    test edx, edx           ; 判断是否有余数
    inc ecx
.no_remainder:
    push ecx                ; 暂存页表个数到栈
    
    ; 所有现行地址对应物理地址，并不考虑内存空洞
    ; 首先初始化页目录
    mov ax, selector_page_dir
    mov es, ax
    xor edi, edi
    xor eax, eax
    mov eax, page_tab_base | PG_P | PG_USU | PG_RWW ; 注意页表开始的地方是写死的
.1:
    stosd
    add eax, 4096   ; 下一个页表
    loop .1
    
    ; 再初始化所有页表
    mov ax, selector_page_tab
    mov es, ax
    pop eax                         ; 从栈中弹出页表个数
    mov ebx, 1024                   ; 一个页表占用一页的空间，含有1024页信息
    mul ebx                         ; 得到页的个数
    mov ecx, eax
    xor edi, edi
    xor eax, eax
    mov eax, PG_P | PG_USU | PG_RWW
.2:
    stosd
    add eax, 4096                   ; 每个页4K
    loop .2
    
    mov eax, page_dir_base
    mov cr3, eax
    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax                    ; 开启分页
    jmp short .3
.3:
    nop
    ret                             ; 开启分页结束
    
display_mem_size:
    push esi
    push edi
    push ecx
    
    mov esi, mem_chk_buffer
    mov ecx, [mem_chk_result]               ; 读取数据结构的个数
.loop:
    mov edx, 5                              ; 内存信息数据结构有5个字段
    mov edi, ard_struct                     ; 同一结构体反复使用
.1:
    push dword [esi]
    call display_int
    pop eax
    stosd                                   ; stosd dword ptr es:[edi], eax
    add esi, 4
    dec edx
    cmp edx, 0
    jnz .1
    call display_return
    cmp dword [ard_type], 1                 ; 判断是否能被OS使用 cmp dword ptr ds:[], 1
    jne .2                                   ; 直接continue，不参与计算
    mov eax, [base_addr_low]
    add eax, [length_low]
    cmp eax, [mem_size]

    jb .2
    mov [mem_size], eax
    
.2:
    loop .loop
    
    call display_return
    
    push ram_size_prefix
    call display_string
    add esp, 4
    
    push dword [mem_size]
    call display_int
    add esp, 4
    
    pop ecx
    pop edi
    pop esi
    ret
    
%include "lib.inc"
    
seg_code32_len equ $-LABEL_SEG_CODE32