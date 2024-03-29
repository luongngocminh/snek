
RS 						EQU P1.7
EN						EQU P1.6
DISPLAY_PORT 			EQU P0
VCC 					EQU P2
GND 					EQU P3
KEYPAD_PORT 			EQU P1
REG_6 					EQU 06
REG_5 					EQU 05
REG_4 					EQU 04
REG_3 					EQU 03		
REG_2 					EQU 02
REG_1 					EQU 01
REG_0 					EQU 00
TEMP 					EQU 28H
STEMP 					EQU 29H

SCORE 					EQU 2AH
	
GAME_OVER 				EQU 2BH
	
SNAKE_LENGTH_PTR 		EQU 30H
	
SNAKE_DIR 				EQU 31H
	
SNAKE_NEXT_DIR 			EQU 32H
	
SNAKE_TAIL 				EQU 33H
	
INITIAL_LENGTH_SNAKE 	EQU 2D
	
INITIAL_SNAKE_DIR 		EQU 2D
	
CURR_KEY_STATES 		EQU 00FH
	
KEY_MASK_0 				EQU 00000001B
KEY_MASK_1 				EQU 00000010B
KEY_MASK_2 				EQU 00000100B
KEY_MASK_3 				EQU 00001000B
ANY_KEY_MASK			EQU 00001111B
		
DISP_START_ADDR 		EQU 20H
DISP_END_ADDR 			EQU 27H

; 0 - up
; 1 - right
; 2 - down
; 3 - left

MAIN: 
	ACALL _setup

	loop: 
	MOV CURR_KEY_STATES, KEYPAD_PORT
	LCALL _get_input_update_new_direction
	ACALL _clear_display_buffer
	ACALL _set_snake
	ACALL _place_snake_egg
	ACALL _update_head
	ACALL _check_if_head_coincides_with_egg
	ACALL _update_snake_array
	ACALL _check_if_snake_ate_itself
	JZ over
	ACALL _display
	SJMP loop
	
	over: 
	MOV R7, #08H
	show_dead_again:
	ACALL _display
	ACALL _delay
	DJNZ R7, show_dead_again
	ACALL _delay
	MOV VCC, #00H
	MOV GND, #00H

	check_again_end: 
		MOV CURR_KEY_STATES, KEYPAD_PORT
		MOV A, #ANY_KEY_MASK
		ACALL A_detect_key_press
		JZ check_again_end
SJMP MAIN

; because display get data from DISP_START_ADDR to DISP_END_ADDR 
; (this region is called display buffer)
; to clear screen, this function will loop 8 times and set all the bytes
; from this region to 00H
_clear_display_buffer:
	MOV R2, #8
	MOV R0, #DISP_START_ADDR
	start:
	MOV @R0, #00H
	INC R0
	DJNZ R2, start
RET

; Initialize the data when start up
_setup:
	MOV GAME_OVER, #0FFH
	MOV SCORE, #0
	MOV KEYPAD_PORT, #0FFH
	ACALL _clear_display_buffer

	MOV R0, #SNAKE_LENGTH_PTR
	MOV @R0, #INITIAL_LENGTH_SNAKE ; initial size of snake
	
	MOV SNAKE_DIR, #INITIAL_SNAKE_DIR
	MOV SNAKE_NEXT_DIR, #2
	
	ACALL lcd_init
	ACALL _welcome_message
	
	check_again: 
	MOV CURR_KEY_STATES, KEYPAD_PORT
	MOV A, #ANY_KEY_MASK
	ACALL A_detect_key_press
	JZ check_again
	
	MOV DPTR, #SCORE_MESSAGE
	; set the initial position of snake to (x,y)
	MOV 33H, #35H ; tail (3,5)
	MOV 34H, #45H ; head (4,5)
RET

; set the snake position into the display buffer for display using _convert_and_set_bit
_set_snake: 
	MOV R0, #SNAKE_LENGTH_PTR
	MOV A, @R0
	MOV R3, A

	MOV R0, #SNAKE_TAIL
	next_byte:
	MOV A, @R0
	INC R0
	; the purpose of these push pop function is to save the current value
	; of R0 and R3 into the stack, so _convert_and_set_bit won't change
	; to these register values when it is being used
	PUSH REG_0
	PUSH REG_3
	ACALL _convert_and_set_bit
	POP REG_3
	POP REG_0
	DJNZ R3, next_byte
