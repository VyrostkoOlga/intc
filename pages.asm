.model tiny
.code
org 100h

start:
    jmp main

main:
    mov   ah, 00h
    mov   al, 03h
    int   10h

    mov   ah, 02h
    mov   al, 01h
    int   10h
    ret
end start
