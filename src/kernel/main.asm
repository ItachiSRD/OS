; =========================================================================
; A Minimal Operating System Boot Sector that prints "Hello World"
; =========================================================================

org 0x0
bits 16

; --- Assembly Time Directives ---

; A macro is a simple text-replacement tool used by the assembler.
; Here, we're defining 'ENDL' to be a shortcut for the two bytes that
; create a new line on the screen: Carriage Return (0x0D) and Line Feed (0x0A).
%define ENDL 0x0D, 0x0A


; --- Run Time Code ---

; Execution starts here at 0x7C00.
start:
    ; It's good practice to jump over any functions or data to the main
    ; part of your program. This keeps the layout clean.
    mov si, msg_hello
    call puts

.halt:
    cli
    hlt


; -------------------------------------------------------------------------
; FUNCTION: puts (Print String)
; -------------------------------------------------------------------------
; Prints a null-terminated string to the screen using a BIOS interrupt.
; Expects: The DS:SI register pair to point to the start of the string.
;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
puts:
    ; save registers we will modify
    push si
    push ax
    push bx

.loop:
    ; `lodsb` is a special instruction that does two things:
    ; 1. It LOADS a Byte from the memory address [DS:SI] into the AL register.
    ; 2. It automatically increments the SI register to point to the next byte.
    lodsb

    ; `or al, al` is a clever, fast way to check if AL is zero.
    ; If AL is zero, the CPU's Zero Flag (ZF) gets set.
    or al, al

    ; `jz` means "Jump if Zero". If the Zero Flag is set (meaning we found
    ; the null terminator `0` at the end of our string), we jump to .done.
    jz .done

    ; Now we use the BIOS to print the character that's in the AL register.
    ; This is done via BIOS interrupt 0x10 (video services).
    mov ah, 0x0E    ; Tell the BIOS we want to use the "teletype" function.
    mov bh, 0       ; Page number 0.
    int 0x10        ; Call the BIOS interrupt.

    ; Jump back to the start of the loop to process the next character.
    jmp .loop

.done:
    ; We're finished, so we restore the original values of the registers
    ; by popping them off the stack in the reverse order we pushed them.
    pop bx
    pop ax
    pop si    
    ret

; --- Data Section ---

; FIX: The `db` (Define Byte) directive was missing here. This tells NASM
; to store the following bytes in the binary file.
msg_hello: db 'Hello world from KERNEL!', ENDL, 0