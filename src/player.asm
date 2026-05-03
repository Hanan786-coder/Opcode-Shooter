; FILE: player.asm
.MODEL SMALL

; Externals (from other files)
EXTRN MapData      : BYTE         
EXTRN MAP_COLS     : ABS          
EXTRN MAP_ROWS     : ABS          
EXTRN TILE_W       : ABS          
EXTRN TILE_H       : ABS          
EXTRN MoveLeft     : BYTE         
EXTRN MoveRight    : BYTE         
EXTRN DoJump       : BYTE         
EXTRN MoveDown     : BYTE         
EXTRN MoveLeft2    : BYTE         
EXTRN MoveRight2   : BYTE         
EXTRN DoJump2      : BYTE         
EXTRN MoveDown2    : BYTE         
EXTRN FirePlayer1  : BYTE         
EXTRN FirePlayer2  : BYTE         
EXTRN VideoSeg     : WORD         
EXTRN FireBulletPlayer1 : NEAR    
EXTRN FireBulletPlayer2 : NEAR    
EXTRN PlayerFacing : WORD         
EXTRN Player2Facing : WORD        

; Public symbols
PUBLIC InitPlayer
PUBLIC UpdatePlayer
PUBLIC DrawPlayer
PUBLIC PlayerX                    
PUBLIC PlayerY
PUBLIC InitPlayer2
PUBLIC UpdatePlayer2
PUBLIC DrawPlayer2
PUBLIC Player2X
PUBLIC Player2Y
PUBLIC PlayerHealth
PUBLIC Player2Health
PUBLIC P1Shield
PUBLIC P2Shield
PUBLIC P1Ultra
PUBLIC P2Ultra

.DATA

PLAYER_W  EQU 14                  
PLAYER_H  EQU 20                  

MOVE_SPEED  EQU 3                 
JUMP_VEL    EQU 11                 
GRAVITY     EQU 1                 
PUSH_DIST   EQU 2                 

SCREEN_W    EQU 320
SCREEN_H    EQU 200

PlayerX     DW  80                
PlayerY     DW  160               
VelocityY   DW  0                 
OnGround    DB  0                 
Player2X    DW  240               
Player2Y    DW  160               
Velocity2Y  DW  0                 
OnGround2   DB  0

PlayerHealth DW 10                
Player2Health DW 10               

P1Shield DB 0
P2Shield DB 0
P1Ultra DB 0
P2Ultra DB 0

BGC         EQU 0Bh   
SK          EQU 07h   
BLK         EQU 00h   
DGR         EQU 08h   
YEL         EQU 0Eh   
BRN         EQU 06h   

P1H         EQU 09h   
P1B         EQU 01h   
P1L         EQU 03h   

P2H         EQU 0Ch   
P2B         EQU 04h   
P2L         EQU 0Ch   

P1Sprite  LABEL BYTE
  DB BGC,BGC,BLK,P1H,P1H,P1H,P1H,P1H,P1H,P1H,BLK,BGC,BGC,BGC
  DB BGC,BLK,P1B,P1B,P1B,P1B,P1B,P1B,P1B,P1B,P1B,BLK,BGC,BGC
  DB BGC,BLK,P1H,YEL,BLK,P1H,P1H,P1H,P1H,BLK,YEL,P1H,BLK,BGC
  DB BGC,BLK,P1B,P1B,P1B,P1B,P1B,P1B,P1B,P1B,P1B,P1B,BLK,BGC
  DB BGC,BGC,BGC,BLK,SK, SK, SK, SK, SK, SK, BLK,BGC,BGC,BGC
  DB BLK,P1H,P1H,BLK,P1B,P1B,P1B,P1B,P1B,P1B,BLK,P1H,P1H,BLK
  DB P1B,P1H,P1H,P1B,P1B,P1H,P1H,P1H,P1H,P1B,P1B,P1H,P1H,P1B
  DB P1B,P1B,P1B,P1B,P1H,P1H,P1H,P1H,P1H,P1H,P1B,P1B,P1B,P1B
  DB P1B,P1B,P1B,BLK,YEL,YEL,YEL,YEL,YEL,YEL,BLK,P1B,P1B,P1B
  DB P1B,P1B,P1B,P1B,P1H,P1H,P1H,P1H,P1H,P1H,P1B,P1B,P1B,P1B
  DB BGC,BLK,BRN,BRN,BRN,BRN,BRN,BRN,BRN,BRN,BRN,BRN,BLK,BGC
  DB BGC,BLK,BRN,BRN,BRN,YEL,YEL,YEL,YEL,BRN,BRN,BRN,BLK,BGC
  DB BGC,BGC,P1L,P1L,P1L,BLK,BGC,BGC,BLK,P1L,P1L,P1L,BGC,BGC
  DB BGC,BGC,P1L,P1L,P1L,BLK,BGC,BGC,BLK,P1L,P1L,P1L,BGC,BGC
  DB BGC,BGC,P1H,P1L,P1H,BLK,BGC,BGC,BLK,P1H,P1L,P1H,BGC,BGC
  DB BGC,BGC,P1L,P1L,P1L,BLK,BGC,BGC,BLK,P1L,P1L,P1L,BGC,BGC
  DB BGC,BGC,P1L,P1L,P1L,BLK,BGC,BGC,BLK,P1L,P1L,P1L,BGC,BGC
  DB BGC,BLK,DGR,DGR,DGR,BLK,BGC,BGC,BLK,DGR,DGR,DGR,BLK,BGC
  DB BGC,BLK,DGR,DGR,DGR,DGR,BLK,BLK,DGR,DGR,DGR,DGR,BLK,BGC
  DB BGC,BLK,BLK,BLK,BLK,BLK,BLK,BLK,BLK,BLK,BLK,BLK,BLK,BGC

