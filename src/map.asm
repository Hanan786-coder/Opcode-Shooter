; FILE: map.asm
; Beautiful flicker-free map selection menu + game map routines.
;
; Menu design:
;   - All drawing goes to BackBuffer (VideoSeg), vsync-blitted to 0A000h
;   - Three colorful panels (cyan/blue, gray/dark, magenta/purple)
;   - Working miniature map previews inside each panel (4x7 px per tile)
;   - Pixel-font "SELECT MAP" title and instruction line
;   - Selected panel highlighted with yellow double border
;   - Zero flicker: keyboard polled once per complete drawn frame

.MODEL SMALL
.286

EXTRN GameRunning : BYTE
EXTRN VideoSeg    : WORD

PUBLIC InitMap
PUBLIC DrawMap
PUBLIC SelectMap
PUBLIC MapData
PUBLIC MAP_COLS
PUBLIC MAP_ROWS
PUBLIC TILE_W
PUBLIC TILE_H
PUBLIC MAPINDEX
PUBLIC SKYCOLOR
PUBLIC GROUNDCOLOR

; ===================================================================
.DATA
; ===================================================================

MAP_COLS    EQU 20
MAP_ROWS    EQU 12
TILE_W      EQU 16
TILE_H      EQU 16

SKYCOLOR    DB 01h
GROUNDCOLOR DB 02h
MAPINDEX    DB 1

COLOR_SKY1  EQU 01h
COLOR_SKY2  EQU 03h
COLOR_SKY3  EQU 05h      ; dark magenta (valid EGA palette index)

; ------ Panel geometry (3 panels x 96px wide, gap 10, margin 6) ---
; 6+96+10+96+10+96+6 = 320 exact
PANEL_Y     EQU 28
PANEL_H     EQU 144
PANEL_W     EQU 96
PANEL1_X    EQU 6
PANEL2_X    EQU 112
PANEL3_X    EQU 218

; Preview tile dimensions (20col * 4 = 80px, 12row * 7 = 84px)
PREV_OFF_X  EQU 9          ; inset from panel left
PREV_OFF_Y  EQU 4          ; inset from panel top
TILE_PW     EQU 4          ; preview tile width in pixels
TILE_PH     EQU 7          ; preview tile height in pixels

; ------ Per-panel colors ------------------------------------------
P1_BG       EQU 01h        ; blue sky
P1_TILE     EQU 02h        ; green ground
P1_BORDER   EQU 0Bh        ; bright cyan
P1_LABEL    EQU 0Bh

P2_BG       EQU 00h        ; black night
P2_TILE     EQU 06h        ; brown stone
P2_BORDER   EQU 07h        ; gray
P2_LABEL    EQU 07h

P3_BG       EQU 05h        ; dark magenta sky
P3_TILE     EQU 0Fh        ; white
P3_BORDER   EQU 0Dh        ; bright magenta
P3_LABEL    EQU 0Dh

SEL_BORDER  EQU 0Eh        ; yellow selection highlight

; ------ Keyboard scan codes (make codes) --------------------------
SCAN_1      EQU 02h
SCAN_2      EQU 03h
SCAN_3      EQU 04h
SCAN_ESC    EQU 01h

; ------ Scratch variables (used by drawing procs) -----------------
SM_BaseX    DW 0
SM_BaseY    DW 0
SM_CurX     DW 0
SM_CurY     DW 0
SM_Scale    DB 1
SM_Color    DB 0

SDL_X       DW 0
SDL_Y       DW 0
SDL_Color   DB 0

SDPC_SelFlag DB 0          ; selected flag passed to SM_DrawPanel
SDPC_TileCol DB 0          ; tile color passed to SM_DrawPanel
SDPC_BordCol DB 0          ; border color passed to SM_DrawPanel

; ===================================================================
; Map templates
; ===================================================================
MapData DB 240 DUP (0)

Map1Template LABEL BYTE
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

Map2Template LABEL BYTE
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,1,1,1,0,0,1,1,1,1,0,0,1,1,1,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 1,1,1,1,1,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,1,1,1,0,0,0,0,1,1,1,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

Map3Template LABEL BYTE
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

