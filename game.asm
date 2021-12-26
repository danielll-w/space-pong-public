; #########################################################################
;
;   game.asm - Assembly file for EECS205 Assignment 4/5
;
;
; #########################################################################

;Author: Dan Weiss
;Creation Date: 3/12/2018
;Project: Space Pong (Pong Clone)

      .586
      .MODEL FLAT,STDCALL
      .STACK 4096
      option casemap :none  ; case sensitive

include stars.inc
include lines.inc
include trig.inc
include blit.inc
include game.inc
include user32.inc
include windows.inc
include winmm.inc
includelib winmm.lib
include masm32.inc
includelib masm32.lib

;; Has keycodes
include keys.inc

	
.DATA
;Players 1 and 2 initialized with Player struct (x position,y position,velocity,Bitmap address)
P1 Player <100,240,27,OFFSET Player1>
P2 Player <539,240,27,OFFSET Player2> 

;Ball initialized with Ball struct (x position, y position,x velocity,y velocity,Bitmap address)
B BallInfo <320,240,-13,0,OFFSET Ball>

;Player Scores and variable to keep track of winner of last point
P1Score DWORD 0
P2Score DWORD 0
lpWinner DWORD ?

;Score Strings
fmtScore1 BYTE "Player1: %d", 0
fmtScore2 BYTE "Player2: %d", 0
outStr BYTE 256 Dup(0)

;Pause logical (1 if on,-1 if not)
Pause DWORD -1

;Titlescreen logical (1 if on,-1 if not)
TitleScreenStatus DWORD -1

;Sound bytes
SndPathWallHit BYTE "wallhit.wav",0
SndPathPaddleHit BYTE "paddlehit.wav",0
SndPathScore BYTE "score.wav",0

;Variables that keep track of scrolling background (2 bitmaps where one is above the other and they are drawn at new positions each update)
SpaceTracker Player <320,240,0,OFFSET space>
SpaceTracker2 Player <320,-240,0,OFFSET space2>

;Random constant used to create dissolve effect by choosing to call DrawPixel or not
CONST DWORD 640

;Dissolvescreen variables
DissolveOn DWORD 1 ;One if on and 0 if off
dissolveInterval DWORD 0 ;Dissolve interval begins at 0 and 
randConstant DWORD 1

;Win variables
WinPause DWORD 1
P1Win DWORD 0
P2Win DWORD 0

.CODE
	

;; Note: You will need to implement CheckIntersect!!!

GameInit PROC
	rdtsc			;generate seed for random number generator to be later used in dissolving the title screen
	INVOKE nseed, eax
	mov DissolveOn,1
	ret         ;; Do not delete this line!!!
GameInit ENDP


