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
;   tlink main.obj map.obj player.obj input.obj, game.exe
;
; HOW TO ASSEMBLE & LINK (MASM/LINK):
;   masm main.asm;
;   masm map.asm;
;   masm player.asm;
;   masm input.asm;
;   link main.obj+map.obj+player.obj+input.obj, game.exe;

.MODEL SMALL
.STACK 200h                       ; 512-byte stack

; Externals from other team members' files
EXTRN InitMap    : NEAR           ; map.asm  – draws the static map
EXTRN DrawMap    : NEAR           ; map.asm  – redraws map each frame
EXTRN InitPlayer : NEAR           ; player.asm – sets player start pos
EXTRN UpdatePlayer : NEAR         ; player.asm – move/gravity logic
EXTRN DrawPlayer : NEAR           ; player.asm – renders player sprite
EXTRN ReadInput  : NEAR           ; input.asm – polls keyboard

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

WelcomeMsg  DB 'Starting game...', 0Dh, 0Ah, '$'

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

    ; Main Game Loop
    ; Loop: read input -> update state -> draw frame
GameLoop:
    CMP  GameRunning, 0
    JE   ExitGame                 ; if GameRunning=0, quit

    ; 1) Read keyboard input (updates player direction flags)
    CALL ReadInput

    ; 2) Update player position, apply gravity, collision
    CALL UpdatePlayer

    ; 3) Draw the scene: map first, player on top (to backbuffer)
    CALL DrawMap
    CALL DrawPlayer

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

END MAIN                          ; tells assembler where execution begins
