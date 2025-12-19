.include "config.asm"

# v0 = get_pixel(x=a0, y=a1)
get_pixel:
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t7)

	lui   $t7, BITMAP_BASE          # bitmap base 0x10000000

	li    $t0, SCREEN_W
	mul   $t1, $a1, $t0        # y * SCREEN_W
	addu  $t1, $t1, $a0        # + x
	sll   $t1, $t1, 2          # *4 bytes per pixel
	addu  $t2, $t7, $t1
	lw    $v0, 0($t2)

	POP($t7)
	POP($t2)
	POP($t1)
	POP($t0)

	jr    $ra

# set_pixel(x=a0, y=a1, color=a2)
set_pixel:
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t7)

	lui   $t7, BITMAP_BASE          # bitmap base 0x10000000

	li    $t0, SCREEN_W
	mul   $t1, $a1, $t0        # y * SCREEN_W
	addu  $t1, $t1, $a0        # + x
	sll   $t1, $t1, 2          # *4 bytes per pixel
	addu  $t2, $t7, $t1
	sw    $a2, 0($t2)

	POP($t7)
	POP($t2)
	POP($t1)
	POP($t0)

	jr    $ra

# draw_rect_5x5(x=a0, y=a1, color=a2) ; fills 5x5 solid block to bitmap display
draw_rect_5x5:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)

	lui   $t7, BITMAP_BASE

	move  $t0, $zero          # row = 0
dr_row_loop:
	bge   $t0, SPR_H, dr_done_block

	move  $t1, $zero          # col = 0
dr_col_loop:
	bge   $t1, SPR_W, dr_next_row

	addu  $t2, $a0, $t1       # pixelX
	addu  $t3, $a1, $t0       # pixelY

	# index = pixelY*SCREEN_W + pixelX
	li    $t4, SCREEN_W
	mul   $t5, $t3, $t4
	addu  $t5, $t5, $t2

	sll   $t5, $t5, 2         # index * 4
	addu  $t6, $t7, $t5       # addr = base + offset
	sw    $a2, 0($t6)

	addiu $t1, $t1, 1
	j     dr_col_loop

dr_next_row:
	addiu $t0, $t0, 1
	j     dr_row_loop

dr_done_block:
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr    $ra

# darken_screen ; dims entire bitmap by dividing each RGB component by DARKEN_DIVISOR (keeps 20% brightness)
darken_screen:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)
	PUSH($t6)

	lui   $t0, BITMAP_BASE      # bitmap base address
	li    $t1, TOTAL_PIXELS     # 128*128 = 16384 pixels

darken_loop:
	beqz  $t1, darken_done

	lw    $t2, 0($t0)           # load pixel color (00RRGGBB)

	# Extract and darken each RGB component
	# Red component
	srl   $t3, $t2, 16          # R = (color >> 16) & 0xFF
	andi  $t3, $t3, 0xFF
	li    $t6, DARKEN_DIVISOR   # divide by 5 to keep 20% brightness
	divu  $t3, $t6
	mflo  $t3                   # R = R / DARKEN_DIVISOR

	# Green component
	srl   $t4, $t2, 8           # G = (color >> 8) & 0xFF
	andi  $t4, $t4, 0xFF
	divu  $t4, $t6
	mflo  $t4                   # G = G / DARKEN_DIVISOR

	# Blue component
	andi  $t5, $t2, 0xFF        # B = color & 0xFF
	divu  $t5, $t6
	mflo  $t5                   # B = B / DARKEN_DIVISOR

	# Recombine: color = (R << 16) | (G << 8) | B
	sll   $t3, $t3, 16
	sll   $t4, $t4, 8
	or    $t2, $t3, $t4
	or    $t2, $t2, $t5

	sw    $t2, 0($t0)           # store darkened pixel

	addiu $t0, $t0, 4           # next pixel
	addiu $t1, $t1, -1
	j     darken_loop

darken_done:
	POP($t6)
	POP($t5)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr    $ra

# draw_pause_text: draws "PAUSE" in white centered on screen
# Uses 5x5 letter sprites, letters are 6 pixels apart (5 + 1 gap)
# "PAUSE" = 5 letters, width = 5*5 + 4*1 = 29 pixels
# Center X = (128 - 29) / 2 = 49 (approximately)
# Center Y = (128 - 5) / 2 = 61 (approximately)
draw_pause_text:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($a0)
	PUSH($a1)
	PUSH($a2)

	li    $t0, 49               # starting X position (centered)
	li    $t1, 61               # Y position (centered)

	# Draw 'P'
	move  $a0, $t0
	move  $a1, $t1
	li    $a2, 0x00FFFFFF       # white color
	jal   draw_letter_P
	addiu $t0, $t0, 6           # move X for next letter

	# Draw 'A'
	move  $a0, $t0
	move  $a1, $t1
	li    $a2, 0x00FFFFFF
	jal   draw_letter_A
	addiu $t0, $t0, 6

	# Draw 'U'
	move  $a0, $t0
	move  $a1, $t1
	li    $a2, 0x00FFFFFF
	jal   draw_letter_U
	addiu $t0, $t0, 6

	# Draw 'S'
	move  $a0, $t0
	move  $a1, $t1
	li    $a2, 0x00FFFFFF
	jal   draw_letter_S
	addiu $t0, $t0, 6

	# Draw 'E'
	move  $a0, $t0
	move  $a1, $t1
	li    $a2, 0x00FFFFFF
	jal   draw_letter_E

	POP($a2)
	POP($a1)
	POP($a0)
	POP($t1)
	POP($t0)
	POP($ra)
	jr    $ra