RET

; 
_update_head:
	MOV A, #SNAKE_TAIL
	ADD A, SNAKE_LENGTH_PTR
	DEC A
	
	MOV R0, A
	MOV A, @R0
	
	MOV TEMP, @R0 ;initial head value, remember this because it will be used in _update_snake_array
	
	MOV R7, SNAKE_DIR
	up: CJNE R7, #0, right
	
		MOV R6, SNAKE_NEXT_DIR
		up_up:     
        CJNE R6, #0, up_right
				; do nothing
				ACALL _update_up ; 
				; do not update the current direction
				AJMP next_update
				
		up_right:  
        CJNE R6, #1, up_down
				ACALL _update_right
				; update the current direction
				MOV SNAKE_DIR, SNAKE_NEXT_DIR
				AJMP next_update
				
		up_down:   
        CJNE R6, #2, up_left
				; do nothing
				ACALL _update_up ; 
				; do not update the current direction
				AJMP next_update
				
		up_left: 
				ACALL _update_left
				; update the current direction
				MOV SNAKE_DIR, SNAKE_NEXT_DIR
				AJMP next_update
		AJMP next_update
		 
	right: CJNE R7, #1, down
		; direction is RIGHT
		; X--
				MOV R6, SNAKE_NEXT_DIR
		right_up:     CJNE R6, #0, right_right
				ACALL _update_up 
				; update the current direction
				MOV SNAKE_DIR, SNAKE_NEXT_DIR
				AJMP next_update
				
		right_right:  CJNE R6, #1, right_down
				ACALL _update_right
				; dont update the current direction
				AJMP next_update
				
		right_down:   CJNE R6, #2, right_left
				ACALL _update_down
				; update the current direction
				MOV SNAKE_DIR, SNAKE_NEXT_DIR
				AJMP next_update
				
		right_left:   CJNE R6, #3, next_update
				ACALL _update_right
				; dont update the current direction
				AJMP next_update
		AJMP next_update
	
	down: 
		CJNE R7, #2, left
		; direction is DOWN
		; Y++
				MOV R6, SNAKE_NEXT_DIR
		down_up:     CJNE R6, #0, down_right
				; do nothing
				ACALL _update_down 
				; dont update the current direction
				AJMP next_update
				
		down_right:  CJNE R6, #1, down_down
				ACALL _update_right
				; update the current direction
				MOV SNAKE_DIR, SNAKE_NEXT_DIR
				AJMP next_update
				
		down_down:   CJNE R6, #2, down_left
				; do nothing
				ACALL _update_down 
				; dont update the current direction 
				AJMP next_update
				
		down_left:   CJNE R6, #3, next_update
				ACALL _update_left
				; update the current direction
				MOV SNAKE_DIR, SNAKE_NEXT_DIR
				AJMP next_update
		AJMP next_update
		
	left:
		CJNE R7,#3,next_update
		; direction is left
		; X++
				MOV R6, SNAKE_NEXT_DIR
		left_up:     CJNE R6, #0, left_right
				ACALL _update_up 
				; update the current direction
				; update the current direction
				MOV SNAKE_DIR, SNAKE_NEXT_DIR
				AJMP next_update
				
		left_right:  CJNE R6, #1, left_down
				ACALL _update_left
				; dont update the current direction
				AJMP next_update
				
		left_down:   CJNE R6, #2, left_left
				ACALL _update_down 
				; update the current direction
				MOV SNAKE_DIR, SNAKE_NEXT_DIR
				AJMP next_update
				
		left_left:   CJNE R6, #3, next_update
				ACALL _update_left
				; dont update the current direction
				AJMP next_update
		AJMP next_update
		
	next_update: 	
	MOV STEMP, A
RET

