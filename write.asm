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
		old_video_handler dd 	?
		increment					db	1
		rowwidth 					dw 	0
		rowwidth_samall 	db 	0
		offs							dw	0
		counter			db		"0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh
		et_counter	db		"0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh
		cl_counter	db		" ", 00Fh, " ", 00Fh, " ", 00Fh, " ", 00Fh, " ", 00Fh
		mes					db		"Already in use", 0dh, 0ah, "$"
		videoseg    dw 		0B800h
		video_mode	db		?
		video_page	db		?

		get_current_video: ; Получаем всю информацию о текущем видеорежиме
		                   ; return curr_page, video_mode, rowwidth(40/80)
		    push 0
	        pop es
	        push ax
		    mov al, byte ptr es:[462h] ; Получили текущую страницу
		    mov video_page, al
		    mov al, byte ptr es:[449h] ; Получили текущий видеорежим
		    mov video_mode, al
		    mov ax, word ptr es:[44ah] ; Получили количество символов в строке
		    mov rowwidth, ax           ; В al по сути
		    pop ax
		    ret

		calc_offset: ; Считаем куда писать для текущего режима и страницы
		             ; Вход: video_mode, curr_page, rowwidth(40/80) ; PS Похоже считается два раза rowwidth
		             ; return: video_buff_addr(адрес сегмента видеопамяти), offs(смещение в видеопамяти)
		    cmp video_mode, 00h
	        je _rowwidth_40
	        cmp video_mode, 01h
	        je _rowwidth_40
	        cmp video_mode, 02h
	        je _rowwidth_80
	        cmp video_mode, 03h
	        je _rowwidth_80
	        cmp video_mode, 07h
	        je _rowwidth_80
	        _next:
	        mov videoseg, 0b800h
	        cmp video_mode, 7h
	        jne _not7
	        mov videoseg, 0b000h
	        _not7:
		        mov bx, rowwidth
		        add rowwidth, bx ; 40 -> 80; 80 -> 160
		        ;mov counter, bx
		        mov ax, 4096     ; Если (80x25) * 2 = 4000 Размер страницы
		        cmp rowwidth, 80
		        jne _not40
		        mov ax, 2048     ; Если 40х25 (40x25) * 2 = 2000 Размер страницы

	        _not40:
	        	mov bl, video_page
	        	mov bh, 0
	        	mul bx       ; dx:ax = bx * ax
	        	mov offs, ax ; Смещение в байтах от начала буфера

		    _exit_calc_offset:
		        ret
	        _rowwidth_40:
	            mov rowwidth, 40
	            jmp _next
	        _rowwidth_80:
	            mov rowwidth, 80
	            jmp _next

video_handler			proc	far
		pushf
		call cs:old_video_handler
		pushf
		pusha
		push es

		call get_current_video
		call calc_offset

		pop es
		popa
		popf
		iret
video_handler			endp

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
		call get_current_video
		call calc_offset
		mov			dx, videoseg
		mov			es, dx
		xor			di, di
		add			di, offs
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
	push es
	push si

	mov ax,40h    ;проверяем на нажатие любого Ctrl
	mov es,ax
	mov al,byte ptr es:[17h]
	test al,04h
	jz _stand

	in al, 60h
	cmp al, 013h     ;Проверяем не нажата ли клавиша 'r' -> ctrl+r
	je handle_reset
	cmp al, 2ch     ; 'z' -> ctrl+z
	je handle_hide
	cmp al, 2eh    ; 'c' -> ctrl+c
	je handle_pause
	jne _stand

handle_reset:   ; Приводим счетчик в начальное состояние
	mov				cx, 5

	mov				dx, cs
	mov				ds, dx
	mov				es, dx
	mov				di, offset counter
	mov				si, offset et_counter
	rep				movsw
	jmp 			_vuhid

handle_pause:
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
	jmp  _vuhid

handle_hide:
	mov				cx, 5

	mov				dx, cs
	mov				ds, dx
	mov				es, dx
	mov				di, offset counter
	mov				si, offset cl_counter
	rep				movsw
	mov				[increment], 0
	jmp _vuhid

	_vuhid:
			; Дальше для меня магия - читать LU/BIOS2.DOC (284 строка)
			; Еще читать тут http://forum.sources.ru/index.php?showtopic=284707
			mov al, 20h     ; сброс КП
			out 20h, al
			in  al, 61h
			or  al, 80h
			out 61h, al     ; сброс прерывания у контроллера клавиатуры
			and al, 7Fh
			out 61h,al
			jmp ttt
	_stand:             ; Если не нажато Ctrl + что-то - вызываем стандартный обработчик
			pushf
			call cs:old_key_handler
	ttt:
			pop si
			pop es
			popa
			iret

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

		mov		ah, 0Fh
		int		10h

		mov		[video_mode], al
		mov		[video_page], bh

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
		mov			al, 10h
    int     21h
    mov     word ptr old_video_handler, bx
    mov     word ptr old_video_handler+2, es

    ; Устанавливаем наш обработчик
		mov			ah, 25h
		mov			al, 10h
    mov     dx, offset video_handler
    int     21h

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