; ===================================================================
; Pixel font: 5 rows x 5 cols (25 bytes, 1=on 0=off)
; ===================================================================
GlyphS  DB 1,1,1,1,0, 1,0,0,0,0, 1,1,1,1,0, 0,0,0,1,0, 1,1,1,1,0
GlyphE  DB 1,1,1,1,0, 1,0,0,0,0, 1,1,1,0,0, 1,0,0,0,0, 1,1,1,1,0
GlyphL  DB 1,0,0,0,0, 1,0,0,0,0, 1,0,0,0,0, 1,0,0,0,0, 1,1,1,1,0
GlyphC  DB 0,1,1,1,0, 1,0,0,0,0, 1,0,0,0,0, 1,0,0,0,0, 0,1,1,1,0
GlyphT  DB 1,1,1,1,1, 0,0,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,1,0,0
GlyphM  DB 1,0,0,0,1, 1,1,0,1,1, 1,0,1,0,1, 1,0,0,0,1, 1,0,0,0,1
GlyphA  DB 0,1,1,1,0, 1,0,0,0,1, 1,1,1,1,1, 1,0,0,0,1, 1,0,0,0,1
GlyphP  DB 1,1,1,1,0, 1,0,0,0,1, 1,1,1,1,0, 1,0,0,0,0, 1,0,0,0,0
GlyphR  DB 1,1,1,1,0, 1,0,0,0,1, 1,1,1,1,0, 1,0,1,0,0, 1,0,0,1,0
GlyphO  DB 0,1,1,1,0, 1,0,0,0,1, 1,0,0,0,1, 1,0,0,0,1, 0,1,1,1,0
GlyphK  DB 1,0,0,1,0, 1,0,1,0,0, 1,1,0,0,0, 1,0,1,0,0, 1,0,0,1,0
GlyphI  DB 0,1,1,1,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,1,0,0, 0,1,1,1,0
GlyphY  DB 1,0,0,0,1, 0,1,0,1,0, 0,0,1,0,0, 0,0,1,0,0, 0,0,1,0,0
GlyphSpace DB 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0
GlyphColon DB 0,0,0,0,0, 0,0,1,0,0, 0,0,0,0,0, 0,0,1,0,0, 0,0,0,0,0

; 3-wide x 5-tall digit glyphs
Glyph1  DB 0,1,0, 1,1,0, 0,1,0, 0,1,0, 1,1,1
Glyph2  DB 1,1,1, 0,0,1, 1,1,1, 1,0,0, 1,1,1
Glyph3  DB 1,1,1, 0,0,1, 0,1,1, 0,0,1, 1,1,1

; Map name label strings (glyph index, 0=end)
; 1=S 2=E 3=L 4=C 5=T 6=M 7=A 8=P 9=R 10=O 11=K 12=I 13=Y
NameClassic DB 4,3,7,1,1,12,4,0   ; CLASSIC
NameCastle  DB 4,7,1,5,3,2,0      ; CASTLE
NameSky     DB 1,11,13,0           ; SKY

; ===================================================================
.CODE
; ===================================================================

; ===================================================================
; SelectMap - map selection menu entry point
; Sets MAPINDEX = 1, 2, or 3 then returns.
; ===================================================================
SelectMap PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    PUSH ES

    MOV  AX, VideoSeg
    MOV  ES, AX             ; ES = BackBuffer for all drawing

SM_DrawFrame:
    ; Clear backbuffer to black
    XOR  DI, DI
    MOV  CX, 32000
    XOR  AX, AX
    REP  STOSW

    CALL SM_DrawTitle
    CALL SM_DrawPanels
    CALL SM_DrawInstruction
    CALL SM_Blit            ; vsync blit

    ; Poll keyboard - wait for a valid key press (make code, not break)
SM_Poll:
    IN   AL, 60h
    TEST AL, 80h            ; bit 7 set = key release, skip
    JNZ  SM_Poll
    CMP  AL, SCAN_1
    JE   SM_Sel1
    CMP  AL, SCAN_2
    JE   SM_Sel2
    CMP  AL, SCAN_3
    JE   SM_Sel3
    CMP  AL, SCAN_ESC
    JNE  SM_Poll
    JMP  SM_Exit            ; ESC = keep current MAPINDEX

SM_Sel1: MOV MAPINDEX, 1
    JMP  SM_Confirm
SM_Sel2: MOV MAPINDEX, 2
    JMP  SM_Confirm
SM_Sel3: MOV MAPINDEX, 3

SM_Confirm:
    ; Redraw with new highlight, blit
    XOR  DI, DI
    MOV  CX, 32000
    XOR  AX, AX
    REP  STOSW
    CALL SM_DrawTitle
    CALL SM_DrawPanels
    CALL SM_DrawInstruction
    CALL SM_Blit

SM_Exit:
    ; Wait for key release (bit 7 = 1) before returning to caller
SM_WaitRel:
    IN   AL, 60h
    TEST AL, 80h
    JZ   SM_WaitRel

    ; Clear backbuffer
    XOR  DI, DI
    MOV  CX, 32000
    XOR  AX, AX
    REP  STOSW

    POP  ES
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SelectMap ENDP

; -------------------------------------------------------------------
; SM_Blit - vsync-locked copy BackBuffer -> 0A000h
; -------------------------------------------------------------------
SM_Blit PROC NEAR
    PUSH AX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    PUSH DS
    PUSH ES

    MOV  DX, 03DAh
SB_WaitEnd:                 ; wait for retrace to end (be outside retrace)
    IN   AL, DX
    TEST AL, 08h
    JNZ  SB_WaitEnd
SB_WaitStart:               ; wait for retrace to begin
    IN   AL, DX
    TEST AL, 08h
    JZ   SB_WaitStart

    MOV  AX, VideoSeg
    MOV  DS, AX
    MOV  AX, 0A000h
    MOV  ES, AX
    XOR  SI, SI
    XOR  DI, DI
    MOV  CX, 32000
    REP  MOVSW

    POP  ES
    POP  DS
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  AX
    RET
