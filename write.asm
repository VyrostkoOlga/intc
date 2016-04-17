.model tiny
.code
.186
org 100h

VIDEO_START	EQU		0B800h
MAX_NUM			EQU		"9"
ESCAPE_CODE EQU 1Bh

start   proc    near
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
		mov   al, 10
		mul   bl
		mov    bl, bh

b1:
		xor    bh, bh
		sub    bl, 30h
		add    ax, bx

		mov   [interrupt_num], al

		; Получаем адрес обработчика прерывания системного таймера
		mov			ax, 351Ch
    int     21h
    mov     word ptr old_timer_handler, bx
    mov     word ptr old_timer_handler+2, es

    ; Устанавливаем наш обработчик прерывания системного таймера
    mov     ax, 251Ch
    mov     dx, offset timer_handler
    int     21h

		; Устанавливаем обработчик клавиатурного прерывания
    mov     ax, 3509h
    int     21h
    mov     word ptr old_key_handler, bx
    mov     word ptr old_key_handler+2, es

    mov     ax, 2509h
    mov     dx, offset key_handler
    int     21h

		; Получаем адрес обработчика нужного нам прерывания
		mov			ah, 35h
		mov			al, [interrupt_num]
    int     21h
    mov     word ptr old_handler, bx
    mov     word ptr old_handler+2, es

    ; Устанавливаем наш обработчик
		mov			ah, 25h
		mov			al, [interrupt_num]
    mov     dx, offset int_handler
    int     21h

    ; check pressed key
;read_key:
    ;mov     ah, 07h          ; 07h = got symbol from console without echo
    ;int     21h

    ;cmp     al, ESCAPE_CODE
    ;je      quit
		;jmp			read_key

;quit:
    ; before exit, reset handlers
    ;mov     ax, 251Ch
    ;mov     dx, word ptr old_timer_handler + 2
    ;mov     ds, dx
    ;mov     dx, word ptr cs:old_timer_handler
    ;int     21h

    ret

interrupt_num   db    0
old_timer_handler dd  ?
old_handler 			dd  ?
old_key_handler 	dd  ?
counter			db		"0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh
et_counter	db		"0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh
start   endp

int_handler			proc		far
		; save all registers
		pusha
		push    es
		push    ds
		push    cs
		pop     ds

		mov			si, 08h
l1:
    cmp			[counter+si], MAX_NUM
    jne			current

    mov			[counter+si], "0"
    cmp			si, 0
    je			finish
    sub			si, 2
    jmp l1

current:
    inc			[counter+si]

finish:
		pop     ds
		pop     es
		popa
		jmp     cs:old_handler

int_handler			endp

; Новый обработчик для таймера
timer_handler  proc    far
    ; save all registers
    pusha
    push    es
    push    ds
    push    cs
    pop     ds

write:
		mov			dx, VIDEO_START
		mov			es, dx
		xor			di, di
		mov			si, offset counter
		mov			cx, 5
		rep movsw

exit_handler:
    pop     ds
    pop     es
    popa
    jmp     cs:old_timer_handler

timer_handler endp

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

    in       al, 60h
    cmp      al, 93h
    je       handle_reset
    cmp      al, 0ACh
    je       handle_quit
    cmp      al, 0AEh
    je       handle_stop
    jne      not_our_key

handle_reset:
		mov				cx, 5

		mov				dx, cs
		mov				ds, dx
		mov				es, dx
		mov				di, offset counter
		mov				si, offset et_counter
		rep				movsw
    jmp not_our_key

handle_stop:
    ;mov     ah, 01Eh
    ;stosw
    jmp  not_our_key

handle_quit:
    ;mov     ah, 01Fh
    ;stosw
    jmp  not_our_key

not_our_key:
    pop     ds
    pop     es
    popa
    jmp     cs:old_key_handler
    ret

key_handler endp

end start
