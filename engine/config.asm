# Engine configuration constants
.eqv SCREEN_W 128
.eqv SCREEN_H 128
.eqv TOTAL_PIXELS 16384         # SCREEN_W * SCREEN_H = 128 * 128
.eqv SPR_W 5
.eqv SPR_H 5
.eqv MAX_X 123
.eqv MAX_Y 123
.eqv BITMAP_BASE 0x1000

# Color definitions
.eqv COLOR_BLACK 0x000000
.eqv WALL_COLOR 0x00081C63
.eqv BREKABLE_COLOR 0x0026775E
.eqv BREKABLE_COLOR2 0x000AA978
.eqv HIDDEN_SQUARE_X 79
.eqv HIDDEN_SQUARE_Y 61

# Directions
.eqv DIR_UP    0
.eqv DIR_DOWN  1
.eqv DIR_LEFT  2
.eqv DIR_RIGHT 3

# INPUT
.eqv KBD_CTRL  0xffff0000
.eqv KBD_DATA  0xffff0004
.eqv KEY_W 119
.eqv KEY_A 97
.eqv KEY_S 115
.eqv KEY_D 100
.eqv KEY_SPACE 32
.eqv KEY_ENTER 13
.eqv KEY_P 112                     # 'p' key for pause (ESC doesn't work in MARS MMIO)
.eqv KEY_P_UPPER 80                # 'P' uppercase key for pause
.eqv KEY_E 101                     # 'e' key for exit
.eqv KEY_E_UPPER 69                # 'E' uppercase key for exit

# Game timing
.eqv FRAME_DELAY 50000
.eqv FRAME_DELAY_SHORT 500         # small utility busy-wait (frame_delay helper)
.eqv FRAMES_PER_SECOND 60          # main loop divider for 1s updates
.eqv BOMB_TIMER_SECONDS 3
.eqv EXPLOSION_FLASH_DELAY 15000   # explosion animation wait

# Enemy configuration
.eqv ENEMY_COLOR 0x00FF0000 # Red
.eqv ENEMY_SIZE 16          # 4 words per enemy entry
.eqv ENEMY_STEP 1           # move 1 pixel per step (player/enemy movement is pixel-based)
.eqv ENEMY_MOVE_PERIOD 2    # move enemies every N frames (tune for speed)
.eqv PLAYER_HURT_COOLDOWN_FRAMES 30  # i-frames after taking damage
.eqv ENEMY_POINTS 50      # points per enemy defeated

# Pause screen constants
.eqv DARKEN_DIVISOR 5           # Divide RGB by 5 for 80% darkening (keeping 20% brightness)

# Macro to push/pop registers
.macro PUSH(%r)
  addiu $sp, $sp, -4
  sw    %r, 0($sp)
.end_macro

.macro POP(%r)
  lw    %r, 0($sp)
  addiu $sp, $sp, 4
.end_macro

# Macro to call a distant label
.macro CALL(%label)
  la   $t9, %label
  jalr $t9
.end_macro

# Print integer in register to terminal (DEBUG)
.macro print_int_reg(%reg)
  li $v0, 1
  move $a0, %reg
  syscall
  # Print newline
  li $v0, 11
  li $a0, 10
  syscall
.end_macro

# Print immediate integer to terminal (DEBUG)
.macro print_int_imm(%imm)
  li $v0, 1
  li $a0, %imm
  syscall
  # Print newline
  li $v0, 11
  li $a0, 10
  syscall
.end_macro