SM_Blit ENDP

; -------------------------------------------------------------------
; SM_DrawTitle
; Pixel-font "SELECT MAP" centered in rows 5-19
; "SELECT" = bright cyan (0Bh), "MAP" = yellow (0Eh)
; Accent lines at y=22,23
; Scale 2: each glyph 10px wide, gap 2px = 12px per char
; 9 chars + 1 space (12px) = 10 * 12 = 120px total
; Center: (320-120)/2 = 100
; -------------------------------------------------------------------
SM_DrawTitle PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; Draw two accent lines at bottom of title area
    MOV  DX, 22
    MOV  AX, 0
    CALL SM_CalcDI
    MOV  CX, 320
    MOV  AL, 09h
    REP  STOSB

    MOV  DX, 23
    MOV  AX, 0
    CALL SM_CalcDI
    MOV  CX, 320
    MOV  AL, 0Bh
    REP  STOSB

    ; S (x=100)
    MOV  AX, 100
    MOV  DX, 5
    MOV  BL, 0Bh
    MOV  CH, 2
    LEA  SI, GlyphS
    CALL SM_DrawGlyph
    ; E
    MOV  AX, 112
    MOV  DX, 5
    MOV  BL, 0Bh
    MOV  CH, 2
    LEA  SI, GlyphE
    CALL SM_DrawGlyph
    ; L
    MOV  AX, 124
    MOV  DX, 5
    MOV  BL, 0Bh
    MOV  CH, 2
    LEA  SI, GlyphL
    CALL SM_DrawGlyph
    ; E
    MOV  AX, 136
    MOV  DX, 5
    MOV  BL, 0Bh
    MOV  CH, 2
    LEA  SI, GlyphE
    CALL SM_DrawGlyph
    ; C
    MOV  AX, 148
    MOV  DX, 5
    MOV  BL, 0Bh
    MOV  CH, 2
    LEA  SI, GlyphC
    CALL SM_DrawGlyph
    ; T
    MOV  AX, 160
    MOV  DX, 5
    MOV  BL, 0Bh
    MOV  CH, 2
    LEA  SI, GlyphT
    CALL SM_DrawGlyph
    ; (12px gap = space, then MAP starts at x=100+72=172)
    ; M (yellow)
    MOV  AX, 172
    MOV  DX, 5
    MOV  BL, 0Eh
    MOV  CH, 2
    LEA  SI, GlyphM
    CALL SM_DrawGlyph
    ; A
    MOV  AX, 184
    MOV  DX, 5
    MOV  BL, 0Eh
    MOV  CH, 2
    LEA  SI, GlyphA
    CALL SM_DrawGlyph
    ; P
    MOV  AX, 196
    MOV  DX, 5
    MOV  BL, 0Eh
    MOV  CH, 2
    LEA  SI, GlyphP
    CALL SM_DrawGlyph

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SM_DrawTitle ENDP

