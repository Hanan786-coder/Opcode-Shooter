; FILE: bullets.asm
; ROLE: Bullet management, physics, and rendering
;
; RESPONSIBILITIES:
;   - Store bullet position (X, Y) and velocity for up to MAX_BULLETS per player
;   - Initialize bullet arrays at startup
;   - Update bullets each frame (move, deactivate if off-screen)
;   - Draw bullets as filled circles using a scanline rasterizer
;   - Fire bullets for both players
;
; BULLET DESIGN:
;   - Filled circle, radius 5 pixels (11 pixels diameter)
;   - Max 10 bullets per player
;   - Player 1 bullets: yellow (color 0Eh)
;   - Player 2 bullets: white  (color 0Fh)
;   - Bullet speed: 8 pixels/frame horizontally
;
; CIRCLE RASTERIZER (DrawBall):
;   Uses a pre-computed half-width table (BallHalfW).
;   For each scanline row, halfW = floor(sqrt(R^2 - dy^2)).
;   We fill pixels from (centerX-halfW) to (centerX+halfW).
;   IMPORTANT: the table is accessed via SI as the base register
;   so that [SI+BX] uses DS (the data segment), NOT SS (the stack
;   segment which BP-based addressing would use by default).

.MODEL SMALL

EXTRN PlayerX  : WORD
EXTRN PlayerY  : WORD
EXTRN Player2X : WORD
EXTRN Player2Y : WORD
EXTRN PlayerHealth : WORD
EXTRN Player2Health : WORD
EXTRN P1Shield : BYTE
EXTRN P2Shield : BYTE
EXTRN P1Ultra : BYTE
EXTRN P2Ultra : BYTE
EXTRN VideoSeg : WORD

PUBLIC InitBullets
PUBLIC UpdateBullets
PUBLIC DrawBullets
PUBLIC FireBulletPlayer1
PUBLIC FireBulletPlayer2
PUBLIC PlayerFacing
PUBLIC Player2Facing
PUBLIC FireCooldown1
PUBLIC FireCooldown2

; ---------------------------------------------------------------
; Equates
; ---------------------------------------------------------------
BULLET_RADIUS  EQU 3
BULLET_DIAM    EQU 7              ; 2*BULLET_RADIUS + 1
BULLET_SPEED   EQU 8
BULLET_COLOR1  EQU 0Eh            ; yellow
BULLET_COLOR2  EQU 0Fh            ; white
MAX_BULLETS    EQU 10
FIRE_COOLDOWN_MAX EQU 20          ; ~0.5 second at 30 FPS VSync rate

PLAYER_W       EQU 14
PLAYER_H       EQU 20
SCREEN_W       EQU 320
SCREEN_H       EQU 200

.DATA

BulletActive1  DB MAX_BULLETS DUP (0)
BulletX1       DW MAX_BULLETS DUP (0)
BulletY1       DW MAX_BULLETS DUP (0)
BulletVelX1    DW MAX_BULLETS DUP (0)

BulletActive2  DB MAX_BULLETS DUP (0)
BulletX2       DW MAX_BULLETS DUP (0)
BulletY2       DW MAX_BULLETS DUP (0)
BulletVelX2    DW MAX_BULLETS DUP (0)

PlayerFacing   DW 1
Player2Facing  DW 1

FireCooldown1  DW 0                ; frames remaining before P1 can fire again
FireCooldown2  DW 0                ; frames remaining before P2 can fire again

; Scratch var: current scanline Y inside DrawBall.
; Kept in memory so MUL (which destroys DX) cannot clobber it.
BallCurY       DW 0

; Pre-computed half-widths for a filled circle of radius 5.
; Index i (0..10) corresponds to dy = (i - BULLET_RADIUS) = -5..+5
; halfW = floor( sqrt(R*R - dy*dy) )
;
;  i  dy  dy^2  25-dy^2  halfW
;  0  -5   25      0       0
;  1  -4   16      9       3
;  2  -3    9     16       4
;  3  -2    4     21       4
;  4  -1    1     24       4
;  5   0    0     25       5
;  6  +1    1     24       4
;  7  +2    4     21       4
;  8  +3    9     16       4
;  9  +4   16      9       3
; 10  +5   25      0       0
BallHalfW  DB  0, 3, 4, 4, 4, 5, 4, 4, 4, 3, 0

.CODE

