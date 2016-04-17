.model tiny
.code
org 100h

start:
    jmp main

main:
    mov   ah, 00h
    mov   al, 00h
    int   10h

    mov   ah, 05h
    mov   al, 01h
    int   10h
    ret
end start