; -------------------------------------------------------------------
; SM_DrawInstruction
; "PRESS 1, 2 OR 3 TO SELECT" at scale 1 (6px per char), y=184
; Accent lines at y=177,178
; -------------------------------------------------------------------
SM_DrawInstruction PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; Accent lines at top of bottom bar
    MOV  DX, 177
    MOV  AX, 0
    CALL SM_CalcDI
    MOV  CX, 320
    MOV  AL, 0Bh
    REP  STOSB

    MOV  DX, 178
    MOV  AX, 0
    CALL SM_CalcDI
    MOV  CX, 320
    MOV  AL, 09h
    REP  STOSB

    ; "PRESS 1, 2 OR 3 TO SELECT"
    ; Layout: 6px/char. Total ~26 chars -> 156px. Center: (320-156)/2 = 82
    ; P R E S S _ 1 , _ 2 _ O R _ 3 _ T O _ S E L E C T
    ; x: 82,88,94,100,106, gap, 118, 124, gap, 136, gap, 148,154, gap, 166, gap, 178,184, gap, 196,202,208,214,220,226

    MOV  AX, 82
    MOV  DX, 184
    MOV  BL, 0Eh
    MOV  CH, 1
    LEA  SI, GlyphP
    CALL SM_DrawGlyph
    MOV  AX, 88
    MOV  BL, 0Eh
    MOV  CH, 1
    LEA  SI, GlyphR
    CALL SM_DrawGlyph
    MOV  AX, 94
    MOV  BL, 0Eh
    MOV  CH, 1
    LEA  SI, GlyphE
    CALL SM_DrawGlyph
    MOV  AX, 100
    MOV  BL, 0Eh
    MOV  CH, 1
    LEA  SI, GlyphS
    CALL SM_DrawGlyph
    MOV  AX, 106
    MOV  BL, 0Eh
    MOV  CH, 1
    LEA  SI, GlyphS
    CALL SM_DrawGlyph

    ; "1" (3-wide digit, bright cyan)
    MOV  AX, 118
    MOV  BL, 0Bh
    LEA  SI, Glyph1
    CALL SM_DrawDigit

    ; "," (colon glyph)
    MOV  AX, 123
    MOV  DX, 184
    MOV  BL, 07h
    MOV  CH, 1
    LEA  SI, GlyphColon
    CALL SM_DrawGlyph

    ; "2"
    MOV  AX, 135
    MOV  DX, 184
    MOV  BL, 0Bh
    LEA  SI, Glyph2
    CALL SM_DrawDigit

    ; "O R"
    MOV  AX, 145
    MOV  DX, 184
    MOV  BL, 07h
    MOV  CH, 1
    LEA  SI, GlyphO
    CALL SM_DrawGlyph
    MOV  AX, 151
    MOV  BL, 07h
    MOV  CH, 1
    LEA  SI, GlyphR
    CALL SM_DrawGlyph

    ; "3"
    MOV  AX, 163
    MOV  DX, 184
    MOV  BL, 0Bh
    LEA  SI, Glyph3
    CALL SM_DrawDigit

    ; "T O"
    MOV  AX, 173
    MOV  DX, 184
    MOV  BL, 07h
    MOV  CH, 1
    LEA  SI, GlyphT
    CALL SM_DrawGlyph
    MOV  AX, 179
    MOV  BL, 07h
    MOV  CH, 1
    LEA  SI, GlyphO
    CALL SM_DrawGlyph

    ; "S E L E C T" (white)
    MOV  AX, 191
    MOV  DX, 184
    MOV  BL, 0Fh
    MOV  CH, 1
    LEA  SI, GlyphS
    CALL SM_DrawGlyph
    MOV  AX, 197
    MOV  BL, 0Fh
    MOV  CH, 1
    LEA  SI, GlyphE
    CALL SM_DrawGlyph
    MOV  AX, 203
    MOV  BL, 0Fh
    MOV  CH, 1
    LEA  SI, GlyphL
    CALL SM_DrawGlyph
    MOV  AX, 209
    MOV  BL, 0Fh
    MOV  CH, 1
    LEA  SI, GlyphE
    CALL SM_DrawGlyph
    MOV  AX, 215
    MOV  BL, 0Fh
    MOV  CH, 1
    LEA  SI, GlyphC
    CALL SM_DrawGlyph
    MOV  AX, 221
    MOV  BL, 0Fh
    MOV  CH, 1
    LEA  SI, GlyphT
    CALL SM_DrawGlyph

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SM_DrawInstruction ENDP

; -------------------------------------------------------------------
; SM_DrawPanels - draws all 3 panels with correct selection highlight
; -------------------------------------------------------------------
SM_DrawPanels PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; ---- Panel 1 ----
    MOV  AX, PANEL1_X
    MOV  BL, P1_BG
    MOV  SDPC_BordCol, P1_BORDER
    MOV  SDPC_TileCol, P1_TILE
    MOV  SDPC_SelFlag, 0
    CMP  MAPINDEX, 1
    JNE  SDP_P1Draw
    MOV  SDPC_SelFlag, 1
SDP_P1Draw:
    LEA  SI, Map1Template
    CALL SM_DrawPanel

    ; ---- Panel 2 ----
    MOV  AX, PANEL2_X
    MOV  BL, P2_BG
    MOV  SDPC_BordCol, P2_BORDER
    MOV  SDPC_TileCol, P2_TILE
    MOV  SDPC_SelFlag, 0
    CMP  MAPINDEX, 2
    JNE  SDP_P2Draw
    MOV  SDPC_SelFlag, 1
SDP_P2Draw:
    LEA  SI, Map2Template
    CALL SM_DrawPanel

    ; ---- Panel 3 ----
    MOV  AX, PANEL3_X
    MOV  BL, P3_BG
    MOV  SDPC_BordCol, P3_BORDER
    MOV  SDPC_TileCol, P3_TILE
    MOV  SDPC_SelFlag, 0
    CMP  MAPINDEX, 3
    JNE  SDP_P3Draw
    MOV  SDPC_SelFlag, 1
SDP_P3Draw:
    LEA  SI, Map3Template
    CALL SM_DrawPanel

    ; ---- Labels below panels ----
    ; Panel 1: "CLASSIC" (7 chars x 6 = 42px, center in 96: offset=(96-42)/2=27, x=6+27=33)
    MOV  AX, 33
    MOV  DX, PANEL_Y + 100
    MOV  BL, P1_LABEL
    CMP  MAPINDEX, 1
    JNE  SDP_L1
    MOV  BL, SEL_BORDER
SDP_L1:
    LEA  SI, NameClassic
    CALL SM_DrawLabel

    ; Panel 2: "CASTLE" (6 chars x 6 = 36px, offset=(96-36)/2=30, x=112+30=142)
    MOV  AX, 142
    MOV  DX, PANEL_Y + 100
    MOV  BL, P2_LABEL
    CMP  MAPINDEX, 2
    JNE  SDP_L2
    MOV  BL, SEL_BORDER
