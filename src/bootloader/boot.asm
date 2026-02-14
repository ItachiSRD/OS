; =========================================================================
; A Minimal Operating System Boot Sector that prints "Hello World"
; =========================================================================

org 0x7C00
bits 16

; --- Assembly Time Directives ---

; A macro is a simple text-replacement tool used by the assembler.
; Here, we're defining 'ENDL' to be a shortcut for the two bytes that
; create a new line on the screen: Carriage Return (0x0D) and Line Feed (0x0A).
%define ENDL 0x0D, 0x0A

;
; FAT12 header
; 
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'NANOBYTE OS'        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes

; --- Run Time Code ---

; Execution starts here at 0x7C00.
start:
    ; It's good practice to jump over any functions or data to the main
    ; part of your program. This keeps the layout clean.
    jmp main


; -------------------------------------------------------------------------
; FUNCTION: puts (Print String)
; -------------------------------------------------------------------------
; Prints a null-terminated string to the screen using a BIOS interrupt.
; Expects: The DS:SI register pair to point to the start of the string.
puts:
    ; A function should not change the state of the CPU unexpectedly.
    ; We save the registers we are about to modify by pushing them onto the stack.
    push si
    push ax

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
    pop ax
    pop si

    ; `ret` returns control back to wherever the function was called from.
    ret


; -------------------------------------------------------------------------
; Main Program Logic
; -------------------------------------------------------------------------
main:
    ; We need to set up our segment registers. The BIOS doesn't guarantee
    ; what they'll be, so we set them to a known value.
    mov ax, 0       ; Can't write 0 directly to a segment register.
    mov ds, ax      ; Set Data Segment to 0. Now DS:SI will point to correct memory.
    mov es, ax      ; Set Extra Segment to 0.

    ; We also need to set up a stack. The stack grows downwards in memory.
    ; We'll place it right at the start of our program's memory space (0x7C00).
    ; Since it grows down, it won't overwrite our code.
    mov ss, ax      ; Set Stack Segment to 0.
    mov sp, 0x7C00  ; Set Stack Pointer.

    ; read something from the floppy disk
    ; BIOS should set DL to drive number
    mov [ebr_drive_number], dl

    mov ax, 1 ; LBA=1, second sector from the disk
    mov cl, 1 ; 1 sector to read
    mov bx, 0x7E00 ; Data should be after the bootloader
    call disk_read

    ; Prepare to call our puts function.
    mov si, msg_hello   ; Load the address of our message into the SI register.
    call puts           ; Call the function to print the string.

    ; Jump to the loaded kernel
    jmp 0x7E00

    cli ; Clear interrupts
    ; Halt the CPU, just like in the simpler version.
    hlt
;
; Error Handlers
;

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h ; wait for key press
    jmp 0FFFFh:0 ; reboot

.halt:
    cli ; Disable interrupts, this way CPU can't get out of "halt" state
    hlt


;
; Disk routines
; 

;
; Converts an LBA Address to a CHS Address
; Parameters:
;      - ax: LBA address
; Returns:
;      - cx [bits 0-5]: sector number
;      - cx [bits 6-15]: cylinder
;      - dh: head

lba_to_chs:
    push ax
    push dx

    xor dx, dx ; dx = 0
    div word [bdb_sectors_per_track] ; ax = LBA / Sectors per Track
                                     ; dx = LBA % Sectors per Track
    
    inc dx ; dx = (LBA % Sectors per Track) + 1 = sector
    mov cx, dx ; cx = sector

    xor dx, dx ; dx = 0
    div word [bdb_heads] ; ax = LBA / Sectors per Track / Heads = cylinder
                         ; dx = (LBA / Sectors per Track) % Heads = head
    mov dh, dl ; dh = head
    mov ch, al ; ch = cylinder (lower 8 bits)

    shl ah, 6
    or cl, ah ; puts upper 2 bits of cylinder in CL

    pop ax
    mov dl, al ; restore dl
    pop ax
    ret

;
; Reads sectors from a disk
; Parameters:
;      - ax: LBA address
;      - cl: number of sectors to read (upto 128)
;      - dl: drive number
;      - es:bx: memory address to store read data
; Returns:
;      - nothing

disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx ; temporary save CL (number of sectors to read)
    call lba_to_chs ; compute CHS
    pop ax ; AL = numbers of sectors to read

    mov ah, 02h
    mov di, 3 ; retry count
    
.retry:
    pusha ; save all registers, we dont know what BIOS will modify
    stc ; set carry flag, some BIOS'es don't set it
    int 13h ; carry flag cleared = success
    jnc .done ; jump if carry not set

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all attempts failed
    jmp floppy_error

.done:
    popa
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret ; restore registers modified 
    
;
; Resets disk controller
; Parameters:
;   dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


; --- Data Section ---

; FIX: The `db` (Define Byte) directive was missing here. This tells NASM
; to store the following bytes in the binary file.
msg_hello:              db 'Hello World!', ENDL, 0
msg_read_failed:        db 'Read from disk failed!', ENDL, 0

; --- Padding and Boot Signature ---

times 510 - ($ - $$) db 0
dw 0xAA55