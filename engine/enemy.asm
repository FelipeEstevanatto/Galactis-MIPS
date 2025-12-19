.data
# Enemy Configuration (data-driven)
# Each enemy entry is ENEMY_SIZE bytes (4 words):
#   0: x (word)
#   4: y (word)
#   8: dir (word)   0=Up, 1=Down, 2=Left, 3=Right
#  12: active (word) 0=inactive, 1=active
enemy_count: .word 5
enemies:
	.word 114, 21, DIR_LEFT,  1  # Enemy 1
	.word 9,   121, DIR_RIGHT, 1  # Enemy 2
	.word 50,  60, DIR_UP,    1  # Enemy 3
	.word 4,  56, DIR_UP,    1  # Enemy 4
	.word 74, 21, DIR_LEFT,  1  # Enemy 5


# Player i-frame cooldown after taking damage from an enemy
player_hurt_cooldown: .word 0

# 5x5 enemy sprite (1 = pixel on, 0 = transparent)
enemy_sprite:
	.byte 0,1,1,1,0
	.byte 1,1,0,1,1
	.byte 1,1,1,1,1
	.byte 0,1,0,1,0
	.byte 1,0,0,0,1

.text

# -----------------------------------------------------------------------------
# Rendering
# -----------------------------------------------------------------------------
# draw_enemy_sprite(x=a0, y=a1)
draw_enemy_sprite:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)

	la   $t0, enemy_sprite
	li   $t1, 0                # row
de_row:
	bge  $t1, 5, de_done
	li   $t2, 0                # col
de_col:
	bge  $t2, 5, de_next_row

	lbu  $t3, 0($t0)
	addiu $t0, $t0, 1
	beq  $t3, $zero, de_skip

	# draw pixel at (x+col, y+row)
	addu $a0, $a0, $t2
	addu $a1, $a1, $t1
	li   $a2, ENEMY_COLOR
	jal  set_pixel

	# restore a0/a1
	subu $a0, $a0, $t2
	subu $a1, $a1, $t1

de_skip:
	addiu $t2, $t2, 1
	j    de_col
de_next_row:
	addiu $t1, $t1, 1
	j    de_row

de_done:
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# -----------------------------------------------------------------------------
# Enemy iteration helpers
# -----------------------------------------------------------------------------
# init_enemies ; draws all active enemies (call after capture_bg)
init_enemies:
	PUSH($ra)
	jal  redraw_all_enemies
	POP($ra)
	jr   $ra

# erase_all_enemies ; restores background under all active enemies using bg_buffer
erase_all_enemies:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)

	la   $t0, enemy_count
	lw   $t1, 0($t0)           # count
	la   $t2, enemies          # ptr
	li   $t3, 0                # i
eae_loop:
	bge  $t3, $t1, eae_done
	lw   $t4, 12($t2)          # active
	beq  $t4, $zero, eae_next
	lw   $a0, 0($t2)           # x
	lw   $a1, 4($t2)           # y
	jal  restore_rect_5x5
eae_next:
	addiu $t2, $t2, ENEMY_SIZE
	addiu $t3, $t3, 1
	j    eae_loop
eae_done:
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# redraw_all_enemies ; draws every active enemy sprite at stored positions
redraw_all_enemies:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)

	la   $t0, enemy_count
	lw   $t1, 0($t0)           # count
	la   $t2, enemies          # ptr
	li   $t3, 0                # i
rae_loop:
	bge  $t3, $t1, rae_done
	lw   $t4, 12($t2)          # active
	beq  $t4, $zero, rae_next
	lw   $a0, 0($t2)           # x
	lw   $a1, 4($t2)           # y
	jal  draw_enemy_sprite
rae_next:
	addiu $t2, $t2, ENEMY_SIZE
	addiu $t3, $t3, 1
	j    rae_loop
rae_done:
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# kill_enemies_in_explosion(x=a0, y=a1) ; deactivates enemies overlapping given 5x5 explosion tile, v0=kill count
kill_enemies_in_explosion:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)
	PUSH($t6)
	PUSH($t7)
	PUSH($s0)
	PUSH($s1)
	PUSH($s2)

	move $s0, $a0              # tile_x
	move $s1, $a1              # tile_y
	li   $s2, 0                # kill count

	la   $t0, enemy_count
	lw   $t1, 0($t0)           # count
	la   $t2, enemies          # ptr
	li   $t3, 0                # i

