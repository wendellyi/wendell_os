; 注意这段代码写得很烂，应该按照
; 真正的函数调用的方式去写代码
display_al:
    push ecx
    push edx
    push edi
    mov edi, [display_position]
    
    mov ah, 0x0f                ; 0000b：黑底 1111b：白字
    mov dl, al
    shr al, 4
    mov ecx, 2
.begin
    and al, 0x0f
    cmp al, 9
    ja .1
    add al, '0'
    jmp .2
.1:
    sub al, 0x0a
    add al, 'A'
.2:
    mov [gs:edi], ax
    add edi, 2
    mov al, dl
    loop .begin
    
    mov [display_position], edi
    pop edi
    pop edx
    pop ecx
    ret

display_int:
    mov eax, [esp+4]
    shr eax, 24
    call display_al
    
    mov eax, [esp+4]
    shr eax, 16
    call display_al
    
    mov eax, [esp+4]
    shr eax, 8
    call display_al
    
    mov eax, [esp+4]
    call display_al
    
    mov ah, 0x07                    ; 0000b：黑底 0111b：灰字
    mov al, 'h'
    push edi
    mov edi, [display_position]
    mov [gs:edi], ax
    add edi, 4
    mov [display_position], edi
    pop edi
    ret
    
display_string:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi
    
    mov esi, [ebp+8]
    mov edi, [display_position]
    mov ah, 0x0f
    
.1:
    lodsb
    test al, al
    jz .2
    cmp al, 0x0a
    jnz .3
    push eax
    mov eax, edi
    mov bl, 160
    div bl
    and eax, 0xff
    inc eax
    mov bl, 160
    mul bl
    mov edi, eax
    pop eax
    jmp .1
.3:
    mov [gs:edi], ax
    add edi, 2
    jmp .1
.2:
    mov [display_position], edi
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret
    