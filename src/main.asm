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
; HOW TO ASSEMBLE & LINK (TASM/TLINK):
;   tasm main.asm
;   tasm map.asm
;   tasm player.asm
;   tasm input.asm
;   tasm bullets.asm
;   tlink main.obj map.obj player.obj input.obj bullets.obj, game.exe
;
; HOW TO ASSEMBLE & LINK (MASM/LINK):
;   masm main.asm;
;   masm map.asm;
;   masm player.asm;
;   masm input.asm;
;   masm bullets.asm;
;   link main.obj+map.obj+player.obj+input.obj+bullets.obj, game.exe;

.MODEL SMALL
.STACK 200h                       ; 512-byte stack

; Externals from other team members' files
EXTRN InitMap    : NEAR           ; map.asm  – draws the static map
EXTRN DrawMap    : NEAR           ; map.asm  – redraws map each frame
EXTRN SelectMap  : NEAR           ; map.asm  – graphical map selector
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

Fonts LABEL BYTE
    DB 1,1,1, 1,0,1, 1,0,1, 1,0,1, 1,1,1 ; 0
    DB 0,1,0, 1,1,0, 0,1,0, 0,1,0, 1,1,1 ; 1
    DB 1,1,1, 0,0,1, 1,1,1, 1,0,0, 1,1,1 ; 2
    DB 1,1,1, 0,0,1, 1,1,1, 0,0,1, 1,1,1 ; 3
FontDash DB 0,0,0, 0,0,0, 1,1,1, 0,0,0, 0,0,0

.CODE

; MAIN PROCEDURE
; Entry point for the entire program.
MAIN PROC FAR
    ; Set up DS to point to our data segment
    MOV  AX, @DATA
    MOV  DS, AX

    ; Set up VideoSeg to point to our BackBuffer
    MOV  AX, SEG BackBuffer
    MOV  VideoSeg, AX

    ; Print welcome message in text mode first
    MOV  AH, 09h
    LEA  DX, WelcomeMsg
    INT  21h

    ; Switch to VGA Mode 13h
    ; Mode 13h: 320x200 pixels, 256 colors
    ; Video memory starts at A000:0000
    CALL SetVideoMode13h

    ; Let player select a map (graphical selector)
    CALL SelectMap

    ; Initialize map data & draw background
    CALL InitMap

    ; Initialize player (set starting position)
    CALL InitPlayer
    CALL InitPlayer2

    ; Initialize bullets
    CALL InitBullets
    
    ; Initialize powerups
    CALL InitPowerups

    ; Hook INT 9h so all keys are tracked simultaneously
    CALL InstallKbdHandler

    ; Main Game Loop
    ; Loop: read input -> update state -> draw frame
GameLoop:
    CMP  GameRunning, 0
    jne SkipExit          ; if GameRunning != 0, skip the jump
        jmp ExitGame          ; if GameRunning == 0, jump to ExitGame
    SkipExit:                 ; the rest of your loop continues here
    ; 1) Read keyboard input (updates player direction flags)
    CALL ReadInput

    ; 2) Update player position, apply gravity, collision
    CALL UpdatePlayer
    CALL UpdatePlayer2

    ; 2.5) Update bullets
    CALL UpdateBullets
    CALL UpdatePowerups
    
    ; --- Check Health & Round Win ---
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
    ; 3) Draw the scene: map first, player on top (to backbuffer)
    CALL DrawMap
    CALL DrawPlayer
    CALL DrawPlayer2
    CALL DrawBullets
    CALL DrawPowerups
    CALL DrawHealthbars
    CALL DrawScore

    ; 4) Wait for VSync before copying to screen (prevent tearing)
    CALL FramePause

    ; 5) Copy off-screen backbuffer to VGA memory (prevents flickers)
    PUSH DS
    MOV  AX, VideoSeg             ; Source = BackBuffer
    MOV  DS, AX
    MOV  AX, 0A000h               ; Destination = VGA
    MOV  ES, AX
    XOR  SI, SI                   ; Source offset = 0
    XOR  DI, DI                   ; Destination offset = 0
    MOV  CX, 32000                ; 320*200 pixels / 2 = 32000 words
    REP  MOVSW                    ; Fast block copy
    POP  DS

    JMP  GameLoop                 ; repeat forever

ExitGame:
    ; Restore text mode (mode 03h) before exit
    CALL SetTextMode

    ; Restore original INT 9h keyboard handler
    CALL RemoveKbdHandler

    ; Check if there is a winner to announce
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
    ; DOS exit (INT 21h AH=4Ch)
    MOV  AH, 4Ch
    MOV  AL, 0                    ; exit code 0 = success
    INT  21h

MAIN ENDP

; SetVideoMode13h
; Sets VGA 320x200 256-color mode (Mode 13h).
; Registers: AX destroyed.
SetVideoMode13h PROC NEAR
    MOV  AH, 00h                  ; BIOS function: set video mode
    MOV  AL, 13h                  ; mode 13h = 320x200 256-color
    INT  10h                      ; call BIOS video interrupt
    RET
SetVideoMode13h ENDP