GamePlay PROC
	
	;Start by showing title screen until spacebar is hit
	
	mov eax,TitleScreenStatus
	cmp eax,1
	je DISSOLVE
	
	INVOKE ClearScreen
	INVOKE BasicBlit,OFFSET titlescreen,320,240
	mov eax,KeyPress
	cmp eax,20h
	
	jne DONE
	mov TitleScreenStatus,1
	
	;Dissolve title screen and then start game
	
	DISSOLVE:
	mov eax,DissolveOn
	cmp eax,1			;If DissolveOn equals 1, move on to check for winner
	jne WinCheck
	
	;Loop through and draw pixels at random points becoming less and likely to be drawn as game updates
	INVOKE ClearScreen
	INVOKE RandomBlit,OFFSET titlescreen,320,240,randConstant
	
	;update randConsant after certain number of updates
	mov eax,dissolveInterval
	cmp dissolveInterval,1
	jle INTERVALNOTMET
	
	add randConstant,1
	mov dissolveInterval,0
	mov eax,8
	cmp randConstant,eax
	jg STOPDISSOLVE
	jmp DONE
	
	INTERVALNOTMET:	
		add dissolveInterval,1
	jmp DONE
	
	STOPDISSOLVE:	
		mov DissolveOn,0 ;0 moved into dissolve to stop dissolving

	;Keep game paused during win until spacebar hit to restart game
	
	WinCheck:
	mov eax,WinPause
	cmp eax,1		;if WinPause equals 1, start game but otherwise keep winscreen up
	je START
	
	INVOKE ClearScreen
	mov eax,P1Win
	cmp eax,1
	jne P2WON ;Draw Win Screen for player 1 if player 1 won, otherwise draw screen for player 2
	
	INVOKE BasicBlit,OFFSET WinScreen1,320,240
	INVOKE BasicBlit,OFFSET RussClipped,320,240
	jmp KEYCHECK
	P2WON:
	INVOKE BasicBlit,OFFSET WinScreen2,320,240
	INVOKE BasicBlit,OFFSET RussClipped,320,240
	
	KEYCHECK:		;Check key to see if spacebar hit (if so, game restarts at 0 to 0)
	mov eax,KeyPress
	cmp eax,20h
	jne DONE
	mov WinPause,1
	mov P1Score,0
	mov P2Score,0
	mov P1Win,0
	mov P2Win,0
	INVOKE ResetGame
	jmp DONE

	;Draw the updated screen
	START:
	INVOKE ClearScreen
	INVOKE BasicBlit,OFFSET space,SpaceTracker.x,SpaceTracker.y
	INVOKE BasicBlit,OFFSET space2,SpaceTracker2.x,SpaceTracker2.y
	INVOKE DrawLine,319,0,319,479,0ffffh
	INVOKE BasicBlit,OFFSET Player1,P1.x,P1.y
	INVOKE BasicBlit,OFFSET Player2,P2.x,P2.y
	INVOKE BasicBlit,OFFSET Ball,B.x,B.y

	;Draw the scores for each player
	;Score 1
	push P1Score
	push offset fmtScore1
	push offset outStr
	call wsprintf
	add esp,12
	INVOKE DrawStr,offset outStr,225,30,0ffh
	
	;Score 2
	push P2Score
	push offset fmtScore2
	push offset outStr
	call wsprintf
	add esp,12
	INVOKE DrawStr,offset outStr,335,30,0ffh

	;Check for pause
	
	PAUSE:
	mov eax,KeyPress
	cmp KeyPress,50h	;If p hit on keyboard, pause or unpause game
	je PAUSESTATUS
	
	jmp PAUSECHECK
	
	PAUSESTATUS:
	neg Pause

	PAUSECHECK:
		mov eax,Pause
		cmp eax,1		;If Pause equals 1, keep game paused and keep drawing same screen
		je DONE

	
	;Move the ball
	mov eax,B.vx
	add B.x,eax
	mov eax,B.vy
	add B.y,eax

	;Move the Screen
	add SpaceTracker.y,1
	add SpaceTracker2.y,1

	;Check if either screen bitmap needs to be moved to a new location
	mov eax,SpaceTracker.y
	cmp eax,720
	jg MOVEONE
	mov eax,SpaceTracker2.y
	cmp eax,720
	jg MOVETWO
	jmp DOWN

	MOVEONE:
		mov SpaceTracker.y,-240
		jmp DOWN

	MOVETWO:
		mov SpaceTracker2.y,-240
	
	;Check for up and down arrow key presses (controlling player 1)
	;or right and left mouse clicks (controlling player 2) and add velocity accordingly
	
	DOWN:
	mov eax,KeyPress
	cmp eax, 28h
	jne UP
		mov eax,P1.y
		cmp eax,410
		jg UP
		mov eax,P1.v
		add P1.y,eax
		jmp RIGHTCLICK
	
	UP:
	cmp eax,26h
	jne RIGHTCLICK
		mov eax,P1.y
		cmp eax,40
		jl RIGHTCLICK
		mov eax,P1.v
		sub P1.y,eax
		
	
	RIGHTCLICK:
		mov eax, MouseStatus.buttons
		cmp eax,0001h
		jne LEFTCLICK
		mov eax,P2.y
		cmp eax,410
		jg LEFTCLICK
		mov eax,P2.v
		add P2.y,eax
		jmp CHECKINTERSECT
	
	LEFTCLICK:
		mov eax, MouseStatus.buttons
		cmp eax,0002h
		jne CHECKINTERSECT
		mov eax,P2.y
		cmp eax,40
		jl CHECKINTERSECT
		mov eax,P2.v
		sub P2.y,eax
	
	;Check intersect between ball and a player and change the direction of the ball after a collision with screen or paddle
	
	CHECKINTERSECT:
		INVOKE CheckIntersect,P1.x,P1.y,OFFSET Player1,B.x,B.y,OFFSET Ball
		mov ebx,0
		cmp eax,1
		je INTERSECT
		INVOKE CheckIntersect,P2.x,P2.y,OFFSET Player2,B.x,B.y,OFFSET Ball
		mov ebx,1
		cmp eax,1
		jne CHECKSCREENCOLLISION
	INTERSECT:
		neg B.vx
		INVOKE PlaySound, offset SndPathPaddleHit, 0, SND_ASYNC
		cmp ebx,0
		je P1hit
		INVOKE BallPaddleCollision,P2.y,B.y
		mov B.vy,eax
		jmp DONE
		P1hit:
		INVOKE BallPaddleCollision,P1.y,B.y
		mov B.vy,eax

	;Check to see if ball hits top of the screen or sides (point scored if sides hit)
	
	;Checks to see if ball hits top or bottom of screen and negate y velocity if so
	CHECKSCREENCOLLISION:
		INVOKE BallScreenCollision,B.x,B.y
		cmp eax,1
		je BOUNCE
		jmp POINTSCORE
	
	BOUNCE:
		neg B.vy
		INVOKE PlaySound, offset SndPathWallHit, 0, SND_ASYNC ;Play wallhit sound
		jmp DONE
	
	;Checks to see if ball gets past one of the paddles and if so, we reset after the point and increment the winner's score
	POINTSCORE:
		mov eax,B.x
		mov lpWinner,0
		cmp eax,0
		jle RESET
		mov lpWinner,1
		cmp eax,639
		jge RESET
		jmp DONE

	;If ball gets past, call reset function that increments score and resets the game screen
	;Then checks if a player has gotten to 11 and resets the whole game
	RESET:
		INVOKE ResetAfterPoint
		INVOKE PlaySound, offset SndPathScore, 0, SND_ASYNC ;Sound played for winning a point
		mov eax,11
		cmp P1Score,eax
		jge P1WINS
		cmp P2Score,eax
		jge P2WINS
		jmp DONE
	P1WINS:
		mov WinPause,-1
		mov P1Win,1
	P2WINS:
		mov WinPause,-1
		mov P2Win,1
	DONE:
	ret         ;; Do not delete this line!!!
