.data
	player_x: .word 4
	player_y: .word 12
	prev_player_x: .word 4
	prev_player_y: .word 12
	has_moved: .word 0
	player_direction: .word 1  # Default facing down (front)

	# 5x5 player sprite (back - facing up)
	back_sprite:
	.word 0x00FFFFFF, 0x0000A5FF, 0x0000A5FF, 0x0000A5FF, 0x00FFFFFF
	.word 0x00FFFFFF, 0x0000A5FF, 0x0000A5FF, 0x0000A5FF, 0x00FFFFFF
	.word 0x0000A5FF, 0x00FFFFFF, 0x00FFFFFF, 0x00FFFFFF, 0x0000A5FF
	.word 0x00000000, 0x0000A5FF, 0x0000A5FF, 0x0000A5FF, 0x00000000
	.word 0x00FFFFFF, 0x0000A5FF, 0x00000000, 0x0000A5FF, 0x00FFFFFF

	.align 2

	# 5x5 player sprite (front - facing down)
	front_sprite:
	.word 0x00FFFFFF, 0x0000A5FF, 0x0000A5FF, 0x0000A5FF, 0x00FFFFFF
	.word 0x00FFFFFF, 0x00FFFF00, 0x00FFFF00, 0x00FFFF00, 0x00FFFFFF
	.word 0x0000A5FF, 0x00FFFFFF, 0x00FFFFFF, 0x00FFFFFF, 0x0000A5FF
	.word 0x00000000, 0x0000A5FF, 0x0000A5FF, 0x0000A5FF, 0x00000000
	.word 0x00FFFFFF, 0x0000A5FF, 0x00000000, 0x0000A5FF, 0x00FFFFFF

	.align 2

	# 5x5 player sprite (left - facing left)
	left_sprite:
	.word 0x00FFFFFF, 0x0000A5FF, 0x0000A5FF, 0x0000A5FF, 0x0000A5FF
	.word 0x00FFFFFF, 0x00FFFF00, 0x00FFFF00, 0x00FFFF00, 0x0000A5FF
	.word 0x0000A5FF, 0x00FFFFFF, 0x00FFFFFF, 0x00FFFFFF, 0x00FFFFFF
	.word 0x00000000, 0x0000A5FF, 0x0000A5FF, 0x0000A5FF, 0x00000000
	.word 0x0000A5FF, 0x0000A5FF, 0x00000000, 0x0000A5FF, 0x0000A5FF

	.align 2

	# 5x5 player sprite (right - facing right)
	right_sprite:
	.word 0x0000A5FF, 0x0000A5FF, 0x0000A5FF, 0x0000A5FF, 0x00000000
	.word 0x0000A5FF, 0x00FFFF00, 0x00FFFF00, 0x00FFFF00, 0x00000000
	.word 0x00FFFFFF, 0x00FFFFFF, 0x00FFFFFF, 0x00FFFFFF, 0x0000A5FF
	.word 0x00000000, 0x0000A5FF, 0x0000A5FF, 0x0000A5FF, 0x00000000
	.word 0x0000A5FF, 0x0000A5FF, 0x00000000, 0x0000A5FF, 0x0000A5FF

	.align 2

	# 5x5 door sprite colors (row by row, 25 pixels total)
	drawDoor_sprite:
	.word 0x00E0B514, 0x00FFDD81, 0x00FFE12B, 0x00FFD712, 0x00CF901C
	.word 0x00FFEDAE, 0x00FFFFFF, 0x00FFFF8B, 0x00FFFF4E, 0x00FFDB34
	.word 0x00FFD970, 0x00FFFF72, 0x00FFFF00, 0x00FFFF47, 0x00FFDC23
	.word 0x00E29B33, 0x00FFFF46, 0x00FFFF00, 0x00BD7F22, 0x00EBAC1E
	.word 0x00BB7920, 0x00FFFF4F, 0x00FFFF02, 0x00FFFF60, 0x00BB7920

	.align 2

	bg_buffer: .space 65536 # safe address so the buffes doesn't overlap with heap data (BITMAP_BASE)

.text

