; FILE: powerups.asm
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

PwrActive DB 3 DUP (0)
PwrType   DB 3 DUP (0)
PwrX      DW 3 DUP (0)
PwrY      DW 3 DUP (0)

SpawnTimer DW 150
RandSeed   DW 1234h

BGC EQU 0Bh 
RD  EQU 0Ch 
BLU EQU 09h 
YL  EQU 0Eh 

SprHeal DB 0Bh, 0Ch, 0Ch, 0Bh, 0Bh, 0Ch, 0Ch, 0Bh
        DB 0Ch, 0Ch, 0Ch, 0Ch, 0Ch, 0Ch, 0Ch, 0Ch
        DB 0Ch, 0Ch, 0Ch, 0Ch, 0Ch, 0Ch, 0Ch, 0Ch
        DB 0Bh, 0Ch, 0Ch, 0Ch, 0Ch, 0Ch, 0Ch, 0Bh
        DB 0Bh, 0Bh, 0Ch, 0Ch, 0Ch, 0Ch, 0Bh, 0Bh
        DB 0Bh, 0Bh, 0Bh, 0Ch, 0Ch, 0Bh, 0Bh, 0Bh
        DB 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh
        DB 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh

SprShield DB 09h, 09h, 09h, 09h, 09h, 09h, 09h, 09h
          DB 09h, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 09h
          DB 09h, 0Bh, 09h, 09h, 09h, 09h, 0Bh, 09h
          DB 09h, 0Bh, 09h, 09h, 09h, 09h, 0Bh, 09h
          DB 0Bh, 09h, 0Bh, 0Bh, 0Bh, 0Bh, 09h, 0Bh
          DB 0Bh, 0Bh, 09h, 0Bh, 0Bh, 09h, 0Bh, 0Bh
          DB 0Bh, 0Bh, 0Bh, 09h, 09h, 0Bh, 0Bh, 0Bh
          DB 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh

SprUltra DB 0Bh, 0Bh, 0Bh, 0Eh, 0Eh, 0Bh, 0Bh, 0Bh
         DB 0Bh, 0Bh, 0Eh, 0Eh, 0Eh, 0Eh, 0Bh, 0Bh
         DB 0Eh, 0Eh, 0Eh, 0Eh, 0Eh, 0Eh, 0Eh, 0Eh
         DB 0Bh, 0Eh, 0Eh, 0Eh, 0Eh, 0Eh, 0Eh, 0Bh
         DB 0Bh, 0Bh, 0Eh, 0Eh, 0Eh, 0Eh, 0Bh, 0Bh
         DB 0Bh, 0Eh, 0Eh, 0Bh, 0Bh, 0Eh, 0Eh, 0Bh
         DB 0Eh, 0Eh, 0Bh, 0Bh, 0Bh, 0Bh, 0Eh, 0Eh
         DB 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh, 0Bh

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
    JGE  InitDone
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
    JG   CheckCol
    MOV  SpawnTimer, SPAWN_INTERVAL
    XOR  BX, BX
FindFree:
    CMP  BX, MAX_POWERUPS
    JL   CheckFreeSlot
    JMP  CheckCol
CheckFreeSlot:
    CMP  PwrActive[BX], 0
    JE   SpawnSlot
    INC  BX
    JMP  FindFree
SpawnSlot:
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

CheckCol:
    XOR  BX, BX
UpdLoop:
    CMP  BX, MAX_POWERUPS
    JL   ContUpd
    JMP  UpdDone
ContUpd:
    CMP  PwrActive[BX], 0
    JNE  ContUpd2
    JMP  NextPwr
ContUpd2:
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

DrawPowerups PROC NEAR
    PUSH ES
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    MOV  AX, VideoSeg
    MOV  ES, AX
    XOR  BX, BX
DrwLoop:
    CMP  BX, MAX_POWERUPS
    JL   ContDrw
    JMP  DrwDone
ContDrw:
    CMP  PwrActive[BX], 0
    JNE  ContDrw2
    JMP  DrwNext
ContDrw2:
    MOV  SI, BX
    SHL  SI, 1
    MOV  AX, PwrX[SI]
    MOV  DX, PwrY[SI]
    MOV  CL, PwrType[BX]
    CMP  CL, 1
    JE   UseUltra
    CMP  CL, 2
    JE   UseShield
    LEA  SI, SprHeal
    JMP  DoDraw
UseUltra:
    LEA  SI, SprUltra
    JMP  DoDraw
UseShield:
    LEA  SI, SprShield
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
    MOV  AL, [SI]
    INC  SI
    CMP  AL, 0Bh
    JE   SkipPix
    STOSB
    DEC  DI
SkipPix:
    INC  DI
    LOOP DrwCol
    POP  AX
    POP  CX
    POP  DX
    INC  DX
    LOOP DrwRow
DrwNext:
    INC  BX
    JMP  DrwLoop
DrwDone:
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