; FILE: bullets.asm
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

BULLET_RADIUS  EQU 3
BULLET_DIAM    EQU 7              
BULLET_SPEED   EQU 8
BULLET_COLOR1  EQU 0Eh            
BULLET_COLOR2  EQU 0Fh            
MAX_BULLETS    EQU 10
FIRE_COOLDOWN_MAX EQU 20          

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

FireCooldown1  DW 0                
FireCooldown2  DW 0                

BallCurY       DW 0

BallHalfW  DB  0, 3, 4, 4, 4, 5, 4, 4, 4, 3, 0

.CODE

InitBullets PROC NEAR
    PUSH AX
    PUSH CX
    PUSH DI
    PUSH ES
    MOV  AX, DS
    MOV  ES, AX            
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

FireBulletPlayer1 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH SI
    CMP  FireCooldown1, 0
    JA   FireExit1
    MOV  AX, PlayerX
    SUB  AX, Player2X
    JNS  DistPos1          
    NEG  AX                
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
    SHL  SI, 1              
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
    MOV  FireCooldown1, FIRE_COOLDOWN_MAX
FireExit1:
    POP  SI
    POP  BX
    POP  AX
    RET
FireBulletPlayer1 ENDP

FireBulletPlayer2 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH SI
    CMP  FireCooldown2, 0
    JA   FireExit2
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
    MOV  FireCooldown2, FIRE_COOLDOWN_MAX
FireExit2:
    POP  SI
    POP  BX
    POP  AX
    RET
FireBulletPlayer2 ENDP

UpdateBullets PROC NEAR
    PUSH AX
    PUSH BX
    PUSH SI
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
    JB   Skip318              ; FIX: Opposite of JAE
    JMP  UpdP2Start           ; FIX: Far Jump
Skip318:

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
    JB   Skip382              ; FIX: Opposite of JAE
    JMP  UpdDone              ; FIX: Far Jump
Skip382:

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

DrawBall PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP
    MOV  BP, AX
    MOV  BH, DL
    SUB  CX, BULLET_RADIUS
    MOV  BallCurY, CX
    LEA  SI, BallHalfW
    XOR  BX, BX            
DrawRow:
    CMP  BX, BULLET_DIAM
    JGE  DrawDone
    MOV  AX, BallCurY
    CMP  AX, 0             
    JL   NextRow
    CMP  AX, SCREEN_H      
    JGE  DrawDone          
    MOV  DL, [SI+BX]       
    XOR  DH, DH            
    MOV  CX, BP
    SUB  CX, DX
    CMP  CX, 0
    JGE  LXok
    XOR  CX, CX
LXok:                      
    MOV  DI, BP
    ADD  DI, DX
    CMP  DI, SCREEN_W - 1
    JLE  RXok
    MOV  DI, SCREEN_W - 1
RXok:                      
    MOV  DX, DI
    SUB  DX, CX
    INC  DX                
    CMP  DX, 0
    JLE  NextRow
    PUSH CX                
    PUSH DX                
    MOV  AX, BallCurY
    MOV  DI, 320
    MUL  DI                
    POP  DX                
    POP  CX                
    ADD  AX, CX            
    MOV  DI, AX            
    MOV  CX, DX            
    MOV  AL, BH            
    REP  STOSB             
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