SDP_L2:
    LEA  SI, NameCastle
    CALL SM_DrawLabel

    ; Panel 3: "SKY" (3 chars x 6 = 18px, offset=(96-18)/2=39, x=218+39=257)
    MOV  AX, 257
    MOV  DX, PANEL_Y + 100
    MOV  BL, P3_LABEL
    CMP  MAPINDEX, 3
    JNE  SDP_L3
    MOV  BL, SEL_BORDER
SDP_L3:
    LEA  SI, NameSky
    CALL SM_DrawLabel

    ; ---- Panel number digits ----
    ; Each digit is 3px wide, centered in 96px panel: x = panel_x + (96-3)/2 = panel_x+46
    MOV  AX, PANEL1_X + 46
    MOV  DX, PANEL_Y + 110
    MOV  BL, P1_LABEL
    CMP  MAPINDEX, 1
    JNE  SDP_D1
    MOV  BL, SEL_BORDER
SDP_D1:
    LEA  SI, Glyph1
    CALL SM_DrawDigit

    MOV  AX, PANEL2_X + 46
    MOV  DX, PANEL_Y + 110
    MOV  BL, P2_LABEL
    CMP  MAPINDEX, 2
    JNE  SDP_D2
    MOV  BL, SEL_BORDER
SDP_D2:
    LEA  SI, Glyph2
    CALL SM_DrawDigit

    MOV  AX, PANEL3_X + 46
    MOV  DX, PANEL_Y + 110
    MOV  BL, P3_LABEL
    CMP  MAPINDEX, 3
    JNE  SDP_D3
    MOV  BL, SEL_BORDER
SDP_D3:
    LEA  SI, Glyph3
    CALL SM_DrawDigit

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SM_DrawPanels ENDP

; -------------------------------------------------------------------
; SM_DrawPanel
;   Draws one panel: background fill, border, map preview.
;   Parameters passed via data variables (set by SM_DrawPanels):
;     SDPC_SelFlag - 0=normal border, 1=yellow double border
;     SDPC_TileCol - tile color for preview
;     SDPC_BordCol - normal border color
;   AX = panel left x
;   BL = background color
;   SI = map template pointer
; -------------------------------------------------------------------
SM_DrawPanel PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    PUSH BP

    MOV  BP, AX             ; BP = panel left x

    ; ---- 1. Fill panel background ----
    MOV  DI, PANEL_Y        ; DI used as row y counter
    MOV  CX, PANEL_H
SDP2_FillRow:
    PUSH CX
    MOV  AX, BP
    MOV  DX, DI
    CALL SM_CalcDI
    MOV  CX, PANEL_W
    MOV  AL, BL
    REP  STOSB
    INC  DI
    POP  CX
    LOOP SDP2_FillRow

    ; ---- 2. Draw border ----
    CMP  SDPC_SelFlag, 1
    JE   SDP2_DoubleBord

    ; Single 1px border
    MOV  AL, SDPC_BordCol
    CALL SM_Border1
    JMP  SDP2_Preview

SDP2_DoubleBord:
    ; Double 2px yellow border
    MOV  AL, SEL_BORDER
    CALL SM_Border2

SDP2_Preview:
    ; ---- 3. Draw map preview ----
    MOV  AX, BP
    ADD  AX, PREV_OFF_X     ; preview_x = panel_x + inset
    MOV  DX, PANEL_Y + PREV_OFF_Y
    MOV  BL, SDPC_TileCol
    ; SI = map template (still on stack, not corrupted by above)
    CALL SM_Preview

    POP  BP
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SM_DrawPanel ENDP

; -------------------------------------------------------------------
; SM_Border1 - draw 1px border around current panel
;   BP = panel left x, AL = color
; -------------------------------------------------------------------
SM_Border1 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI

    MOV  BL, AL

    ; Top row
    MOV  AX, BP
    MOV  DX, PANEL_Y
    CALL SM_CalcDI
    MOV  CX, PANEL_W
    MOV  AL, BL
    REP  STOSB

    ; Bottom row
    MOV  AX, BP
    MOV  DX, PANEL_Y + PANEL_H - 1
    CALL SM_CalcDI
    MOV  CX, PANEL_W
    MOV  AL, BL
    REP  STOSB

    ; Left and right column pixels
    MOV  DX, PANEL_Y
    MOV  CX, PANEL_H
SMB1_ColLoop:
    PUSH CX
    MOV  AX, BP
    CALL SM_CalcDI
    MOV  ES:[DI], BL
    MOV  ES:[DI + PANEL_W - 1], BL
    INC  DX
    POP  CX
    LOOP SMB1_ColLoop

    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SM_Border1 ENDP