kie_loop:
	bge  $t3, $t1, kie_done
	lw   $t4, 12($t2)          # active
	beq  $t4, $zero, kie_next

	# Get enemy position
	lw   $t5, 0($t2)           # enemy_x
	lw   $t6, 4($t2)           # enemy_y

	# Check X overlap (strict - no corner/diagonal contact)
	addu $t7, $s0, 5           # tile_x + 5
	bge  $t5, $t7, kie_next    # enemy_x >= tile_x + 5: no overlap

	addu $t7, $t5, 5           # enemy_x + 5
	ble  $t7, $s0, kie_next    # enemy_x + 5 <= tile_x: no overlap

	# Check Y overlap (strict - no corner/diagonal contact)
	addu $t7, $s1, 5           # tile_y + 5
	bge  $t6, $t7, kie_next    # enemy_y >= tile_y + 5: no overlap

	addu $t7, $t6, 5           # enemy_y + 5
	ble  $t7, $s1, kie_next    # enemy_y + 5 <= tile_y: no overlap

	# Enemy overlaps with explosion tile - kill it
	sw   $zero, 12($t2)        # active = 0
	addiu $s2, $s2, 1          # increment kill count

kie_next:
	addiu $t2, $t2, ENEMY_SIZE
	addiu $t3, $t3, 1
	j    kie_loop

kie_done:
	move $v0, $s2              # return kill count

	POP($s2)
	POP($s1)
	POP($s0)
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

# kill_enemies_in_tile(x=a0, y=a1) ; deactivates enemies whose top-left matches coords
kill_enemies_in_tile:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)

	move $t4, $a0              # x
	move $t5, $a1              # y
	la   $t0, enemy_count
	lw   $t1, 0($t0)           # count
	la   $t2, enemies          # ptr
	li   $t3, 0                # i
ket_loop:
	bge  $t3, $t1, ket_done
	lw   $t0, 12($t2)          # active
	beq  $t0, $zero, ket_next
	lw   $t0, 0($t2)           # ex
	lw   $t1, 4($t2)           # ey
	bne  $t0, $t4, ket_next
	bne  $t1, $t5, ket_next
	sw   $zero, 12($t2)        # active = 0
ket_next:
	addiu $t2, $t2, ENEMY_SIZE
	addiu $t3, $t3, 1
	j    ket_loop
ket_done:
	POP($t5)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# -----------------------------------------------------------------------------
# Player damage from enemy touch
# -----------------------------------------------------------------------------
# check_player_enemy_collisions ; AABB check vs active enemies, applies damage if cooldown expired
check_player_enemy_collisions:
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

	# 1. Cooldown gate: Don't take damage if already in i-frames
	la   $t0, player_hurt_cooldown
	lw   $t1, 0($t0)
	bgtz $t1, cpec_done

	# 2. Get Player Rect (Top-Left and Bottom-Right)
	lw   $t2, player_x         # Player X1
	lw   $t3, player_y         # Player Y1
	addiu $t7, $t2, 4          # Player X2 (X1 + SPR_W - 1)
	addiu $t8, $t3, 4          # Player Y2 (Y1 + SPR_H - 1)

	la   $t4, enemy_count
	lw   $t5, 0($t4)           # count
	la   $t6, enemies          # ptr
cpec_loop:
	beqz $t5, cpec_done
	lw   $t0, 12($t6)          # Is enemy active?
	beq  $t0, $zero, cpec_next
	
	# 3. Get Enemy Position
	lw   $t0, 0($t6)           # Enemy X1
	lw   $t1, 4($t6)           # Enemy Y1
	
	# 4. AABB Collision Check
	# Collision occurs if:
	# (Rect1.X1 <= Rect2.X2) && (Rect1.X2 >= Rect2.X1) &&
	# (Rect1.Y1 <= Rect2.Y2) && (Rect1.Y2 >= Rect2.Y1)
	
	# Check X overlap
	bgt  $t2, $t0, check_x2_gt_e1  # If Player X1 > Enemy X1, check Player X2
	addiu $t9, $t2, 4              # Player X2
	blt  $t9, $t0, cpec_next       # If Player X2 < Enemy X1, no collision
	j    check_y_overlap

check_x2_gt_e1:
	addiu $t9, $t0, 4              # Enemy X2
	blt  $t9, $t2, cpec_next       # If Enemy X2 < Player X1, no collision

check_y_overlap:
	# Check Y overlap
	bgt  $t3, $t1, check_y2_gt_e1
	addiu $t9, $t3, 4              # Player Y2
	blt  $t9, $t1, cpec_next       # If Player Y2 < Enemy Y1, no collision
	j    collision_detected

check_y2_gt_e1:
	addiu $t9, $t1, 4              # Enemy Y2
	blt  $t9, $t3, cpec_next       # If Enemy Y2 < Player Y1, no collision

