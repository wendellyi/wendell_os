; 文件 bootsec.asm
; 现将自身移到段0x9000的地方，然后读取setup模块。

SETUPLEN equ 4        ; setup模块占用的扇区数量
BOOTSEG equ 0x07c0    ; bootsec模块起始段
INITSEG equ 0x9000    ; bootsec的新位置
SETUPSEG equ 0x9020   ; setup模块从这里开始执行
SYSSEG equ 0x1000     ; system模块开始执行
;ENDSEG = SYSSEG+SYSSIZE ; 停止加载的地方

mov ax, BOOTSEG
mov ds, ax          ; 0x07c0
mov ax, INITSEG
mov es, ax          ; 0x9000
mov cx, 256         ; 每次移动一个字，刚好512个字节
sub si, si          ; 源地址 ds:si = 0x07c0:0x0000
sub di, di          ; 目的地址 es:di = 0x9000:0x0000
rep
movsw

jmp INITSEG:go      ; 远转移

go:
    mov ax, cs      ; cs = 0x9000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xff00  ; 将栈初始化为0x9000:0xff00    

load_setup:
    mov dx, 0x0000              ; 驱动器0，磁头0
    mov cx, 0x0002              ; ch起始扇区2
    mov bx, 0x0200              ; es:bx 缓冲区的起始地址
    mov ax, 0x0200+SETUPLEN     ; ah操作类型，读取磁盘内容到内存
                                 ; al表示要读取的扇区数量
    int 0x13
    ; 错误码在ah中
    jnc ok_load_setup
    mov dx, 0x0000
    mov ax, 0x0000
    int 0x13
    jmp load_setup
    
ok_load_setup:
    mov dl, 0x00
    mov ax, 0x0800
    int 0x13
    mov ch, 0x00
    seg cs
    mov sectors, cx
    mov ax, INITSEG
    mov es, ax
    
    mov ah, 0x03
    xor bh, bh
    int 0x10
    
    mov cx, 24
    mov bx, 0x0007
    mov bp, msg1
    mov ax, 0x1301
    int 0x10
    
    mov ax, SYSSEG
    mov es, ax
    call read_it
    call kill_motor
    
    seg cs
    mov ax, root_dev
    cmp ax, 0
    jne root_defined
    
    seg cs
    mov bx, sectors
    mov ax, 0x0208
    cmp bx, 15
    je root_defined
    mov ax, 0x021c
    cmp bx, 18
    je root_defined
undef_root:
    jmp undef_root
    
root_defined:
    seg cs
    mov root_dev, ax
    
    jmp SETUPSEG:0
    
    call print_msg
    jmp $           ; 死循环
    
print_msg:
    mov ax, boot_msg_start
    mov bp, ax
    mov cx, boot_msg_end - boot_msg_start
    mov ax, 0x1301
    mov bx, 0x0c
    mov dl, 0
    int 0x10
    ret
    
boot_msg_start:
    db "Hello World"
boot_msg_end:

times 510-($-$$) db 0
dw 0xaa55