; -------------------------------------------------------------------
; SM_Border2 - draw 2px border around current panel (selection)
;   BP = panel left x, AL = color
; -------------------------------------------------------------------
SM_Border2 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI

    MOV  BL, AL

    ; Top 2 rows
    MOV  AX, BP
    MOV  DX, PANEL_Y
    CALL SM_CalcDI
    MOV  CX, PANEL_W
    MOV  AL, BL
    REP  STOSB
    MOV  AX, BP
    MOV  DX, PANEL_Y + 1
    CALL SM_CalcDI
    MOV  CX, PANEL_W
    MOV  AL, BL
    REP  STOSB

    ; Bottom 2 rows
    MOV  AX, BP
    MOV  DX, PANEL_Y + PANEL_H - 2
    CALL SM_CalcDI
    MOV  CX, PANEL_W
    MOV  AL, BL
    REP  STOSB
    MOV  AX, BP
    MOV  DX, PANEL_Y + PANEL_H - 1
    CALL SM_CalcDI
    MOV  CX, PANEL_W
    MOV  AL, BL
    REP  STOSB

    ; Left 2 cols and right 2 cols per row
    MOV  DX, PANEL_Y
    MOV  CX, PANEL_H
SMB2_ColLoop:
    PUSH CX
    MOV  AX, BP
    CALL SM_CalcDI
    MOV  ES:[DI], BL
    MOV  ES:[DI+1], BL
    MOV  ES:[DI + PANEL_W - 2], BL
    MOV  ES:[DI + PANEL_W - 1], BL
    INC  DX
    POP  CX
    LOOP SMB2_ColLoop

    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SM_Border2 ENDP

; -------------------------------------------------------------------
; SM_Preview - draws scaled-down map into panel preview area
;   AX = preview left x (absolute)
;   DX = preview top y  (absolute)
;   BL = tile color
;   SI = 240-byte map template (12 rows x 20 cols)
;   Each tile drawn as TILE_PW x TILE_PH pixels (4 x 7)
; -------------------------------------------------------------------
SMP_BaseX   DW 0
SMP_BaseY   DW 0
SMP_TileClr DB 0

SM_Preview PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI

    MOV  SMP_BaseX,   AX
    MOV  SMP_BaseY,   DX
    MOV  SMP_TileClr, BL

    ; Row loop: 0 to MAP_ROWS-1
    XOR  DX, DX             ; DX = row index
SMP_RowLoop:
    CMP  DX, MAP_ROWS
    JGE  SMP_Done

    ; row_y = SMP_BaseY + row * TILE_PH
    PUSH DX
    MOV  AX, DX
    MOV  CX, TILE_PH
    MUL  CX                 ; AX = row * 7 (DX=0, row<=11, 11*7=77 < 256)
    ADD  AX, SMP_BaseY
    MOV  BX, AX             ; BX = row_y

    ; Col loop: 0 to MAP_COLS-1
    XOR  CX, CX             ; CX = col index
SMP_ColLoop:
    CMP  CX, MAP_COLS
    JGE  SMP_NextRow

    MOV  AL, [SI]
    INC  SI
    CMP  AL, 1
    JNE  SMP_Skip

    ; tile_x = SMP_BaseX + col * TILE_PW
    PUSH CX
    PUSH BX
    PUSH SI
    MOV  AX, CX
    SHL  AX, 2              ; AX = col * 4
    ADD  AX, SMP_BaseX      ; AX = tile_x

    ; Draw TILE_PH rows of TILE_PW pixels
    MOV  DX, BX             ; DX = row_y
    MOV  CX, TILE_PH
SMP_TRow:
    PUSH CX
    PUSH AX
    CALL SM_CalcDI
    MOV  AL, SMP_TileClr
    MOV  ES:[DI],   AL
    MOV  ES:[DI+1], AL
    MOV  ES:[DI+2], AL
    MOV  ES:[DI+3], AL
    POP  AX
    INC  DX
    POP  CX
    LOOP SMP_TRow

    POP  SI
    POP  BX
    POP  CX

SMP_Skip:
    INC  CX
    JMP  SMP_ColLoop

SMP_NextRow:
    POP  DX
    INC  DX
    JMP  SMP_RowLoop

SMP_Done:
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SM_Preview ENDP

; -------------------------------------------------------------------
; SM_DrawGlyph
;   Draw a 5x5 pixel font glyph with scaling.
;   AX=x, DX=y, BL=color, SI=25-byte glyph data, CH=scale (1 or 2)
; -------------------------------------------------------------------
SM_DrawGlyph PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI

    MOV  SM_BaseX, AX
    MOV  SM_BaseY, DX
    MOV  SM_Color, BL
    MOV  SM_Scale, CH

    MOV  SM_CurY, DX        ; SM_CurY = base_y

    XOR  CX, CX             ; row = 0
SDG_RowLoop:
    CMP  CX, 5
    JGE  SDG_Done

    PUSH CX

    MOV  AX, SM_BaseX
    MOV  SM_CurX, AX

    XOR  CX, CX             ; col = 0
SDG_ColLoop:
    CMP  CX, 5
    JGE  SDG_ColDone

    MOV  AL, [SI]
    INC  SI
    CMP  AL, 1
    JNE  SDG_SkipPix

    ; Draw scale x scale block at (SM_CurX, SM_CurY)
    PUSH CX
    PUSH SI
    MOV  CL, SM_Scale
    MOV  CH, 0              ; CX = scale (loop counter)
    MOV  AX, SM_CurX
    MOV  DX, SM_CurY

