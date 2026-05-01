; FILE: map.asm
; PERSON: Member 2
; ROLE: Map layout, background, platform drawing
;
; RESPONSIBILITIES:
;   - Define the map as a grid of tile types in memory
;   - Draw the sky/background color
;   - Draw all platform tiles (floors and walls)
;   - Expose InitMap and DrawMap for main.asm to call
;
; MAP COORDINATE SYSTEM:
;   Screen is 320 x 200 pixels (Mode 13h).
;   We divide it into a grid of TILE_W x TILE_H pixel tiles.
;   TILE_W = 16, TILE_H = 16  =>  20 columns x 12 rows
;
; TILE TYPES:
;   0 = empty (sky)
;   1 = solid platform (ground/floor)
;
; VIDEO MEMORY:
;   Segment A000h, offset = row*320 + col

.MODEL SMALL

; Externals
EXTRN GameRunning : BYTE          ; from main.asm (not used here
                                  ;   but good practice to declare)
EXTRN VideoSeg : WORD             ; Dynamic video segment for double buffering

; Public symbols
PUBLIC InitMap
PUBLIC DrawMap
PUBLIC MapData                    ; player.asm needs this for collision
PUBLIC MAP_COLS
PUBLIC MAP_ROWS
PUBLIC TILE_W
PUBLIC TILE_H

.DATA

; Map dimensions (equates = compile-time constants)
MAP_COLS EQU 20                   ; 20 tiles wide  (20*16 = 320px)
MAP_ROWS EQU 12                   ; 12 tiles tall  (12*16 = 192px)
TILE_W   EQU 16                   ; tile width  in pixels
TILE_H   EQU 16                   ; tile height in pixels

; Color palette indices (Mode 13h default palette)
SKY_COLOR      EQU 01h            ; dark blue  – background sky
GROUND_COLOR   EQU 02h            ; green      – ground tiles
PLATFORM_COLOR EQU 06h            ; brown/dark – raised platforms
BORDER_COLOR   EQU 07h            ; gray       – tile border/outline

; Map Layout
; 20 bytes per row, 12 rows = 240 bytes total.
; Read left-to-right, top-to-bottom.
; 0=sky, 1=solid tile
MapData LABEL BYTE
    ; Row 0  (top of screen)
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    ; Row 1
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    ; Row 2
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    ; Row 3  – a platform in the middle
    DB 0,0,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,0
    ; Row 4
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    ; Row 5   – two small platforms
    DB 0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0
    ; Row 6
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    ; Row 7
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    ; Row 8
    DB 0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,0,0,0
    ; Row 9
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    ; Row 10
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    ; Row 11 (bottom – solid ground floor, full width)
    DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

.CODE

; InitMap
; Called ONCE at startup.
; Clears the screen to sky color, then draws all map tiles.
InitMap PROC NEAR
    ; Clear entire screen to sky color
    ; Video memory: segment A000h
    ; 320*200 = 64000 bytes to fill
    PUSH ES
    PUSH DI
    PUSH CX
    PUSH AX

    MOV  AX, VideoSeg             ; Back buffer segment
    MOV  ES, AX
    XOR  DI, DI                   ; start at offset 0
    MOV  CX, 32000                ; 320*200 / 2 = 32000 words
    MOV  AL, SKY_COLOR            ; AL = sky color
    MOV  AH, SKY_COLOR            ; AH = sky color
    REP  STOSW                    ; ES:[DI++] = AX, repeat CX times

    POP  AX
    POP  CX
    POP  DI
    POP  ES

    ; Draw all tiles from MapData
    CALL DrawAllTiles

    RET
InitMap ENDP

