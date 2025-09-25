; =========================================================================
; A Minimal "Hello World" Operating System Boot Sector
; =========================================================================

; --- Stage 1: Assembly Time (Building the .bin file) ---
; Everything in this file is first read by the NASM assembler. NASM's job
; is to translate this human-readable text into a 512-byte binary file
; containing pure machine code and data. It processes two kinds of statements:
; 1. DIRECTIVES: Commands for the assembler itself (e.g., `org`, `dw`).
; 2. INSTRUCTIONS: Commands that will be run by the CPU later (e.g., `hlt`, `jmp`).

; -------------------------------------------------------------------------
; DIRECTIVE: `org` (Set Origin)
; -------------------------------------------------------------------------
; This tells NASM where the program will be located in memory at RUN TIME.
; The BIOS standard is to load the first boot sector from a disk into
; the computer's RAM at the physical memory address 0x7C00. This directive
; ensures that if we had labels or variables, their addresses would be
; calculated correctly relative to this starting point.
org 0x7C00

; -------------------------------------------------------------------------
; DIRECTIVE: `bits` (Set CPU Mode)
; -------------------------------------------------------------------------
; This tells NASM to generate machine code for a 16-bit processor.
; For backward compatibility, all x86 CPUs start in a 16-bit "real mode,"
; so our initial code must also be 16-bit.
bits 16


; --- Stage 2: Run Time (CPU Execution) ---
; The following code is what the CPU actually runs AFTER the BIOS has:
;   1. Loaded the entire 512-byte file into RAM at 0x7C00.
;   2. ALREADY checked for and verified the 0xAA55 signature at the end.

; The 'main' label is just for our convenience; execution starts at 0x7C00.
main:
    ; -------------------------------------------------------------------------
    ; INSTRUCTION: `hlt` (Halt)
    ; -------------------------------------------------------------------------
    ; This tells the CPU to STOP executing instructions and enter a low-power
    ; idle state. In our simple OS, this is the end of the program. The system
    ; has successfully booted and will now do nothing.
    hlt

; -------------------------------------------------------------------------
; Failsafe Infinite Loop
; -------------------------------------------------------------------------
; The code below `hlt` will NOT run under normal circumstances.
.halt:
    ; INSTRUCTION: `jmp` (Jump)
    ; A `hlt` command can be "woken up" by a hardware interrupt (like a
    ; keyboard press or system timer). If this happens, the CPU would try to
    ; execute the instruction immediately following `hlt`.
    ; This `jmp` command creates an infinite loop, safely trapping the CPU
    ; here. This prevents it from running random data in memory and crashing.
    jmp .halt


; --- Stage 1 Continued: Data Padding and Signature (Assembly Time) ---
; The following lines are DIRECTIVES, not instructions. They are processed
; by NASM to correctly structure the final 512-byte file.

; -------------------------------------------------------------------------
; DIRECTIVE: `times` (Repeat)
; -------------------------------------------------------------------------
; This is a command to NASM. It pads our file with zeros to make it the
; correct size. The calculation `510 - ($ - $$)` means: "fill with zeros
; (`db 0`) until we reach the 510th byte of the file."
;   `$`  = current position
;   `$$` = start position
times 510 - ($ - $$) db 0

; -------------------------------------------------------------------------
; DIRECTIVE: `dw` (Define Word)
; -------------------------------------------------------------------------
; This is the "magic number" the BIOS looks for. This directive tells
; NASM to write a 2-byte word (0xAA55) at the very end of the file
; (bytes 511 and 512). The BIOS verifies this signature *before* it decides
; to run our code. This value is already baked into the `main.bin` file
; long before the CPU ever sees it.
dw 0xAA55