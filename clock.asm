; a 512 byte bootsector digital clock
;
; 7 segment-chars => each digit only needs 1 byte storage with bits set when segment on
;  _    1
; |_|  243
; |_|  576
;
; nasm -f bin clock.asm 
; qemu-system-i386 -fda clock -boot a



[bits 16]
[org 0x7c00]

jmp 0x0:boot

boot:
	xor bx, bx		; bx needs to be 0 for int 0x10
	mov ds, bx
	mov ax, 0x8000
	mov ss, ax
	xor sp, sp
	push 0xb800
	pop es
	;cld

update:
	mov ah, BYTE [col]
	xor al, al
	mov cx, 2000
	xor di, di
	rep stosw

	mov ah, 0x02
	int 0x1a		; Get RTC time => ch hour, cl min, dh sec, dl dst flag (all BCD)

	test BYTE [h24], 1
	jne hour24
	cmp ch, 00010010b	; bcd 12
	jle hour24			; if <=12 display normal
	sub ch, 00010010b
	xchg ch, al
	das					; das only operates on al
	xchg ch, al

hour24:
	mov bl, ch
	shr bl, 4
	xor di, di
	call paint_digit

	mov bl, ch
	and bl, 1111b
	mov di, 34
	call paint_digit

	mov bl, cl
	shr bl, 4
	mov di, 92
	call paint_digit

	mov bl, cl
	and bl, 1111b
	mov di, 126
	call paint_digit

; dots
	xor ax, ax
	bt dx, 8	;every second blink dots
	jc dot
	mov ax, [fullchr]
dot:
	mov di, 876		; x:38, y:5 => (5*80+40)*2
	mov cx, 3
	rep stosw
	mov cx, 3
	mov di, 1036		; x:38, y:5 => (5*80+40)*2
	rep stosw

	mov cx, 3
	mov di, 1996
	rep stosw
	mov cx, 3
	mov di, 2156
	rep stosw

	mov ah, 2
	mov dx, 0x1524		; set cursor pos, dh = y, dl = x
	int 0x10

	; output date
	mov ah, 0x04
	int 0x1a	; get date: ch - century, cl - year, dh - month, dl -day

	mov ah, 0x0e

	mov al, dl
	shr al, 4
	add al, "0"
	int 0x10
	mov al, dl
	and al, 01111b
	add al, "0"
	int 0x10

	mov al, "."
	int 0x10

	mov al, dh
	shr al, 4
	add al, "0"
	int 0x10
	mov al, dh
	and al, 01111b
	add al, "0"
	int 0x10

	mov al, "."
	int 0x10

	mov al, cl
	shr al, 4
	add al, "0"
	int 0x10
	mov al, cl
	and al, 01111b
	add al, "0"
	int 0x10


	; print help text
	mov si, help
phelp:
	lodsb 
	test al,al
	jz helpdone
	int 0x10
	jmp phelp

helpdone:

	; move hw cursor out of sight, bios function needs less code than vga port
	mov ah, 2
	mov dx, 0x1900		; set cursor pos, dh = y, dl = x
	int 0x10


	; check for keystroke
	mov ah, 0x01
	int 0x16		; this would return ascii + scancode in ax but we need to clear the buffer anyway
	jz nokey

	xor ah, ah
	int 0x16		; ah = scancode; AL = ascii
	
	cmp al, "f"		; foreground color cycle
	jne nextkey
	mov al, [col]
	mov ah, al
	inc al
	and ax, 0xF00F
	or al, ah
	mov [col], al
	jmp nokey
nextkey:
	cmp al, "b"
	jne nextkey1
	mov al, [col]
	mov ah, al
	and al, 0xF
	shr ah, 4
	inc ah
	and ah, 0xF
	shl ah, 4
	or al, ah
	mov [col], al
	jmp nokey
nextkey1:
	cmp al, "h"		; switch between 24/12 hour
	jne nokey
	xor BYTE [h24], 1

nokey:
	mov cx, 0x0007		; cx:dx = 0.5s
	mov dx, 0xa120
	mov ah, 0x86
	int 0x15			; wait in microseconds

	jmp update


; paint_digit(char digit, int xpos)
; bx: digit
; di: xpos
paint_digit:
	pusha
	; fetch digit pattern
	movzx dx, [pattern+bx]
	
	xor ax, ax
	bt dx, 6
	jnc b5
	;paint bit 6 here
	call bar_horiz
b5:
	bt dx, 5
	jnc b4
	call bar_vert
b4:
	bt dx, 4
	jnc b3
	push di
	add di, 24		;12*2
	call bar_vert
	pop di
b3:
	bt dx, 3
	jnc b2
	mov al, 8
	call bar_horiz
b2:
	bt dx, 2
	jnc b1
	mov al, 8
	call bar_vert
b1:
	bt dx, 1
	jnc b0
	mov al, 8
	push di
	add di, 24		;12*2
	call bar_vert
	pop di
b0:
	bt dx, 0
	jnc digdone
	mov ax, 16
	call bar_horiz
	
digdone:
	popa
	ret

; bar_horiz(x, y)
; ax: ypos
; di: xpos
bar_horiz:
	pusha

	mov bx, 160
	mul bx		; ax *=80*2
	add di, ax	; xpos + ypos*80

	mov bx, 3
barh:
	mov cx, 16
	mov ax, [fullchr]
	rep stosw
	add di, 128		; 160 - 16*2
	dec bx
	jnz barh

	popa
	ret
	
bar_vert:
	pusha
	
	mov bx, 160
	mul bx		; ax *=80*2
	add di, ax	; xpos + ypos*80
	
	mov bx, 11
barv:
	mov cx, 4
	mov ax, [fullchr]
	rep stosw
	add di, 152			; 160 - 4*2
	dec bx
	jnz barv

	popa
	ret
	

; starting at "0"
pattern db 01110111b, 00010010b, 01011101b, 01011011b, 0111010b, 01101011b, 01101111b, 01010010b, 01111111b, 01111011b
fullchr:
	chr db 0xdb
	col db 0x07

h24		db 1		; use 24h format
help 	db 13,10,10,"h: 24h",13,10,"f/b: color",0

times 510-($-$$) db 0
dw 0xAA55