P2Sprite  LABEL BYTE
  DB BGC,BGC,BLK,P2H,P2H,P2H,P2H,P2H,P2H,P2H,BLK,BGC,BGC,BGC
  DB BGC,BLK,P2B,P2B,P2B,P2B,P2B,P2B,P2B,P2B,P2B,BLK,BGC,BGC
  DB BGC,BLK,P2H,YEL,BLK,P2H,P2H,P2H,P2H,BLK,YEL,P2H,BLK,BGC
  DB BGC,BLK,P2B,P2B,P2B,P2B,P2B,P2B,P2B,P2B,P2B,P2B,BLK,BGC
  DB BGC,BGC,BGC,BLK,SK, SK, SK, SK, SK, SK, BLK,BGC,BGC,BGC
  DB BLK,P2H,P2H,BLK,P2B,P2B,P2B,P2B,P2B,P2B,BLK,P2H,P2H,BLK
  DB P2B,P2H,P2H,P2B,P2B,P2H,P2H,P2H,P2H,P2B,P2B,P2H,P2H,P2B
  DB P2B,P2B,P2B,P2B,P2H,P2H,P2H,P2H,P2H,P2H,P2B,P2B,P2B,P2B
  DB P2B,P2B,P2B,BLK,YEL,YEL,YEL,YEL,YEL,YEL,BLK,P2B,P2B,P2B
  DB P2B,P2B,P2B,P2B,P2H,P2H,P2H,P2H,P2H,P2H,P2B,P2B,P2B,P2B
  DB BGC,BLK,BRN,BRN,BRN,BRN,BRN,BRN,BRN,BRN,BRN,BRN,BLK,BGC
  DB BGC,BLK,BRN,BRN,BRN,YEL,YEL,YEL,YEL,BRN,BRN,BRN,BLK,BGC
  DB BGC,BGC,P2L,P2L,P2L,BLK,BGC,BGC,BLK,P2L,P2L,P2L,BGC,BGC
  DB BGC,BGC,P2L,P2L,P2L,BLK,BGC,BGC,BLK,P2L,P2L,P2L,BGC,BGC
  DB BGC,BGC,P2H,P2L,P2H,BLK,BGC,BGC,BLK,P2H,P2L,P2H,BGC,BGC
  DB BGC,BGC,P2L,P2L,P2L,BLK,BGC,BGC,BLK,P2L,P2L,P2L,BGC,BGC
  DB BGC,BGC,P2L,P2L,P2L,BLK,BGC,BGC,BLK,P2L,P2L,P2L,BGC,BGC
  DB BGC,BLK,DGR,DGR,DGR,BLK,BGC,BGC,BLK,DGR,DGR,DGR,BLK,BGC
  DB BGC,BLK,DGR,DGR,DGR,DGR,BLK,BLK,DGR,DGR,DGR,DGR,BLK,BGC
  DB BGC,BLK,BLK,BLK,BLK,BLK,BLK,BLK,BLK,BLK,BLK,BLK,BLK,BGC

.CODE

InitPlayer PROC NEAR
    MOV  PlayerX, 80              
    MOV  PlayerY, 160             
    MOV  VelocityY, 0             
    MOV  OnGround, 0              
    RET
InitPlayer ENDP

