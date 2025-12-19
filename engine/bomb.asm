# Bomb system
# Handles bomb placement, rendering, and explosion logic
.data
	# Bomb state
	bomb_active: .word 0
	bomb_x: .word 0
	bomb_y: .word 0
	bomb_timer: .word 0

	# 5x5 bomb sprite with colors (0 = transparent)
	# Colors: 1=dark gray, 2=medium gray, 3=red (fuse), 4=orange (highlight)
	bomb_sprite:
	.byte 0,0,3,0,0
	.byte 2,1,4,1,2
	.byte 1,4,1,2,1
	.byte 1,4,1,1,1
	.byte 0,1,1,1,0
	
	# Color palette for bomb
	bomb_colors:
	.word 0x00000000  # 0: transparent
	.word 0x00202020  # 1: dark gray
	.word 0x00606060  # 2: medium gray
	.word 0x00FF0000  # 3: red (fuse)
	.word 0x00A0A0A0  # 4: light gray (highlight)

	# Explosion animation colors
	.eqv EXPLOSION_COLOR_WHITE  0x00FFFFFF
	.eqv EXPLOSION_COLOR_ORANGE 0x00FF8000

	# Buffer to store explosion tile positions for animation
	# Format: x1, y1, x2, y2, ... (max 13 tiles = center + 3 in each direction * 4 directions)
	# Count is tracked via explosion_tile_count
	explosion_tiles: .space 104  # 13 tiles * 2 coords * 4 bytes = 104 bytes
	explosion_tile_count: .word 0

.text
# v0 = is_door_color(color=a0) ; checks color against drawDoor_sprite palette
is_door_color:
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	
	la   $t0, drawDoor_sprite  # door sprite pointer
	li   $t1, 25               # 25 pixels (5x5)
	
idc_loop:
	beqz $t1, idc_not_found
	lw   $t2, 0($t0)           # load door color
	beq  $a0, $t2, idc_found   # match found
	addiu $t0, $t0, 4          # next color
	addiu $t1, $t1, -1
	j    idc_loop

idc_found:
	li   $v0, 1
	j    idc_done

idc_not_found:
	li   $v0, 0

idc_done:
	POP($t2)
	POP($t1)
	POP($t0)
	jr   $ra

# flash_delay ; busy-wait used by explosion animation (clobbers t0)
flash_delay:
	PUSH($t0)
	li   $t0, EXPLOSION_FLASH_DELAY
fd_flash_loop:
	addiu $t0, $t0, -1
	bgtz $t0, fd_flash_loop
	POP($t0)
	jr   $ra

# flash_5x5_tile(x=a0, y=a1, color=a2) ; fills 5x5 tile if inside bounds
flash_5x5_tile:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)
	PUSH($t6)
	PUSH($t7)

	move $t4, $a0              # save x
	move $t5, $a1              # save y
	li   $t6, SCREEN_W         # load screen bounds once
	li   $t7, SCREEN_H
	
	li   $t0, 0                # row
f5_row:
	bge  $t0, 5, f5_done
	li   $t1, 0                # col
	
f5_col:
	bge  $t1, 5, f5_next_row
	
	# Calculate position
	addu $t2, $t4, $t1         # x + col
	addu $t3, $t5, $t0         # y + row
	
	# Check bounds
	bltz $t2, f5_skip
	bltz $t3, f5_skip
	bge  $t2, $t6, f5_skip
	bge  $t3, $t7, f5_skip
	
	# Draw pixel
	move $a0, $t2
	move $a1, $t3
	jal  set_pixel
	
	# Restore a0, a1 for next iteration
	move $a0, $t4
	move $a1, $t5
	
f5_skip:
	addiu $t1, $t1, 1
	j    f5_col
	
f5_next_row:
	addiu $t0, $t0, 1
	j    f5_row

f5_done:
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

