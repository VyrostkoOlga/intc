.model tiny
.code
.186
org 100h

ESCAPE_CODE    EQU   1Bh
SPACE_CODE     EQU   20h
ALT_STATE      EQU   08h

start   proc    near
    ; Устанавливаем обработчик клавиатурного прерывания
    mov     ax, 3509h
    int     21h
    mov     word ptr old_key_handler, bx
    mov     word ptr old_key_handler+2, es

    mov     ax, 2509h
    mov     dx, offset key_handler
    int     21h

;l1:
    ;call key_handler
    ;cmp  bx, 0FFh
    ;jne l1

    ret

old_key_handler dd  ?
start   endp

; Новый клавиатурный обработчик
key_handler  proc    far
    pusha
    push    es
    push    ds
    push    cs
    pop     ds

    mov     dx, 0040h
    mov     ds, dx

    mov     al,byte ptr ds:0017h ; считать байт состояния клавиатуры,
    test    al,04h                      ; если не нажат Ctrl,
    jz      not_our_key

    mov     dx, cs
    mov     ds, dx

    mov			dx, 0B800h
    mov			es, dx
    xor     di, di

    in       al, 60h
    cmp      al, 93h
    je       handle_reset
    cmp      al, 0ACh
    je       handle_quit
    cmp      al, 0AEh
    je       handle_stop
    jne      not_our_key

handle_reset:
    mov     ah, 01Fh
    stosw
    jmp not_our_key

handle_stop:
    mov     ah, 01Eh
    stosw
    jmp  not_our_key

handle_quit:
    mov     ah, 01Fh
    stosw
    jmp  not_our_key

not_our_key:
    pop     ds
    pop     es
    popa
    jmp     cs:old_key_handler
    ret

key_handler endp

end start