# update_player ; processes input, moves/clamps player, handles pause/bomb, triggers HUD/victory
update_player:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($s6)	 # direction

	# old position
	lw  $t2, player_x
	lw  $t3, player_y
	sw $zero, has_moved

	# read key (non-blocking)
	jal read_key_nb          # returns ASCII in $v0, or 0 if none
	move $t0, $v0
	beq  $t0, $zero, no_move

	# Check for pause key (P or p)
	li   $t1, KEY_P
	beq  $t0, $t1, do_pause_player
	li   $t1, KEY_P_UPPER
	beq  $t0, $t1, do_pause_player

	j    continue_player_update


do_pause_player:
	jal pause_game
	j    no_move

continue_player_update:

	# default: new = old
	move $t4, $t2            # new_x
	move $t5, $t3            # new_y

	li   $t1, KEY_W
	beq  $t0, $t1, move_up
	li   $t1, KEY_S
	beq  $t0, $t1, move_down
	li   $t1, KEY_A
	beq  $t0, $t1, move_left
	li   $t1, KEY_D
	beq  $t0, $t1, move_right
	li   $t1, KEY_SPACE
	beq  $t0, $t1, handle_place_bomb
	j    after_move

move_up:
	addi $t5, $t5, -1
	li   $s6, DIR_UP
	sw   $s6, player_direction
	j    after_move
move_down:
	addi $t5, $t5,  1
	li   $s6, DIR_DOWN
	sw   $s6, player_direction
	j    after_move
move_left:
	addi $t4, $t4, -1
	li   $s6, DIR_LEFT
	sw   $s6, player_direction
	j    after_move
move_right:
	addi $t4, $t4,  1
	li   $s6, DIR_RIGHT
	sw   $s6, player_direction
	j    after_move

handle_place_bomb:
	jal  place_bomb
	j    after_move

after_move:
	# clamp new_x to [0 .. SCREEN_W - SPR_W]
	bltz $t4, clamp_x0
	li   $t6, MAX_X
	bgt  $t4, $t6, clamp_xmax
	j    clamp_y
clamp_x0:
	move $t4, $zero
	j    clamp_y
clamp_xmax:
	li   $t4, MAX_X

clamp_y:
	bltz $t5, clamp_y0
	li   $t6, MAX_Y
	bgt  $t5, $t6, clamp_ymax
	j    post_clamp

clamp_y0:
	move $t5, $zero
	j    post_clamp

clamp_ymax:
	li   $t5, MAX_Y
	j    post_clamp

post_clamp:
	# First try: normal move
	move $a0, $t4
	move $a1, $t5
	jal  can_move_to
	bne  $v0, $zero, do_redraw

	# If blocked, try "tolerance" (±1) on the perpendicular axis
	li   $t7, DIR_LEFT
	beq  $s6, $t7, snap_y
	li   $t7, DIR_RIGHT
	beq  $s6, $t7, snap_y

	li   $t7, DIR_UP
	beq  $s6, $t7, snap_x
	li   $t7, DIR_DOWN
	beq  $s6, $t7, snap_x

	j    no_move

# --- moving left/right: adjust Y by -1 or +1 ---
snap_y:
	# try y-1
	addi $t6, $t5, -1
	bltz $t6, snap_y_plus       # don't go < 0

	move $a0, $t4
	move $a1, $t6
	jal  can_move_to
	beq  $v0, $zero, snap_y_plus
	move $t5, $t6               # accept snapped y
	j    do_redraw

snap_y_plus:
	# try y+1
	addi $t6, $t5, 1
	li   $t7, MAX_Y
	bgt  $t6, $t7, no_move

	move $a0, $t4
	move $a1, $t6
	jal  can_move_to
	beq  $v0, $zero, no_move
	move $t5, $t6
	j    do_redraw

# --- moving up/down: adjust X by -1 or +1 ---
snap_x:
	# try x-1
	addi $t6, $t4, -1
	bltz $t6, snap_x_plus

	move $a0, $t6
	move $a1, $t5
	jal  can_move_to
	beq  $v0, $zero, snap_x_plus
	move $t4, $t6
	j    do_redraw

snap_x_plus:
	# try x+1
	addi $t6, $t4, 1
	li   $t7, MAX_X
	bgt  $t6, $t7, no_move

	move $a0, $t6
	move $a1, $t5
	jal  can_move_to
	beq  $v0, $zero, no_move
	move $t4, $t6
	j    do_redraw
	