; ===============================================================
; InitBullets  -  zero all bullet arrays
; ===============================================================
InitBullets PROC NEAR
    PUSH AX
    PUSH CX
    PUSH DI
    PUSH ES

    MOV  AX, DS
    MOV  ES, AX            ; STOS writes ES:DI; point ES at data seg

    XOR  AX, AX

    MOV  CX, MAX_BULLETS
    LEA  DI, BulletActive1
    REP  STOSB

    MOV  CX, MAX_BULLETS
    LEA  DI, BulletX1
    REP  STOSW

    MOV  CX, MAX_BULLETS
    LEA  DI, BulletY1
    REP  STOSW

    MOV  CX, MAX_BULLETS
    LEA  DI, BulletVelX1
    REP  STOSW

    MOV  CX, MAX_BULLETS
    LEA  DI, BulletActive2
    REP  STOSB

    MOV  CX, MAX_BULLETS
    LEA  DI, BulletX2
    REP  STOSW

    MOV  CX, MAX_BULLETS
    LEA  DI, BulletY2
    REP  STOSW

    MOV  CX, MAX_BULLETS
    LEA  DI, BulletVelX2
    REP  STOSW

    POP  ES
    POP  DI
    POP  CX
    POP  AX
    RET
InitBullets ENDP

; ===============================================================
; FireBulletPlayer1  -  spawn a bullet for player 1
; ===============================================================
FireBulletPlayer1 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH SI

    ; Check cooldown – if still counting down, skip firing
    CMP  FireCooldown1, 0
    JA   FireExit1

    ; Ensure distance >= 10 pixels
    MOV  AX, PlayerX
    SUB  AX, Player2X
    JNS  DistPos1          ; if result non-negative keep
    NEG  AX                ; make positive
DistPos1:
    CMP  AX, 10
    JL   FireExit1

    XOR  BX, BX
FindFree1:
    CMP  BX, MAX_BULLETS
    JAE  FireExit1
    CMP  BulletActive1[BX], 0
    JE   GotSlot1
    INC  BX
    JMP  FindFree1

GotSlot1:
    MOV  BulletActive1[BX], 1

    MOV  SI, BX
    SHL  SI, 1              ; word index = slot * 2

    MOV  AX, PlayerY
    ADD  AX, PLAYER_H / 2 - 3
    MOV  BulletY1[SI], AX

    MOV  AX, PlayerFacing
    CMP  AX, 1
    JNE  P1GoLeft

    MOV  AX, PlayerX
    ADD  AX, PLAYER_W
    MOV  BulletX1[SI], AX
    MOV  BulletVelX1[SI], BULLET_SPEED
    JMP  P1FiredOk

P1GoLeft:
    MOV  AX, PlayerX
    SUB  AX, BULLET_RADIUS
    MOV  BulletX1[SI], AX
    MOV  AX, -BULLET_SPEED
    MOV  BulletVelX1[SI], AX

P1FiredOk:
    ; Reset cooldown after successful fire
    MOV  FireCooldown1, FIRE_COOLDOWN_MAX

FireExit1:
    POP  SI
    POP  BX
    POP  AX
    RET
FireBulletPlayer1 ENDP

; ===============================================================
; FireBulletPlayer2  -  spawn a bullet for player 2
; ===============================================================
FireBulletPlayer2 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH SI

    ; Check cooldown – if still counting down, skip firing
    CMP  FireCooldown2, 0
    JA   FireExit2

    ; Ensure distance >= 10 pixels
    MOV  AX, Player2X
    SUB  AX, PlayerX
    JNS  DistPos2
    NEG  AX
DistPos2:
    CMP  AX, 10
    JL   FireExit2

    XOR  BX, BX
FindFree2:
    CMP  BX, MAX_BULLETS
    JAE  FireExit2
    CMP  BulletActive2[BX], 0
    JE   GotSlot2
    INC  BX
    JMP  FindFree2

GotSlot2:
    MOV  BulletActive2[BX], 1

    MOV  SI, BX
    SHL  SI, 1

    MOV  AX, Player2Y
    ADD  AX, PLAYER_H / 2 - 3
    MOV  BulletY2[SI], AX

    MOV  AX, Player2Facing
    CMP  AX, 1
    JNE  P2GoLeft

    MOV  AX, Player2X
    ADD  AX, PLAYER_W
    MOV  BulletX2[SI], AX
    MOV  BulletVelX2[SI], BULLET_SPEED
    JMP  P2FiredOk

P2GoLeft:
    MOV  AX, Player2X
    SUB  AX, BULLET_RADIUS
    MOV  BulletX2[SI], AX
    MOV  AX, -BULLET_SPEED
    MOV  BulletVelX2[SI], AX