UpdatePlayer PROC NEAR
    CMP  MoveLeft, 1
    JNE  CheckRight
    MOV  AX, PlayerX
    SUB  AX, MOVE_SPEED
    CMP  AX, 0
    JGE  SetLeftX
    MOV  AX, 0
SetLeftX:
    PUSH AX
    CALL CheckLeftCollision       
    JC   LeftBlocked
    POP  AX
    PUSH AX
    CALL CheckLeftCollisionWithPlayer2  
    JC   LeftBlocked
    POP  AX
    MOV  PlayerX, AX
    JMP  CheckRight
LeftBlocked:
    POP  AX                       

CheckRight:
    CMP  MoveRight, 1
    JNE  DoneHorizontal
    MOV  AX, PlayerX
    ADD  AX, MOVE_SPEED
    MOV  BX, SCREEN_W
    SUB  BX, PLAYER_W             
    CMP  AX, BX
    JLE  SetRightX
    MOV  AX, BX
SetRightX:
    PUSH AX
    CALL CheckRightCollision      
    JC   RightBlocked
    POP  AX
    PUSH AX
    CALL CheckRightCollisionWithPlayer2  
    JC   RightBlocked
    POP  AX
    MOV  PlayerX, AX
    JMP  DoneHorizontal
RightBlocked:
    POP  AX

DoneHorizontal:
    MOV  AX, PlayerX
    CMP  AX, Player2X
    JG   P1RightFace
    MOV  PlayerFacing, 1
    JMP  DoneFacing
P1RightFace:
    MOV  PlayerFacing, -1
    
DoneFacing:
    CMP  FirePlayer1, 1
    JNE  CheckJump1
    CALL FireBulletPlayer1

CheckJump1:
    CMP  DoJump, 1
    JNE  DoneJump
    CMP  OnGround, 1              
    JNE  DoneJump
    MOV  VelocityY, -JUMP_VEL    
    MOV  OnGround, 0              
    MOV  DoJump, 0                
DoneJump:

    CALL CheckPlayerCollisionP1
    MOV  AX, VelocityY
    ADD  AX, GRAVITY
    MOV  VelocityY, AX
    MOV  AX, PlayerY
    ADD  AX, VelocityY
    MOV  PlayerY, AX
    CMP  PlayerY, 0
    JGE  CheckFloor
    MOV  PlayerY, 0
    MOV  VelocityY, 0             

CheckFloor:
    MOV  AX, SCREEN_H
    SUB  AX, PLAYER_H             
    CMP  PlayerY, AX
    JLE  CheckTileBelow
    MOV  PlayerY, AX
    MOV  VelocityY, 0
    MOV  OnGround, 1

CheckTileBelow:
    CALL CheckGroundCollision     
    RET
UpdatePlayer ENDP

CheckPlayerCollisionP1 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV  AX, PlayerX
    MOV  BX, Player2X
    ADD  BX, PLAYER_W
    CMP  AX, BX                   
    JL   SkipP1_1                 ; FIX: Opposite of JGE
    JMP  NoCollisionP1            ; FIX: Far Jump
SkipP1_1:
    
    MOV  CX, PlayerX
    ADD  CX, PLAYER_W
    MOV  DX, Player2X
    CMP  CX, DX                   
    JG   SkipP1_2                 ; FIX: Opposite of JLE
    JMP  NoCollisionP1            ; FIX: Far Jump
SkipP1_2:
    
    MOV  AX, PlayerY
    MOV  BX, Player2Y
    ADD  BX, PLAYER_H
    CMP  AX, BX                   
    JL   SkipP1_3                 ; FIX: Opposite of JGE
    JMP  NoCollisionP1            ; FIX: Far Jump
SkipP1_3:
    
    MOV  CX, PlayerY
    ADD  CX, PLAYER_H
    MOV  DX, Player2Y
    CMP  CX, DX                   
    JG   SkipP1_4                 ; FIX: Opposite of JLE
    JMP  NoCollisionP1            ; FIX: Far Jump
SkipP1_4:
    
    MOV  AX, PlayerX
    ADD  AX, PLAYER_W / 2         
    MOV  BX, Player2X
    ADD  BX, PLAYER_W / 2         
    CMP  AX, BX
    JLE  PushLeft_P1              
    MOV  AX, PlayerX
    ADD  AX, PUSH_DIST
    MOV  BX, SCREEN_W
    SUB  BX, PLAYER_W
    CMP  AX, BX
    JLE  SetPushRight_P1
    MOV  AX, BX
