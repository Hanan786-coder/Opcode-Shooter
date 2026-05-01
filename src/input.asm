
; FILE: input.asm
; ROLE: Keyboard input handling
; Uses INT 9h hook + 128-byte key-state table so that
; any number of keys can be held simultaneously.
;
; HOW IT WORKS:
;   InstallKbdHandler  - saves old INT 9h vector, installs our handler
;   RemoveKbdHandler   - restores original INT 9h vector (call before exit)
;   ReadInput          - samples KeyState[] table and sets Move/Jump flags
;
; CALL SEQUENCE (from main.asm):
;   CALL InstallKbdHandler   ; once, before game loop
;   ... game loop calls CALL ReadInput every frame ...
;   CALL RemoveKbdHandler    ; once, before returning to DOS

.MODEL SMALL

EXTRN GameRunning : BYTE

PUBLIC MoveLeft
PUBLIC MoveRight
PUBLIC DoJump
PUBLIC MoveLeft2
PUBLIC MoveRight2
PUBLIC DoJump2
PUBLIC ReadInput
PUBLIC InstallKbdHandler
PUBLIC RemoveKbdHandler

.DATA

MoveLeft    DB  0
MoveRight   DB  0
DoJump      DB  0

MoveLeft2   DB  0
MoveRight2  DB  0
DoJump2     DB  0

SCAN_LEFT   EQU 4Bh
SCAN_RIGHT  EQU 4Dh
SCAN_UP     EQU 48h
SCAN_ESC    EQU 01h

SCAN_A      EQU 1Eh
SCAN_D      EQU 20h
SCAN_W      EQU 11h

; Saved old INT 9h vector
OldInt9Off  DW  0
OldInt9Seg  DW  0

; 128-byte key-state table: KeyState[scancode] = 1 held, 0 released
KeyState    DB  128 DUP (0)

.CODE
; KbdHandler - INT 9h ISR
; Reads scan code from port 60h, updates KeyState[], then chains
; to the original BIOS INT 9h so the BIOS buffer still functions.
; ---------------------------------------------------------------
KbdHandler PROC FAR
    PUSH AX
    PUSH BX
    PUSH DS
    MOV  AX, @DATA
    MOV  DS, AX

    IN   AL, 60h           ; read raw scan code from keyboard controller

    MOV  BL, AL
    AND  BL, 7Fh           ; strip high bit to get base scan code
    MOV  BH, 0
    CMP  BX, 128
    JAE  KbdChain          ; ignore any out-of-range scan codes

    TEST AL, 80h
    JNZ  KeyRelease

KeyPress:
    MOV  KeyState[BX], 1
    JMP  KbdChain

KeyRelease:
    MOV  KeyState[BX], 0

KbdChain:
    POP  DS
    POP  BX
    POP  AX

    ; Far jump to original BIOS handler (ACKs controller, updates shift flags)
    DB   0EAh              ; far JMP opcode
OldVecOff   DW  0          ; offset  - filled by InstallKbdHandler
OldVecSeg   DW  0          ; segment - filled by InstallKbdHandler

KbdHandler ENDP


; ---------------------------------------------------------------
; InstallKbdHandler - call once before the game loop
; ---------------------------------------------------------------
InstallKbdHandler PROC NEAR
    PUSH AX
    PUSH BX
    PUSH DS
    PUSH ES

    ; Read current INT 9h vector
    MOV  AX, 3509h
    INT  21h               ; returns vector in ES:BX

    ; Save in data segment
    MOV  AX, @DATA
    MOV  DS, AX
    MOV  OldInt9Off, BX
    MOV  OldInt9Seg, ES

    ; Also patch the far-JMP inside KbdHandler (in code segment)
    MOV  CS:[OldVecOff], BX
    MOV  CS:[OldVecSeg], ES

    ; Install KbdHandler as new INT 9h
    MOV  AX, 2509h
    PUSH CS
    POP  DS
    LEA  DX, KbdHandler
    INT  21h

    POP  ES
    POP  DS
    POP  BX
    POP  AX
    RET
InstallKbdHandler ENDP


; ---------------------------------------------------------------
; RemoveKbdHandler - call once before returning to DOS
; ---------------------------------------------------------------
RemoveKbdHandler PROC NEAR
    PUSH AX
    PUSH DS

    MOV  AX, @DATA
    MOV  DS, AX

    MOV  AX, 2509h
    MOV  DX, OldInt9Off
    MOV  AX, OldInt9Seg
    MOV  DS, AX
    MOV  AX, 2509h
    INT  21h

    POP  DS
    POP  AX
    RET
RemoveKbdHandler ENDP


; ---------------------------------------------------------------
; ReadInput - call every frame
; Samples KeyState[] and sets the movement flags.
; ---------------------------------------------------------------
ReadInput PROC NEAR
    PUSH AX
    PUSH BX
    PUSH DS

    MOV  AX, @DATA
    MOV  DS, AX

    ; Clear all flags
    MOV  MoveLeft,   0
    MOV  MoveRight,  0
    MOV  DoJump,     0
    MOV  MoveLeft2,  0
    MOV  MoveRight2, 0
    MOV  DoJump2,    0

    ; Player 1 - Arrow keys
    MOV  BX, SCAN_LEFT
    CMP  KeyState[BX], 1
    JNE  ChkRight
    MOV  MoveLeft, 1

ChkRight:
    MOV  BX, SCAN_RIGHT
    CMP  KeyState[BX], 1
    JNE  ChkUp
    MOV  MoveRight, 1

ChkUp:
    MOV  BX, SCAN_UP
    CMP  KeyState[BX], 1
    JNE  ChkA
    MOV  DoJump, 1

    ; Player 2 - WASD
ChkA:
    MOV  BX, SCAN_A
    CMP  KeyState[BX], 1
    JNE  ChkD
    MOV  MoveLeft2, 1

ChkD:
    MOV  BX, SCAN_D
    CMP  KeyState[BX], 1
    JNE  ChkW
    MOV  MoveRight2, 1

ChkW:
    MOV  BX, SCAN_W
    CMP  KeyState[BX], 1
    JNE  ChkEsc
    MOV  DoJump2, 1

ChkEsc:
    MOV  BX, SCAN_ESC
    CMP  KeyState[BX], 1
    JNE  ReadDone
    MOV  GameRunning, 0

ReadDone:
    POP  DS
    POP  BX
    POP  AX
    RET
ReadInput ENDP

END