; update each of the snake body bit's position when head position changed
_update_snake_array:
	MOV A, #SNAKE_TAIL
	ADD A, SNAKE_LENGTH_PTR
	DEC A
	MOV R0, A
	MOV @R0, STEMP ; write the new head value back to head location - egg logic later
	next_mem_loc:
	DEC R0
	MOV STEMP, @R0
	MOV @R0, TEMP
	MOV TEMP, STEMP
	CJNE R0, #SNAKE_TAIL, next_mem_loc
RET

; display the data from the display buffer DISP_START_ADDR
_display:

	MOV R6, #22H ; this value controls the speed of the snake
	again_2:
	MOV R2, #8
	MOV R3, #01H
	MOV R0, #DISP_START_ADDR 
	
	again: 
	MOV A, @R0
	INC R0
	CPL A
	MOV GND, A
	MOV VCC, R3

	MOV A, R3
	RL A
	MOV R3, A
	
	ACALL _delay_between_frame

	DJNZ R2, again
	DJNZ R6, again_2
return: RET

; Function: _update_right
; Description: X--
_update_right:
	PUSH REG_6
	PUSH 0E0H
	
	ANL A, #0FH
	JZ add_7
	DEC A
	SJMP dont_add
	add_7: 
	ADD A, #7D
	dont_add:
	MOV R6, A
	POP 0E0H
	ANL A, #0F0H
	ORL A, R6
	POP REG_6
RET

; Function: _update_up
; Description: Y--
_update_up:
	PUSH REG_6
	PUSH 0E0H
	ANL A, #0F0H
	SWAP A
	JZ add_right
	DEC A
	SJMP dont_add_right
	add_right:
	ADD A, #7
	dont_add_right:
	SWAP A
	MOV R6, A
	POP 0E0H
	ANL A, #0FH
	ORL A, R6
	POP REG_6
RET

; Function: _update_left
; Descsription: X++
_update_left:
	PUSH REG_6
	PUSH 0E0H
	ANL A, #0FH
	CJNE A, #07, dont_subtract
	CLR A
	SJMP dont_increment
	dont_subtract:
	INC A
	dont_increment:
	MOV R6,A
	POP 0E0H
	ANL A, #0F0H
	ORL A, R6
	POP REG_6
RET

; Function: _update_down
; Description: Y++
_update_down:
	PUSH REG_6
	PUSH 0E0H
	ANL A, #0F0H
	SWAP A
	CJNE A, #07, dont_subtract_left
	CLR A
	SJMP dont_increment_left
	dont_subtract_left:
	INC A
	dont_increment_left:
	SWAP A
	MOV R6, A
	POP 0E0H
	ANL A, #0FH
	ORL A, R6
	POP REG_6
RET

; Function: _convert_and_set_bit
; Arguments: A
; Description: Get the XY coordinate in A and set the corresponding bit where A = YX ( example: A = 24H = 00100100B <=> X = 4, Y = 2)
_convert_and_set_bit:
	PUSH 0E0H ;Push current value of A into the stack, which is the full coordinate
	ANL A, #0FH ;Mask A with 00001111 to get the X part of A
	MOV B, #DISP_START_ADDR
	ADD A, B ;Get the address where the byte represent the column at Xth column count from right start from 0
	MOV R0, A ;R0 now have the address above 

	POP 0E0H ;get back the full coordinate and set to A
	SWAP A ; ( ex: 0x25 => 0x52)
	ANL A, #0FH ;Mask A with 00001111 get the Y part of A
	MOV R3, A ;move Y onto R3

	MOV A, #01H ; 00000001

	back_up: ;this left shift A until 1 is at the Yth (count from 0) position of the byte (ex: if Y = 3 => A = 00001000) 
	RL A 
	DJNZ R3, back_up
	
	MOV TEMP, @R0 ;move the value in R0, which is the byte represent the current Xth column, into TEMP mem.
	ORL A, TEMP ;set the bit (A = 00001000, TEMP = 00000000 => the Yth = 3th bit will be set)
	MOV @R0, A ;save the new byte into memory
RET

