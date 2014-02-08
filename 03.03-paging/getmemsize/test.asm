; 获取内存信息的最基本代码

org 0x7c00
jmp LABEL_BEGIN                 ; 直接跳转到开始处

LABEL_DATA:
_mem_chk_result: dd 0
_mem_chk_buffer: times 128 db 0

data_len equ $-LABEL_DATA

LABEL_BEGIN:
    mov ax, 0xb800
    mov gs, ax
    mov edi, (80*0+0)*2
    mov ah, 0x0c
    mov al, 'S'
    mov [gs:edi], ax
    
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x0100
    
    mov ebx, 0
    mov di, _mem_chk_buffer
.loop:    
    mov eax, 0xe820
    mov ecx, 20
    mov edx, 0x534d4150
    int 0x15
    jc LABEL_MEM_CHK_FAILED         ; 有进位，表示出错了
    add di, 20
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
    
times 510-($-$$) db 0
dw 0xaa55

; nasm -f bin test.asm -o test.img