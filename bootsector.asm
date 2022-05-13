[bits 16]

playercharacter equ '>' | 0x0900
playerxposition equ 3

; set up initial enviromnent

mov ax,0x7c0
mov ds,ax
mov ss,ax
mov sp,ax 
; seed RNG using the BIOS system clock counter

xor ah,ah
int 0x1A

mov [rand],dx



; clean enemy data memory area

push word 0x1000
pop es
mov cx,0x8000
xor di,di
xor al,al

rep stosb

; mask the keyboard interrupt in the PIC

in al,0x21
or al,2
out 0x21,al

; draw game area

mov al, '='
mov bh,9

call drawline

mov bh,15
call drawline

mov bh,12
call moveplayer

; main game loop



gameloop:
	
	; check if there was keyboard input
	
	in al,0x64 ; ps/2 controller status register
	and al,1 ; first bit is 1 if buffer full, otherwise empty
	jz .simulate
	
	in al,0x60 ; get scancode

	mov bh,[playerpos]
	
	cmp al,0x11 ; set 1 W
	jne .S

	dec bh

	.S:
	cmp al,0x1F ; set 1 S
	jne .K
	
	inc bh

	.K:
	
	call moveplayer ; at this point we will have known if the player must move. if bh hasn't changed at all it will just stay in the same spot
	
	cmp al,0x25 ; set 1 K
	jne .simulate

	
	mov bl,playerxposition+1
	mov bh,[playerpos]
	mov ah,0b11010000
	call shoot

	.simulate:
	
	;check if we should do a simulation tick

	xor ah,ah
	int 0x1A

	cmp dx,[lasttick]
	je gameloop
	mov [lasttick],dx


	xor di,di
	
	; check if we should add a new enemy and where

	add byte [rand],0xD9
	mov al,[rand]
	cmp al,0xF9
	jb .nope

	push di
	call findfirstfree	

	mov bh,10
	and al,3
	add bh,al
	and al,1
	add bh,al

	mov ah,0b10010111
	mov al,'<'
	mov bl,78
	mov cl,6

	call createentity
	
	pop di

	.nope:

	; simulation table:
	; offset  | size  | 
	;   0x0   |   1   |  flags
	;   0x1   |   1   |  x position
	;   0x2   |   1   |  y position
	;   0x3   |   1   |  tickstillupdate1 (i.e. moving)
	;   0x4   |   1   |  update1startertick
	;   0x5   |   1   |  tickstillupdate2 (i.e. shooting)
	;   0x6   |   1   |  update2startertick
	;   0x7   |   1   |  character
	; ------------------------------------------------------
	;  flags:
	;  bit 7: valid
	;  bit 3,4,5,6: colour
	;  bit 2: shoots
	;  bit 1: movedirection (unset for positive X, set for negative X (i.e enemy))
	;  bit 0: enemy 
	
	
	.loop:
		
		;check if valid

		mov cl, [es:di]
		test cl,cl
		jz .continue
		
		; check for update1
		
		dec byte [es:di+3]
		jnz .update2check

		mov dh,[es:di]
		and dh,0b10 ; get direction bit

		call moveentity
		
		mov byte ah,[es:di+4]
		mov byte [es:di+3],ah
		


	
		call putcharat

		; check for update2

		.update2check:
		


		dec byte [es:di+5]
		jnz .continue
		mov cl,[es:di]
		and cl,0b100
		jz .continue
		
		
		mov ah,0b11100011				
		mov bx,[es:di+1]
		
		call shoot

		mov byte [es:di+5],20
		.continue:
		add di,8 ; table size
		cmp di,0x8000
	jbe .loop

	
jmp gameloop


; subroutines

; ah = flags
; expects ES to be 0x1000
shoot:
	
	push di
	call findfirstfree
	mov al,'-'
	mov cl,1
	call createentity
	pop di
	ret

;nukes an entity
;input is ES:DI is the entity

nukeentity:
	push byte 8
	pop cx
	xor al,al
	rep stosb
	ret


; create entity

; ES:DI = where
; ah = flags
; al = character
; bh = position X
; bl = position Y
; cl = update1startertick

createentity:

	mov [es:di],ah
	mov [es:di+1],bx
	mov [es:di+7],al
	inc byte [es:di+3]
	mov [es:di+4],cl
	inc byte [es:di+5]


	call putcharat

	ret

; expects es to be 0x1000
; di = entity
; dh direction ( 0 for ----> else <----)

; move entity

moveentity:

	mov bx,[es:di+1]
	
	test bl,bl
	jnz .keepgoing
	call nukeentity
	ret
	.keepgoing:
	cmp bl,79
	jb .safenow
	call nukeentity
	ret
	

	.safenow:
	push bx

	test dh,dh
	jnz .left
	
	inc bx

	jmp .domove

	.left:

	
	dec bx
	
	
	.domove:
		
	mov al,[es:di+7]

	call putcharat
	
	mov ah,[playerpos]
	mov al,playerxposition
	cmp bx,ax
	je gameover
	
	; if player projectile then kill nonprojectiles
	
	pusha
	
	mov dx,bx
	
	call findwithpos
		
	test al,al
	jz .goon

	mov al,[es:bx]
	mov ah,[es:di]
	and al,0b100
	jz .goon
	and ah,0b1
	jnz .goon

	call nukeentity
	
	mov di,bx

	call nukeentity

	mov bx,dx

	xor al,al
	
	call putcharat
		
	

	popa
	pop bx
	ret
	
	.goon:
	
	popa

	mov [es:di+1],bx
	
	pop bx

	; now show whatever was underneath
	
	push bx

	call findwithpos

	test ax,ax
	jz .void
	

	mov al,[es:bx+7]


	pop bx
	
	call putcharat

	ret

	.void:
		pop bx
		xor ax,ax

		call putcharat
	

	
	.return:	

	ret

; expects es to be 0x1000
; bh = y position to search
; bl = x position to search
; es:bx = result
; ax = valid
; if al is not 0 then it is valid

findwithpos:
	
	mov cx,bx	
	xor bx,bx
	
	.loop:
		cmp byte [es:bx],0
		je .continue
		mov ax,[es:bx+1]
		cmp ax,cx
		jne .continue
		ret

	.continue:
		add bx,8
		cmp bx,0x8000
		jb .loop
	
	xor ax,ax

	ret
	
	

;end of game L

gameover:
	cli
	hlt



; expects ES to be 0x1000

; returns first free entity location in memory in es:bx


findfirstfree:
	
	xor di,di
	
	.loop:

		cmp byte [es:di],0
	
		je .found
		
		add di,8

		jmp .loop


	.found:
		ret
	

; bh = new position

moveplayer:

	pusha
	
	cmp bh,9
	jbe .return
	cmp bh,15
	jge .return

	mov bl,playerxposition
	push bx
	mov bh,[playerpos]
	xor ax,ax

	call putcharat

	pop bx

	mov ax,playercharacter
		
	call putcharat
	
	mov [playerpos],bh
	
	.return:

	popa
	ret
; al = character
; bh = where vertically

drawline:
	
	push byte 80
	pop cx
		
	.loop:
		mov bl,cl
		dec bx

		call putcharat
	loop .loop


	ret
	

;bl = X
;bh = Y
;al = char

putcharat:
	pusha
	
	mov ah,2
	mov dx,bx
	xor bh,bh
	int 0x10
	mov bl,0b1001
	mov ah,9
	xor cx,cx
	inc cx
	int 0x10	

	popa
	ret

; gets a new random number
; al = number

random:

	;ret
	

rand: db 0
playerpos: db 12
lasttick: dw 0


times 510-($-$$) db 0
dw 0xAA55