GamePlay ENDP

CheckIntersect PROC USES ebx ecx edx edi oneX:DWORD,oneY:DWORD,oneBitmap:PTR EECS205BITMAP,twoX:DWORD,twoY:DWORD,twoBitmap:PTR EECS205BITMAP
	LOCAL uloneX:DWORD,uloneY:DWORD,ultwoX:DWORD,ultwoY:DWORD,broneX:DWORD,broneY:DWORD,brtwoX:DWORD,brtwoY:DWORD

	;Pointers to each input's bitmaps put into registers
	mov edx,oneBitmap
	mov edi,twoBitmap

	;Get upper left corner coordinates of first bitmap
	mov eax,(EECS205BITMAP PTR[edx]).dwWidth
	sar eax,1
	mov ebx,oneX
	sub ebx,eax
	mov uloneX,ebx
	

	mov eax,(EECS205BITMAP PTR[edx]).dwHeight
	sar eax,1
	mov ebx,oneY
	sub ebx,eax
	mov uloneY,ebx

	;Get upper left corner coordinates of second bitmap
	mov eax,(EECS205BITMAP PTR[edi]).dwWidth
	sar eax,1
	mov ebx,twoX
	sub ebx,eax
	mov ultwoX,ebx
	sub ultwoX,10

	mov eax,(EECS205BITMAP PTR[edi]).dwHeight
	sar eax,1
	mov ebx,twoY
	sub ebx,eax
	mov ultwoY,ebx



	;Get bottom right corner coordinates of first bitmap
	mov eax,(EECS205BITMAP PTR[edx]).dwWidth
	sar eax,1
	mov ebx,oneX
	add ebx,eax
	mov broneX,ebx
	

	mov eax,(EECS205BITMAP PTR[edx]).dwHeight
	sar eax,1
	mov ebx,oneY
	add ebx,eax
	mov broneY,ebx

	;Get bottom right corner coordinates of second bitmap
	mov eax,(EECS205BITMAP PTR[edi]).dwWidth
	sar eax,1
	mov ebx,twoX
	add ebx,eax
	mov brtwoX,ebx
	add brtwoX,10

	mov eax,(EECS205BITMAP PTR[edi]).dwHeight
	sar eax,1
	mov ebx,twoY
	add ebx,eax
	mov brtwoY,ebx

	



	;Using upper left and bottom right coordinates of each bitmap
	;to check for collisions

	mov eax,uloneX
	cmp eax,brtwoX
	jg NOTINTERSECTING

	mov eax,ultwoX
	cmp eax,broneX
	jg NOTINTERSECTING

	mov eax,uloneY
	cmp eax,brtwoY
	jg NOTINTERSECTING
	
	mov eax,ultwoY
	cmp eax,broneY
	jg NOTINTERSECTING

	;Return 0 if a collision does not occur and vice versa
	mov eax,1
	jmp DONE

	NOTINTERSECTING:
		mov eax,0
	DONE:
	ret