SetPushRight_P1:
    MOV  PlayerX, AX
    MOV  AX, Player2X
    SUB  AX, PUSH_DIST
    CMP  AX, 0
    JGE  SetPushLeft_P2
    MOV  AX, 0
SetPushLeft_P2:
    MOV  Player2X, AX
    JMP  NoCollisionP1
PushLeft_P1:
    MOV  AX, PlayerX
    SUB  AX, PUSH_DIST
    CMP  AX, 0
    JGE  SetPushLeft_P1_2
    MOV  AX, 0
SetPushLeft_P1_2:
    MOV  PlayerX, AX
    MOV  AX, Player2X
    ADD  AX, PUSH_DIST
    MOV  BX, SCREEN_W
    SUB  BX, PLAYER_W
    CMP  AX, BX
    JLE  SetPushRight_P2
    MOV  AX, BX
SetPushRight_P2:
    MOV  Player2X, AX
NoCollisionP1:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
CheckPlayerCollisionP1 ENDP

CheckPlayerCollisionP2 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    MOV  AX, Player2X
    MOV  BX, PlayerX
    ADD  BX, PLAYER_W
    CMP  AX, BX                   
    JL   SkipP2_1                 ; FIX: Opposite of JGE
    JMP  NoCollisionP2            ; FIX: Far Jump
SkipP2_1:
    
    MOV  CX, Player2X
    ADD  CX, PLAYER_W
    MOV  DX, PlayerX
    CMP  CX, DX                   
    JG   SkipP2_2                 ; FIX: Opposite of JLE
    JMP  NoCollisionP2            ; FIX: Far Jump
SkipP2_2:
    
    MOV  AX, Player2Y
    MOV  BX, PlayerY
    ADD  BX, PLAYER_H
    CMP  AX, BX                   
    JL   SkipP2_3                 ; FIX: Opposite of JGE
    JMP  NoCollisionP2            ; FIX: Far Jump
SkipP2_3:
    
    MOV  CX, Player2Y
    ADD  CX, PLAYER_H
    MOV  DX, PlayerY
    CMP  CX, DX                   
    JG   SkipP2_4                 ; FIX: Opposite of JLE
    JMP  NoCollisionP2            ; FIX: Far Jump
SkipP2_4:
    
    MOV  AX, Player2X
    ADD  AX, PLAYER_W / 2         
    MOV  BX, PlayerX
    ADD  BX, PLAYER_W / 2         
    CMP  AX, BX
    JLE  PushLeft_P2              
    MOV  AX, Player2X
    ADD  AX, PUSH_DIST
    MOV  BX, SCREEN_W
    SUB  BX, PLAYER_W
    CMP  AX, BX
    JLE  SetPushRight_P2_2
    MOV  AX, BX
SetPushRight_P2_2:
    MOV  Player2X, AX
    MOV  AX, PlayerX
    SUB  AX, PUSH_DIST
    CMP  AX, 0
    JGE  SetPushLeft_P1_3
    MOV  AX, 0
SetPushLeft_P1_3:
    MOV  PlayerX, AX
    JMP  NoCollisionP2
PushLeft_P2:
    MOV  AX, Player2X
    SUB  AX, PUSH_DIST
    CMP  AX, 0
    JGE  SetPushLeft_P2_2
    MOV  AX, 0
SetPushLeft_P2_2:
    MOV  Player2X, AX
    MOV  AX, PlayerX
    ADD  AX, PUSH_DIST
    MOV  BX, SCREEN_W
    SUB  BX, PLAYER_W
    CMP  AX, BX
    JLE  SetPushRight_P1_2
    MOV  AX, BX
SetPushRight_P1_2:
    MOV  PlayerX, AX
NoCollisionP2:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
CheckPlayerCollisionP2 ENDP

CheckLeftCollisionWithPlayer2 PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  BX, Player2X
    ADD  BX, PLAYER_W
    CMP  AX, BX
    JGE  NoColP1L
    MOV  CX, AX
    ADD  CX, PLAYER_W
    MOV  DX, Player2X
    CMP  CX, DX
    JLE  NoColP1L
    MOV  BX, PlayerY
    MOV  CX, Player2Y
    ADD  CX, PLAYER_H
    CMP  BX, CX
    JGE  NoColP1L
    MOV  DX, PlayerY
    ADD  DX, PLAYER_H
    MOV  CX, Player2Y
    CMP  DX, CX
    JLE  NoColP1L
    STC                           
    JMP  DoneColP1L
NoColP1L:
    CLC                           
