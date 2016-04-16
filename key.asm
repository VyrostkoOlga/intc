.model tiny
.code
.186
org 100h

ESCAPE_CODE    EQU   1Bh
SPACE_CODE     EQU   20h
CTRL_STATE     EQU   08h

start   proc    near
    ; Устанавливаем обработчик клавиатурного прерывания
    mov     ax, 3509h
    int     21h
    mov     word ptr old_key_handler, bx
    mov     word ptr old_key_handler+2, es

    mov     ax, 2509h
    mov     dx, offset key_handler
    int     21h

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

    mov			dx, 0B800h
    mov			es, dx
    xor			di, di

    mov     dx, 0h
    mov     ds, dx
    mov     al, ds:0417h
    stosb

    pop     ds
    pop     es
    popa
    jmp     cs:old_key_handler

key_handler endp

end start