# add_explosion_tile(x=a0, y=a1) ; appends coords to explosion_tiles buffer
add_explosion_tile:
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	
	la   $t0, explosion_tile_count
	lw   $t1, 0($t0)            # current count
	
	# Calculate offset: count * 8 (each tile is 2 words = 8 bytes)
	sll  $t2, $t1, 3
	la   $t0, explosion_tiles
	addu $t0, $t0, $t2
	
	# Store x and y
	sw   $a0, 0($t0)
	sw   $a1, 4($t0)
	
	# Increment count
	la   $t0, explosion_tile_count
	addiu $t1, $t1, 1
	sw   $t1, 0($t0)
	
	POP($t2)
	POP($t1)
	POP($t0)
	jr   $ra

# flash_all_explosion_tiles(color=a0) ; draws every buffered explosion tile using flash_5x5_tile
flash_all_explosion_tiles:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($s0)
	
	move $s0, $a0              # save color
	
	la   $t0, explosion_tile_count
	lw   $t1, 0($t0)           # count
	la   $t2, explosion_tiles  # ptr
	
faet_loop:
	beqz $t1, faet_done
	
	lw   $a0, 0($t2)           # x
	lw   $a1, 4($t2)           # y
	move $a2, $s0              # color
	jal  flash_5x5_tile
	
	addiu $t2, $t2, 8          # next tile (2 words)
	addiu $t1, $t1, -1
	j    faet_loop
	
faet_done:
	POP($s0)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# clear_explosion_tiles ; zeroes explosion_tile_count
clear_explosion_tiles:
	PUSH($t0)
	la   $t0, explosion_tile_count
	sw   $zero, 0($t0)
	POP($t0)
	jr   $ra

# draw_bomb_sprite(x=a0, y=a1) ; renders 5x5 bomb using palette colors, skips transparent
draw_bomb_sprite:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)

	la   $t0, bomb_sprite     # sprite pointer
	li   $t1, 0               # row

bs_row:
	bge  $t1, 5, bs_done
	li   $t2, 0               # col

bs_col:
	bge  $t2, 5, bs_next_row

	lbu  $t3, 0($t0)
	addiu $t0, $t0, 1
	beq  $t3, $zero, bs_skip   # transparent pixel

	# Get color from palette
	la   $t4, bomb_colors
	sll  $t5, $t3, 2           # multiply index by 4
	addu $t4, $t4, $t5
	lw   $a2, 0($t4)           # load color from palette

	# draw pixel at (x+col, y+row)
	addu $a0, $a0, $t2
	addu $a1, $a1, $t1
	jal  set_pixel

	subu $a0, $a0, $t2         # restore
	subu $a1, $a1, $t1

bs_skip:
	addiu $t2, $t2, 1
	j    bs_col

bs_next_row:
	addiu $t1, $t1, 1
	j    bs_row

bs_done:
	POP($t5)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# update_bomb_colors(timer=a0) ; adjusts bomb palette based on timer (5..1)
update_bomb_colors:
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	
	la   $t0, bomb_colors
	
	# Timer 5-4: Gray bomb
	# Timer 3-2: Orange tint
	# Timer 1: Bright red/orange
	
	li   $t1, 3
	bge  $a0, $t1, ubc_gray    # timer >= 3: gray
	li   $t1, 2  
	bge  $a0, $t1, ubc_orange  # timer >= 2: orange
	j    ubc_red               # timer 1: red

ubc_gray:
	# Gray bomb (starting state)
	li   $t1, 0x00303030
	sw   $t1, 4($t0)           # color 1: dark gray
	li   $t1, 0x00606060
	sw   $t1, 8($t0)           # color 2: medium gray
	li   $t1, 0x00909090
	sw   $t1, 16($t0)          # color 4: light gray
	j    ubc_done

ubc_orange:
	# Orange tint (danger approaching)
	li   $t1, 0x00603010
	sw   $t1, 4($t0)           # color 1: dark orange-gray
	li   $t1, 0x00A06020
	sw   $t1, 8($t0)           # color 2: orange-gray
	li   $t1, 0x00FFA040
	sw   $t1, 16($t0)          # color 4: bright orange
	j    ubc_done

