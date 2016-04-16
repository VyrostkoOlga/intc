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

		; Получаем адрес обработчика нужного нам прерывания
		mov			ah, 35h
		mov			al, [interrupt_num]
    int     21h
    mov     word ptr old_timer_handler, bx
    mov     word ptr old_timer_handler+2, es

    ; Устанавливаем наш обработчик
		mov			ah, 25h
		mov			al, [interrupt_num]
    ;mov     ax, 251Ch
    mov     dx, offset timer_handler
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
counter			db		"0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh
start   endp

; Новый обработчик для таймера
timer_handler  proc    far
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
    je			write
    sub			si, 2
    jmp l1

current:
    inc			[counter+si]

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

end start
