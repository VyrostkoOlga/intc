.model tiny
.code
.186
org 100h

VIDEO_START	EQU		0B800h
MAX_NUM			EQU		"9"

start:
		jmp main

		interrupt_num   db    0
		old_timer_handler dd  ?
		old_handler 			dd  ?
		old_key_handler 	dd  ?
		old_pres_handler  dd 	?
		increment					db	1
		counter			db		"0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh
		et_counter	db		"0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh
		cl_counter	db		" ", 00Fh, " ", 00Fh, " ", 00Fh, " ", 00Fh, " ", 00Fh
		mes					db		"Already in use", 0dh, 0ah, "$"

presence_handler	proc	far
		cmp ah, 80h
		je finish_presense
		jmp dword ptr cs:[old_pres_handler]

finish_presense:
		mov al, 0ffh
		ret
presence_handler endp

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
		mov			bl, [increment]
    add			[counter+si], bl

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

    mov     al,byte ptr ds:0017h 				; считать байт состояния клавиатуры,
    test    al,04h                      ; если не нажат Ctrl, не наша комбинация
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
		mov				dx, cs
		mov				ds, dx
		xor				ch, ch
		mov				cl, [increment]
		cmp				cl, 1
		je				cur_stop
		mov				[increment], 1
		jmp				cur_finish
cur_stop:
		mov				[increment], 0
cur_finish:
    jmp  not_our_key

handle_quit:
		mov				cx, 5

		mov				dx, cs
		mov				ds, dx
		mov				es, dx
		mov				di, offset counter
		mov				si, offset cl_counter
		rep				movsw
		mov				[increment], 0
    jmp  not_our_key

not_our_key:
		; Здесь нужно убрать символ перед передачей управления дальше
		;mov     dx, 0040h
		;mov     ds, dx
		;mov			di, word ptr ds:001Ah
		;mov			word ptr ds:001Ch,di

    pop     ds
    pop     es
    popa
    jmp     cs:old_key_handler
    ret

key_handler endp

main:
		xor 	ax, ax
		xor 	dx, dx
		xor 	bx, bx
		xor 	cx, cx

		mov 	ah, 80h
		int 	2fh

		cmp 	al, 0ffh
		jne		run

stop:
		mov		ah, 09h
		mov		dx, offset mes
		int		21h
		int		20h

run:
		xor		ax, ax
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
		cli
		mov			ax, 351Ch
    int     21h
    mov     word ptr old_timer_handler, bx
    mov     word ptr old_timer_handler+2, es

    ; Устанавливаем наш обработчик прерывания системного таймера
    mov     ax, 251Ch
    mov     dx, offset timer_handler
    int     21h
		;sti

		; Устанавливаем обработчик клавиатурного прерывания
		;cli
    mov     ax, 3509h
    int     21h
    mov     word ptr old_key_handler, bx
    mov     word ptr old_key_handler+2, es

    mov     ax, 2509h
    mov     dx, offset key_handler
    int     21h
		;sti

		; Устанавливаем обработчик мультиплексного прерывания
		;cli
		mov			ah, 35h
		mov			al, 02Fh
    int     21h
    mov     word ptr old_pres_handler, bx
    mov     word ptr old_pres_handler+2, es

    ; Устанавливаем наш обработчик
		mov			ah, 25h
		mov			al, 02Fh
    mov     dx, offset presence_handler
    int     21h
		;sti

		; Получаем адрес обработчика нужного нам прерывания
		;cli
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
		sti

		mov			dx, offset main
		int			27h

end start
