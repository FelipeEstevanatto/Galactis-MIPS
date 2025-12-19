.text
.globl main # Workaround for MARS not recognizing main as entry point
j main
nop
# SCREEN SPRITES/BACKGROUNDS
.include "sprites/menuSprite.asm"
.include "sprites/mapSprite.asm"
.include "sprites/clearScreen.asm"
.include "sprites/gameoverScreen.asm"
.include "sprites/victoryScreen.asm"
.include "sprites/tutorialScreen.asm"

# ENGINE MODULES
.include "engine/gfx.asm"
.include "engine/hud.asm"
.include "engine/collide.asm"
.include "engine/input.asm"
.include "engine/bomb.asm"
.include "engine/player.asm"
.include "engine/enemy.asm"

.data
	.align 2
	# Colors that should block movement (00RRGGBB)
	COLLISION_PALETTE:
		.word 0x00081C63      # WALL_COLOR
		.word 0x0026775E      # BREKABLE_COLOR
		.word 0x000AA978      # BREKABLE_COLOR2
	.align 2
	COLLISION_PALETTE_LEN:
		.word 3

	lives_value: .word 3
	score_value: .word 99
	time_value: .word 0
	frame_counter: .word 0    # Counts frames for timing
	
	# Pause state buffer (stores original screen before darkening)
	.align 2
	pause_buffer: .space 65536  # TOTAL_PIXELS * 4 = 128*128*4 bytes for screen backup
.text
# main ; entry point sets HUD defaults, shows menu/tutorial, then runs game loop (uses s0 as bitmap base)
main:
	lui $s0, BITMAP_BASE	# Set base address for bitmap display in the upper 16 bits (0x10000000)
	
	# Set score and lives to initial values
	li  $a0, 3
	jal set_lives
	li  $a0, 0
	jal set_score
	li  $a0, 0
	jal set_time

	# Menu -> Tutorial loop
menu_loop:
	drawMenu()
	jal wait_for_key_or_exit # blocks until a key is pressed (E exits)

	# Show tutorial screen after menu
	tutorialScreen()

	# Tutorial input:
	# - E/e: go back to menu
	# - Enter (ASCII 10): start game
	# - Any other key: keep waiting
tutorial_wait:
	jal wait_for_key          # blocks until a key is pressed, ASCII in $v0
	li  $t0, KEY_E
	beq $v0, $t0, menu_loop
	li  $t0, KEY_E_UPPER
	beq $v0, $t0, menu_loop
	li  $t0, 10               # Enter in this environment (line feed)
	beq $v0, $t0, start_game
	j   tutorial_wait

start_game:
	# 1. Draw Map
	drawMap()

	# 2. CAPTURE BACKGROUND BEFORE DRAWING PLAYER
	# This ensures the buffer contains the clean map, not the player.
	jal capture_bg

	# 2.2 Draw hidden door square to bg_buffer
	jal draw_hidden_square

	# 2.1 Init enemies (data-driven) and draw them on top of map
	jal init_enemies

	# 3. Init player position
	li  $t0, 4
	sw  $t0, player_x
	li  $t0, 21
	sw  $t0, player_y

	# 3.1 Init Enemy positions
	jal init_enemies_positions

	lw  $a0, player_x
	lw  $a1, player_y
	jal draw_player_sprite

	# 5. Draw initial HUD
	jal  draw_hud

game_loop:
	# Simple busy-wait delay to slow down the loop
	li   $t9, FRAME_DELAY
delay_loop:
	addiu $t9, $t9, -1
	bgtz $t9, delay_loop
	
	# Increment frame counter and check for bomb timer update
	lw   $t0, frame_counter
	addiu $t0, $t0, 1
	sw   $t0, frame_counter
	
	# Only update bomb timer every FRAMES_PER_SECOND frames (~1 second with delay)
	li   $t1, FRAMES_PER_SECOND
	div  $t0, $t1
	mfhi $t0                      # remainder
	bne  $t0, $zero, skip_bomb_timer_update
	
	# Update time (increment every second)
	jal  increment_time
	
	# Update bomb timer (handles explosion automatically)
	jal  update_bomb_timer
	
	# Redraw HUD to show updated time
	jal  draw_hud

skip_bomb_timer_update:
	jal update_player
	jal update_enemies

	# small delay to control speed (optional)
	jal frame_delay
	j   game_loop

# pause_game ; saves bitmap to pause_buffer, darkens, shows text, waits for P/p, then restores (clobbers t0-t3)
pause_game:
	PUSH($ra)
	PUSH($t0)
	PUSH($t1)
	PUSH($t2)
	PUSH($t3)

	# 1. Save current screen to pause_buffer
	lui  $t0, BITMAP_BASE       # src = bitmap
	la   $t1, pause_buffer      # dst = pause_buffer
	li   $t2, TOTAL_PIXELS      # 128*128 = 16384 pixels

save_screen_loop:
	lw   $t3, 0($t0)
	sw   $t3, 0($t1)
	addiu $t0, $t0, 4
	addiu $t1, $t1, 4
	addiu $t2, $t2, -1
	bne  $t2, $zero, save_screen_loop

	# 2. Darken the screen by 80%
	jal  darken_screen

	# 3. Draw "PAUSE" text in white
	jal  draw_pause_text

	# 4. Wait for P key to resume (handles both 'p' and 'P')
wait_for_p:
	jal wait_for_key        # blocks until a key is pressed, ASCII in $v0
	li   $t1, KEY_P
	beq  $v0, $t1, pause_resume
	li   $t1, KEY_P_UPPER
	beq  $v0, $t1, pause_resume
	j    wait_for_p            # not P, keep waiting

pause_resume:
	# 5. Restore screen from pause_buffer
	la   $t0, pause_buffer      # src = pause_buffer
	lui  $t1, BITMAP_BASE       # dst = bitmap
	li   $t2, TOTAL_PIXELS      # 128*128 = 16384 pixels

restore_screen_loop:
	lw   $t3, 0($t0)
	sw   $t3, 0($t1)
	addiu $t0, $t0, 4
	addiu $t1, $t1, 4
	addiu $t2, $t2, -1
	bne  $t2, $zero, restore_screen_loop

	POP($t3)
	POP($t2)
	POP($t1)
	POP($t0)
	POP($ra)
	jr   $ra

# frame_delay ; short busy-wait used to slow the main loop (clobbers t0)
frame_delay:
	li  $t0, FRAME_DELAY_SHORT
fd_loop:
	addiu $t0, $t0, -1
	bne $t0, $zero, fd_loop
	jr  $ra

# show_game_over ; renders game over screen and waits for Enter, draws score_value (loops back to main)
show_game_over:
	# Clear screen
	gameOverScreen()

	# Draw Score on Gameover screen
	# score at (x=75, y=95)
	li   $a0, 75
	li   $a1, 95
	la   $t0, score_value
	lw   $a2, 0($t0)
	li   $a3, 0x00FFFFFF
	jal  draw_number_3x5_right

	# Wait for ENTER to go back to menu, or E to exit
go_wait_for_enter:
	jal wait_for_key_or_exit # blocks until a key is pressed (E exits)
	li   $t0, 10             # ASCII code for Enter (line feed)
	bne  $v0, $t0, go_wait_for_enter
	j   main

	# Exit program (in MARS, this will close the window)
	li   $v0, 10
	syscall