DoneColP1L:
    POP  DX
    POP  CX
    POP  BX
    RET
CheckLeftCollisionWithPlayer2 ENDP

CheckRightCollisionWithPlayer2 PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  BX, Player2X
    ADD  BX, PLAYER_W
    CMP  AX, BX
    JGE  NoColP1R
    MOV  CX, AX
    ADD  CX, PLAYER_W
    MOV  DX, Player2X
    CMP  CX, DX
    JLE  NoColP1R
    MOV  BX, PlayerY
    MOV  CX, Player2Y
    ADD  CX, PLAYER_H
    CMP  BX, CX
    JGE  NoColP1R
    MOV  DX, PlayerY
    ADD  DX, PLAYER_H
    MOV  CX, Player2Y
    CMP  DX, CX
    JLE  NoColP1R
    STC                           
    JMP  DoneColP1R
NoColP1R:
    CLC                           
DoneColP1R:
    POP  DX
    POP  CX
    POP  BX
    RET
CheckRightCollisionWithPlayer2 ENDP

CheckLeftCollisionWithPlayer1 PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  BX, PlayerX
    ADD  BX, PLAYER_W
    CMP  AX, BX
    JGE  NoColP2L
    MOV  CX, AX
    ADD  CX, PLAYER_W
    MOV  DX, PlayerX
    CMP  CX, DX
    JLE  NoColP2L
    MOV  BX, Player2Y
    MOV  CX, PlayerY
    ADD  CX, PLAYER_H
    CMP  BX, CX
    JGE  NoColP2L
    MOV  DX, Player2Y
    ADD  DX, PLAYER_H
    MOV  CX, PlayerY
    CMP  DX, CX
    JLE  NoColP2L
    STC                           
    JMP  DoneColP2L
NoColP2L:
    CLC                           
DoneColP2L:
    POP  DX
    POP  CX
    POP  BX
    RET
CheckLeftCollisionWithPlayer1 ENDP

CheckRightCollisionWithPlayer1 PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  BX, PlayerX
    ADD  BX, PLAYER_W
    CMP  AX, BX
    JGE  NoColP2R
    MOV  CX, AX
    ADD  CX, PLAYER_W
    MOV  DX, PlayerX
    CMP  CX, DX
    JLE  NoColP2R
    MOV  BX, Player2Y
    MOV  CX, PlayerY
    ADD  CX, PLAYER_H
    CMP  BX, CX
    JGE  NoColP2R
    MOV  DX, Player2Y
    ADD  DX, PLAYER_H
    MOV  CX, PlayerY
    CMP  DX, CX
    JLE  NoColP2R
    STC                           
    JMP  DoneColP2R
NoColP2R:
    CLC                           
DoneColP2R:
    POP  DX
    POP  CX
    POP  BX
    RET
CheckRightCollisionWithPlayer1 ENDP

CheckGroundCollision PROC NEAR
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI
    MOV  AX, PlayerY
    ADD  AX, PLAYER_H             
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       
    MOV  SI, PlayerX
    ADD  SI, PLAYER_W / 2         
    XOR  DX, DX
    MOV  BX, TILE_W
    MOV  AX, SI
    DIV  BX                       
    CMP  AX, MAP_COLS
    JAE  NoGroundHit
    PUSH AX                       
    MOV  AX, PlayerY
    ADD  AX, PLAYER_H
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       
    CMP  AX, MAP_ROWS
    JAE  NoGroundHitPop
    PUSH AX                       
    MOV  BX, MAP_COLS
    MUL  BX                       
    POP  CX                       
    POP  SI                       
    ADD  AX, SI
    MOV  SI, AX                   
    MOV  AL, MapData[SI]
    CMP  AL, 1
    JNE  NoGroundHit2             
    CMP  MoveDown, 1
    JNE  CheckHit1
    MOV  DX, MAP_ROWS
    DEC  DX
    CMP  CX, DX
    JGE  CheckHit1
    MOV  AX, PlayerY
    ADD  AX, 17
    MOV  PlayerY, AX
    MOV  VelocityY, 2
    JMP  NoGroundHit2
CheckHit1:
    MOV  AX, PlayerY
    ADD  AX, PLAYER_H
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       
    MUL  BX                       
    SUB  AX, PLAYER_H             
    MOV  PlayerY, AX
    MOV  VelocityY, 0
    MOV  OnGround, 1
    JMP  GroundDone
NoGroundHitPop:
    POP  AX
    JMP  NoGroundHit
NoGroundHit2:
NoGroundHit:
    MOV  OnGround, 0