# Letter drawing functions (5x5 pixel letters)
# Input: a0=x, a1=y, a2=color

# draw_letter_P: draws letter P at (x=a0, y=a1) with color=a2
# Pattern:
# XXXX.
# X...X
# XXXX.
# X....
# X....
draw_letter_P:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)

	# Row 0: XXXX.
	move  $t0, $a0
	move  $t1, $a1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	move  $a0, $t0

	# Row 1: X...X
	addiu $a1, $a1, 1
	jal   set_pixel
	addiu $a0, $a0, 4
	jal   set_pixel
	move  $a0, $t0

	# Row 2: XXXX.
	addiu $a1, $a1, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	move  $a0, $t0

	# Row 3: X....
	addiu $a1, $a1, 1
	jal   set_pixel

	# Row 4: X....
	addiu $a1, $a1, 1
	jal   set_pixel

	move  $a1, $t1              # restore a1
	POP($t1)
	POP($t0)
	POP($ra)
	jr    $ra

# draw_letter_A: draws letter A at (x=a0, y=a1) with color=a2
# Pattern:
# .XXX.
# X...X
# XXXXX
# X...X
# X...X
draw_letter_A:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)

	move  $t0, $a0
	move  $t1, $a1

	# Row 0: .XXX.
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	move  $a0, $t0

	# Row 1: X...X
	addiu $a1, $a1, 1
	jal   set_pixel
	addiu $a0, $a0, 4
	jal   set_pixel
	move  $a0, $t0

	# Row 2: XXXXX
	addiu $a1, $a1, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	move  $a0, $t0

	# Row 3: X...X
	addiu $a1, $a1, 1
	jal   set_pixel
	addiu $a0, $a0, 4
	jal   set_pixel
	move  $a0, $t0

	# Row 4: X...X
	addiu $a1, $a1, 1
	jal   set_pixel
	addiu $a0, $a0, 4
	jal   set_pixel

	move  $a0, $t0
	move  $a1, $t1
	POP($t1)
	POP($t0)
	POP($ra)
	jr    $ra

# draw_letter_U: draws letter U at (x=a0, y=a1) with color=a2
# Pattern:
# X...X
# X...X
# X...X
# X...X
# .XXX.
draw_letter_U:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)

	move  $t0, $a0
	move  $t1, $a1

	# Row 0: X...X
	jal   set_pixel
	addiu $a0, $a0, 4
	jal   set_pixel
	move  $a0, $t0

	# Row 1: X...X
	addiu $a1, $a1, 1
	jal   set_pixel
	addiu $a0, $a0, 4
	jal   set_pixel
	move  $a0, $t0

	# Row 2: X...X
	addiu $a1, $a1, 1
	jal   set_pixel
	addiu $a0, $a0, 4
	jal   set_pixel
	move  $a0, $t0

	# Row 3: X...X
	addiu $a1, $a1, 1
	jal   set_pixel
	addiu $a0, $a0, 4
	jal   set_pixel
	move  $a0, $t0

	# Row 4: .XXX.
	addiu $a1, $a1, 1
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel

	move  $a0, $t0
	move  $a1, $t1
	POP($t1)
	POP($t0)
	POP($ra)
	jr    $ra

# draw_letter_S: draws letter S at (x=a0, y=a1) with color=a2
# Pattern:
# .XXXX
# X....
# .XXX.
# ....X
# XXXX.
draw_letter_S:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)

	move  $t0, $a0
	move  $t1, $a1

	# Row 0: .XXXX
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	move  $a0, $t0

	# Row 1: X....
	addiu $a1, $a1, 1
	jal   set_pixel

	# Row 2: .XXX.
	addiu $a1, $a1, 1
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	move  $a0, $t0

	# Row 3: ....X
	addiu $a1, $a1, 1
	addiu $a0, $a0, 4
	jal   set_pixel
	move  $a0, $t0

	# Row 4: XXXX.
	addiu $a1, $a1, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel

	move  $a0, $t0
	move  $a1, $t1
	POP($t1)
	POP($t0)
	POP($ra)
	jr    $ra

# draw_letter_E: draws letter E at (x=a0, y=a1) with color=a2
# Pattern:
# XXXXX
# X....
# XXX..
# X....
# XXXXX
draw_letter_E:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)

	move  $t0, $a0
	move  $t1, $a1

	# Row 0: XXXXX
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	move  $a0, $t0

	# Row 1: X....
	addiu $a1, $a1, 1
	jal   set_pixel

	# Row 2: XXX..
	addiu $a1, $a1, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	move  $a0, $t0

	# Row 3: X....
	addiu $a1, $a1, 1
	jal   set_pixel

	# Row 4: XXXXX
	addiu $a1, $a1, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel
	addiu $a0, $a0, 1
	jal   set_pixel

	move  $a0, $t0
	move  $a1, $t1
	POP($t1)
	POP($t0)
	POP($ra)
	jr    $ra