ubc_red:
	# Bright red/orange (about to explode!)
	li   $t1, 0x00800000
	sw   $t1, 4($t0)           # color 1: dark red
	li   $t1, 0x00FF4000
	sw   $t1, 8($t0)           # color 2: red-orange
	li   $t1, 0x00FFFF00
	sw   $t1, 16($t0)          # color 4: yellow (hot!)

ubc_done:
	POP($t2)
	POP($t1)
	POP($t0)
	jr   $ra

# update_bomb_timer ; ticks active bomb, redraws sprite, triggers explosion when timer hits 0
update_bomb_timer:
	PUSH($ra)
	
	# Check if bomb is active
	lw   $t0, bomb_active
	beq  $t0, $zero, ubt_done
	
	# Decrement timer
	lw   $t0, bomb_timer
	
	# Debug: print timer value
	PUSH($a0)
	li $v0, 1
	move $a0, $t0
	syscall
	li $v0, 11
	li $a0, 10
	syscall
	POP($a0)
	
	addiu $t0, $t0, -1
	sw   $t0, bomb_timer
	
	# Update bomb colors based on new timer value
	move $a0, $t0
	jal  update_bomb_colors
	
	# Check if player is on the bomb position
	lw   $t1, bomb_x
	lw   $t2, bomb_y
	lw   $t3, player_x
	lw   $t4, player_y
	
	# If player is on bomb, erase player first
	bne  $t1, $t3, ubt_no_player
	bne  $t2, $t4, ubt_no_player
	
	# Player is on bomb - erase player
	move $a0, $t3
	move $a1, $t4
	jal  restore_rect_5x5
	
ubt_no_player:
	# Erase old bomb
	lw   $a0, bomb_x
	lw   $a1, bomb_y
	jal  restore_rect_5x5
	
	# Redraw bomb with new colors
	lw   $a0, bomb_x
	lw   $a1, bomb_y
	jal  draw_bomb_sprite
	
	# Redraw player if they were on the bomb
	lw   $t1, bomb_x
	lw   $t2, bomb_y
	lw   $t3, player_x
	lw   $t4, player_y
	bne  $t1, $t3, ubt_check_timer
	bne  $t2, $t4, ubt_check_timer
	
	# Player is on bomb - redraw player on top
	move $a0, $t3
	move $a1, $t4
	jal  draw_player_sprite
	
ubt_check_timer:
	# Check if timer reached 0
	lw   $t0, bomb_timer
	bne  $t0, $zero, ubt_done
	
	# Timer reached 0, explode bomb
	# First, erase player from screen to avoid capturing it in background
	lw   $a0, player_x
	lw   $a1, player_y
	jal  restore_rect_5x5
	jal  explode_bomb
	# explode_bomb returns $v0 = 1 if player was hit
	beqz $v0, ubt_no_death
	
	# Player died in explosion
	jal  handle_player_death
	
ubt_no_death:
	# Redraw player after explosion
	lw   $a0, player_x
	lw   $a1, player_y
	jal  draw_player_sprite

ubt_done:
	POP($ra)
	jr   $ra

# v0 = place_bomb() ; arms bomb at player_x/player_y if inactive and draws it
place_bomb:
	PUSH($ra)
	
	# Check if bomb already active
	lw   $t0, bomb_active
	bne  $t0, $zero, pb_already_active
	
	# Activate bomb
	li   $t0, 1
	sw   $t0, bomb_active
	
	# Set bomb timer (5 seconds at 1 update per second)
	li   $t0, BOMB_TIMER_SECONDS
	sw   $t0, bomb_timer
	
	# Set bomb position at player's current location
	lw   $t0, player_x
	sw   $t0, bomb_x
	lw   $t0, player_y
	sw   $t0, bomb_y
	
	# Initialize bomb colors to gray (timer = 5)
	li   $a0, 5
	jal  update_bomb_colors
	
	# Just draw the bomb on top of player (don't mess with background)
	lw   $a0, bomb_x
	lw   $a1, bomb_y
	jal  draw_bomb_sprite
	
	li   $v0, 1            # Success
	j    pb_done

