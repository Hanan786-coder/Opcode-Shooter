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
; Each digit = 15 bytes (5 rows of 3 pixels)
Fonts LABEL BYTE
    DB 1,1,1, 1,0,1, 1,0,1, 1,0,1, 1,1,1 ; 0
    DB 0,1,0, 1,1,0, 0,1,0, 0,1,0, 1,1,1 ; 1
    DB 1,1,1, 0,0,1, 1,1,1, 1,0,0, 1,1,1 ; 2
    DB 1,1,1, 0,0,1, 1,1,1, 0,0,1, 1,1,1 ; 3
FontDash DB 0,0,0, 0,0,0, 1,1,1, 0,0,0, 0,0,0

; --- UI Layout Constants ---
; HUD strip:  Y = 0..15  (16 rows)
; Separator:  Y = 15
; P1 bar:     X = 5..124,  10 segments each 11px wide + 1px gap
; P2 bar:     X = 196..315, same mirrored
; Score area: X = 140..179, Y = 3..8  (center of HUD)
; P1 icon:    X = 128..136, Y = 3 (just left of score)
; P2 icon:    X = 183..191, Y = 3 (just right of score)

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
    JE   ExitGame                 ; if GameRunning=0, quit

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
    CALL DrawPowerupUI
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

; ---------------------------------------------------------------
; DrawHealthbars
; Draws the full HUD strip at the top of the screen (Y=0..15).
;   - Black background (Y=0..14)
;   - Dark-gray separator line (Y=15)
;   - P1 bar: 10 segments, X=5..124  (seg width=11, gap=1)
;   - P2 bar: 10 segments, X=196..315 (mirrors P1, depletes right->left)
;   - Segment colors: green(02h) hp>=7, yellow(0Eh) hp>=4, red(04h) hp<4
;   - Empty segment: dark-gray (08h)
; ---------------------------------------------------------------
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

    ; === Clear HUD strip Y=0..14 to black ===
    XOR  DI, DI            ; offset 0 = (Y=0, X=0)
    MOV  CX, 320 * 15      ; 15 rows * 320 pixels
    MOV  AL, 00h
    REP  STOSB

    ; === Separator line Y=15 in dark-gray (08h) ===
    ; DI is now at offset 320*15 = 4800
    MOV  CX, 320
    MOV  AL, 08h
    REP  STOSB

    ; === Draw P1 border box  X=4..125, Y=1..13 (dark gray 08h) ===
    ; Top edge Y=1
    MOV  DX, 1
    MOV  AX, 4
    CALL CalcDI
    MOV  CX, 122
    MOV  AL, 08h
    REP  STOSB
    ; Bottom edge Y=13
    MOV  DX, 13
    MOV  AX, 4
    CALL CalcDI
    MOV  CX, 122
    MOV  AL, 08h
    REP  STOSB
    ; Left/right vertical edges Y=1..13
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

    ; === Draw P2 border box  X=195..316, Y=1..13 ===
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

    ; ===================================================
    ; P1 HEALTH BAR  (X=5, 10 segments of 11px wide, 1px gap)
    ; BP = segment X,  SI = segment index 1..10
    ; BX = health,     AH = fill color
    ; ===================================================
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
    MOV  BP, 5              ; BP = segment X (safe from CalcDI)
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

    ; ===================================================
    ; P2 HEALTH BAR  (depletes right-to-left, mirror of P1)
    ; Rightmost seg at X=304, each seg 11px, step left by 12
    ; ===================================================
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

; ---------------------------------------------------------------
; DrawChar
; Draws a 3x5 pixel font character.
; Input: AX=X, DX=Y, BL=color, SI=pointer to 15-byte font data
; ES must already point to VideoSeg.
; Clobbers: CX, DI (ES preserved, AX/DX/SI/BL preserved via stack)
; ---------------------------------------------------------------
DrawChar PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI

    MOV  CX, 5              ; 5 rows
DC_RowLoop:
    PUSH CX
    PUSH AX                 ; save X
    CALL CalcDI
    POP  AX                 ; restore X

    ; Draw 3 pixels of this row
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

    INC  DX                 ; next row Y
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

; ---------------------------------------------------------------
; DrawScore
; Renders  "P1score - P2score"  centered in the HUD (Y=4..8).
; Score digits are 3x5 pixels, drawn at:
;   P1 digit: X=147, Y=4  in cyan (0Bh)
;   dash:     X=152, Y=4  in white (0Fh)
;   P2 digit: X=157, Y=4  in red (0Ch)
; ---------------------------------------------------------------
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

    ; --- P1 Score Lines (Fills Top -> Down) ---
    MOV  SI, 1          ; Block index 1..3
    MOV  BX, P1Score    ; BX = current score
    MOV  DX, 3          ; *** START AT TOP (Y=3) ***
DS_P1Loop:
    CMP  SI, 4
    JAE  DS_P1Done

    MOV  AL, 08h        ; Default: EMPTY color (dark gray)
    CMP  SI, BX
    JA   DS_P1Draw      ; If index > score, keep gray
    MOV  AL, 0Bh        ; Otherwise: FILLED color (cyan)
DS_P1Draw:
    PUSH DX             ; Save current Y
    PUSH SI
    MOV  SI, 2          ; Height (2 rows per line)
DS_P1Row:
    PUSH SI
    PUSH AX             ; *** SAVE COLOR ***
    MOV  AX, 142        ; X coordinate
    CALL CalcDI
    POP  AX             ; *** RESTORE COLOR ***
    MOV  CX, 12         ; Width
    REP  STOSB
    POP  SI
    INC  DX             ; Next row
    DEC  SI
    JNZ  DS_P1Row
    
    POP  SI
    POP  DX
    ADD  DX, 4          ; *** MOVE DOWN FOR NEXT POINT ***
    INC  SI
    JMP  DS_P1Loop
DS_P1Done:

    ; --- P2 Score Lines (Fills Top -> Down) ---
    MOV  SI, 1
    MOV  BX, P2Score
    MOV  DX, 3          ; *** START AT TOP (Y=3) ***
DS_P2Loop:
    CMP  SI, 4
    JAE  DS_P2Done

    MOV  AL, 08h
    CMP  SI, BX
    JA   DS_P2Draw
    MOV  AL, 0Ch        ; FILLED color (red)
DS_P2Draw:
    PUSH DX
    PUSH SI
    MOV  SI, 2
DS_P2Row:
    PUSH SI
    PUSH AX             ; *** SAVE COLOR ***
    MOV  AX, 166        ; X coordinate
    CALL CalcDI
    POP  AX             ; *** RESTORE COLOR ***
    MOV  CX, 12
    REP  STOSB
    POP  SI
    INC  DX
    DEC  SI
    JNZ  DS_P2Row

    POP  SI
    POP  DX
    ADD  DX, 4          ; *** MOVE DOWN FOR NEXT POINT ***
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

END MAIN                          ; tells assembler where execution begins