do_redraw:
	li   $t0, 1
	sw   $t0, has_moved
	jal  commit_move_and_render
	jal  check_victory
	j    no_move

no_move:
	POP($s6)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr $ra

# draw_player_sprite(x=a0, y=a1) ; draws selected facing sprite at coords, transparent on black
draw_player_sprite:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)
	PUSH($t6)

	# Select sprite based on player_direction
	# DIR_UP=0, DIR_DOWN=1, DIR_LEFT=2, DIR_RIGHT=3
	lw   $t5, player_direction
	
	li   $t6, DIR_UP
	beq  $t5, $t6, ps_use_back
	li   $t6, DIR_DOWN
	beq  $t5, $t6, ps_use_front
	li   $t6, DIR_LEFT
	beq  $t5, $t6, ps_use_left
	li   $t6, DIR_RIGHT
	beq  $t5, $t6, ps_use_right
	j    ps_use_front          # default to front if direction is invalid

ps_use_back:
	la   $t0, back_sprite
	j    ps_start
ps_use_front:
	la   $t0, front_sprite
	j    ps_start
ps_use_left:
	la   $t0, left_sprite
	j    ps_start
ps_use_right:
	la   $t0, right_sprite

ps_start:
	li   $t1, 0               # row

ps_row:
	bge  $t1, 5, ps_done
	li   $t2, 0               # col

ps_col:
	bge  $t2, 5, ps_next_row

	# Load color value (word) from sprite
	lw   $t3, 0($t0)
	addiu $t0, $t0, 4         # advance by 4 bytes (1 word)
	
	# Skip black pixels (0x00000000) - transparent
	beq  $t3, $zero, ps_skip

	# draw pixel at (x+col, y+row) with color from sprite
	addu $a0, $a0, $t2
	addu $a1, $a1, $t1
	move $a2, $t3             # use color from sprite
	jal  set_pixel

	subu $a0, $a0, $t2         # restore
	subu $a1, $a1, $t1

ps_skip:
	addiu $t2, $t2, 1
	j    ps_col

ps_next_row:
	addiu $t1, $t1, 1
	j    ps_row

ps_done:
	POP($t6)
	POP($t5)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# capture_bg ; copies entire bitmap (0x10000000) into bg_buffer for restore_rect_5x5
capture_bg:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)

	lui  $t0, BITMAP_BASE       # src = bitmap base
	la   $t1, bg_buffer    # dst = buffer base
	li   $t2, 16384         # number of pixels (128*128)

cap_loop:
	lw   $t3, 0($t0)
	sw   $t3, 0($t1)
	addiu $t0, $t0, 4
	addiu $t1, $t1, 4
	addiu $t2, $t2, -1

	bne  $t2, $zero, cap_loop

	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# draw_hidden_square ; stamps door sprite into bg_buffer at hidden square unless breakable colors present
draw_hidden_square:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)
	PUSH($t6)
	PUSH($t7)
	PUSH($t8)

	li   $t4, HIDDEN_SQUARE_X  # baseX
	li   $t5, HIDDEN_SQUARE_Y  # baseY
	la   $t8, drawDoor_sprite  # sprite data pointer

	li   $t0, 0                # row = 0
dhs_row:
	bge  $t0, SPR_H, dhs_done

	li   $t1, 0                # col = 0
dhs_col:
	bge  $t1, SPR_W, dhs_nextrow

	addu $t2, $t4, $t1         # x = baseX + col
	addu $t3, $t5, $t0         # y = baseY + row

	# Calculate buffer index = (y * SCREEN_W + x) * 4
	li   $t6, SCREEN_W
	mul  $t6, $t3, $t6
	addu $t6, $t6, $t2
	sll  $t6, $t6, 2

	# Get address in bg_buffer
	la   $t7, bg_buffer
	addu $t7, $t7, $t6

	# Read current pixel value
	lw   $t6, 0($t7)

	# Check if pixel is BREKABLE_COLOR or BREKABLE_COLOR2
	li   $t2, BREKABLE_COLOR
	beq  $t6, $t2, dhs_skip    # skip if breakable color
	li   $t2, BREKABLE_COLOR2
	beq  $t6, $t2, dhs_skip    # skip if breakable color 2

	# Get door sprite color for current pixel
	lw   $t6, 0($t8)
	sw   $t6, 0($t7)