; DrawMap
; Called every frame.
; Redraws the map (needed after player erases tiles beneath it).
; Optimisation: in a real game you'd only redraw dirty tiles,
; but for simplicity we redraw everything each frame.
DrawMap PROC NEAR
    ; Clear sky first (erase player from last frame)
    PUSH ES
    PUSH DI
    PUSH CX
    PUSH AX

    MOV  AX, VideoSeg             ; Back buffer segment
    MOV  ES, AX
    XOR  DI, DI
    MOV  CX, 32000                ; 32000 words
    MOV  AL, SKY_COLOR            
    MOV  AH, SKY_COLOR            ; AH, AL both SKY_COLOR
    REP  STOSW

    POP  AX
    POP  CX
    POP  DI
    POP  ES

    ; Redraw all solid tiles
    CALL DrawAllTiles
    RET
DrawMap ENDP

; DrawAllTiles (internal helper)
; Loops through MapData and calls DrawTile for each solid cell.
DrawAllTiles PROC NEAR
    PUSH SI                       ; SI = index into MapData
    PUSH CX                       ; CX = tile counter
    PUSH BX                       ; BX = column counter
    PUSH DX                       ; DX = row counter

    XOR  SI, SI                   ; SI = 0 (first byte of MapData)
    XOR  DX, DX                   ; DX = current row (0..MAP_ROWS-1)

RowLoop:
    CMP  DX, MAP_ROWS
    JGE  DoneAllTiles             ; all rows processed

    XOR  BX, BX                   ; BX = current column (0..MAP_COLS-1)

ColLoop:
    CMP  BX, MAP_COLS
    JGE  NextRow                  ; done with this row

    ; Check tile type at MapData[SI]
    MOV  AL, MapData[SI]
    CMP  AL, 1
    JNE  SkipTile                 ; 0 = empty, skip drawing

    ; It's a solid tile – compute pixel position and draw
    ; PixelX = BX * TILE_W
    ; PixelY = DX * TILE_H
    PUSH BX
    PUSH DX

    MOV  AX, BX
    MOV  CX, TILE_W
    MUL  CX
    MOV  BX, AX                   ; save pixel X in BX temporarily

    POP  AX                       ; pop original DX into AX
    PUSH AX                       ; push it back to balance stack
    MOV  CX, TILE_H
    MUL  CX
    MOV  DX, AX                   ; DX = pixel Y

    MOV  AX, BX                   ; AX = pixel X
    
    CALL DrawOneTile
    POP  DX
    POP  BX

SkipTile:
    INC  SI                       ; advance to next byte in MapData
    INC  BX                       ; next column
    JMP  ColLoop

NextRow:
    INC  DX                       ; next row
    JMP  RowLoop

DoneAllTiles:
    POP  DX
    POP  BX
    POP  CX
    POP  SI
    RET
DrawAllTiles ENDP

; DrawOneTile
; Draws a single TILE_W x TILE_H filled rectangle.
; INPUT:  AX = top-left pixel X
;         DX = top-left pixel Y
; Destroys: BX, CX, ES, DI
DrawOneTile PROC NEAR
    PUSH ES
    PUSH BX
    PUSH CX
    PUSH DI
    PUSH AX
    PUSH DX

    ; Save X and Y
    MOV  BX, AX                   ; BX = X
    ; DX already = Y

    MOV  AX, VideoSeg             ; Back buffer segment
    MOV  ES, AX

    ; Draw TILE_H rows
    MOV  CX, TILE_H               ; row counter
TileRowLoop:
    ; Compute offset: DX*320 + BX
    PUSH DX
    MOV  AX, DX
    MOV  DI, 320
    MUL  DI                       ; AX = DX * 320
    ADD  AX, BX                   ; AX = DX*320 + BX
    MOV  DI, AX                   ; DI = video memory offset

    ; Fill TILE_W pixels in this row
    PUSH CX
    MOV  CX, TILE_W
    MOV  AL, GROUND_COLOR         ; tile fill color
    REP  STOSB                    ; write CX pixels

    POP  CX
    POP  DX
    INC  DX                       ; move to next row
    LOOP TileRowLoop

    POP  DX
    POP  AX
    POP  DI
    POP  CX
    POP  BX
    POP  ES
    RET
DrawOneTile ENDP

END
