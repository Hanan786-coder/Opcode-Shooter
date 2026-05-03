; FILE: main.asm
; PERSON: Member 1
; ROLE: Entry point, game loop, DOS setup & teardown
;
; RESPONSIBILITIES:
;   - Set video mode (320x200 256-color, Mode 13h)
;   - Initialize all game data by calling init routines
;   - Run the main game loop (read input -> update -> draw)
;   - Restore text mode and exit cleanly
;
; HOW TO ASSEMBLE & LINK (MASM/LINK):
;   masm main.asm;
;   masm map.asm;
;   masm player.asm;
;   masm input.asm;
;   masm bullets.asm;
;   link main.obj+map.obj+player.obj+input.obj+bullets.obj, game.exe;

.MODEL SMALL
.286                              ; Enable 286 instructions (shift-by-immediate, etc.)
.STACK 200h                       ; 512-byte stack

; Externals from other team members' files
EXTRN InitMap    : NEAR           ; map.asm  – draws the static map
EXTRN DrawMap    : NEAR           ; map.asm  – redraws map each frame
EXTRN InitPlayer : NEAR           ; player.asm – sets player start pos
EXTRN UpdatePlayer : NEAR         ; player.asm – move/gravity logic
EXTRN DrawPlayer : NEAR           ; player.asm – renders player sprite
EXTRN InitPlayer2 : NEAR
EXTRN UpdatePlayer2 : NEAR
EXTRN DrawPlayer2 : NEAR
EXTRN ReadInput          : NEAR   ; input.asm – samples key-state table
EXTRN InstallKbdHandler  : NEAR   ; input.asm – hooks INT 9h
EXTRN RemoveKbdHandler   : NEAR   ; input.asm – restores INT 9h
EXTRN InitBullets : NEAR          ; bullets.asm – initialize bullets
EXTRN UpdateBullets : NEAR        ; bullets.asm – update bullet physics
EXTRN DrawBullets : NEAR          ; bullets.asm – render bullets
EXTRN InitPowerups : NEAR         ; powerups.asm
EXTRN UpdatePowerups : NEAR       ; powerups.asm
EXTRN DrawPowerups : NEAR         ; powerups.asm
EXTRN DrawPowerupUI : NEAR        ; powerups.asm
EXTRN PlayerHealth : WORD         ; player.asm
EXTRN Player2Health : WORD        ; player.asm
EXTRN P1Shield : BYTE             ; player.asm
EXTRN P2Shield : BYTE             ; player.asm
EXTRN P1Ultra : BYTE              ; player.asm
EXTRN P2Ultra : BYTE              ; player.asm

; Global variables used by ALL modules
PUBLIC GameRunning                ; 1 = keep looping, 0 = quit
PUBLIC FrameDelay                 ; controls game speed
PUBLIC VideoSeg                   ; Segment for double-buffering

.FARDATA
BackBuffer DB 64000 DUP (?)       ; 64KB off-screen buffer

.DATA
GameRunning DB 1                  ; game loop flag (1=running, 0=quit)
FrameDelay  DW 3000               ; inner delay loop counter
                                  ;   bigger number = slower game
VideoSeg    DW ?                  ; holds BackBuffer segment

P1Score     DW 0
P2Score     DW 0
Winner      DW 0

WelcomeMsg  DB 'Starting game...', 0Dh, 0Ah, '$'
P1WinMsg    DB 'Player 1 Wins!', 0Dh, 0Ah, '$'
P2WinMsg    DB 'Player 2 Wins!', 0Dh, 0Ah, '$'

; 3x5 pixel font for digits 0-3 and dash
Fonts LABEL BYTE
    DB 1,1,1, 1,0,1, 1,0,1, 1,0,1, 1,1,1 ; 0
    DB 0,1,0, 1,1,0, 0,1,0, 0,1,0, 1,1,1 ; 1
    DB 1,1,1, 0,0,1, 1,1,1, 1,0,0, 1,1,1 ; 2
    DB 1,1,1, 0,0,1, 1,1,1, 0,0,1, 1,1,1 ; 3
FontDash DB 0,0,0, 0,0,0, 1,1,1, 0,0,0, 0,0,0

.CODE

; MAIN PROCEDURE
MAIN PROC FAR
    MOV  AX, @DATA
    MOV  DS, AX

    MOV  AX, SEG BackBuffer
    MOV  VideoSeg, AX

    MOV  AH, 09h
    LEA  DX, WelcomeMsg
    INT  21h

    CALL SetVideoMode13h
    CALL InitMap
    CALL InitPlayer
    CALL InitPlayer2
    CALL InitBullets
    CALL InitPowerups
    CALL InstallKbdHandler

GameLoop:
    CMP  GameRunning, 0
    JNE  SkipExitGame             ; FIX: If not zero, skip the exit jump
    JMP  ExitGame                 ; FIX: Far jump to reach ExitGame
