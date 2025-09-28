; =========================================================================
; A FAT12 Boot Sector that can read from a floppy disk
; =========================================================================

org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

; -------------------------------------------------------------------------
; FAT12 BIOS Parameter Block (BPB)
; -------------------------------------------------------------------------
; This is no longer just a program; it's also the "table of contents" for
; the disk. An operating system needs this information to understand the
; disk's geometry (size, sectors, etc.).
jmp short start ; Jump over the data block to our code.
nop             ; No operation. Fills one byte for alignment.

; This header must be exactly correct for an OS to read the disk.
bdb_oem:                    db 'MSWIN4.1'           ; OEM Identifier.
bdb_bytes_per_sector:       dw 512                  ; Almost always 512 bytes.
bdb_sectors_per_cluster:    db 1                    ; 1 sector = 1 cluster on a floppy.
bdb_reserved_sectors:       dw 1                    ; The boot sector itself is the only reserved one.
bdb_fat_count:              db 2                    ; Two copies of the File Allocation Table for safety.
bdb_dir_entries_count:      dw 224                  ; Number of files that can be in the root directory.
bdb_total_sectors:          dw 2880                 ; 2880 sectors * 512 bytes/sector = 1.44MB.
bdb_media_descriptor_type:  db 0xF0                 ; 0xF0 indicates a 1.44MB floppy disk.
bdb_sectors_per_fat:        dw 9                    ; Each of the two FATs is 9 sectors long.
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2                    ; A floppy disk has two sides (heads).
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; Extended Boot Record (EBR)
ebr_drive_number:           db 0                    ; Will be filled by the BIOS at boot time.
                            db 0                    ; Reserved.
ebr_signature:              db 0x29                 ; Indicates the next fields are present.
ebr_volume_id:              dd 0x12345678           ; A "unique" serial number for the disk.
ebr_volume_label:           db 'NANOBYTE OS'        ; 11-byte disk name.
ebr_system_id:              db 'FAT12   '           ; 8-byte filesystem identifier.


; --- Start of Executable Code ---
start:
    jmp main    ; Jump over functions to the main program logic.

; --- Functions ---

puts:
    ; Prints a null-terminated string.
    ; Input: DS:SI points to the string.
    push si     ; Save SI (our string pointer) on the stack.
    push ax     ; Save AX (general-purpose register) as we will modify it.
    push bx

.loop:
    lodsb       ; Load byte from [DS:SI] into AL, then increment SI.
    or al, al   ; Check if AL is zero (the null terminator).
    jz .done    ; If it is, jump to the end.
    mov ah, 0x0E; Tell BIOS we want to use the "teletype" print function.
    mov bh, 0   ; Page number 0.
    int 0x10    ; Call BIOS video interrupt to print the character in AL.
    jmp .loop
.done:
    pop bx
    pop ax      ; Restore the original value of AX from the stack.
    pop si      ; Restore the original value of SI from the stack.
    ret         ; Return from the function.


; --- Main Program Logic ---
main:
    ; Setup segment registers and stack (critical initialization).
    mov ax, 0       ; AX = 0.
    mov ds, ax      ; DS (Data Segment) = 0.
    mov es, ax      ; ES (Extra Segment) = 0.
    mov ss, ax      ; SS (Stack Segment) = 0.
    mov sp, 0x7C00  ; SP (Stack Pointer) starts at 0x7C00 and grows downward.

    ; The BIOS helpfully tells us which drive we booted from by placing its
    ; number in the DL register (0x00 for floppy, 0x80 for first HDD).
    ; We save this value for later use in our disk read functions.
    mov [ebr_drive_number], dl

    ; --- Load the second sector of the disk into memory ---
    mov ax, 1           ; AX = LBA address 1 (the second sector, since LBA is 0-indexed).
    mov cl, 1           ; CL = Number of sectors to read (just 1).
    mov bx, 0x7E00      ; ES:BX = Destination address. We load it right after our
                        ; 512-byte boot sector (0x7C00 + 512 = 0x7E00).
    call disk_read      ; Call our function to perform the read.

    ; Print a success message.
    mov si, msg_hello   ; SI = Address of our hello message.
    call puts           ; Call the print function.

    cli
    hlt                 ; Halt the CPU.