GroundDone:
    POP  SI
    POP  DX
    POP  BX
    POP  AX
    RET
CheckGroundCollision ENDP

CheckLeftCollision PROC NEAR
    PUSH BX
    PUSH DX
    PUSH SI
    MOV  BX, AX                   
    MOV  DX, PlayerY
    ADD  DX, PLAYER_H / 2         
    XOR  AX, AX
    MOV  AX, BX
    XOR  DX, DX
    MOV  SI, PlayerY
    ADD  SI, PLAYER_H / 2
    MOV  AX, BX
    XOR  DX, DX
    MOV  BX, TILE_W
    DIV  BX                       
    MOV  BX, SI
    PUSH AX                       
    MOV  AX, BX
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       
    POP  BX                       
    PUSH BX
    MOV  BX, MAP_COLS
    MUL  BX
    POP  BX
    ADD  AX, BX
    MOV  SI, AX
    MOV  AL, MapData[SI]
    CMP  AL, 1
    JE   LeftBlk
    CLC                           
    JMP  LeftDone
LeftBlk:
    STC                           
LeftDone:
    POP  SI
    POP  DX
    POP  BX
    RET
CheckLeftCollision ENDP

CheckRightCollision PROC NEAR
    PUSH BX
    PUSH DX
    PUSH SI
    ADD  AX, PLAYER_W
    DEC  AX
    MOV  BX, AX                   
    MOV  SI, PlayerY
    ADD  SI, PLAYER_H / 2
    MOV  AX, BX
    XOR  DX, DX
    MOV  BX, TILE_W
    DIV  BX                       
    MOV  BX, SI
    PUSH AX
    MOV  AX, BX
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       
    POP  BX                       
    PUSH BX
    MOV  BX, MAP_COLS
    MUL  BX
    POP  BX
    ADD  AX, BX
    MOV  SI, AX
    MOV  AL, MapData[SI]
    CMP  AL, 1
    JE   RightBlk
    CLC
    JMP  RightDone
RightBlk:
    STC
RightDone:
    POP  SI
    POP  DX
    POP  BX
    RET
CheckRightCollision ENDP

DrawPlayer PROC NEAR
    PUSH ES
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    MOV  AX, VideoSeg
    MOV  ES, AX
    LEA  SI, P1Sprite             
    MOV  DX, PlayerY              
    MOV  CX, PLAYER_H             
DP1_RowLoop:
    PUSH DX
    PUSH CX
    MOV  AX, DX
    MOV  BX, 320
    MUL  BX                       
    ADD  AX, PlayerX
    MOV  DI, AX                   
    MOV  BX, PLAYER_W
DP1_ColLoop:
    MOV  AL, [SI]                 
    INC  SI
    CMP  AL, BGC                  
    JE   DP1_Skip                 
    MOV  ES:[DI], AL              
DP1_Skip:
    INC  DI
    DEC  BX
    JNZ  DP1_ColLoop
    POP  CX
    POP  DX
    INC  DX                       
    LOOP DP1_RowLoop
    MOV  DX, PlayerY
    ADD  DX, PLAYER_H / 2 - 3       
    MOV  AX, PlayerFacing
    CMP  AX, 1
    JNE  P1GunLeft
    MOV  CX, PlayerX
    ADD  CX, PLAYER_W - 2         
    JMP  P1DrawGun
P1GunLeft:
    MOV  CX, PlayerX
    SUB  CX, 4                    
P1DrawGun:
    MOV  AX, DX
    MOV  BX, 320
    MUL  BX
    ADD  AX, CX
    MOV  DI, AX
    MOV  AL, 08h                  
    MOV  ES:[DI], AL
    MOV  ES:[DI+1], AL
    MOV  ES:[DI+2], AL
    MOV  ES:[DI+3], AL
    MOV  ES:[DI+4], AL
    MOV  ES:[DI+5], AL
    ADD  DI, 320
    MOV  ES:[DI], AL
    MOV  ES:[DI+1], AL
    MOV  ES:[DI+2], AL
    MOV  ES:[DI+3], AL
    MOV  ES:[DI+4], AL
    MOV  ES:[DI+5], AL
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    POP  ES
    RET
DrawPlayer ENDP

InitPlayer2 PROC NEAR
    MOV  Player2X, 240              
    MOV  Player2Y, 160             
    MOV  Velocity2Y, 0             
    MOV  OnGround2, 0              
    RET
InitPlayer2 ENDP

