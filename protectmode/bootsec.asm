INITSEG equ 0x9000
INIT_SEC_COUNT equ 4

org 07c00h
mov ax, cs
mov ds, ax
mov es, ax
call print_msg
call read_code
jmp INITSEG:0

read_code:
    mov ax, INITSEG
    mov es, ax
    mov bx, 0x0000
    mov cx, 0x0002  ; 内容存放在2号扇区
    mov dx, 0x0000
    mov ax, 0x0200+INIT_SEC_COUNT ; ah=0x02 al=0x01
    int 0x13
    ret
    
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
    db 'now we in real mode, then enter protect mode ...'
MSGSEG_END:

times 510-($-$$) db 0
dw 0xaa55
