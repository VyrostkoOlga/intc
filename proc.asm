write			proc		near
    ; Сохраняем контекст
    pusha
    push	ds
    push 	es

    ; будем копировать в видеопамять, левый верхний угол
    push	VIDEO_START
    pop		es
    xor		di, di

    push	cs
    pop		ds
    mov		si, offset counter

    mov		cx, 5
    rep		movsw

    ; Возвращаем контекст
    pop		es
    pop		ds
    popa
    ret
write	  endp

inc_counter		proc	near
    ; Сохраняем контекст
    pusha
    push	ds
    push 	es

    mov			si, 08h
l1:
    mov			al, counter[si]
    cmp			al, MAX_NUM
    jne			current

    mov			di, offset counter
    add			di, si
    mov			al, "0"
    stosb
    cmp			si, 0
    je			finish
    sub			si, 2
    jmp l1

current:
    inc			al
    mov			di, offset counter
    add			di, si
    stosb

finish:
    ; Возвращаем контекст
    pop		es
    pop		ds
    popa
    ret
inc_counter		endp
