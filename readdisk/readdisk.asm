MSGSEG equ 0x9020       ; 消息读入的内存段
MAXMSGLEN equ 128       ; 消息的最大长度

org 07c00h
mov ax, cs
mov ds, ax
mov es, ax
call read_msg
call print_msg
hlt
;jmp $			; 死循环

read_msg:
    mov ax, MSGSEG
    mov es, ax
    mov bx, 0x0000
    mov cx, 0x0002  ; 内容存放在2号扇区
    mov dx, 0x0000
    mov ax, 0x0201  ; ah=0x02 al=0x01
    int 0x13
    ret

print_msg:
    mov ax, MSGSEG  ; es需要被重新初始化
    mov es, ax
	mov bp, 0x0000
	mov cx, MAXMSGLEN
	mov ax, 0x1301
	mov bx, 0x000c
	;mov dl, 0
	int 0x10
	ret

times 510-($-$$) db 0
dw 0xaa55