CheckIntersect ENDP

ClearScreen PROC
	;ClearScreen draws black into each pixel of the backbuffer using str commands
	mov eax,0
	mov edi,ScreenBitsPtr
	mov ecx,480*640
	cld
	REP STOSb
	ret
ClearScreen ENDP

;Ball paddle collision takes the difference between the ball y coordinate and the paddle y coordinate
;The y speed of the ball is set to this difference so the ball bounces at an angle when hitting away from the center of the paddle

BallPaddleCollision PROC USES ebx edx paddleY:DWORD,ballY:DWORD
	mov ebx,ballY
	sub ebx,paddleY
	mov eax,ebx
	
	;If difference is 0, keep ball y velocity at 0
	;Otherwise, if greater than 0, subtract off a constant from difference between ball and paddle y coords
	cmp eax,0
	jg POS

	cmp eax,0
	jl NEGATIVE

	cmp eax,0
	je EXIT
	POS:
		sub eax,10
		cmp eax,12
		jle EXIT
		mov eax,12
		jmp EXIT
	NEGATIVE:
		add eax,10
		cmp eax,-12
		jge EXIT
		mov eax,-9
	EXIT:
	ret
BallPaddleCollision ENDP

;BallScreenCollision checks if the ball hits the top or bottom of the screen and returns a 1 if so

BallScreenCollision PROC ballx:DWORD,ballY:DWORD
	mov eax,ballY
	cmp eax,0
	jle SCREENCOLLISION
	cmp eax,445
	jge SCREENCOLLISION
	
	mov eax,0
	jmp DONE

	SCREENCOLLISION:
		mov eax,1
	DONE:
	ret
BallScreenCollision ENDP

;ResetAfterPoint increments a player's score based on who won the last point and resets
;all the positions for the next point

ResetAfterPoint PROC
	
	;Based on who won last point, increment that player's score
	
	cmp lpWinner,0
	je P1POINT
	cmp lpWinner,1
	je P2POINT
	
	P1POINT:
		inc P2Score
		jmp RESETPOSITIONS
	P2POINT:
		inc P1Score
		
	
	RESETPOSITIONS:
	mov P1.x,100
	mov P1.y,240
	mov P2.x,539
	mov P2.y,240
	mov B.x,320
	mov B.y,240
	mov B.vy,0	
	ret