SkipExitGame:

    CALL ReadInput
    CALL UpdatePlayer
    CALL UpdatePlayer2
    CALL UpdateBullets
    CALL UpdatePowerups
    
    CMP  PlayerHealth, 0
    JG   CheckP2Health
    INC  P2Score
    CMP  P2Score, 3
    JGE  P2WinsMatch
    CALL ResetRound
    JMP  DrawScene
CheckP2Health:
    CMP  Player2Health, 0
    JG   DrawScene
    INC  P1Score
    CMP  P1Score, 3
    JGE  P1WinsMatch
    CALL ResetRound
    JMP  DrawScene

P1WinsMatch:
    MOV  Winner, 1
    MOV  GameRunning, 0
    JMP  DrawScene
P2WinsMatch:
    MOV  Winner, 2
    MOV  GameRunning, 0
    JMP  DrawScene

DrawScene:
    CALL DrawMap
    CALL DrawPlayer
    CALL DrawPlayer2
    CALL DrawBullets
    CALL DrawPowerups
    CALL DrawHealthbars
    CALL DrawPowerupUI
    CALL DrawScore

    CALL FramePause

    PUSH DS
    MOV  AX, VideoSeg             
    MOV  DS, AX
    MOV  AX, 0A000h               
    MOV  ES, AX
    XOR  SI, SI                   
    XOR  DI, DI                   
    MOV  CX, 32000                
    REP  MOVSW                    
    POP  DS

    JMP  GameLoop                 

ExitGame:
    CALL SetTextMode
    CALL RemoveKbdHandler

    CMP  Winner, 1
    JE   PrintP1Win
    CMP  Winner, 2
    JE   PrintP2Win
    JMP  DoExit
    
PrintP1Win:
    MOV  AH, 09h
    LEA  DX, P1WinMsg
    INT  21h
    JMP  DoExit
    
PrintP2Win:
    MOV  AH, 09h
    LEA  DX, P2WinMsg
    INT  21h

DoExit:
    MOV  AH, 4Ch
    MOV  AL, 0                    
    INT  21h

MAIN ENDP

SetVideoMode13h PROC NEAR
    MOV  AH, 00h                  
    MOV  AL, 13h                  
    INT  10h                      
    RET
SetVideoMode13h ENDP

SetTextMode PROC NEAR
    MOV  AH, 00h
    MOV  AL, 03h                  
    INT  10h
    RET
SetTextMode ENDP

FramePause PROC NEAR
    PUSH AX
    PUSH DX
    MOV  DX, 03DAh                
WaitNotVSync:
    IN   AL, DX
    TEST AL, 08h                  
    JNZ  WaitNotVSync             
WaitVSyncStart:
    IN   AL, DX
    TEST AL, 08h
    JZ   WaitVSyncStart           
    POP  DX
    POP  AX
    RET
FramePause ENDP

DrawHealthbars PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH ES

    MOV  AX, VideoSeg
    MOV  ES, AX

    XOR  DI, DI            
    MOV  CX, 320 * 15      
    MOV  AL, 00h
    REP  STOSB

    MOV  CX, 320
    MOV  AL, 08h
    REP  STOSB

    MOV  DX, 1
    MOV  AX, 4
    CALL CalcDI
    MOV  CX, 122
    MOV  AL, 08h
    REP  STOSB
    MOV  DX, 13
    MOV  AX, 4
    CALL CalcDI
    MOV  CX, 122
    MOV  AL, 08h
    REP  STOSB
    MOV  DX, 1
    MOV  CX, 13
HB_P1Vert:
    PUSH CX
    MOV  AX, 4
    CALL CalcDI
    MOV  AL, 08h
    STOSB
    MOV  AX, 125
    CALL CalcDI
    MOV  AL, 08h
    STOSB
    INC  DX
    POP  CX
    LOOP HB_P1Vert

    MOV  DX, 1
    MOV  AX, 195
    CALL CalcDI
    MOV  CX, 122
    MOV  AL, 08h
    REP  STOSB
    MOV  DX, 13
    MOV  AX, 195
    CALL CalcDI
    MOV  CX, 122
    MOV  AL, 08h
    REP  STOSB
    MOV  DX, 1
    MOV  CX, 13
HB_P2Vert:
    PUSH CX
    MOV  AX, 195
    CALL CalcDI
    MOV  AL, 08h
    STOSB
    MOV  AX, 316
    CALL CalcDI
    MOV  AL, 08h
    STOSB
    INC  DX
    POP  CX
    LOOP HB_P2Vert

    PUSH BP
    MOV  BX, PlayerHealth
    MOV  AL, 02h
    CMP  BX, 7
    JGE  HB_P1Col
    MOV  AL, 0Eh
    CMP  BX, 4
    JGE  HB_P1Col
    MOV  AL, 04h
HB_P1Col:
    MOV  AH, AL
    MOV  SI, 1
    MOV  BP, 5              
