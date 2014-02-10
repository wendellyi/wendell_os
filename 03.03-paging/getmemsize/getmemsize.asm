jmp LABEL_BEGIN                 ; 直接跳转到开始处

[SECTION .data]
ALIGN 32
[BITS 32]
LABEL_DATA:
_mem_chk_result: dd 0
;_display_position: dd ((80*6+0)*2)
_mem_size: dd 0
_ard_struct:
    _base_addr_low: dd 0
    _base_addr_hig: dd 0
    _length_low: dd 0
    _length_hig: dd 0
    _ard_type: dd 0
ard_struct_size equ $-_ard_struct
    
_mem_chk_buffer: times 128 db 0

[SECTION .s16]
[BITS 16]
LABEL_BEGIN:
    mov ax, 0xb800
    mov gs, ax
    mov edi, (80*1+0)*2
    mov ah, 0x0c
    mov al, 'S'
    mov [gs:edi], ax
    
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x0100
        
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

    mov ax, 0xb800
    mov gs, ax
    mov edi, (80*10+0)*2
    mov ah, 0x0c
    mov al, 'E'
    mov [gs:edi], ax
    jmp $