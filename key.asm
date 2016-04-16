.model tiny
.code
.386

org 100h

start:
  jmp main

CTRL_STATE    db    08h

key_handler     proc      near
    ; Сохраняем состояние
    pusha
    push  ax
    push  dx
    push  ds

    push  0h
    pop   ds
    mov   al, byte ptr ds:0417h           ; байт состояние клавиатуры
    cmp   al, 08h
    jne   finish

    push  0B800h
    pop   es
    xor   di, di

    mov   ax, 0FF1FH
    stosw

finish:
    ; Возвращаем исходное состояние
    pop     ds
    pop     dx
    pop     ax
    popa
    call    word ptr cs:old_handler
    iret

    mes           db    "Hello!$", 0dh, 0ah
    old_handler   dw    0
key_handler endp

main:
  ; Сохраняем адрес старого обработчика
  mov   ax, 3509h
  int   21h
  mov   word ptr old_handler, bx
  mov   word ptr old_handler+2, es

  ; Устанавливаем свой обработчик
  mov   ax, 2509h
  mov   dx, offset key_handler
  int   21h

  mov   dx, offset main
  int   27h

  ;push   ds
  ;push   0h
  ;pop    ds
;l1:
  ;mov   al, byte ptr ds:0417h           ; байт состояние клавиатуры
  ;cmp   al, 08h
  ;je    f1
  ;jmp   l1

;f1:
  ;pop   ds
  ;ret
end start