pb_already_active:
	li   $v0, 0            # Failed, bomb already active

pb_done:
	POP($ra)
	jr   $ra

# handle_player_death ; decrements lives, respawns player, shows game over at 0
handle_player_death:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	
	# Get current lives
	la   $t0, lives_value
	lw   $t1, 0($t0)
	
	# Check if already dead (lives = 0)
	beqz $t1, hpd_done
	
	# Decrement lives
	addiu $t1, $t1, -1
	sw   $t1, 0($t0)
	
	# Respawn at start position (4, 21)
	li   $t0, 4
	la   $t1, player_x
	sw   $t0, 0($t1)
	la   $t1, prev_player_x
	sw   $t0, 0($t1)
	
	li   $t0, 21
	la   $t1, player_y
	sw   $t0, 0($t1)
	la   $t1, prev_player_y
	sw   $t0, 0($t1)
	
	# Update HUD to show new lives
	jal  draw_hud
	
	# Check if game over (lives = 0)
	la   $t0, lives_value
	lw   $t1, 0($t0)
	bnez $t1, hpd_done         # Still has lives, just respawn
	
	# Game Over - lives reached 0
	jal  show_game_over        # Call game over screen function
	
hpd_done:
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# check_player_in_explosion: checks if player is in 5x5 tile at (a0, a1)
# Returns: $v0 = 1 if player hit, 0 otherwise
check_player_in_explosion:
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)
	
	move $t0, $a0              # explosion tile x
	move $t1, $a1              # explosion tile y
	
	# Get player position
	la   $t2, player_x
	lw   $t3, 0($t2)
	la   $t2, player_y
	lw   $t4, 0($t2)
	
	# Check if player's 5x5 sprite strictly overlaps with this explosion tile
	# Use strict inequality to exclude diagonal (corner-only) overlaps
	# No hit if: player_x >= tile_x + 5 || player_x + 5 <= tile_x
	#         || player_y >= tile_y + 5 || player_y + 5 <= tile_y
	
	# Check X overlap (strict - no corner/diagonal contact)
	addu $t5, $t0, 5           # tile_x + 5
	bge  $t3, $t5, cpie_no_hit # player_x >= tile_x + 5 -> no overlap

	addu $t5, $t3, 5           # player_x + 5
	ble  $t5, $t0, cpie_no_hit # player_x + 5 <= tile_x -> no overlap

	# Check Y overlap (strict - no corner/diagonal contact)
	addu $t5, $t1, 5           # tile_y + 5
	bge  $t4, $t5, cpie_no_hit # player_y >= tile_y + 5 -> no overlap

	addu $t5, $t4, 5           # player_y + 5
	ble  $t5, $t1, cpie_no_hit # player_y + 5 <= tile_y -> no overlap
	
	# Player is hit!
	li   $v0, 1
	j    cpie_done
	
cpie_no_hit:
	li   $v0, 0
	
cpie_done:
	POP($t5)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	jr   $ra

# destroy_5x5_tile: destroys a 5x5 tile of non-wall pixels
# Input: $a0 = x, $a1 = y (top-left corner of 5x5 tile)
# Output: $v0 = 1 if continued (no wall), 0 if hit wall (stop)
# Two-pass approach: first check for walls, then destroy if no walls found
destroy_5x5_tile:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)
	
	move $t0, $a0              # save x
	move $t1, $a1              # save y
	
	# === PASS 1: Check for any wall pixels ===
	li   $t2, 0                # row
d5_check_row:
	bge  $t2, 5, d5_no_wall_found
	li   $t3, 0                # col
	