collision_detected:
	# collision! set cooldown
	la   $t0, player_hurt_cooldown
	li   $t1, PLAYER_HURT_COOLDOWN_FRAMES
	sw   $t1, 0($t0)

	# erase player at current location
	move $a0, $t2
	move $a1, $t3
	jal  restore_rect_5x5

	# apply damage/respawn
	jal  handle_player_death

	# draw player at respawn position
	lw   $a0, player_x
	lw   $a1, player_y
	jal  draw_player_sprite
	j    cpec_done             # Stop checking after one hit

cpec_next:
	addiu $t6, $t6, ENEMY_SIZE
	addiu $t5, $t5, -1
	j    cpec_loop

cpec_done:
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

# -----------------------------------------------------------------------------
# Movement / AI
# -----------------------------------------------------------------------------
# update_enemies ; decrements cooldown, steps enemies periodically, then checks collisions
update_enemies:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)

	# decrement hurt cooldown (every frame)
	la   $t0, player_hurt_cooldown
	lw   $t1, 0($t0)
	blez $t1, ue_cooldown_done
	addiu $t1, $t1, -1
	sw   $t1, 0($t0)
ue_cooldown_done:
	# Only move on selected frames
	la   $t0, frame_counter
	lw   $t1, 0($t0)
	li   $t2, ENEMY_MOVE_PERIOD
	div  $t1, $t2
	mfhi $t3
	bne  $t3, $zero, ue_after_move

	la   $t0, enemy_count
	lw   $t1, 0($t0)
	la   $t4, enemies          # ptr
	li   $t5, 0                # i
ue_loop:
	bge  $t5, $t1, ue_after_move
	move $a0, $t4              # a0 = ptr to enemy entry
	jal  move_enemy_entry
	addiu $t4, $t4, ENEMY_SIZE
	addiu $t5, $t5, 1
	j    ue_loop

ue_after_move:
	jal  check_player_enemy_collisions

	POP($t5)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# move_enemy_entry(ptr=a0) ; steps one enemy with simple right-turn roaming and respects bomb/solid tiles
move_enemy_entry:
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
	PUSH($s0)
	PUSH($s1)
	PUSH($s2)
	PUSH($s3)

	move $s0, $a0              # s0 = ptr
	lw   $t0, 12($s0)          # active?
	beq  $t0, $zero, mee_done

	# old state
	lw   $s1, 0($s0)           # old_x
	lw   $s2, 4($s0)           # old_y
	lw   $s3, 8($s0)           # dir

	li   $t9, 0                # attempt counter
mee_try_dir:
	bge  $t9, 4, mee_stay

	# candidate = old
	move $t1, $s1              # cand_x
	move $t2, $s2              # cand_y

	li   $t3, DIR_UP
	beq  $s3, $t3, mee_dir_up
	li   $t3, DIR_DOWN
	beq  $s3, $t3, mee_dir_down
	li   $t3, DIR_LEFT
	beq  $s3, $t3, mee_dir_left
	j    mee_dir_right

# -----------------------------------------------------------------------------
# set_enemy_position(index=a0, x=a1, y=a2) ; updates enemy coordinates if index valid
set_enemy_position:
    PUSH($ra)
    PUSH($t0)
    PUSH($t1)
    PUSH($t2)

    la   $t0, enemy_count
    lw   $t1, 0($t0)
    bge  $a0, $t1, sep_done   # if index >= count, return

    la   $t0, enemies
    li   $t2, ENEMY_SIZE
    mul  $t2, $a0, $t2        # offset = index * ENEMY_SIZE
    addu $t0, $t0, $t2        # t0 = &enemies[index]

    sw   $a1, 0($t0)          # set x
    sw   $a2, 4($t0)          # set y

sep_done:
    POP($t2)
    POP($t1)
    POP($t0)
    POP($ra)
    jr   $ra
mee_dir_up:
	addiu $t2, $t2, -ENEMY_STEP
	j    mee_post_dir
mee_dir_down:
	addiu $t2, $t2,  ENEMY_STEP
	j    mee_post_dir
mee_dir_left:
	addiu $t1, $t1, -ENEMY_STEP
	j    mee_post_dir
mee_dir_right:
	addiu $t1, $t1,  ENEMY_STEP