ResetAfterPoint ENDP

;ResetGame is called when either player wins and sets all positions back to original without implementing score

ResetGame PROC
	mov P1.x,100
	mov P1.y,240
	mov P2.x,539
	mov P2.y,240
	mov B.x,320
	mov B.y,240
	mov B.vy,0
	ret
ResetGame ENDP


;Random blit is an altered version of BasicBlit that loops through a bitmap randomly drawing pixels if a randomly generated constant is equal to 1

RandomBlit PROC USES ebx ecx edx esi edi ptrBitmap:PTR EECS205BITMAP , xcenter:DWORD, ycenter:DWORD,randConst:DWORD
      LOCAL ulx:DWORD,uly:DWORD,tempulx:DWORD,tempuly:DWORD,counter:DWORD,colorLength:DWORD
	
	;Store address of bitmap in esi
	mov esi, ptrBitmap
	
	;Store size of color array
	mov eax,(EECS205BITMAP PTR[esi]).dwWidth
	mul (EECS205BITMAP PTR[esi]).dwHeight
	mov colorLength,eax

	;Put values of beginning of bitmap (e.g. arguments are a center point and this sets the upper left hand corner of the bitmap as the initial x and y)

	;Subtract dwWidth/2 from xcenter and store in variables called ulx (upper left x) and tempulx
	mov ebx,(EECS205BITMAP PTR[esi]).dwWidth
	sar ebx,1
	mov ecx,xcenter
	sub ecx,ebx
	mov ulx,ecx
	mov tempulx,ecx
 
	;Subtract dwHeight/2 from y center and store in variables called uly (upper left y) and tempuly
	mov ebx,(EECS205BITMAP PTR[esi]).dwHeight
	sar ebx,1
	mov ecx,ycenter
	sub ecx,ebx
	mov uly,ecx
	mov tempuly,ecx

	;LOOP through each coordinate of the bitmap drawing the appropriate color or not drawing if color is equal to the transparency color

	mov counter,0 ;Counter to keep track of how many bytes from address for first color value

	mov edi,(EECS205BITMAP PTR[esi]).lpBytes	;address of beginning of color array
	
	;Nested for loop to go through all coordinates
	jmp XCOND
	XVALS:
		INVOKE nrandom,randConst
		add eax,1
		cmp eax,1
		jne DONTDRAW ;Check if random constant is equal to 1 and do not draw if so
	
		mov eax,counter
		cmp eax,colorLength
		jge DONTDRAW
		
		mov al,BYTE PTR [edi+eax]			;get color counter bytes away from beginning and put into al
		mov cl,(EECS205BITMAP PTR [esi]).bTransparent	;compare with transparent value and don't draw if the same
		cmp cl,al
		je DONTDRAW
		INVOKE DrawPixel,ulx,uly,al			;draw the pixel at the current location with the apppropraite color
	DONTDRAW:
		mov eax,1
		add ulx,eax
		add counter,eax
	XCOND:							;if current x value is less than the upper left plus the width, increment the y coordinate
								;and jump to condition that checks if y is less than the upper left y plus the height
		mov ebx,(EECS205BITMAP PTR[esi]).dwWidth
		add ebx,tempulx
		cmp ulx,ebx	
		jl XVALS
		inc uly
		jmp YCOND
	RESETX:
		mov eax,tempulx					;resets current xvalue for next iteration of inner for loop
		mov ulx,eax
		jmp XVALS
	YCOND:							;if current y is greater than the height of the bitmap, the loop ends
								;otherwise, jump to RESETX, reset the current x coordinate, and keep drawing in XVALS branch
		mov ebx,(EECS205BITMAP PTR[esi]).dwHeight
		add ebx,tempuly
		cmp uly,ebx
		jl RESETX
	ret 			; Don't delete this line!!!	
RandomBlit ENDP
END