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

BGC EQU 0   ; not used for letters, kept for DrawPowerups sprites

; 8x8 Heart (Heal - Type 3) - kept for world pickup sprites
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

; -----------------------------------------------------
; DrawPowerupUI
; Draws two 5x9 indicator blocks per player inside HUD.
; Slot layout (Y=2..10, height=9):
;   P1 Ultra  block: X=128  yellow (0Eh) if active, dark (08h) if not
;   P1 Shield block: X=134  blue   (09h) if active, dark (08h) if not
;   P2 Ultra  block: X=183  yellow (0Eh) if active, dark (08h) if not
;   P2 Shield block: X=189  blue   (09h) if active, dark (08h) if not
; -----------------------------------------------------
DrawPowerupUI PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH ES

    MOV  AX, VideoSeg
    MOV  ES, AX

    ; --- P1 Indicators (Moved further right to X=130/136) ---
    MOV  AL, 00h        ; Black (Hidden)
    CMP  P1Ultra, 1
    JNE  PUI_P1U
    MOV  AL, 0Eh        ; Yellow
PUI_P1U:
    MOV  BL, AL
    MOV  AX, 130        ; Safe X
    CALL DrawBlock5x9

    MOV  AL, 00h
    CMP  P1Shield, 1
    JNE  PUI_P1S
    MOV  AL, 09h        ; Blue
PUI_P1S:
    MOV  BL, AL
    MOV  AX, 136        ; Safe X
    CALL DrawBlock5x9

    ; --- P2 Indicators (Moved further left to X=178/184) ---
    MOV  AL, 00h
    CMP  P2Ultra, 1
    JNE  PUI_P2U
    MOV  AL, 0Eh
PUI_P2U:
    MOV  BL, AL
    MOV  AX, 178        ; Safe X
    CALL DrawBlock5x9

    MOV  AL, 00h
    CMP  P2Shield, 1
    JNE  PUI_P2S
    MOV  AL, 09h
PUI_P2S:
    MOV  BL, AL
    MOV  AX, 184        ; Safe X
    CALL DrawBlock5x9

    POP  ES
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawPowerupUI ENDP

; -----------------------------------------------------
; DrawBlock5x9
; Draws a 5x9 filled rectangle at X=AX, Y=2..10, color=BL
; ES must point to VideoSeg.
; -----------------------------------------------------
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

; -----------------------------------------------------
; CalcDI
; Helper to compute offset without using MUL (which clobbers DX/AX)
; Input:  DX = Y, AX = X
; Output: DI = (Y * 320) + X
; -----------------------------------------------------
CalcDI PROC NEAR
    PUSH DX
    MOV  DI, DX
    SHL  DI, 8      ; DI = Y * 256
    SHL  DX, 6      ; DX = Y * 64
    ADD  DI, DX     ; DI = Y * 320
    ADD  DI, AX     ; DI = Y * 320 + X
    POP  DX
    RET
CalcDI ENDP

END
