.data
	# 3x5 digits, rows packed as 3-bit values (0..7)
	digits3x5:
		# 0
		.byte 7,5,5,5,7
		# 1
		.byte 2,6,2,2,7
		# 2
		.byte 7,1,7,4,7
		# 3
		.byte 7,1,7,1,7
		# 4
		.byte 5,5,7,1,1
		# 5
		.byte 7,4,7,1,7
		# 6
		.byte 7,4,7,5,7
		# 7
		.byte 7,1,1,1,1
		# 8
		.byte 7,5,7,5,7
		# 9
		.byte 7,5,7,1,7
.text
# draw_digit_3x5(x=a0, y=a1, digit=a2, color=a3)
draw_digit_3x5:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)
	PUSH($t6)

	# ptr = digits3x5 + digit*5
	la   $t0, digits3x5
	li   $t1, 5
	mul  $t2, $a2, $t1
	addu $t0, $t0, $t2

	li   $t3, 0          # row = 0
dd_row:
	bge  $t3, 5, dd_done
	lbu  $t4, 0($t0)     # pattern bits for this row (3 bits)
	addiu $t0, $t0, 1

	li   $t5, 0          # col = 0
dd_col:
	bge  $t5, 3, dd_next_row

	# test bit (from left to right): bit2, bit1, bit0
	li   $t6, 2
	subu $t6, $t6, $t5
	srlv $t2, $t4, $t6
	andi $t2, $t2, 1
	beq  $t2, $zero, dd_skip_pixel

	# set pixel at (a0+col, a1+row)
	addu $t1, $a0, $t5
	addu $t2, $a1, $t3
	# inline setpixel
	lui  $t7, BITMAP_BASE
	li   $t8, SCREEN_W
	mul  $t9, $t2, $t8
	addu $t9, $t9, $t1
	sll  $t9, $t9, 2
	addu $t9, $t7, $t9
	sw   $a3, 0($t9)

dd_skip_pixel:
	addiu $t5, $t5, 1
	j    dd_col

dd_next_row:
	addiu $t3, $t3, 1
	j    dd_row

dd_done:
  POP($t6)
	POP($t5)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# draw_number_3x5_right(xRight=a0, y=a1, value=a2, color=a3)
draw_number_3x5_right:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($s0)

	move $t0, $a2          # value
	move $t1, $a0          # current x (right edge position)
	move $s0, $a3          # save color

	# special-case 0
	bne  $t0, $zero, dn_loop
	move $a0, $t1
	# a1 stays
	li   $a2, 0
	move $a3, $s0          # restore color
	jal  draw_digit_3x5
	j    dn_done

dn_loop:
	# digit = value % 10 ; value /= 10
	li   $t2, 10
	div  $t0, $t2
	mfhi $t3               # digit
	mflo $t0               # value

	# draw this digit with its left at (xRight-2)
	addiu $a0, $t1, -2     # because digit width is 3
	# a1 stays
	move  $a2, $t3
	move  $a3, $s0         # restore color
	jal   draw_digit_3x5

	addiu $t1, $t1, -4     # move left by 4 pixels (3 + gap)
	bne   $t0, $zero, dn_loop

dn_done:
	POP($s0)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# fill_rect(x=a0, y=a1, width=a2, height=a3, color=s0)
fill_rect:
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)

	move $t0, $a1          # current y
	addu $t1, $a1, $a3     # end y
fr_row:
	bge  $t0, $t1, fr_done
	move $t2, $a0          # current x
	addu $t3, $a0, $a2     # end x
fr_col:
	bge  $t2, $t3, fr_next_row
	
	# set pixel at (t2, t0)
	lui  $t4, BITMAP_BASE
	li   $t5, SCREEN_W
	mul  $t5, $t0, $t5
	addu $t5, $t5, $t2
	sll  $t5, $t5, 2
	addu $t5, $t4, $t5
	sw   $s0, 0($t5)
	
	addiu $t2, $t2, 1
	j    fr_col
fr_next_row:
	addiu $t0, $t0, 1
	j    fr_row
fr_done:
	POP($t5)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	jr   $ra

# increment_time: adds 1 to time_value
increment_time:
	la   $t0, time_value
	lw   $t1, 0($t0)
	addiu $t1, $t1, 1
	sw   $t1, 0($t0)
	jr   $ra

# set_lives(new_value=a0)
set_lives:
	la   $t0, lives_value
	sw   $a0, 0($t0)
	jr   $ra

# set_score(new_value=a0)
set_score:
	la   $t0, score_value
	sw   $a0, 0($t0)
	jr   $ra

# add_score(amount=a0)
add_score:
	la   $t0, score_value
	lw   $t1, 0($t0)
	addu $t1, $t1, $a0
	sw   $t1, 0($t0)
	jr   $ra

# set_time(new_value=a0)
set_time:
	la   $t0, time_value
	sw   $a0, 0($t0)
	jr   $ra

# draw_hud ; redraws lives/score/time using stored values (clobbers a0-a3, s0, t0)
draw_hud:
	PUSH($ra)
	PUSH($s0)

	# Clear lives area (x=18, y=7, width=7, height=7)
	li   $a0, 18
	li   $a1, 7
	li   $a2, 7
	li   $a3, 7
	li   $s0, COLOR_BLACK
	jal  fill_rect

	# lives at (x=20, y=8)
	li   $a0, 22
	li   $a1, 8
	la   $t0, lives_value
	lw   $a2, 0($t0)
	li   $a3, 0x00FFFFFF
	jal  draw_number_3x5_right

	# Clear score area (x=61, y=7, width=16, height=7)
	li   $a0, 61
	li   $a1, 7
	li   $a2, 16
	li   $a3, 7
	li   $s0, COLOR_BLACK
	jal  fill_rect

	# score at (x=73, y=8)
	li   $a0, 73
	li   $a1, 8
	la   $t0, score_value
	lw   $a2, 0($t0)
	li   $a3, 0x00FFFFFF
	jal  draw_number_3x5_right

	# Clear time area (x=100, y=7, width=20, height=7)
	li   $a0, 100
	li   $a1, 7
	li   $a2, 20
	li   $a3, 7
	li   $s0, COLOR_BLACK
	jal  fill_rect

	# time at (x=115, y=8)
	li   $a0, 115
	li   $a1, 8
	la   $t0, time_value
	lw   $a2, 0($t0)
	li   $a3, 0x00FFFFFF
	jal  draw_number_3x5_right

	POP($s0)
	POP($ra)
	jr   $ra