mee_post_dir:
	# clamp to bounds
	bltz $t1, mee_blocked
	bltz $t2, mee_blocked
	li   $t4, MAX_X
	bgt  $t1, $t4, mee_blocked
	li   $t4, MAX_Y
	bgt  $t2, $t4, mee_blocked

	# check collision with map walls
	move $a0, $t1
	move $a1, $t2
	jal  can_move_to
	beq  $v0, $zero, mee_blocked

	# treat active bomb as a wall (AABB collision for 5x5 sprites)
	lw   $t5, bomb_active
	beq  $t5, $zero, mee_move_ok
	lw   $t6, bomb_x
	lw   $t7, bomb_y
	# Check X-axis overlap: cand_x < bomb_x + 5 AND cand_x + 5 > bomb_x
	# If cand_x >= bomb_x + 5, no overlap (enemy is to the right)
	addiu $t8, $t6, SPR_W          # t8 = bomb_x + 5
	bge  $t1, $t8, mee_move_ok
	# If cand_x + 5 <= bomb_x, no overlap (enemy is to the left)
	addiu $t8, $t1, SPR_W          # t8 = cand_x + 5
	ble  $t8, $t6, mee_move_ok
	# Check Y-axis overlap: cand_y < bomb_y + 5 AND cand_y + 5 > bomb_y
	# If cand_y >= bomb_y + 5, no overlap (enemy is below)
	addiu $t8, $t7, SPR_H          # t8 = bomb_y + 5
	bge  $t2, $t8, mee_move_ok
	# If cand_y + 5 <= bomb_y, no overlap (enemy is above)
	addiu $t8, $t2, SPR_H          # t8 = cand_y + 5
	ble  $t8, $t7, mee_move_ok
	# Both axes overlap - enemy would collide with bomb
	j    mee_blocked

mee_move_ok:
	# Restore old background under enemy
	move $a0, $s1
	move $a1, $s2
	jal  restore_rect_5x5

	# Redraw bomb if it was on old rect
	lw   $t5, bomb_active
	beq  $t5, $zero, mee_skip_old_bomb
	lw   $t6, bomb_x
	lw   $t7, bomb_y
	bne  $t6, $s1, mee_skip_old_bomb
	bne  $t7, $s2, mee_skip_old_bomb
	move $a0, $t6
	move $a1, $t7
	jal  draw_bomb_sprite
mee_skip_old_bomb:

	# Redraw player if it was on old rect
	lw   $t6, player_x
	lw   $t7, player_y
	bne  $t6, $s1, mee_skip_old_player
	bne  $t7, $s2, mee_skip_old_player
	move $a0, $t6
	move $a1, $t7
	jal  draw_player_sprite
mee_skip_old_player:

	# Commit new state
	sw   $t1, 0($s0)
	sw   $t2, 4($s0)
	sw   $s3, 8($s0)

	# Draw enemy at new position
	move $a0, $t1
	move $a1, $t2
	jal  draw_enemy_sprite

	# If bomb overlaps new tile, draw it on top
	lw   $t5, bomb_active
	beq  $t5, $zero, mee_skip_new_bomb
	lw   $t6, bomb_x
	lw   $t7, bomb_y
	bne  $t6, $t1, mee_skip_new_bomb
	bne  $t7, $t2, mee_skip_new_bomb
	move $a0, $t6
	move $a1, $t7
	jal  draw_bomb_sprite
mee_skip_new_bomb:
	# If player overlaps new tile, draw player on top
	lw   $t6, player_x
	lw   $t7, player_y
	bne  $t6, $t1, mee_done
	bne  $t7, $t2, mee_done
	move $a0, $t6
	move $a1, $t7
	jal  draw_player_sprite
	j    mee_done

mee_blocked:
	# rotate dir right: (dir + 1) % 4
	addiu $s3, $s3, 1
	andi  $s3, $s3, 3
	addiu $t9, $t9, 1
	j     mee_try_dir

mee_stay:
	sw   $s3, 8($s0)

mee_done:
	POP($s3)
	POP($s2)
	POP($s1)
	POP($s0)
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

# init_enemies_positions ; resets initial positions/active flags for all enemies
init_enemies_positions:
	PUSH($ra)
	
	# Set enemy 0 position
	li   $a0, 0                # index
	li   $a1, 114              # x
	li   $a2, 21               # y
	jal  set_enemy_position

	# Set enemy 1 position
	li   $a0, 1                # index
	li   $a1, 9                # x
	li   $a2, 121              # y
	jal  set_enemy_position

	# Set enemy 2 position
	li   $a0, 2                # index
	li   $a1, 50               # x
	li   $a2, 60               # y
	jal  set_enemy_position

	# Set all enemies as active (alive)
	la   $t0, enemies
	li   $t1, 1                # active value
	li   $t2, 0                # i = 0
	la   $t3, enemy_count
	lw   $t4, 0($t3)           # count
iep_active_loop:
	bge  $t2, $t4, iep_active_done
	li   $t5, ENEMY_SIZE
	mul  $t6, $t2, $t5
	addu $t7, $t0, $t6         # &enemies[i]
	sw   $t1, 12($t7)          # set active
	addiu $t2, $t2, 1
	j    iep_active_loop
iep_active_done:

	POP($ra)
	jr   $ra