UpdatePlayer2 PROC NEAR
    CMP  MoveLeft2, 1
    JNE  CheckRight_P2
    MOV  AX, Player2X
    SUB  AX, MOVE_SPEED
    CMP  AX, 0
    JGE  SetLeftX_P2
    MOV  AX, 0
SetLeftX_P2:
    PUSH AX
    CALL CheckLeftCollision_P2       
    JC   LeftBlocked_P2
    POP  AX
    PUSH AX
    CALL CheckLeftCollisionWithPlayer1  
    JC   LeftBlocked_P2
    POP  AX
    MOV  Player2X, AX
    JMP  CheckRight_P2
LeftBlocked_P2:
    POP  AX                       

CheckRight_P2:
    CMP  MoveRight2, 1
    JNE  DoneHorizontal_P2
    MOV  AX, Player2X
    ADD  AX, MOVE_SPEED
    MOV  BX, SCREEN_W
    SUB  BX, PLAYER_W             
    CMP  AX, BX
    JLE  SetRightX_P2
    MOV  AX, BX
SetRightX_P2:
    PUSH AX
    CALL CheckRightCollision_P2      
    JC   RightBlocked_P2
    POP  AX
    PUSH AX
    CALL CheckRightCollisionWithPlayer1  
    JC   RightBlocked_P2
    POP  AX
    MOV  Player2X, AX
    JMP  DoneHorizontal_P2
RightBlocked_P2:
    POP  AX

DoneHorizontal_P2:
    MOV  AX, Player2X
    CMP  AX, PlayerX
    JG   P2RightFace
    MOV  Player2Facing, 1
    JMP  DoneFacing_P2
P2RightFace:
    MOV  Player2Facing, -1
DoneFacing_P2:
    CMP  FirePlayer2, 1
    JNE  CheckJump2
    CALL FireBulletPlayer2

CheckJump2:
    CMP  DoJump2, 1
    JNE  DoneJump_P2
    CMP  OnGround2, 1              
    JNE  DoneJump_P2
    MOV  Velocity2Y, -JUMP_VEL    
    MOV  OnGround2, 0              
    MOV  DoJump2, 0                
DoneJump_P2:

    CALL CheckPlayerCollisionP2
    MOV  AX, Velocity2Y
    ADD  AX, GRAVITY
    MOV  Velocity2Y, AX
    MOV  AX, Player2Y
    ADD  AX, Velocity2Y
    MOV  Player2Y, AX
    CMP  Player2Y, 0
    JGE  CheckFloor_P2
    MOV  Player2Y, 0
    MOV  Velocity2Y, 0             

CheckFloor_P2:
    MOV  AX, SCREEN_H
    SUB  AX, PLAYER_H             
    CMP  Player2Y, AX
    JLE  CheckTileBelow_P2
    MOV  Player2Y, AX
    MOV  Velocity2Y, 0
    MOV  OnGround2, 1

CheckTileBelow_P2:
    CALL CheckGroundCollision_P2     
    RET
UpdatePlayer2 ENDP

CheckGroundCollision_P2 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI
    MOV  AX, Player2Y
    ADD  AX, PLAYER_H             
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       
    MOV  SI, Player2X
    ADD  SI, PLAYER_W / 2         
    XOR  DX, DX
    MOV  BX, TILE_W
    MOV  AX, SI
    DIV  BX                       
    CMP  AX, MAP_COLS
    JAE  NoGroundHit_P2
    PUSH AX                       
    MOV  AX, Player2Y
    ADD  AX, PLAYER_H
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       
    CMP  AX, MAP_ROWS
    JAE  NoGroundHitPop_P2
    PUSH AX
    MOV  BX, MAP_COLS
    MUL  BX                       
    POP  CX
    POP  SI                       
    ADD  AX, SI
    MOV  SI, AX                   
    MOV  AL, MapData[SI]
    CMP  AL, 1
    JNE  NoGroundHit2_P2             
    CMP  MoveDown2, 1
    JNE  CheckHit2
    MOV  DX, MAP_ROWS
    DEC  DX
    CMP  CX, DX
    JGE  CheckHit2
    MOV  AX, Player2Y
    ADD  AX, 17
    MOV  Player2Y, AX
    MOV  Velocity2Y, 2
    JMP  NoGroundHit2_P2
CheckHit2:
    MOV  AX, Player2Y
    ADD  AX, PLAYER_H
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       
    MUL  BX                       
    SUB  AX, PLAYER_H             
    MOV  Player2Y, AX
    MOV  Velocity2Y, 0
    MOV  OnGround2, 1
    JMP  GroundDone_P2