; Description: Determines the next direction based on key press
_get_input_update_new_direction:
	input_right: 
	MOV A, #KEY_MASK_0
	LCALL A_detect_key_press
	JZ input_up
	MOV SNAKE_NEXT_DIR, #0
	RET
	
	input_up: 	
	MOV A, #KEY_MASK_1
	LCALL A_detect_key_press
	JZ input_left
	MOV SNAKE_NEXT_DIR, #1
	RET
	
	input_left: 
	MOV A, #KEY_MASK_2
	LCALL A_detect_key_press
	JZ input_down
	MOV SNAKE_NEXT_DIR, #2
	RET
	
	input_down: 
	MOV A, #KEY_MASK_3
	LCALL A_detect_key_press
	JZ return_get_input_new_direction
	MOV SNAKE_NEXT_DIR, #3

return_get_input_new_direction: RET

; Function: A_detect_key_press
; Description: Returns True in A if key is pressed
A_detect_key_press:
	; Save the current context on the stack
	PUSH REG_0
	PUSH PSW

	MOV R0, A
	MOV A, CURR_KEY_STATES
	CPL A
	ANL A, R0

	; Restore the previous context from the stack
	POP PSW
	POP REG_0
RET

; Function: _check_if_head_coincides_with_egg
; Description: This function checks if the snake has eaten the egg or not
_check_if_head_coincides_with_egg:
	MOV DPTR, #EGG_LOCATIONS
	MOV A, SCORE
	MOVC A, @A+DPTR
	MOV R4, A
	MOV A, #SNAKE_TAIL
	ADD A, SNAKE_LENGTH_PTR
	DEC A
	
	MOV R0, A
	MOV A, @R0
	
	XRL A, R4
	JNZ return_check_if_head
	INC SCORE
	INC SNAKE_LENGTH_PTR

return_check_if_head: RET

; Function: _place_snake_egg
; Description: Place the snake egg. Right now it is according to a fixed table of locations, 
;				further improvements can make it random
_place_snake_egg:
	MOV DPTR, #EGG_LOCATIONS
	MOV A, SCORE
	MOVC A, @A+DPTR
	ACALL _convert_and_set_bit
RET

; Function: _check_if_snake_ate_itself
; Description: The function checks if the snake ate itself or not
_check_if_snake_ate_itself:
	MOV A, #SNAKE_TAIL
	ADD A, SNAKE_LENGTH_PTR
	DEC A
	
	MOV R0, A
	MOV TEMP, @R0
	
	not_equal: 
	DEC R0
	MOV A, @R0
	XRL A, TEMP
	JZ its_game_over
	CJNE R0, #SNAKE_TAIL, not_equal
	RET
	its_game_over: 
	MOV GAME_OVER, #00H
RET
	
; Function: _delay_between_frame
; Description: Used for delay between each frame of display
_delay_between_frame:  
PUSH REG_4
PUSH REG_3
PUSH REG_2
MOV R4,#05H
WAIT1: MOV R3,#20H
WAIT2: MOV R2,#01H
WAIT3: DJNZ R2,WAIT3
        DJNZ R3,WAIT2
        DJNZ R4,WAIT1
POP REG_2
POP REG_3
POP REG_4
RET

_delay:  
	PUSH REG_4
	PUSH REG_3
	PUSH REG_2
	MOV R4,#01H
	WAIT_1: MOV R3,#60H
	WAIT_2: MOV R2,#00H
	WAIT_3: DJNZ R2,WAIT_3
			DJNZ R3,WAIT_2
			DJNZ R4,WAIT_1
	POP REG_2
	POP REG_3
	POP REG_4
RET

ORG 0800H
EGG_LOCATIONS: DB 43H, 23H, 15H, 67H, 50H, 33H, 47H, 03H, 25H, 15H, 26H, 52H, 77H, 27H, 56H, 64H, 32H, 55H, 38H, 13H, 11H, 17H, 43H, 23H, 15H, 67H, 50H, 33H, 47H, 03H, 25H, 15H, 26H, 52H, 77H, 27H, 56H, 64H, 32H, 55H, 38H, 13H, 11H, 17H
WELCOME_MESSAGE: DB "SNAKE GAME!",0
PRESS_KEY: DB "PRESS TO START",0
END_MESSAGE: DB "GAME OVER!", 0
SCORE_MESSAGE: DB "SCORE: ", 0
END