; --- Error Handling ---
floppy_error:
    mov si, msg_read_failed ; SI = Address of the error message.
    call puts
    jmp wait_key_and_reboot
    ; Fall through to the reboot routine.

wait_key_and_reboot:
    mov ah, 0           ; AH = 0 tells BIOS int 16h to "wait for keystroke".
    int 16h            ; Call BIOS keyboard interrupt.
    jmp 0xFFFF:0        ; This is a well-known address that causes a system reboot.

.halt:
    cli
    hlt
; --- Disk Routines ---

; Converts a Linear Block Address (LBA) to Cylinder, Head, Sector (CHS) format.
; Old BIOS functions require CHS, but LBA is much easier to work with.
; Input: AX = LBA address.
lba_to_chs:
    push ax
    push dx             ; Save DX, as the DIV instruction will overwrite it.
    xor dx, dx          ; Clear DX to 0. The DIV instruction uses DX:AX as a 32-bit dividend.
    div word [bdb_sectors_per_track] ; Divide LBA by sectors_per_track.
                        ; AX = LBA / 18 (Quotient)
                        ; DX = LBA % 18 (Remainder)
    inc dx              ; Remainder + 1 = Sector number (CHS is 1-based).
    mov cx, dx          ; CX = Sector number.

    xor dx, dx          ; Clear DX again for the next division.
    div word [bdb_heads]; Divide the previous quotient by number of heads (2).
                        ; AX = Quotient / 2 = Cylinder number
                        ; DX = Quotient % 2 = Head number
    mov dh, dl          ; DH = Head number.
    mov ch, al          ; CH = Cylinder number (lower 8 bits).

    ; The cylinder number can be up to 10 bits, so the top 2 bits are stored
    ; in the top 2 bits of the sector field (in CL). This is a quirk of the CHS format.
    shl ah, 6           ; Shift the upper bits of the cylinder into position.
    or cl, ah           ; Combine them with the sector number in CL.

    pop ax
    mov dl, al
    pop ax              ; Restore the original value of DX.
    ret

; Reads sectors from a disk using BIOS interrupt 13h.
; Input: AX = LBA address.
;        CL = Number of sectors to read.
;        ES:BX = Destination memory address.
; Uses:  DL = Drive number (which we saved earlier).
disk_read:
    push ax             ; Save registers we will modify.
    push bx
    push cx
    push dx
    push di

    push cx
    call lba_to_chs     ; Convert LBA in AX to CHS format (result in CX, DH).
    pop ax

    mov ah, 0x02        ; AH = 0x02 is the BIOS "Read Sectors" function.
    mov di, 3           ; DI = Retry count. We'll try 3 times before giving up.
.retry:
    pusha               ; Save all general-purpose registers (AX, CX, DX, BX, SP, BP, SI, DI).
    stc                 ; Set Carry Flag. Some BIOSes require this.
    int 0x13            ; Call the BIOS disk interrupt!
    jnc .done_ok        ; If Carry Flag is NOT set, the read was a success. Jump.

    ; --- Read failed, so let's retry ---
    popa                ; Restore registers.
    call disk_reset     ; Try resetting the disk controller.
    dec di              ; Decrement retry counter.
    test di, di         ; Check if DI is zero.
    jnz .retry          ; If not zero, jump back and try again.

.fail:
    jmp floppy_error

.done_ok:
    popa                ; Restore all registers.
    pop di              ; Restore original register values from the stack.
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Resets the disk controller.
disk_reset:
    pusha
    mov ah, 0           ; AH = 0 is the "Reset Disk" function for int 13h.
    stc
    int 0x13
    jc floppy_error     ; If reset fails (carry flag set), something is very wrong.
    popa
    ret

; --- Data Section ---
msg_hello:          db 'Successfully read from disk!', ENDL, 0
msg_read_failed:    db 'Read from disk failed!', ENDL, 0

; --- Padding and Boot Signature ---
times 510 - ($ - $$) db 0
dw 0xAA55
