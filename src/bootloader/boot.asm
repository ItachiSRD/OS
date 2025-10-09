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
    ; setup data segments
    mov ax, 0           ; can't set ds/es directly
    mov ds, ax
    mov es, ax
    
    ; setup stack
    mov ss, ax
    mov sp, 0x7C00              ; stack grows downwards from where we are loaded in memory

    ; some BIOSes might start us at 07C0:0000 instead of 0000:7C00, make sure we are in the
    ; expected location
    push es
    push word .after
    retf

.after:

    ; read something from floppy disk
    ; BIOS should set DL to drive number
    mov [ebr_drive_number], dl

    ; show loading message
    mov si, msg_loading
    call puts

    ; read drive parameters (sectors per track and head count),
    ; instead of relying on data on formatted disk
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F                        ; remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx     ; sector count

    inc dh
    mov [bdb_heads], dh                 ; head count

    ; compute LBA of root directory = reserved + fats * sectors_per_fat
    ; note: this section can be hardcoded
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx                              ; ax = (fats * sectors_per_fat)
    add ax, [bdb_reserved_sectors]      ; ax = LBA of root directory
    push ax

    ; compute size of root directory = (32 * number_of_entries) / bytes_per_sector
    mov ax, [bdb_dir_entries_count]
    shl ax, 5                           ; ax *= 32
    xor dx, dx                          ; dx = 0
    div word [bdb_bytes_per_sector]     ; number of sectors we need to read

    test dx, dx                         ; if dx != 0, add 1
    jz .root_dir_after
    inc ax                              ; division remainder != 0, add 1
                                        ; this means we have a sector only partially filled with entries

.root_dir_after:

    ; read root directory
    mov cl, al                          ; cl = number of sectors to read = size of root directory
    pop ax                              ; ax = LBA of root directory
    mov dl, [ebr_drive_number]          ; dl = drive number (we saved it previously)
    mov bx, buffer                      ; es:bx = buffer
    call disk_read

    ; search for kernel.bin
    xor bx, bx
    mov di, buffer

.search_kernel:
    mov si, file_kernel_bin
    mov cx, 11                          ; compare up to 11 characters
    push di
    repe cmpsb
    pop di
    je .found_kernel

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_kernel

    ; kernel not found
    jmp kernel_not_found_error

.found_kernel:

    ; di should have the address to the entry
    mov ax, [di + 26]                   ; first logical cluster field (offset 26)
    mov [kernel_cluster], ax

    ; load FAT from disk into memory
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ; read kernel and process FAT chain
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
    
    ; Read next cluster
    mov ax, [kernel_cluster]
    
    ; not nice :( hardcoded value
    add ax, 31                          ; first cluster = (kernel_cluster - 2) * sectors_per_cluster + start_sector
                                        ; start sector = reserved + fats + root directory size = 1 + 18 + 134 = 33
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    ; compute location of next cluster
    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx                              ; ax = index of entry in FAT, dx = cluster mod 2

    mov si, buffer
    add si, ax
    mov ax, [ds:si]                     ; read entry from FAT table at index ax

    or dx, dx
    jz .even

.odd:
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0x0FF8                      ; end of chain
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    
    ; jump to our kernel
    mov dl, [ebr_drive_number]          ; boot device in dl

    mov ax, KERNEL_LOAD_SEGMENT         ; set segment registers
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot             ; should never happen

    cli                                 ; disable interrupts, this way CPU can't get out of "halt" state
    hlt


; --- Error Handling ---
floppy_error:
    mov si, msg_read_failed ; SI = Address of the error message.
    call puts
    jmp wait_key_and_reboot
    ; Fall through to the reboot routine.

kernel_not_found_error:
    mov si, msg_kernel_not_found
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0           ; AH = 0 tells BIOS int 16h to "wait for keystroke".
    int 16h            ; Call BIOS keyboard interrupt.
    jmp 0xFFFF:0        ; This is a well-known address that causes a system reboot.

.halt:
    cli
    hlt


; --- Functions ---
;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
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
msg_loading:            db 'Loading...', ENDL, 0
msg_read_failed:        db 'Read from disk failed!', ENDL, 0
msg_kernel_not_found:   db 'KERNEL.BIN file not found!', ENDL, 0
file_kernel_bin:        db 'KERNEL  BIN'
kernel_cluster:         dw 0

KERNEL_LOAD_SEGMENT     equ 0x2000
KERNEL_LOAD_OFFSET      equ 0

; --- Padding and Boot Signature ---
times 510 - ($ - $$) db 0
dw 0xAA55

buffer: