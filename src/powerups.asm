; FILE: powerups.asm
; ROLE: Randomly spawning powerups, rendering, and player collision

.MODEL SMALL
.286
EXTRN PlayerX : WORD
EXTRN PlayerY : WORD
EXTRN Player2X : WORD
EXTRN Player2Y : WORD
EXTRN PlayerHealth : WORD
EXTRN Player2Health : WORD
EXTRN P1Shield : BYTE
EXTRN P2Shield : BYTE
EXTRN P1Ultra : BYTE
EXTRN P2Ultra : BYTE
EXTRN MapData : BYTE
EXTRN VideoSeg : WORD

PUBLIC InitPowerups
PUBLIC UpdatePowerups
PUBLIC DrawPowerups
PUBLIC DrawPowerupUI

.DATA

MAX_POWERUPS EQU 3
SPAWN_INTERVAL EQU 150
POWERUP_W EQU 8
POWERUP_H EQU 8
PLAYER_W EQU 14
PLAYER_H EQU 20

PwrActive DB MAX_POWERUPS DUP (0)
PwrType   DB MAX_POWERUPS DUP (0)  ; 1=Ultra, 2=Shield, 3=Heal
PwrX      DW MAX_POWERUPS DUP (0)
PwrY      DW MAX_POWERUPS DUP (0)

SpawnTimer DW SPAWN_INTERVAL
RandSeed   DW 1234h

BGC EQU 0   

RD  EQU 0Ch ; Red
BLU EQU 09h ; Blue
YL  EQU 0Eh ; Yellow
BGT EQU 0Bh ; Transparent bg color

SprHeal LABEL BYTE
  DB BGT, RD,  RD,  BGT, BGT, RD,  RD,  BGT
  DB RD,  RD,  RD,  RD,  RD,  RD,  RD,  RD
  DB RD,  RD,  RD,  RD,  RD,  RD,  RD,  RD
  DB BGT, RD,  RD,  RD,  RD,  RD,  RD,  BGT
  DB BGT, BGT, RD,  RD,  RD,  RD,  BGT, BGT
  DB BGT, BGT, BGT, RD,  RD,  BGT, BGT, BGT
  DB BGT, BGT, BGT, BGT, BGT, BGT, BGT, BGT
  DB BGT, BGT, BGT, BGT, BGT, BGT, BGT, BGT

SprShield LABEL BYTE
  DB BLU,  BLU,  BLU,  BLU,  BLU,  BLU,  BLU,  BLU
  DB BLU,  BGT, BGT, BGT, BGT, BGT, BGT, BLU
  DB BLU,  BGT, BLU,  BLU,  BLU,  BLU,  BGT, BLU
  DB BLU,  BGT, BLU,  BLU,  BLU,  BLU,  BGT, BLU
  DB BGT, BLU,  BGT, BGT, BGT, BGT, BLU,  BGT
  DB BGT, BGT, BLU,  BGT, BGT, BLU,  BGT, BGT
  DB BGT, BGT, BGT, BLU,  BLU,  BGT, BGT, BGT
  DB BGT, BGT, BGT, BGT, BGT, BGT, BGT, BGT

SprUltra LABEL BYTE
  DB BGT, BGT, BGT, YL,  YL,  BGT, BGT, BGT
  DB BGT, BGT, YL,  YL,  YL,  YL,  BGT, BGT
  DB YL,  YL,  YL,  YL,  YL,  YL,  YL,  YL
  DB BGT, YL,  YL,  YL,  YL,  YL,  YL,  BGT
  DB BGT, BGT, YL,  YL,  YL,  YL,  BGT, BGT
  DB BGT, YL,  YL,  BGT, BGT, YL,  YL,  BGT
  DB YL,  YL,  BGT, BGT, BGT, BGT, YL,  YL
  DB BGT, BGT, BGT, BGT, BGT, BGT, BGT, BGT

.CODE

Random PROC NEAR
    PUSH CX
    PUSH DX
    MOV  AX, RandSeed
    MOV  CX, 25173
    MUL  CX
    ADD  AX, 13849
    MOV  RandSeed, AX
    POP  DX
    POP  CX
    RET
Random ENDP

RandomRange PROC NEAR
    PUSH DX
    CALL Random
    XOR  DX, DX
    DIV  BX
    MOV  AX, DX
    POP  DX
    RET
RandomRange ENDP