; SetTextMode
; Restores 80x25 color text mode (Mode 03h).
; Called before program exits so the DOS prompt looks normal.
SetTextMode PROC NEAR
    MOV  AH, 00h
    MOV  AL, 03h                  ; mode 03h = 80x25 text
    INT  10h
    RET
SetTextMode ENDP

; FramePause
; Waits for the VGA vertical retrace so game speed is 
; consistent across all emulator speeds (approx 70 FPS).
FramePause PROC NEAR
    PUSH AX
    PUSH DX

    MOV  DX, 03DAh                ; VGA status port

WaitNotVSync:
    IN   AL, DX
    TEST AL, 08h                  ; bit 3 = VSync status
    JNZ  WaitNotVSync             ; if in VSync, wait for it to end

WaitVSyncStart:
    IN   AL, DX
    TEST AL, 08h
    JZ   WaitVSyncStart           ; wait until VSync begins

    POP  DX
    POP  AX
    RET
FramePause ENDP

; DrawHealthbars
; Renders health UI at the top of the screen
DrawHealthbars PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH ES
    
    MOV  AX, VideoSeg
    MOV  ES, AX
    
    ; --- Player 1 Outline ---
    MOV DX, 4
    MOV CX, 6
P1OutRow:
    PUSH CX
    MOV AX, DX
    MOV CX, 320
    MUL CX
    ADD AX, 9
    MOV DI, AX
    MOV CX, 42
    MOV AL, 08h ; Dark gray
    REP STOSB
    POP CX
    INC DX
    LOOP P1OutRow

    ; --- Player 1 Healthbar (Cyan 0Bh) ---
    ; X = 10, Y = 5. Height = 4, Width = PlayerHealth * 4
    MOV  DX, 5
    MOV  BX, PlayerHealth
    CMP  BX, 0
    JLE  DrawP2Health    ; if dead, no bar
    SHL  BX, 1           ; BX = health * 2
    SHL  BX, 1           ; BX = health * 4
    
    MOV  CX, 4           ; 4 rows
P1HRow:
    PUSH CX
    MOV  AX, DX
    MOV  CX, 320
    MUL  CX
    ADD  AX, 10          ; X = 10
    MOV  DI, AX
    
    MOV  CX, BX          ; Width
    MOV  AL, 0Bh         ; Cyan
    REP  STOSB
    
    POP  CX
    INC  DX
    LOOP P1HRow

DrawP2Health:
    ; --- Player 2 Outline ---
    MOV DX, 4
    MOV CX, 6
P2OutRow:
    PUSH CX
    MOV AX, DX
    MOV CX, 320
    MUL CX
    ADD AX, 269
    MOV DI, AX
    MOV CX, 42
    MOV AL, 08h
    REP STOSB
    POP CX
    INC DX
    LOOP P2OutRow

    ; --- Player 2 Healthbar (Red 0Ch) ---
    ; X = 310 - width, Y = 5. Height = 4, Width = Player2Health * 4
    MOV  DX, 5
    MOV  BX, Player2Health
    CMP  BX, 0
    JLE  HealthDone
    SHL  BX, 1           ; BX = health * 2
    SHL  BX, 1           ; BX = health * 4
    
    MOV  CX, 4           ; 4 rows
P2HRow:
    PUSH CX
    MOV  AX, DX
    MOV  CX, 320
    MUL  CX
    ADD  AX, 310
    SUB  AX, BX          ; X = 310 - width
    MOV  DI, AX
    
    MOV  CX, BX          ; Width
    MOV  AL, 0Ch         ; Red
    REP  STOSB
    
    POP  CX
    INC  DX
    LOOP P2HRow

HealthDone:
    POP  ES
    POP  DI
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

    MOV CX, 5
CharRowLoop:
    PUSH CX
    PUSH AX
    PUSH DX

    MOV CX, 320
    XCHG AX, DX
    MUL CX
    ADD AX, DX 
    MOV DI, AX

    MOV CX, 3
CharColLoop:
    MOV AL, DS:[SI]
    INC SI
    CMP AL, 1
    JNE CharSkip
    MOV ES:[DI], BL
CharSkip:
    INC DI
    LOOP CharColLoop

    POP DX
    POP AX
    POP CX
    INC DX
    LOOP CharRowLoop

    POP SI
    POP DI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
DrawChar ENDP

DrawScore PROC NEAR
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI
    
    MOV AX, VideoSeg
    MOV ES, AX

    ; P1 Score (X = 148, Y = 5)
    MOV AX, P1Score
    MOV BX, 15
    MUL BX
    LEA SI, Fonts
    ADD SI, AX
    MOV AX, 148
    MOV DX, 5
    MOV BL, 0Fh ; White
    CALL DrawChar

    ; Dash (X = 154, Y = 5)
    LEA SI, FontDash
    MOV AX, 154
    MOV DX, 5
    MOV BL, 0Fh
    CALL DrawChar

    ; P2 Score (X = 160, Y = 5)
    MOV AX, P2Score
    MOV BX, 15
    MUL BX
    LEA SI, Fonts
    ADD SI, AX
    MOV AX, 160
    MOV DX, 5
    MOV BL, 0Fh
    CALL DrawChar

    POP SI
    POP DX
    POP BX
    POP AX
    RET
DrawScore ENDP

END MAIN                          ; tells assembler where execution begins
