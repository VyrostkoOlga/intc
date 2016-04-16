; чтение числа с командной строки

.model tiny
.code

org 100h

start:
  jmp main

main:
  call  readInterrupt
  ret

readInterrupt   proc  near
    ; Считываем длину командной строки
    mov   si, 80h
    lodsb
    xor   ah, ah
    mov   cx, ax

    ; Считываем слово командной строки
    mov   si, 82h
    lodsw
    mov   bx, ax
    xor   ax, ax

    ; Если длина командной строки < 3 ( односимвольная запись числа )
    cmp   cx, 3
    jl    b1

    sub   bl, 30h
    mov   al, 10h
    mul   bl
    mov    bl, bh

  b1:
    xor    bh, bh
    sub    bl, 30h
    add   ax, bx

    mov   interrupt_num, ax
    ret
readInterrupt endp

interrupt_num   dw    0
end start