InitPowerups PROC NEAR
    PUSH AX
    PUSH DX
    MOV  AH, 00h
    INT  1Ah
    MOV  RandSeed, DX
    XOR  BX, BX
ClearLoop:
    CMP  BX, MAX_POWERUPS
    JAE  InitDone
    MOV  PwrActive[BX], 0
    INC  BX
    JMP  ClearLoop
InitDone:
    POP  DX
    POP  AX
    RET
InitPowerups ENDP

UpdatePowerups PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    DEC  SpawnTimer
    CMP  SpawnTimer, 0
    JLE  SkipJump    ; If NOT Greater (Less or Equal), skip the jump
        JMP  CheckCol    ; Unconditional jump (can reach much further)
    SkipJump:    MOV  SpawnTimer, SPAWN_INTERVAL
    XOR  BX, BX
FindFree:
    CMP  BX, MAX_POWERUPS
    JAE  CheckCol        
    CMP  PwrActive[BX], 0
    JE   SpawnSlot
    INC  BX
    JMP  FindFree
SpawnSlot:
RetrySpawn:
    MOV  PwrActive[BX], 1
    PUSH BX
    MOV  BX, 3
    CALL RandomRange
    INC  AX
    POP  BX
    MOV  PwrType[BX], AL
    PUSH BX
    MOV  BX, 290
    CALL RandomRange
    ADD  AX, 10
    POP  BX
    MOV  SI, BX
    SHL  SI, 1
    MOV  PwrX[SI], AX
    PUSH BX
    MOV  BX, 130
    CALL RandomRange
    ADD  AX, 30
    POP  BX
    MOV  SI, BX
    SHL  SI, 1
    MOV  PwrY[SI], AX

    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  AX, PwrY[SI]
    ADD  AX, 4             ; Center Y
    XOR  DX, DX
    MOV  CX, 16      
    DIV  CX
    MOV  BX, AX            ; BX = Row
    MOV  AX, PwrX[SI]
    ADD  AX, 4             ; Center X
    XOR  DX, DX
    DIV  CX                ; AX = Col
    MOV  CX, AX            ; CX = Col
    MOV  AX, BX
    MOV  DX, 20      
    MUL  DX                ; Row * 20
    ADD  AX, CX            ; + Col
    MOV  DI, AX
    MOV  AL, MapData[DI]
    CMP  AL, 1
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    JE   RetrySpawn

CheckCol:
    XOR  BX, BX
UpdLoop:
    CMP  BX, MAX_POWERUPS
    JB   SkipPwr1             ; FIX: Opposite of JAE
    JMP  UpdDone              ; FIX: Far Jump
SkipPwr1:

    CMP  PwrActive[BX], 0
    JNE  SkipPwr2             ; FIX: Opposite of JE
    JMP  NextPwr              ; FIX: Far Jump
SkipPwr2:
    
    MOV  SI, BX
    SHL  SI, 1
    MOV  AX, PwrX[SI]
    MOV  CX, PwrY[SI]
    MOV  DX, PlayerX
    ADD  DX, PLAYER_W
    CMP  AX, DX
    JGE  CheckP2
    MOV  DX, AX
    ADD  DX, POWERUP_W
    CMP  DX, PlayerX
    JLE  CheckP2
    MOV  DX, PlayerY
    ADD  DX, PLAYER_H
    CMP  CX, DX
    JGE  CheckP2
    MOV  DX, CX
    ADD  DX, POWERUP_H
    CMP  DX, PlayerY
    JLE  CheckP2
    MOV  PwrActive[BX], 0
    MOV  AL, PwrType[BX]
    CMP  AL, 1
    JE   P1GotUltra
    CMP  AL, 2
    JE   P1GotShield
    CMP  AL, 3
    JE   P1GotHeal
    JMP  NextPwr
P1GotUltra:
    MOV  P1Ultra, 1
    JMP  NextPwr
P1GotShield:
    MOV  P1Shield, 1
    JMP  NextPwr
P1GotHeal:
    ADD  PlayerHealth, 2
    CMP  PlayerHealth, 10
    JLE  NextPwr
    MOV  PlayerHealth, 10
    JMP  NextPwr