SDG_SR:                     ; scale row loop
    PUSH CX
    PUSH DX
    PUSH AX
    CALL SM_CalcDI
    MOV  AL, SM_Color
    MOV  CL, SM_Scale
    MOV  CH, 0
SDG_SC:                     ; scale col loop
    MOV  ES:[DI], AL
    INC  DI
    LOOP SDG_SC
    POP  AX
    POP  DX
    INC  DX
    POP  CX
    LOOP SDG_SR

    POP  SI
    POP  CX

SDG_SkipPix:
    MOV  AL, SM_Scale
    MOV  AH, 0
    ADD  SM_CurX, AX        ; advance x by scale
    INC  CX
    JMP  SDG_ColLoop

SDG_ColDone:
    POP  CX

    MOV  AL, SM_Scale
    MOV  AH, 0
    ADD  SM_CurY, AX        ; advance y by scale
    INC  CX
    JMP  SDG_RowLoop

SDG_Done:
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SM_DrawGlyph ENDP

; -------------------------------------------------------------------
; SM_DrawDigit - draws a 3-wide x 5-tall digit glyph at scale 1
;   AX=x, DX=y, BL=color, SI=15-byte digit data
; -------------------------------------------------------------------
SM_DrawDigit PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI

    MOV  SM_BaseX, AX
    MOV  SM_BaseY, DX
    MOV  SM_Color, BL
    MOV  SM_CurY,  DX

    XOR  CX, CX
SMDD_Row:
    CMP  CX, 5
    JGE  SMDD_Done

    PUSH CX
    MOV  AX, SM_BaseX
    MOV  SM_CurX, AX

    XOR  CX, CX
SMDD_Col:
    CMP  CX, 3
    JGE  SMDD_ColDone

    MOV  AL, [SI]
    INC  SI
    CMP  AL, 1
    JNE  SMDD_Skip

    MOV  AX, SM_CurX
    MOV  DX, SM_CurY
    CALL SM_CalcDI
    MOV  AL, SM_Color
    MOV  ES:[DI], AL

SMDD_Skip:
    ADD  SM_CurX, 1
    INC  CX
    JMP  SMDD_Col

SMDD_ColDone:
    POP  CX
    ADD  SM_CurY, 1
    INC  CX
    JMP  SMDD_Row

SMDD_Done:
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SM_DrawDigit ENDP

; -------------------------------------------------------------------
; SM_DrawLabel - draw null-terminated glyph-index label string
;   AX=x, DX=y, BL=color, SI=index array
;   Glyph indices: 1=S 2=E 3=L 4=C 5=T 6=M 7=A 8=P 9=R 10=O 11=K 12=I 13=Y
; -------------------------------------------------------------------
SM_DrawLabel PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI

    MOV  SDL_X,     AX
    MOV  SDL_Y,     DX
    MOV  SDL_Color, BL

SDL_Loop:
    MOV  BL, [SI]           ; read glyph index
    INC  SI
    CMP  BL, 0
    JNE  SDL_NotEnd    ; If not zero, skip the jump and continue
    JMP  SDL_Done      ; If zero, use a FAR jump to exit
    SDL_NotEnd:
    ; Map index -> glyph address into DI
    LEA  DI, GlyphSpace     ; default
    CMP  BL, 1  
    JNE  SDL_T2  
    LEA  DI, GlyphS  
    JMP  SDL_Draw
SDL_T2:  CMP BL, 2  
    JNE  SDL_T3  
    LEA  DI, GlyphE  
    JMP  SDL_Draw
SDL_T3:  CMP BL, 3  
    JNE  SDL_T4  
    LEA  DI, GlyphL  
    JMP  SDL_Draw
SDL_T4:  CMP BL, 4  
    JNE  SDL_T5  
    LEA  DI, GlyphC  
    JMP  SDL_Draw
SDL_T5:  CMP BL, 5  
    JNE  SDL_T6  
    LEA  DI, GlyphT  
    JMP  SDL_Draw
SDL_T6:  CMP BL, 6  
    JNE  SDL_T7  
    LEA  DI, GlyphM  
    JMP  SDL_Draw
SDL_T7:  CMP BL, 7  
    JNE  SDL_T8  
    LEA  DI, GlyphA  
    JMP  SDL_Draw
SDL_T8:  CMP BL, 8  
    JNE  SDL_T9  
    LEA  DI, GlyphP  
    JMP  SDL_Draw
SDL_T9:  CMP BL, 9  
    JNE  SDL_T10  
    LEA  DI, GlyphR  
    JMP  SDL_Draw
SDL_T10: CMP BL, 10  
    JNE  SDL_T11  
    LEA  DI, GlyphO  
    JMP  SDL_Draw
SDL_T11: CMP BL, 11  
    JNE  SDL_T12  
    LEA  DI, GlyphK  
    JMP  SDL_Draw