d5_check_col:
	bge  $t3, 5, d5_check_next_row
	
	# Calculate position
	addu $t4, $t0, $t3         # x + col
	addu $t5, $t1, $t2         # y + row
	
	# Check bounds
	bltz $t4, d5_check_skip
	bltz $t5, d5_check_skip
	li   $a2, SCREEN_W
	bge  $t4, $a2, d5_check_skip
	li   $a2, SCREEN_H
	bge  $t5, $a2, d5_check_skip
	
	# Get pixel
	move $a0, $t4
	move $a1, $t5
	jal  get_pixel
	
	# Check if wall
	li   $a2, 0x00FFFFFF
	and  $v0, $v0, $a2
	li   $a2, WALL_COLOR
	bne  $v0, $a2, d5_check_skip
	
	# Hit a wall - stop immediately, don't destroy anything
	li   $v0, 0
	j    d5_done
	
d5_check_skip:
	addiu $t3, $t3, 1
	j    d5_check_col
	
d5_check_next_row:
	addiu $t2, $t2, 1
	j    d5_check_row

d5_no_wall_found:
	# === PASS 2: Destroy non-door pixels (no walls in this tile) ===
	li   $t2, 0                # row
d5_destroy_row:
	bge  $t2, 5, d5_success
	li   $t3, 0                # col
	
d5_destroy_col:
	bge  $t3, 5, d5_destroy_next_row
	
	# Calculate position
	addu $t4, $t0, $t3         # x + col
	addu $t5, $t1, $t2         # y + row
	
	# Check bounds
	bltz $t4, d5_destroy_skip
	bltz $t5, d5_destroy_skip
	li   $a2, SCREEN_W
	bge  $t4, $a2, d5_destroy_skip
	li   $a2, SCREEN_H
	bge  $t5, $a2, d5_destroy_skip
	
	# Get pixel
	move $a0, $t4
	move $a1, $t5
	jal  get_pixel
	
	# Check if door color - skip to preserve door visibility
	li   $a2, 0x00FFFFFF
	and  $a0, $v0, $a2         # mask alpha and pass color to is_door_color
	jal  is_door_color
	bnez $v0, d5_destroy_skip  # skip if door color
	
	# Destroy this pixel (set to black)
	move $a0, $t4
	move $a1, $t5
	li   $a2, COLOR_BLACK
	jal  set_pixel
	
d5_destroy_skip:
	addiu $t3, $t3, 1
	j    d5_destroy_col
	
d5_destroy_next_row:
	addiu $t2, $t2, 1
	j    d5_destroy_row

d5_success:
	# No wall found, return 1 (continue explosion)
	li   $v0, 1
	
d5_done:
	POP($t5)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# explode_bomb ; animates cross-shaped blast, destroys tiles, updates enemies, v0=1 if player hit
explode_bomb:
	PUSH($ra)
	PUSH($s0)
	PUSH($s1)
	PUSH($s2)
	PUSH($s3)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)

	lw   $t0, bomb_x
	lw   $t1, bomb_y
	li   $s0, 0                # player hit flag
	li   $s1, 0                # enemy kill count
	move $s2, $t0              # save bomb_x in s2
	move $s3, $t1              # save bomb_y in s3

	# Clear the explosion tiles buffer
	jal  clear_explosion_tiles

	# Erase bomb sprite first
	move $a0, $s2
	move $a1, $s3
	jal  restore_rect_5x5

	# Erase enemies before modifying the map so they don't get captured into bg_buffer
	jal  erase_all_enemies

	# ========== PHASE 1: Collect tiles, check player/enemy hits ==========
	
	# Add bomb center tile
	move $a0, $s2
	move $a1, $s3
	jal  add_explosion_tile

	# Check player hit at center
	move $a0, $s2
	move $a1, $s3
	jal  check_player_in_explosion
	or   $s0, $s0, $v0

	# Kill enemies at center
	move $a0, $s2
	move $a1, $s3
	jal  kill_enemies_in_explosion
	addu $s1, $s1, $v0

	# Collect LEFT tiles
	li   $t2, 0                # tile counter
