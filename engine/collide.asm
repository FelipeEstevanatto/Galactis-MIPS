# v0 = can_move_to(x=a0, y=a1) ; checks SPR_W x SPR_H area for any blocked color
can_move_to:
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

	move $t2, $a0              # baseX
	move $t3, $a1              # baseY

	li   $t0, 0                # row
cm_row:
	bge  $t0, SPR_H, cm_ok

	li   $t1, 0                # col
cm_col:
	bge  $t1, SPR_W, cm_nextrow

	addu $a0, $t2, $t1         # x = baseX + col
	addu $a1, $t3, $t0         # y = baseY + row
	jal  get_pixel

	# keep only 00RRGGBB
	li   $t8, 0x00FFFFFF
	and  $v0, $v0, $t8

	# ---- palette check: if pixel matches any entry => blocked ----
	la   $t4, COLLISION_PALETTE          # t4 = &palette[0]
	la   $t7, COLLISION_PALETTE_LEN      # t7 = &len
	lw   $t5, 0($t7)                     # t5 = len
cm_pal_loop:
	beqz $t5, cm_pal_done       # exhausted palette -> not blocked

	lw   $t6, 0($t4)            # palette color (00RRGGBB)
	beq  $v0, $t6, cm_blocked   # match => cannot move

	addiu $t4, $t4, 4           # next palette entry
	addiu $t5, $t5, -1
	j    cm_pal_loop

cm_pal_done:
	# -------------------------------------------------------------

	addiu $t1, $t1, 1
	j    cm_col

cm_nextrow:
	addiu $t0, $t0, 1
	j    cm_row

cm_blocked:
	move $v0, $zero            # false
	j    cm_done

cm_ok:
	li   $v0, 1                # true

cm_done:
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