CheckP2:
    MOV  DX, Player2X
    ADD  DX, PLAYER_W
    CMP  AX, DX
    JGE  NextPwr
    MOV  DX, AX
    ADD  DX, POWERUP_W
    CMP  DX, Player2X
    JLE  NextPwr
    MOV  DX, Player2Y
    ADD  DX, PLAYER_H
    CMP  CX, DX
    JGE  NextPwr
    MOV  DX, CX
    ADD  DX, POWERUP_H
    CMP  DX, Player2Y
    JLE  NextPwr
    MOV  PwrActive[BX], 0
    MOV  AL, PwrType[BX]
    CMP  AL, 1
    JE   P2GotUltra
    CMP  AL, 2
    JE   P2GotShield
    CMP  AL, 3
    JE   P2GotHeal
    JMP  NextPwr
P2GotUltra:
    MOV  P2Ultra, 1
    JMP  NextPwr
P2GotShield:
    MOV  P2Shield, 1
    JMP  NextPwr
P2GotHeal:
    ADD  Player2Health, 2
    CMP  Player2Health, 10
    JLE  NextPwr
    MOV  Player2Health, 10
NextPwr:
    INC  BX
    JMP  UpdLoop
UpdDone:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
UpdatePowerups ENDP

DrawPowerups PROC NEAR
    PUSH ES
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH BP
    MOV  AX, VideoSeg
    MOV  ES, AX
    XOR  BX, BX
DrwLoop:
    CMP  BX, MAX_POWERUPS
    JAE  DrwDone
    CMP  PwrActive[BX], 0
    JE   DrwNext
    MOV  SI, BX
    SHL  SI, 1
    MOV  AX, PwrX[SI]
    MOV  DX, PwrY[SI]
    MOV  CL, PwrType[BX]
    CMP  CL, 1
    JE   UseUltra
    CMP  CL, 2
    JE   UseShield
    LEA  BP, SprHeal
    JMP  DoDraw
UseUltra:
    LEA  BP, SprUltra
    JMP  DoDraw
UseShield:
    LEA  BP, SprShield
DoDraw:
    MOV  CX, POWERUP_H
DrwRow:
    PUSH DX
    PUSH CX
    PUSH AX
    MOV  DI, DX
    MOV  CX, 320
    XCHG AX, DI
    MUL  CX
    ADD  DI, AX     
    MOV  CX, POWERUP_W
DrwCol:
    MOV  AL, DS:[BP]
    INC  BP
    CMP  AL, BGT
    JE   SkipPix
    MOV  ES:[DI], AL
SkipPix:
    INC  DI
    DEC  CX
    JNZ  DrwCol
    POP  AX
    POP  CX
    POP  DX
    INC  DX
    LOOP DrwRow
DrwNext:
    INC  BX
    JMP  DrwLoop
DrwDone:
    POP  BP
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    POP  ES
    RET
DrawPowerups ENDP

DrawPowerupUI PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH ES
    MOV  AX, VideoSeg
    MOV  ES, AX
    
    CMP  P1Ultra, 1
    JNE  Skip_P1U
    MOV  BL, 0Eh        
    MOV  AX, 127        
    CALL DrawBlock5x9
Skip_P1U:

    CMP  P1Shield, 1
    JNE  Skip_P1S
    MOV  BL, 09h        
    MOV  AX, 133        
    CALL DrawBlock5x9
Skip_P1S:

    CMP  P2Ultra, 1
    JNE  Skip_P2U
    MOV  BL, 0Eh
    MOV  AX, 183        
    CALL DrawBlock5x9
Skip_P2U:

    CMP  P2Shield, 1
    JNE  Skip_P2S
    MOV  BL, 09h
    MOV  AX, 189        
    CALL DrawBlock5x9
Skip_P2S:

    POP  ES
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawPowerupUI ENDP

DrawBlock5x9 PROC NEAR
    PUSH AX
    PUSH CX
    PUSH DX
    PUSH DI
    MOV  DX, 2
    MOV  CX, 9
DB59_Row:
    PUSH CX
    PUSH AX
    CALL CalcDI
    POP  AX
    MOV  CX, 5
    MOV  AL, BL
    REP  STOSB
    INC  DX
    POP  CX
    LOOP DB59_Row
    POP  DI
    POP  DX
    POP  CX
    POP  AX
    RET
DrawBlock5x9 ENDP

CalcDI PROC NEAR
    PUSH DX
    MOV  DI, DX
    SHL  DI, 8      
    SHL  DX, 6      
    ADD  DI, DX     
    ADD  DI, AX     
    POP  DX
    RET
CalcDI ENDP

END