org 0x0
bits 16


%define ENDL 0x0D, 0x0A


start:
    mov si, msg_hello
    call puts

.halt:
    cli
    hlt

;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
puts:
    push si
    push ax
    push bx

.loop:
    lodsb               ; loads next character in al
    or al, al           ; is char NULL
    jz .done

    mov ah, 0x0E        ; call bios interrupt
    mov bh, 0           ; set page number to 0
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si    
    ret

msg_hello: db 'Hello world from KERNEL!', ENDL, 0