P2FiredOk:
    ; Reset cooldown after successful fire
    MOV  FireCooldown2, FIRE_COOLDOWN_MAX

FireExit2:
    POP  SI
    POP  BX
    POP  AX
    RET
FireBulletPlayer2 ENDP

; ===============================================================
; UpdateBullets  -  move bullets, deactivate if off-screen
; ===============================================================
UpdateBullets PROC NEAR
    PUSH AX
    PUSH BX
    PUSH SI

    ; Decrement fire cooldowns each frame (stop at 0)
    CMP  FireCooldown1, 0
    JE   CoolDone1
    DEC  FireCooldown1
CoolDone1:
    CMP  FireCooldown2, 0
    JE   CoolDone2
    DEC  FireCooldown2
CoolDone2:

    XOR  BX, BX
UpdP1:
    CMP  BX, MAX_BULLETS
    jb skip_b1           ; Jump if Below (opposite of JAE) to skip
        jmp UpdP2Start       ; Far jump to the label
    skip_b1:
    CMP  BulletActive1[BX], 0
    JE   UpdP1Next

    MOV  SI, BX
    SHL  SI, 1
    MOV  AX, BulletX1[SI]
    ADD  AX, BulletVelX1[SI]
    MOV  BulletX1[SI], AX

    CMP  AX, 0
    JL   DeactP1
    CMP  AX, SCREEN_W
    JGE  DeactP1

    ; --- Collision Check with P2 ---
    MOV  AX, BulletX1[SI]
    CMP  AX, Player2X
    JL   NoColP1
    MOV  DX, Player2X
    ADD  DX, PLAYER_W
    CMP  AX, DX
    JG   NoColP1

    MOV  AX, BulletY1[SI]
    CMP  AX, Player2Y
    JL   NoColP1
    MOV  DX, Player2Y
    ADD  DX, PLAYER_H
    CMP  AX, DX
    JG   NoColP1

    ; Collision hit!
    MOV  BulletActive1[BX], 0
    
    CMP  P2Shield, 1
    JNE  P1HitDmg
    MOV  P2Shield, 0
    JMP  UpdP1Next
P1HitDmg:
    CMP  P1Ultra, 0
    JE   P1NormDmg
    DEC  P1Ultra
    SUB  Player2Health, 2
    JMP  UpdP1Next
P1NormDmg:
    DEC  Player2Health
    JMP  UpdP1Next

NoColP1:
    JMP  UpdP1Next

DeactP1:
    MOV  BulletActive1[BX], 0

UpdP1Next:
    INC  BX
    JMP  UpdP1

UpdP2Start:
    XOR  BX, BX
UpdP2:
    CMP  BX, MAX_BULLETS
    jb skip_b2           ; Jump if Below to skip
        jmp UpdDone          ; Far jump to the label
    skip_b2:
    CMP  BulletActive2[BX], 0
    JE   UpdP2Next

    MOV  SI, BX
    SHL  SI, 1
    MOV  AX, BulletX2[SI]
    ADD  AX, BulletVelX2[SI]
    MOV  BulletX2[SI], AX

    CMP  AX, 0
    JL   DeactP2
    CMP  AX, SCREEN_W
    JGE  DeactP2

    ; --- Collision Check with P1 ---
    MOV  AX, BulletX2[SI]
    CMP  AX, PlayerX
    JL   NoColP2
    MOV  DX, PlayerX
    ADD  DX, PLAYER_W
    CMP  AX, DX
    JG   NoColP2

    MOV  AX, BulletY2[SI]
    CMP  AX, PlayerY
    JL   NoColP2
    MOV  DX, PlayerY
    ADD  DX, PLAYER_H
    CMP  AX, DX
    JG   NoColP2

    ; Collision hit!
    MOV  BulletActive2[BX], 0
    
    CMP  P1Shield, 1
    JNE  P2HitDmg
    MOV  P1Shield, 0
    JMP  UpdP2Next
P2HitDmg:
    CMP  P2Ultra, 0
    JE   P2NormDmg
    DEC  P2Ultra
    SUB  PlayerHealth, 2
    JMP  UpdP2Next
P2NormDmg:
    DEC  PlayerHealth
    JMP  UpdP2Next

NoColP2:
    JMP  UpdP2Next

DeactP2:
    MOV  BulletActive2[BX], 0

UpdP2Next:
    INC  BX
    JMP  UpdP2

UpdDone:
    POP  SI
    POP  BX
    POP  AX
    RET
UpdateBullets ENDP

