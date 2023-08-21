org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

; FAT12 header

jmp short start
nop

bdb_oem:					 db 'MSWIN4.1'			; 8 bytes
bdb_bytes_per_sector:		 dw 512
bdb_sectors_per_cluster:	 db 1
bdb_reserved_sectors:		 dw 1
bdb_fat_count:				 db 2
bdb_dir_entries_count:		 dw 0E0h
bdb_total_sectors:			 dw 2880				; 1.44MB
bdb_media_descriptor_type:	 db 0F0h				; F0 = 3.5" floppy disk
bdb_sectors_per_fat:		 dw 9
bdb_sectors_per_track:		 dw 18
bdb_heads:					 dw 2
bdb_hidden_sectors:			 dd 0
bdb_large_sector_count:		 dd 0

; Extended boot record

ebr_drive_number:			 db 0 					; 0x00 Floppy, 0x80 HDD
							 db 0 					; Reserved
ebr_signature:				 db 29h
ebr_volume_id:				 db 92h, 29h, 27h, 12h	; Serial number
ebr_volume_label:			 db 'NIKKIOSV1.0'
ebr_system_id:				 db 'FAT12   '

;
; CODE GOES HERE
;

start:
	jmp main

; Prints a string to the screen
; Parameters:
;	ds:si points to string

puts:
	; Save registers that will be modified
	push si
	push ax

.loop:
	lodsb			; Loads next character in al
	or al, al		; Verify if next char is null
	jz .done

	mov ah, 0x0e	; Call BIOS interrupt
	mov bh, 0
	int 0x10
	
	jmp .loop

.done:
	pop ax
	pop si
	ret

main:

    ; setup data segments
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00

	; floppy test
	; set DL to drive number

	mov [ebr_drive_number], dl

	mov ax, 1 							; LBA=1, second sector
	mov cl, 1 							; 1 sector to read
	mov bx, 0x7E00 						; data after bootloader
	call disk_read
	
    ; print message
    mov si, msg_hello
    call puts

	cli
    hlt

; Error Handles

floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h								 ; wait for keypress
	jmp 0FFFFh:0 						 ; jump to beginning of BIOS, reboot

.halt:
    cli
    hlt

; Disk routines

; Conversion LBA -> CHS
; Parameters:
;	ax: LBA address
; Returns:
;	- cx [bits 0-5]: sector number
;	- cx [bits 6-15]: cylinder
;	- dh: head

lba_to_chs:

	push ax
	push dx

	xor dx, dx							; dx = 0
	div word [bdb_sectors_per_track]	; ax = LBA / SectorsPerTrack
										; dx = LBA % SectorsPerTrack
	inc dx								; dx = LBA % SectorsPerTrack + 1 = sector
	mov cx, dx							; cx = sector

	xor dx, dx
	div word [bdb_heads]				; ax = (LBA / SectorsPerTrack) / Heads = cylinder
										; dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh, dl							; dh = head
	mov ch, al							; ch = cylinder (lower 8 bits)
	shl ah, 6
	or cl, ah							; put upper 2 bits of cylinder in CL

	pop ax
	mov dl, al							; restore DL
	pop ax

	ret

; Read sectors from disk
; Parameters:
;	- ax: LBA address
;	- cl: number of sectors to read (MAX 128)
;	- dl: drive number
;	- es:bx: memory address where to store read data

disk_read:
	
	push ax
	push bx
	push cx								; save registers that are modified
	push dx
	push di

	push cx								; temporarily save CL
	call lba_to_chs
	pop ax

	mov ah, 02h
	mov di, 3							; number of retries
	
.retry:
	pusha
	stc
	int 13h
	jnc .done

	; read failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	; Disk read fail
	jmp floppy_error

.done:
	popa

	pop di
	pop dx
	pop cx								 ; restore modified registers
	pop bx
	pop ax

	ret

; Disk controller reset

disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret
	
msg_hello: db 'Hello, World!', ENDL, 0
msg_read_failed: db 'Failed to read from disk.', ENDL, 0


times 510-($-$$) db 0
dw 0AA55h