dhs_skip:
	addiu $t8, $t8, 4          # advance sprite pointer
	addiu $t1, $t1, 1
	j    dhs_col

dhs_nextrow:
	addiu $t0, $t0, 1
	j    dhs_row

dhs_done:
	POP($t8)
	POP($t7)
	POP($t6)
	POP($t5)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# check_victory ; if player sits on hidden square, shows victory screen and waits for Enter
check_victory:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)

	# Load player position
	lw   $t0, player_x
	lw   $t1, player_y

	# Check if player X matches hidden square X
	li   $t2, HIDDEN_SQUARE_X
	bne  $t0, $t2, cv_no_victory

	# Check if player Y matches hidden square Y
	li   $t2, HIDDEN_SQUARE_Y
	bne  $t1, $t2, cv_no_victory

	# Player is at center of hidden square - trigger victory!
	# Set bitmap base in $s0 as required by victoryScreen macro
	lui  $s0, BITMAP_BASE
	victoryScreen()

	# Draw Score on victory screen
	# score at (x=75, y=94)
	li   $a0, 75
	li   $a1, 94
	la   $t0, score_value
	lw   $a2, 0($t0)
	li   $a3, 0x00FFFFFF
	jal  draw_number_3x5_right

	# Wait for ENTER to go back to menu, or E to exit
cv_wait_for_enter:
	jal  wait_for_key_or_exit
	li   $t0, 10             # ASCII code for Enter (line feed)
	bne  $v0, $t0, cv_wait_for_enter
	j    main

cv_no_victory:
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra


# restore_rect_5x5(x=a0, y=a1) ; copies 5x5 rect from bg_buffer back to bitmap
restore_rect_5x5:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)
	PUSH($t6)
	PUSH($t7)
	PUSH($t8)
	PUSH($t9)

	move $t4, $a0          # baseX
	move $t5, $a1          # baseY

	li   $t0, 0            # row
rr_row:
	bge  $t0, SPR_H, rr_done

	li   $t1, 0            # col
rr_col:
	bge  $t1, SPR_W, rr_nextrow

	addu $t2, $t4, $t1     # x = baseX + col
	addu $t3, $t5, $t0     # y = baseY + row

	# index = (y*SCREEN_W + x) * 4
	li   $t6, SCREEN_W
	mul  $t6, $t3, $t6
	addu $t6, $t6, $t2
	sll  $t6, $t6, 2

	# src = bg_buffer + index
	la   $t7, bg_buffer
	addu $t7, $t7, $t6
	lw   $t8, 0($t7)

	# dst = bitmap + index
	lui  $t9, BITMAP_BASE
	addu $t9, $t9, $t6
	sw   $t8, 0($t9)

	addiu $t1, $t1, 1
	j    rr_col

rr_nextrow:
	addiu $t0, $t0, 1
	j    rr_row

rr_done:
	POP($t9)
	POP($t8)
	POP($t7)
	POP($t6)
	POP($t5)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)

	POP($ra)
	jr   $ra

# commit_move_and_render ; restores old tile, commits player position, redraws HUD/bomb/player
commit_move_and_render:
	PUSH($ra)

	# restore old background first (prevents trails)
	move $a0, $t2
	move $a1, $t3
	jal  restore_rect_5x5

	# Redraw bomb if active (in case player moved over it)
	lw   $t0, bomb_active
	beq  $t0, $zero, skip_redraw_bomb
	lw   $a0, bomb_x
	lw   $a1, bomb_y
	jal  draw_bomb_sprite
skip_redraw_bomb:

	# commit new position
	sw   $t4, player_x
	sw   $t5, player_y

	# draw player last
	move $a0, $t4
	move $a1, $t5
	jal  draw_player_sprite

	# Increase score by 1 for each successful move (DEBUG)
	# li   $a0, 1
	# jal add_score

	jal draw_hud

	POP($ra)
	jr   $ra