eb_collect_left:
	bge  $t2, 3, eb_collect_right
	move $t3, $t2
	sll  $t3, $t3, 2
	addu $t3, $t3, $t2         # t3 = t2 * 5
	subu $t4, $s2, $t3
	addi $t4, $t4, -5
	
	# Check if this tile hits a wall (using can_destroy_tile)
	move $a0, $t4
	move $a1, $s3
	jal  can_destroy_tile
	beqz $v0, eb_collect_right # wall hit, stop going left
	
	# Add tile to buffer
	move $a0, $t4
	move $a1, $s3
	jal  add_explosion_tile
	
	# Check player hit
	move $a0, $t4
	move $a1, $s3
	jal  check_player_in_explosion
	or   $s0, $s0, $v0
	
	# Kill enemies
	move $a0, $t4
	move $a1, $s3
	jal  kill_enemies_in_explosion
	addu $s1, $s1, $v0
	
	addiu $t2, $t2, 1
	j    eb_collect_left

eb_collect_right:
	li   $t2, 0
eb_collect_right_loop:
	bge  $t2, 3, eb_collect_up
	move $t3, $t2
	sll  $t3, $t3, 2
	addu $t3, $t3, $t2         # t3 = t2 * 5
	addu $t4, $s2, $t3
	addi $t4, $t4, 5
	
	move $a0, $t4
	move $a1, $s3
	jal  can_destroy_tile
	beqz $v0, eb_collect_up
	
	move $a0, $t4
	move $a1, $s3
	jal  add_explosion_tile
	
	move $a0, $t4
	move $a1, $s3
	jal  check_player_in_explosion
	or   $s0, $s0, $v0
	
	move $a0, $t4
	move $a1, $s3
	jal  kill_enemies_in_explosion
	addu $s1, $s1, $v0
	
	addiu $t2, $t2, 1
	j    eb_collect_right_loop

eb_collect_up:
	li   $t2, 0
eb_collect_up_loop:
	bge  $t2, 3, eb_collect_down
	move $t3, $t2
	sll  $t3, $t3, 2
	addu $t3, $t3, $t2         # t3 = t2 * 5
	subu $t5, $s3, $t3
	addi $t5, $t5, -5
	
	move $a0, $s2
	move $a1, $t5
	jal  can_destroy_tile
	beqz $v0, eb_collect_down
	
	move $a0, $s2
	move $a1, $t5
	jal  add_explosion_tile
	
	move $a0, $s2
	move $a1, $t5
	jal  check_player_in_explosion
	or   $s0, $s0, $v0
	
	move $a0, $s2
	move $a1, $t5
	jal  kill_enemies_in_explosion
	addu $s1, $s1, $v0
	
	addiu $t2, $t2, 1
	j    eb_collect_up_loop

eb_collect_down:
	li   $t2, 0
eb_collect_down_loop:
	bge  $t2, 3, eb_animate
	move $t3, $t2
	sll  $t3, $t3, 2
	addu $t3, $t3, $t2         # t3 = t2 * 5
	addu $t5, $s3, $t3
	addi $t5, $t5, 5
	
	move $a0, $s2
	move $a1, $t5
	jal  can_destroy_tile
	beqz $v0, eb_animate
	
	move $a0, $s2
	move $a1, $t5
	jal  add_explosion_tile
	
	move $a0, $s2
	move $a1, $t5
	jal  check_player_in_explosion
	or   $s0, $s0, $v0
	
	move $a0, $s2
	move $a1, $t5
	jal  kill_enemies_in_explosion
	addu $s1, $s1, $v0
	
	addiu $t2, $t2, 1
	j    eb_collect_down_loop

