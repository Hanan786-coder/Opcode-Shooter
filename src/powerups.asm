; FILE: powerups.asm
; ROLE: Randomly spawning powerups, rendering, and player collision

.MODEL SMALL

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
EXTRN VideoSeg : WORD

PUBLIC InitPowerups
PUBLIC UpdatePowerups
PUBLIC DrawPowerups

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

BGC EQU 0Bh ; Transparent
RD  EQU 0Ch ; Red
BLU  EQU 09h ; Blue
YL  EQU 0Eh ; Yellow

; 8x8 Heart (Heal - Type 3)
SprHeal LABEL BYTE
  DB BGC, RD,  RD,  BGC, BGC, RD,  RD,  BGC
  DB RD,  RD,  RD,  RD,  RD,  RD,  RD,  RD
  DB RD,  RD,  RD,  RD,  RD,  RD,  RD,  RD
  DB BGC, RD,  RD,  RD,  RD,  RD,  RD,  BGC
  DB BGC, BGC, RD,  RD,  RD,  RD,  BGC, BGC
  DB BGC, BGC, BGC, RD,  RD,  BGC, BGC, BGC
  DB BGC, BGC, BGC, BGC, BGC, BGC, BGC, BGC
  DB BGC, BGC, BGC, BGC, BGC, BGC, BGC, BGC

; 8x8 Shield (Shield - Type 2)
SprShield LABEL BYTE
  DB BLU,  BLU,  BLU,  BLU,  BLU,  BLU,  BLU,  BLU
  DB BLU,  BGC, BGC, BGC, BGC, BGC, BGC, BLU
  DB BLU,  BGC, BLU,  BLU,  BLU,  BLU,  BGC, BLU
  DB BLU,  BGC, BLU,  BLU,  BLU,  BLU,  BGC, BLU
  DB BGC, BLU,  BGC, BGC, BGC, BGC, BLU,  BGC
  DB BGC, BGC, BLU,  BGC, BGC, BLU,  BGC, BGC
  DB BGC, BGC, BGC, BLU,  BLU,  BGC, BGC, BGC
  DB BGC, BGC, BGC, BGC, BGC, BGC, BGC, BGC

; 8x8 Star (Ultra Bullet - Type 1)
SprUltra LABEL BYTE
  DB BGC, BGC, BGC, YL,  YL,  BGC, BGC, BGC
  DB BGC, BGC, YL,  YL,  YL,  YL,  BGC, BGC
  DB YL,  YL,  YL,  YL,  YL,  YL,  YL,  YL
  DB BGC, YL,  YL,  YL,  YL,  YL,  YL,  BGC
  DB BGC, BGC, YL,  YL,  YL,  YL,  BGC, BGC
  DB BGC, YL,  YL,  BGC, BGC, YL,  YL,  BGC
  DB YL,  YL,  BGC, BGC, BGC, BGC, YL,  YL
  DB BGC, BGC, BGC, BGC, BGC, BGC, BGC, BGC

.CODE

; ---------------------------------------------------------------
; Random Number Generator
; ---------------------------------------------------------------
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
    ; BX = max value (returns 0 to BX-1)
    PUSH DX
    CALL Random
    XOR  DX, DX
    DIV  BX
    MOV  AX, DX
    POP  DX
    RET
RandomRange ENDP

; ---------------------------------------------------------------
; Initialization
; ---------------------------------------------------------------
InitPowerups PROC NEAR
    PUSH AX
    PUSH DX
    
    ; Seed RNG from system timer
    MOV  AH, 00h
    INT  1Ah
    MOV  RandSeed, DX
    
    ; Clear arrays
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

; ---------------------------------------------------------------
; Update
; ---------------------------------------------------------------
UpdatePowerups PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; Spawn logic
    DEC  SpawnTimer
    CMP  SpawnTimer, 0
    JG   CheckCol
    
    ; Reset timer
    MOV  SpawnTimer, SPAWN_INTERVAL
    
    ; Find free slot
    XOR  BX, BX
FindFree:
    CMP  BX, MAX_POWERUPS
    JAE  CheckCol        ; No free slots
    CMP  PwrActive[BX], 0
    JE   SpawnSlot
    INC  BX
    JMP  FindFree
    
SpawnSlot:
    MOV  PwrActive[BX], 1
    
    ; Random Type (1 to 3)
    PUSH BX
    MOV  BX, 3
    CALL RandomRange
    INC  AX
    POP  BX
    MOV  PwrType[BX], AL
    
    ; Random X (10 to 300)
    PUSH BX
    MOV  BX, 290
    CALL RandomRange
    ADD  AX, 10
    POP  BX
    MOV  SI, BX
    SHL  SI, 1
    MOV  PwrX[SI], AX
    
    ; Random Y (30 to 160)
    PUSH BX
    MOV  BX, 130
    CALL RandomRange
    ADD  AX, 30
    POP  BX
    MOV  PwrY[SI], AX

CheckCol:
    XOR  BX, BX
UpdLoop:
    CMP  BX, MAX_POWERUPS
    JAE  UpdDone
    CMP  PwrActive[BX], 0
    JE   NextPwr
    
    MOV  SI, BX
    SHL  SI, 1
    
    ; Check collision with Player 1
    MOV  AX, PwrX[SI]
    MOV  CX, PwrY[SI]
    
    ; P1 X check
    MOV  DX, PlayerX
    ADD  DX, PLAYER_W
    CMP  AX, DX
    JGE  CheckP2
    MOV  DX, AX
    ADD  DX, POWERUP_W
    CMP  DX, PlayerX
    JLE  CheckP2
    
    ; P1 Y check
    MOV  DX, PlayerY
    ADD  DX, PLAYER_H
    CMP  CX, DX
    JGE  CheckP2
    MOV  DX, CX
    ADD  DX, POWERUP_H
    CMP  DX, PlayerY
    JLE  CheckP2
    
    ; Hit P1
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
    MOV  P1Ultra, 3
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
    ; P2 X check
    MOV  DX, Player2X
    ADD  DX, PLAYER_W
    CMP  AX, DX
    JGE  NextPwr
    MOV  DX, AX
    ADD  DX, POWERUP_W
    CMP  DX, Player2X
    JLE  NextPwr
    
    ; P2 Y check
    MOV  DX, Player2Y
    ADD  DX, PLAYER_H
    CMP  CX, DX
    JGE  NextPwr
    MOV  DX, CX
    ADD  DX, POWERUP_H
    CMP  DX, Player2Y
    JLE  NextPwr
    
    ; Hit P2
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
    MOV  P2Ultra, 3
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

; ---------------------------------------------------------------
; Drawing
; ---------------------------------------------------------------
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
    
    ; Select sprite
    MOV  CL, PwrType[BX]
    CMP  CL, 1
    JE   UseUltra
    CMP  CL, 2
    JE   UseShield
    ; Type 3 Heal
    LEA  BP, SprHeal
    JMP  DoDraw
    
UseUltra:
    LEA  BP, SprUltra
    JMP  DoDraw
    
UseShield:
    LEA  BP, SprShield
    
DoDraw:
    ; Draw 8x8 sprite at AX, DX
    MOV  CX, POWERUP_H
DrwRow:
    PUSH DX
    PUSH CX
    PUSH AX
    
    MOV  DI, DX
    MOV  CX, 320
    XCHG AX, DI
    MUL  CX
    ADD  DI, AX     ; DI = Y * 320 + X
    
    MOV  CX, POWERUP_W
DrwCol:
    MOV  AL, DS:[BP]
    INC  BP
    CMP  AL, BGC
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

END