; ===============================================================
; DrawBullets  -  render all active bullets
; ===============================================================
DrawBullets PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH ES

    MOV  AX, VideoSeg
    MOV  ES, AX

    XOR  BX, BX
DrP1:
    CMP  BX, MAX_BULLETS
    JAE  DrP2Start

    CMP  BulletActive1[BX], 0
    JE   DrP1Next

    MOV  SI, BX
    SHL  SI, 1
    MOV  AX, BulletX1[SI]
    MOV  CX, BulletY1[SI]
    MOV  DL, BULLET_COLOR1
    CALL DrawBall

DrP1Next:
    INC  BX
    JMP  DrP1

DrP2Start:
    XOR  BX, BX
DrP2:
    CMP  BX, MAX_BULLETS
    JAE  DrDone

    CMP  BulletActive2[BX], 0
    JE   DrP2Next

    MOV  SI, BX
    SHL  SI, 1
    MOV  AX, BulletX2[SI]
    MOV  CX, BulletY2[SI]
    MOV  DL, BULLET_COLOR2
    CALL DrawBall

DrP2Next:
    INC  BX
    JMP  DrP2

DrDone:
    POP  ES
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawBullets ENDP

; ===============================================================
; DrawBall  -  scanline-fill a circle
;
; INPUT : AX = center X
;         CX = center Y
;         DL = colour byte
;         ES = back-buffer segment (set by DrawBullets)
; OUTPUT: nothing (all registers preserved)
;
; Uses BallCurY (memory) to track the current scanline so that
; the MUL instruction cannot accidentally destroy it.
;
; Critical design note:
;   The half-width table is read with  MOV DH, [SI+BX]
;   where SI = LEA of BallHalfW.  SI-based addressing defaults
;   to DS, which is the data segment -- correct.
;   If we used BP as the base instead, [BP+BX] would default to
;   SS (the stack segment) and read garbage, producing a black line.
; ===============================================================
DrawBall PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP

    ; BP = center X  (we need AX free for arithmetic)
    ; BH = colour
    MOV  BP, AX
    MOV  BH, DL

    ; BallCurY = centerY - BULLET_RADIUS  (first scanline of the circle)
    SUB  CX, BULLET_RADIUS
    MOV  BallCurY, CX

    ; SI = offset of BallHalfW table in DS
    ; [SI + rowIndex] will be read as DS:[SI+BX] -- correct segment
    LEA  SI, BallHalfW

    XOR  BX, BX            ; BX = row index, 0 .. BULLET_DIAM-1

DrawRow:
    CMP  BX, BULLET_DIAM
    JGE  DrawDone

    MOV  AX, BallCurY

    CMP  AX, 0             ; row above screen?
    JL   NextRow

    CMP  AX, SCREEN_H      ; row below screen?
    JGE  DrawDone          ; rows only increase, so we're finished

    ; halfW = BallHalfW[rowIndex]   -- read via SI so segment = DS
    MOV  DL, [SI+BX]       ; DL = halfW
    XOR  DH, DH            ; DX = halfW as word

    ; leftX = centerX - halfW   (clamp to 0)
    MOV  CX, BP
    SUB  CX, DX
    CMP  CX, 0
    JGE  LXok
    XOR  CX, CX
LXok:                      ; CX = leftX

    ; rightX = centerX + halfW  (clamp to SCREEN_W - 1)
    MOV  DI, BP
    ADD  DI, DX
    CMP  DI, SCREEN_W - 1
    JLE  RXok
    MOV  DI, SCREEN_W - 1
RXok:                      ; DI = rightX

    ; span = rightX - leftX + 1
    MOV  DX, DI
    SUB  DX, CX
    INC  DX                ; DX = pixel count
    CMP  DX, 0
    JLE  NextRow

    ; video offset = BallCurY * 320 + leftX
    ; We push CX (leftX) and DX (span) because MUL destroys DX.
    PUSH CX                ; save leftX
    PUSH DX                ; save span

    MOV  AX, BallCurY
    MOV  DI, 320
    MUL  DI                ; AX = BallCurY * 320  (DX = high word, ~0)

    POP  DX                ; restore span  -> DX
    POP  CX                ; restore leftX -> CX
    ADD  AX, CX            ; AX = row start + leftX
    MOV  DI, AX            ; ES:DI = destination

    MOV  CX, DX            ; CX = span count
    MOV  AL, BH            ; AL = colour
    REP  STOSB             ; fill the span

NextRow:
    INC  WORD PTR BallCurY
    INC  BX
    JMP  DrawRow

DrawDone:
    POP  BP
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawBall ENDP

END