eb_animate:
	# ========== PHASE 2: Flash animation ==========
	# Flash white
	li   $a0, EXPLOSION_COLOR_WHITE
	jal  flash_all_explosion_tiles
	jal  flash_delay
	
	# Flash orange
	li   $a0, EXPLOSION_COLOR_ORANGE
	jal  flash_all_explosion_tiles
	jal  flash_delay
	
	# Flash white again
	li   $a0, EXPLOSION_COLOR_WHITE
	jal  flash_all_explosion_tiles
	jal  flash_delay
	
	# Flash orange again
	li   $a0, EXPLOSION_COLOR_ORANGE
	jal  flash_all_explosion_tiles
	jal  flash_delay

	# ========== PHASE 3: Destroy all collected tiles ==========
	la   $t0, explosion_tile_count
	lw   $t1, 0($t0)           # count
	la   $t2, explosion_tiles  # ptr

eb_destroy_loop:
	beqz $t1, eb_done
	
	lw   $a0, 0($t2)           # x
	lw   $a1, 4($t2)           # y
	jal  destroy_5x5_tile      # destroy tile (return value ignored here)
	
	addiu $t2, $t2, 8          # next tile
	addiu $t1, $t1, -1
	j    eb_destroy_loop

eb_done:
	# Deactivate bomb
	sw   $zero, bomb_active
	sw   $zero, bomb_timer

	# Scoring:
	# - +1 for every bomb explosion
	# - +50 for every enemy killed in the explosion
	li   $a0, 1
	jal  add_score

	beqz $s1, eb_no_kill_score
	li   $t0, ENEMY_POINTS
	mult $s1, $t0
	mflo $a0
	jal  add_score
eb_no_kill_score:

	# Recapture background after explosion
	jal  capture_bg
	# Redraw hidden door square (it may now be visible if breakable tiles were destroyed)
	jal  draw_hidden_square
	# Copy door from bg_buffer to screen so it becomes visible
	li   $a0, HIDDEN_SQUARE_X
	li   $a1, HIDDEN_SQUARE_Y
	jal  restore_rect_5x5
	# Redraw enemies on top of the new background (destroyed tiles are now part of bg_buffer)
	jal  redraw_all_enemies

	# Return player hit status
	move $v0, $s0

	POP($t5)
	POP($t4)
	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($s3)
	POP($s2)
	POP($s1)
	POP($s0)
	POP($ra)
	jr   $ra

# can_destroy_tile: checks if a 5x5 tile can be destroyed (no walls)
# Input: $a0 = x, $a1 = y
# Output: $v0 = 1 if can destroy (no wall), 0 if wall present
can_destroy_tile:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)
	PUSH($t4)
	PUSH($t5)
	PUSH($t6)
	PUSH($t7)
	
	move $t0, $a0              # save x
	move $t1, $a1              # save y
	li   $t6, SCREEN_W         # load screen bounds once
	li   $t7, SCREEN_H
	
	li   $t2, 0                # row
cdt_row:
	bge  $t2, 5, cdt_can_destroy
	li   $t3, 0                # col
	
cdt_col:
	bge  $t3, 5, cdt_next_row
	
	addu $t4, $t0, $t3         # x + col
	addu $t5, $t1, $t2         # y + row
	
	# Check bounds
	bltz $t4, cdt_skip
	bltz $t5, cdt_skip
	bge  $t4, $t6, cdt_skip
	bge  $t5, $t7, cdt_skip
	
	# Get pixel
	move $a0, $t4
	move $a1, $t5
	jal  get_pixel
	
	# Check if wall
	li   $a2, 0x00FFFFFF
	and  $v0, $v0, $a2
	li   $a2, WALL_COLOR
	bne  $v0, $a2, cdt_skip
	
	# Hit a wall - return 0
	li   $v0, 0
	j    cdt_done
	
cdt_skip:
	addiu $t3, $t3, 1
	j    cdt_col
	
cdt_next_row:
	addiu $t2, $t2, 1
	j    cdt_row

cdt_can_destroy:
	li   $v0, 1
	
cdt_done:
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