SDL_T12: CMP BL, 12  
    JNE  SDL_T13  
    LEA  DI, GlyphI  
    JMP  SDL_Draw
SDL_T13: CMP BL, 13  
    JNE  SDL_Draw  
    LEA  DI, GlyphY

SDL_Draw:
    ; Draw this glyph: need to save/restore SI around the call
    PUSH SI
    MOV  SI, DI             ; SI = glyph data
    MOV  AX, SDL_X
    MOV  DX, SDL_Y
    MOV  BL, SDL_Color
    MOV  CH, 1              ; scale 1
    CALL SM_DrawGlyph
    POP  SI

    ADD  SDL_X, 6           ; advance x by 5px glyph + 1px gap
    JMP  SDL_Loop

SDL_Done:
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SM_DrawLabel ENDP

; -------------------------------------------------------------------
; SM_CalcDI - compute pixel offset: DI = DX*320 + AX
;   Preserves DX and AX. Trashes nothing else.
; -------------------------------------------------------------------
SM_CalcDI PROC NEAR
    PUSH DX
    MOV  DI, DX
    SHL  DI, 8
    SHL  DX, 6
    ADD  DI, DX
    ADD  DI, AX
    POP  DX
    RET
SM_CalcDI ENDP

; ===================================================================
; Game map routines (original, unchanged)
; ===================================================================

InitMap PROC NEAR
    PUSH AX
    PUSH CX
    PUSH DI
    PUSH SI
    PUSH ES
    PUSH DS
    CALL GetSkyColor
    MOV  SKYCOLOR, AL
    MOV  AX, VideoSeg
    MOV  ES, AX
    XOR  DI, DI
    MOV  CX, 32000
    MOV  AL, SKYCOLOR
    MOV  AH, AL
    REP  STOSW
    CALL GetMapDataPtr
    PUSH DS
    POP  ES
    LEA  DI, MapData
    MOV  CX, 240
    CLD
    REP  MOVSB
    MOV  AX, VideoSeg
    MOV  ES, AX
    CALL DrawAllTiles
    POP  DS
    POP  ES
    POP  SI
    POP  DI
    POP  CX
    POP  AX
    RET
InitMap ENDP

DrawMap PROC NEAR
    PUSH AX
    PUSH CX
    PUSH DI
    PUSH ES
    CALL GetSkyColor
    MOV  SKYCOLOR, AL
    MOV  AX, VideoSeg
    MOV  ES, AX
    XOR  DI, DI
    MOV  CX, 32000
    MOV  AL, SKYCOLOR
    MOV  AH, AL
    REP  STOSW
    CALL DrawAllTiles
    POP  ES
    POP  DI
    POP  CX
    POP  AX
    RET
DrawMap ENDP

GetSkyColor PROC NEAR
    MOV  AL, MAPINDEX
    CMP  AL, 2
    JE   GSC2
    CMP  AL, 3
    JE   GSC3
    MOV  AL, COLOR_SKY1
    RET
GSC2: MOV AL, COLOR_SKY2
    RET
GSC3: MOV AL, COLOR_SKY3
    RET
GetSkyColor ENDP

GetMapDataPtr PROC NEAR
    MOV  AL, MAPINDEX
    CMP  AL, 2
    JE   GMP2
    CMP  AL, 3
    JE   GMP3
    LEA  SI, Map1Template
    RET
GMP2: LEA SI, Map2Template
    RET
GMP3: LEA SI, Map3Template
    RET
GetMapDataPtr ENDP

DrawAllTiles PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    LEA  SI, MapData
    XOR  DX, DX
DATRow:
    CMP  DX, MAP_ROWS
    JL   ContDATR
    JMP  DATDone
ContDATR:
    XOR  BX, BX
DATCol:
    CMP  BX, MAP_COLS
    JL   ContDATC
    JMP  DATNextR
ContDATC:
    MOV  AL, [SI]
    CMP  AL, 1
    JNE  DATSkip
    PUSH BX
    PUSH DX
    MOV  AX, BX
    MOV  CX, TILE_W
    MUL  CX
    MOV  BX, AX
    POP  AX
    PUSH AX
    MOV  CX, TILE_H
    MUL  CX
    MOV  DX, AX
    MOV  AX, BX
    CALL DrawOneTile
    POP  DX
    POP  BX
DATSkip:
    INC  SI
    INC  BX
    JMP  DATCol
DATNextR:
    INC  DX
    JMP  DATRow
DATDone:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawAllTiles ENDP

DrawOneTile PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH ES
    MOV  BX, AX
    MOV  AX, VideoSeg
    MOV  ES, AX
    MOV  CX, TILE_H
DOTRow:
    PUSH DX
    MOV  AX, DX
    MOV  DI, 320
    MUL  DI
    ADD  AX, BX
    MOV  DI, AX
    PUSH CX
    MOV  CX, TILE_W
    MOV  AL, GROUNDCOLOR
    REP  STOSB
    POP  CX
    POP  DX
    INC  DX
    LOOP DOTRow
    POP  ES
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawOneTile ENDP

END