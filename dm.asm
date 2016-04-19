; Садиться на любой вектор (не садиться повторно int2F) ввод из коммандной строки, на что садиться
; 16 разрядная величина - выводим в 10-чном виде
; Слева сверху - вывод (перехватываем int9 LU папка)
; Комманды: -сброс, -стоп, -поехали, -сняться [перестать считать и отображаться] (alt+клавиша)
; Если комманда наша - сами обрабатываем (бит выставляем) либо пробрасываем дальше
; Сидит на таймере INT8h - для самого вывода на экран
; Пишем прямо в видеопамять
; Сидим на int10h для просмотра изменения режима (low mwmory)
; Всего 5 мест посадки
; Точку рисования можно менять (супер доп)

.model tiny
.386 ; -127 + 128 до 386 условный jmp
     ; Хотим больше
.code
org 100h

s:
	jmp start

	sys_handler_21h dd 0 ; DOS
	sys_handler_2Fh dd 0 ; Мультиплексное
	sys_handler_08h dd 0 ; System timer
	sys_handler_10h dd 0 ; Video Service
	sys_handler_09h dd 0 ; Keyboard
	sys_handler_user dd 0; Пользователь

	counter dw 0
	video_mode db 0
	video_buff_addr dw 0b800h
	rowwidth dw 0
	rowwidth_samall db 0
	curr_page db 0
	offs dw 0
	hiden db 0

	interrupt_num db 0
	s_counter db "0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh
	zero_counter db	"0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh, "0", 01Fh
	hide_counter db	" ", 00Fh, " ", 00Fh, " ", 00Fh, " ", 00Fh, " ", 00Fh
	msgInstalled db 'Handlers are installed already!$'
	mes2 db 'Сtrl + C 1$'
	increment db 1

	;buffer dd ?

	get_current_video: ; Получаем всю информацию о текущем видеорежиме
	                   ; return curr_page, video_mode, rowwidth(40/80)
	    push 0
        pop es
        push ax
	    mov al, byte ptr es:[462h] ; Получили текущую страницу
	    mov curr_page, al
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
        mov video_buff_addr, 0b800h
        cmp video_mode, 7h
        jne _not7
        mov video_buff_addr, 0b000h
        _not7:
	        mov bx, rowwidth
	        add rowwidth, bx ; 40 -> 80; 80 -> 160
	        mov counter, bx
	        mov ax, 4096     ; Если (80x25) * 2 = 4000 Размер страницы
	        cmp rowwidth, 80
	        jne _not40
	        mov ax, 2048     ; Если 40х25 (40x25) * 2 = 2000 Размер страницы

        _not40:
        	mov bl, curr_page
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

	convert:
	    push ax
        push bx
        push dx
        push cx

        mov bx, 10 ; 5 символов и 5 атрибутов
        mov cx, 8
        mov ax, counter
        _conv:
            xor dx, dx
            div bx ; ax=dx:ax/bx
                   ; dx=reminder
            add dl, '0'
            cmp dl, '9'
            jbe _store
            add dl, 'A'-'0'-10
        _store:
            push video_buff_addr
	        pop es
	        ;mov es, offset video_buff_addr
	        push cx
	        pop di
	        push ax
	        mov al, dl
	        stosb
	        pop ax
	        dec cx
	        dec cx
            ;dec si
            ;mov [si], dl
            and ax, ax
            jnz _conv

            pop cx
            pop dx
            pop bx
            pop ax
            ret

	; Новые обработчики
	handler_user:
	    inc counter ; Просто считаем каждый вывод (не связано с текущей реализацией)
	    pusha ; Сохраняем регистры общего назначения
		push es
		push ds
		push cs
		pop  ds

		mov	si, 08h

		find_space: ; Ищем, в какой разряд можно прибавить
            cmp	[s_counter+si], "9"
            jne	counter_inc

            mov	[s_counter+si], "0"
            cmp	si, 0
            je exit_handler_user
            sub	si, 2
            jmp find_space

        counter_inc:
		    mov	bl, [increment]
            add	[s_counter+si], bl

        exit_handler_user:
        	pop ds
        	pop es
        	popa
        	jmp cs:sys_handler_user

	handler_2Fh:
		cmp ax, 0ff01h
		jne _wrong
		cmp cx, 02eeh
		jne _wrong
		add bx, 0101h
		push cs
		pop es
		mov dx, offset handler_2Fh ; Вычислили наш полный адрес es:dx
		iret ; pop ip
		     ; pop cs
		     ; popf
		_wrong:
			jmp cs:sys_handler_2Fh

	handler_08h: ; Сидим на таймере
	    pusha
        push es
        push ds
        push cs
        pop  ds

        write: ; Пишем на экран строку counter
               ; С левого верхнего угла
               ; Перед этим считаем смещение - куда писать
            call get_current_video ; Считаем на каждом тике, так как обр
            call calc_offset       ; int10 не работает нормально :(

            mov bl, [hiden]
            cmp bl, 03h ; Если нас спрятали - больше ничего не пишем
            je _hiden_state_on

            mov	dx, video_buff_addr
            mov	es, dx
            xor	di, di
            add di, offs
            mov	si, offset s_counter

            mov	cx, 5
            rep movsw ; (ES:DI) <- (DS:SI); si+2 di+2

        _exit_handler:
            pop     ds
            pop     es
            popa
            jmp     cs:sys_handler_08h

        _hiden_state_on: ; Для отладки
            ; mov ax,0b800h
            ; mov es,ax
            ; mov byte ptr es:[20], bl
            ; mov byte ptr es:[1+20], 020h
            jmp _exit_handler


	handler_10h proc far ; Ловим переключение видеорежима
	                     ; После стандартного обработчика в low memory смотрим значения
	                     ; Но все равно все не ловится :(
	    pushf
	    call cs: dword ptr sys_handler_10h
	    pushf
	    pusha
        push es

	    call get_current_video
        call calc_offset

        pop es
        popa
        popf
	    iret
	handler_10h endp


	handler_09h: ; Обработка нажатий клавиатуры
	    pusha
        push es
        push si

        mov ax,40h    ;проверяем на нажатие любого Ctrl
        mov es,ax
        mov al,byte ptr es:[17h]
        test al,04h
        jz _stand

        in al, 60h
        cmp al, 2eh     ;Проверяем не нажата ли клавиша 'с' -> ctrl+c
        je handle_reset
        cmp al, 2dh     ; 'x' -> ctrl+x
        je handle_hide
        cmp al, 030h    ; 'b' -> ctrl+b
        je handle_pause
        jne _stand

        handle_reset:   ; Приводим счетчик в начальное состояние
		    mov	cx, 5
		    push cs
		    pop dx
		    mov	ds, dx
		    mov	es, dx
		    mov	di, offset s_counter
		    mov	si, offset zero_counter
		    rep	movsw ; (ES:DI) <- (DS:SI); si+2, di+2
		    ; mov counter, 0
            jmp _vuhid

        handle_pause:   ; Если был остановлен - стартуем
                        ; Если шел, то останавливаем
            mov	dx, cs
		    mov	ds, dx
		    mov	al, [increment]
		    cmp	al, 1

		    je to_stop_state
		    mov	[increment], 1
		    jmp	go_on
            to_stop_state:
                mov	[increment], 0
            go_on:
                jmp _vuhid

        handle_hide:   ; Делаем это место черным
                       ; Ставим флаг hiden, чтобы больше не выводить

            ; Перезапишем это место черным, чтобы сразу все исчезло
		    mov	cx, 5
		    push cs
		    pop dx
		    mov	ds, dx
		    mov	dx, video_buff_addr
		    mov	es, dx
		    xor	di, di
		    add di, offs
		    mov	si, offset hide_counter
		    rep	movsw ; (ES:DI) <- (DS:SI); si+2, di+2

		    mov [hiden], 03h ; Установили флаг
		                     ; Что больше не пишем 03h - сердечко для отладки
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
            call cs:sys_handler_09h
        ttt:
            pop si
            pop es
            popa
            iret

	start:
	    xor ax, ax
		xor dx, dx
		xor bx, bx
		xor cx, cx

	    mov ax, 0ff01h
		mov cx, 02eeh
		mov dx, 0000h
		mov bx, 0101h
		int 2Fh
		cmp bx, 0202h
		je _handlers_installed
		jmp _parse_command

		_handlers_installed:
		    mov	ah, 09h
		    mov	dx, offset msgInstalled
		    int	21h
		    int	20h

		_parse_command:
		    xor ax, ax
		    ; Считываем длину командной строки в cx
		    mov si, 80h
		    lodsb ; (al) <- ds:si; si++
		    xor ah, ah
		    mov cx, ax

		    ; Считываем слово командной строки в bx
		    mov si, 82h
		    lodsw ; (ax) <- ds:si; si + 2
		    mov bx, ax
		    xor ax, ax

		    ; Если длина командной строки < 3 (односимвольная запись числа)
		    cmp cx, 3
		    jl int_0_9

		    sub bl, '0' ; Иначе 2 символа
		    mov al, 10
		    mul bl
		    mov bl, bh

		    int_0_9:
		        xor bh, bh
		        sub bl, '0'
		        add ax, bx

		        mov interrupt_num, al

		        mov	ah, 0Fh
		        int	10h

		        mov	video_mode, al
		        mov	curr_page, bh



		_install_handler:

            ; Системный таймер
            mov ah, 35h
	        mov al, 08h
	        int 21h
	        mov word ptr sys_handler_08h, bx
	        mov word ptr sys_handler_08h + 2, es

	        mov ah, 25h
	        mov al, 08h
	        mov dx, offset handler_08h
	        int 21h

	        ; Клавиатура
	        mov ax, 3509h
            int 21h
            mov word ptr sys_handler_09h, bx
            mov word ptr sys_handler_09h+2, es

            mov ax, 2509h
            mov dx, offset handler_09h
            int 21h

            ; Мультиплексное прерывание
            mov	ah, 35h
		    mov	al, 02Fh
            int 21h
            mov word ptr sys_handler_2Fh, bx
            mov word ptr sys_handler_2Fh+2, es

	        mov	ah, 25h
	        mov	al, 02Fh
            mov dx, offset handler_2Fh
            int 21h

            ; Обработчик работы с видео
	        mov ah, 35h
	        mov al, 10h
	        int 21h
	        mov word ptr sys_handler_10h, bx
	        mov word ptr sys_handler_10h + 2, es

	        mov ah, 25h
	        mov al, 10h
	        mov dx, offset handler_10h
	        int 21h

            ; Обработчик пользователя
	        mov	ah, 35h
		    mov al, [interrupt_num]
            int 21h
            mov word ptr sys_handler_user, bx
            mov word ptr sys_handler_user+2, es

	        mov	ah, 25h
	        mov	al, [interrupt_num]
            mov dx, offset handler_user
            int 21h

            mov dx, offset metka
            int 27h

		 ;    mov ah, 31h  ; Stay resident
			; mov dx, 18h  ; dx - size of resident portion in pargh
			;              ; 1 parhg = 16 bytes ?
			;int 21h


	; _s_end:
	; 	ret
metka:
end s