HB_P1Seg:
    CMP  SI, 11
    JAE  HB_P1Done
    MOV  AL, 08h
    CMP  SI, BX
    JA   HB_P1Draw
    MOV  AL, AH
HB_P1Draw:
    PUSH BP
    PUSH SI
    PUSH BX
    PUSH AX
    MOV  BL, AL
    MOV  DX, 2
    MOV  CX, 9
HB_P1Row:
    PUSH CX
    MOV  AX, BP
    CALL CalcDI
    MOV  CX, 11
    MOV  AL, BL
    REP  STOSB
    INC  DX
    POP  CX
    LOOP HB_P1Row
    POP  AX
    POP  BX
    POP  SI
    POP  BP
    ADD  BP, 12
    INC  SI
    JMP  HB_P1Seg
HB_P1Done:
    POP  BP

    PUSH BP
    MOV  BX, Player2Health
    MOV  AL, 02h
    CMP  BX, 7
    JGE  HB_P2Col
    MOV  AL, 0Eh
    CMP  BX, 4
    JGE  HB_P2Col
    MOV  AL, 04h
HB_P2Col:
    MOV  AH, AL
    MOV  SI, 1
    MOV  BP, 304
HB_P2Seg:
    CMP  SI, 11
    JAE  HB_P2Done
    MOV  AL, 08h
    CMP  SI, BX
    JA   HB_P2Draw
    MOV  AL, AH
HB_P2Draw:
    PUSH BP
    PUSH SI
    PUSH BX
    PUSH AX
    MOV  BL, AL
    MOV  DX, 2
    MOV  CX, 9
HB_P2Row:
    PUSH CX
    MOV  AX, BP
    CALL CalcDI
    MOV  CX, 11
    MOV  AL, BL
    REP  STOSB
    INC  DX
    POP  CX
    LOOP HB_P2Row
    POP  AX
    POP  BX
    POP  SI
    POP  BP
    SUB  BP, 12
    INC  SI
    JMP  HB_P2Seg
HB_P2Done:
    POP  BP

    POP  ES
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawHealthbars ENDP

ResetRound PROC NEAR
    CALL InitPlayer
    CALL InitPlayer2
    CALL InitBullets
    CALL InitPowerups
    MOV PlayerHealth, 10
    MOV Player2Health, 10
    MOV P1Shield, 0
    MOV P2Shield, 0
    MOV P1Ultra, 0
    MOV P2Ultra, 0
    RET
ResetRound ENDP

DrawChar PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    MOV  CX, 5              
DC_RowLoop:
    PUSH CX
    PUSH AX                 
    CALL CalcDI
    POP  AX                 
    MOV  CX, 3
DC_ColLoop:
    MOV  AL, DS:[SI]
    INC  SI
    CMP  AL, 1
    JNE  DC_Skip
    MOV  ES:[DI], BL
DC_Skip:
    INC  DI
    LOOP DC_ColLoop
    INC  DX                 
    POP  CX
    LOOP DC_RowLoop
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawChar ENDP

DrawScore PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH ES
    MOV  AX, VideoSeg
    MOV  ES, AX
    MOV  SI, 1          
    MOV  BX, P1Score    
    MOV  DX, 3          
DS_P1Loop:
    CMP  SI, 4
    JAE  DS_P1Done
    MOV  AL, 08h        
    CMP  SI, BX
    JA   DS_P1Draw      
    MOV  AL, 0Bh        
DS_P1Draw:
    PUSH DX             
    PUSH SI
    MOV  SI, 2          
DS_P1Row:
    PUSH SI
    PUSH AX             
    MOV  AX, 142        
    CALL CalcDI
    POP  AX             
    MOV  CX, 12         
    REP  STOSB
    POP  SI
    INC  DX             
    DEC  SI
    JNZ  DS_P1Row
    POP  SI
    POP  DX
    ADD  DX, 4          
    INC  SI
    JMP  DS_P1Loop
DS_P1Done:

    MOV  SI, 1
    MOV  BX, P2Score
    MOV  DX, 3          
DS_P2Loop:
    CMP  SI, 4
    JAE  DS_P2Done
    MOV  AL, 08h
    CMP  SI, BX
    JA   DS_P2Draw
    MOV  AL, 0Ch        
DS_P2Draw:
    PUSH DX
    PUSH SI
    MOV  SI, 2
DS_P2Row:
    PUSH SI
    PUSH AX             
    MOV  AX, 166        
    CALL CalcDI
    POP  AX             
    MOV  CX, 12
    REP  STOSB
    POP  SI
    INC  DX
    DEC  SI
    JNZ  DS_P2Row
    POP  SI
    POP  DX
    ADD  DX, 4          
    INC  SI
    JMP  DS_P2Loop
DS_P2Done:
    POP  ES
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawScore ENDP

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

END MAIN