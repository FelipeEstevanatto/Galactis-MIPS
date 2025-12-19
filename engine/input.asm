
.data
	pending_key: .word 0    # Stores non-pause keys read during pause check
	
.text
# wait_for_key ; blocks until a key is pressed, returns ASCII in $v0
wait_for_key:
poll_key:
	lw  $t0, KBD_CTRL
	andi $t0, $t0, 1        # check "key available" bit
	beq $t0, $zero, poll_key

	lw  $v0, KBD_DATA       # consume key (ASCII in $v0)
	jr  $ra

# read_key_nb ; returns pending_key or non-blocking KBD_DATA (v0=0 if none)
read_key_nb:
	# First check if there's a pending key from pause check
	lw   $v0, pending_key
	beq  $v0, $zero, check_keyboard
	
	# Clear pending key and return it
	sw   $zero, pending_key
	jr   $ra

check_keyboard:
	lw   $t0, KBD_CTRL
	andi $t0, $t0, 1
	beq  $t0, $zero, no_key
	lw   $v0, KBD_DATA
	jr   $ra
no_key:
	move $v0, $zero
	jr   $ra

# wait_for_key_or_exit: blocks until a key is pressed, returns ASCII in $v0
# If E or e is pressed, exits the program cleanly
wait_for_key_or_exit:
poll_key_exit:
	lw   $t0, KBD_CTRL
	andi $t0, $t0, 1        # check "key available" bit
	beq  $t0, $zero, poll_key_exit

	lw   $v0, KBD_DATA      # consume key (ASCII in $v0)

	# Check for exit key (E or e)
	li   $t0, KEY_E
	beq  $v0, $t0, do_exit
	li   $t0, KEY_E_UPPER
	beq  $v0, $t0, do_exit

	jr   $ra                # return with key in $v0

do_exit:
	clearScreen()
	li   $v0, 10            # syscall code for exit
	syscall