NoGroundHitPop_P2:
    POP  AX
    JMP  NoGroundHit_P2
NoGroundHit2_P2:
NoGroundHit_P2:
    MOV  OnGround2, 0
GroundDone_P2:
    POP  SI
    POP  DX
    POP  BX
    POP  AX
    RET
CheckGroundCollision_P2 ENDP

CheckLeftCollision_P2 PROC NEAR
    PUSH BX
    PUSH DX
    PUSH SI
    MOV  BX, AX                   
    MOV  DX, Player2Y
    ADD  DX, PLAYER_H / 2         
    XOR  AX, AX
    MOV  AX, BX
    XOR  DX, DX
    MOV  SI, Player2Y
    ADD  SI, PLAYER_H / 2
    MOV  AX, BX
    XOR  DX, DX
    MOV  BX, TILE_W
    DIV  BX                       
    MOV  BX, SI
    PUSH AX                       
    MOV  AX, BX
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       
    POP  BX                       
    PUSH BX
    MOV  BX, MAP_COLS
    MUL  BX
    POP  BX
    ADD  AX, BX
    MOV  SI, AX
    MOV  AL, MapData[SI]
    CMP  AL, 1
    JE   LeftBlk_P2
    CLC                           
    JMP  LeftDone_P2
LeftBlk_P2:
    STC                           
LeftDone_P2:
    POP  SI
    POP  DX
    POP  BX
    RET
CheckLeftCollision_P2 ENDP

CheckRightCollision_P2 PROC NEAR
    PUSH BX
    PUSH DX
    PUSH SI
    ADD  AX, PLAYER_W
    DEC  AX
    MOV  BX, AX                   
    MOV  SI, Player2Y
    ADD  SI, PLAYER_H / 2
    MOV  AX, BX
    XOR  DX, DX
    MOV  BX, TILE_W
    DIV  BX                       
    MOV  BX, SI
    PUSH AX
    MOV  AX, BX
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       
    POP  BX                       
    PUSH BX
    MOV  BX, MAP_COLS
    MUL  BX
    POP  BX
    ADD  AX, BX
    MOV  SI, AX
    MOV  AL, MapData[SI]
    CMP  AL, 1
    JE   RightBlk_P2
    CLC
    JMP  RightDone_P2
RightBlk_P2:
    STC
RightDone_P2:
    POP  SI
    POP  DX
    POP  BX
    RET
CheckRightCollision_P2 ENDP

DrawPlayer2 PROC NEAR
    PUSH ES
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    MOV  AX, VideoSeg
    MOV  ES, AX
    LEA  SI, P2Sprite             
    MOV  DX, Player2Y             
    MOV  CX, PLAYER_H             
DP2_RowLoop:
    PUSH DX
    PUSH CX
    MOV  AX, DX
    MOV  BX, 320
    MUL  BX                       
    ADD  AX, Player2X
    MOV  DI, AX
    MOV  BX, PLAYER_W
DP2_ColLoop:
    MOV  AL, [SI]
    INC  SI
    CMP  AL, BGC
    JE   DP2_Skip
    MOV  ES:[DI], AL
DP2_Skip:
    INC  DI
    DEC  BX
    JNZ  DP2_ColLoop
    POP  CX
    POP  DX
    INC  DX
    LOOP DP2_RowLoop
    MOV  DX, Player2Y
    ADD  DX, PLAYER_H / 2 - 3        
    MOV  AX, Player2Facing
    CMP  AX, 1
    JNE  P2GunLeft
    MOV  CX, Player2X
    ADD  CX, PLAYER_W - 2         
    JMP  P2DrawGun
P2GunLeft:
    MOV  CX, Player2X
    SUB  CX, 4                    
P2DrawGun:
    MOV  AX, DX
    MOV  BX, 320
    MUL  BX
    ADD  AX, CX
    MOV  DI, AX
    MOV  AL, 08h                  
    MOV  ES:[DI], AL
    MOV  ES:[DI+1], AL
    MOV  ES:[DI+2], AL
    MOV  ES:[DI+3], AL
    MOV  ES:[DI+4], AL
    MOV  ES:[DI+5], AL
    ADD  DI, 320
    MOV  ES:[DI], AL
    MOV  ES:[DI+1], AL
    MOV  ES:[DI+2], AL
    MOV  ES:[DI+3], AL
    MOV  ES:[DI+4], AL
    MOV  ES:[DI+5], AL
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    POP  ES
    RET
DrawPlayer2 ENDP

END