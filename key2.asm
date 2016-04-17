.model tiny
.code
.186
org 100h

start:
  jmp main

  old_int09h    dd      ?

main:
; сохранить адрес предыдущего обработчика прерывания 09h
      mov     ax,3509h
      int        21h
      mov     word ptr old_int09h,bx
      mov     word ptr old_int09h+2,es
; установить наш обработчик
      mov     ax,2509h
      mov     dx,offset int09h_handler
      int     21h
      ret

int09h_handler  proc    far
      pusha
      push    es      ; сохранить ВСЕ регистры
      push    ds
      push    cs
      pop     ds

      push    0040h
      pop     ds
      mov     di,word ptr ds:001Ah    ; адрес головы буфера клавиатуры
      cmp     di,word ptr ds:001Ch    ; если он равен адресу хвоста,
      je      exit_handler            ; буфер пуст, и нам делать нечего

      mov     ah, 01Fh
      mov     al, "1"
      mov     dx, 0B800h
      mov     es, dx
      inc di
      stosw

      mov     ax,word ptr [di]        ; иначе: считать символ
      cmp     ah,byte ptr 'z'
      jne     exit_handler

      mov     ah, 01Fh
      mov     al, "1"
      mov     dx, 0B800h
      mov     es, dx
      inc     di
      stosw

      mov     al,byte ptr ds:0017h ; считать байт состояния клавиатуры,
      test    al,04h                      ; если не нажат Ctrl,
      jz      exit_handler             ; выйти,

      mov     ah, 01Fh
      mov     dx, 0B800h
      mov     es, dx
      inc     di
      stosw

exit_handler:
      pop     ds              ; восстановить все регистры
      pop     es
      popa
      jmp     cs:old_int09h ; передать управление предыдущему обработчику
int09h_handler endp

end start
