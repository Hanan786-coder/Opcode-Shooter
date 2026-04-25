; FILE: player.asm
; PERSON: Member 3
; ROLE: Player state, movement, gravity, collision, rendering
;
; RESPONSIBILITIES:
;   - Store player position (X, Y) and velocity
;   - Move player left/right based on input flags
;   - Apply simple gravity (player falls until on a platform)
;   - Collide with map tiles (stop falling on solid ground)
;   - Draw the player as a colored rectangle sprite
;
; PLAYER SPRITE:
;   16 x 24 pixels (same width as one map tile, 1.5 tiles tall)
;   Color: bright cyan (color index 0Bh in default VGA palette)
;
; COLLISION:
;   We check the map tile directly below the player's feet.
;   If that tile is solid (type 1), stop vertical movement.
;   Left/right: check tile to the left/right before moving.
;
; INPUT FLAGS (set by input.asm, read here):
;   MoveLeft  DB  – 1 if left arrow held
;   MoveRight DB  – 1 if right arrow held
;   DoJump    DB  – 1 if up arrow just pressed

.MODEL SMALL

; Externals (from other files)
EXTRN MapData      : BYTE         ; map.asm  – tile array
EXTRN MAP_COLS     : ABS          ; map.asm  – 20
EXTRN MAP_ROWS     : ABS          ; map.asm  – 12
EXTRN TILE_W       : ABS          ; map.asm  – 16
EXTRN TILE_H       : ABS          ; map.asm  – 16
EXTRN MoveLeft     : BYTE         ; input.asm
EXTRN MoveRight    : BYTE         ; input.asm
EXTRN DoJump       : BYTE         ; input.asm
EXTRN VideoSeg     : WORD         ; main.asm - dynamic video segment

; Public symbols
PUBLIC InitPlayer
PUBLIC UpdatePlayer
PUBLIC DrawPlayer
PUBLIC PlayerX                    ; other modules may read position
PUBLIC PlayerY

.DATA

; Player sprite dimensions
PLAYER_W  EQU 14                  ; sprite width  (pixels)
PLAYER_H  EQU 20                  ; sprite height (pixels)

; Movement constants
MOVE_SPEED  EQU 3                 ; pixels per frame horizontally
JUMP_VEL    EQU 11                 ; initial upward velocity (pixels/frame)
GRAVITY     EQU 1                 ; downward acceleration per frame

; Screen boundaries
SCREEN_W    EQU 320
SCREEN_H    EQU 200

; Player state variables
PlayerX     DW  80                ; current X position (pixels)
PlayerY     DW  160               ; current Y position (pixels)
VelocityY   DW  0                 ; vertical velocity (signed; up=negative)
OnGround    DB  0                 ; 1 if player is standing on solid tile

; Player sprite color (bright cyan in default palette)
PLAYER_COLOR EQU 0Bh

.CODE

; InitPlayer
; Sets the player to the starting position and clears velocity.
InitPlayer PROC NEAR
    MOV  PlayerX, 80              ; start at X=80 (25% across screen)
    MOV  PlayerY, 160             ; start near bottom, above ground
    MOV  VelocityY, 0             ; no vertical movement at start
    MOV  OnGround, 0              ; assume falling until collision check
    RET
InitPlayer ENDP

; UpdatePlayer
; Called once per frame. Reads input flags, moves player,
; applies gravity, and checks collision with map tiles.
UpdatePlayer PROC NEAR
    ; Horizontal Movement
    ; Check MoveLeft flag
    CMP  MoveLeft, 1
    JNE  CheckRight

    ; Move left: subtract MOVE_SPEED from X
    MOV  AX, PlayerX
    SUB  AX, MOVE_SPEED
    ; Clamp to left screen edge (don't go below 0)
    CMP  AX, 0
    JGE  SetLeftX
    MOV  AX, 0
SetLeftX:
    ; Check if tile to the left is solid before moving
    PUSH AX
    CALL CheckLeftCollision       ; returns CF=1 if blocked
    JC   LeftBlocked
    POP  AX
    MOV  PlayerX, AX
    JMP  CheckRight
LeftBlocked:
    POP  AX                       ; discard, don't move

CheckRight:
    CMP  MoveRight, 1
    JNE  DoneHorizontal

    ; Move right: add MOVE_SPEED to X
    MOV  AX, PlayerX
    ADD  AX, MOVE_SPEED
    ; Clamp to right screen edge
    MOV  BX, SCREEN_W
    SUB  BX, PLAYER_W             ; max X = screen width - sprite width
    CMP  AX, BX
    JLE  SetRightX
    MOV  AX, BX
SetRightX:
    PUSH AX
    CALL CheckRightCollision      ; returns CF=1 if blocked
    JC   RightBlocked
    POP  AX
    MOV  PlayerX, AX
    JMP  DoneHorizontal
RightBlocked:
    POP  AX

DoneHorizontal:

    ; Jumping
    CMP  DoJump, 1
    JNE  DoneJump
    CMP  OnGround, 1              ; can only jump if on the ground
    JNE  DoneJump
    MOV  VelocityY, -JUMP_VEL    ; negative = upward in screen coords
    MOV  OnGround, 0              ; no longer on ground
    MOV  DoJump, 0                ; consume the jump flag
DoneJump:

    ; Gravity & Vertical Movement
    ; Add gravity to velocity (pulls downward = positive Y)
    MOV  AX, VelocityY
    ADD  AX, GRAVITY
    MOV  VelocityY, AX

    ; Apply velocity to Y position
    MOV  AX, PlayerY
    ADD  AX, VelocityY
    MOV  PlayerY, AX

    ; Floor / Ceiling Clamp
    ; Clamp to top of screen
    CMP  PlayerY, 0
    JGE  CheckFloor
    MOV  PlayerY, 0
    MOV  VelocityY, 0             ; hit ceiling, stop upward motion

CheckFloor:
    ; Clamp to bottom of screen
    MOV  AX, SCREEN_H
    SUB  AX, PLAYER_H             ; max Y = screen - sprite height
    CMP  PlayerY, AX
    JLE  CheckTileBelow
    MOV  PlayerY, AX
    MOV  VelocityY, 0
    MOV  OnGround, 1

CheckTileBelow:
    ; Check if a map tile is directly beneath the player
    CALL CheckGroundCollision     ; sets OnGround, adjusts PlayerY

    RET
UpdatePlayer ENDP

; CheckGroundCollision
; Checks the two bottom corners of the player sprite against
; the map tile grid. If solid tile found, snaps player on top.
; Modifies: PlayerY, VelocityY, OnGround
CheckGroundCollision PROC NEAR
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI

    ; Bottom-center pixel of player = PlayerY + PLAYER_H
    MOV  AX, PlayerY
    ADD  AX, PLAYER_H             ; AX = bottom Y of sprite

    ; Convert bottom Y to tile row: tileRow = AX / TILE_H
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       ; AX = tile row, DX = remainder

    ; Convert player center X to tile column
    MOV  SI, PlayerX
    ADD  SI, PLAYER_W / 2         ; center X
    XOR  DX, DX
    MOV  BX, TILE_W
    MOV  AX, SI
    DIV  BX                       ; AX = tile column

    ; Bounds check: row must be < MAP_ROWS, col < MAP_COLS
    CMP  AX, MAP_COLS
    JAE  NoGroundHit
    PUSH AX                       ; save column
    MOV  AX, PlayerY
    ADD  AX, PLAYER_H
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       ; AX = row again
    CMP  AX, MAP_ROWS
    JAE  NoGroundHitPop

    ; Compute index into MapData: index = row * MAP_COLS + col
    MOV  BX, MAP_COLS
    MUL  BX                       ; AX = row * MAP_COLS
    POP  SI                       ; SI = column
    ADD  AX, SI
    MOV  SI, AX                   ; SI = final index

    ; Read tile type
    MOV  AL, MapData[SI]
    CMP  AL, 1
    JNE  NoGroundHit2             ; tile is empty, no collision

    ; Collision! Snap player Y so feet sit on top of tile.
    ; tileTopY = tileRow * TILE_H
    ; We already have row in AX/DX from earlier division;
    ; recompute for clarity:
    MOV  AX, PlayerY
    ADD  AX, PLAYER_H
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       ; AX = row
    MUL  BX                       ; AX = row * TILE_H  (tile top Y)
    SUB  AX, PLAYER_H             ; player Y = tile top - sprite height
    MOV  PlayerY, AX
    MOV  VelocityY, 0
    MOV  OnGround, 1
    JMP  GroundDone

NoGroundHitPop:
    POP  AX
    JMP  NoGroundHit
NoGroundHit2:
NoGroundHit:
    ; No tile below – player is in the air
    MOV  OnGround, 0

GroundDone:
    POP  SI
    POP  DX
    POP  BX
    POP  AX
    RET
CheckGroundCollision ENDP

; CheckLeftCollision
; Checks the tile to the left of the player.
; INPUT:  AX = proposed new PlayerX (after subtracting speed)
; OUTPUT: CF=1 if blocked, CF=0 if free
CheckLeftCollision PROC NEAR
    PUSH BX
    PUSH DX
    PUSH SI

    ; Left edge pixel X = AX (proposed new X)
    ; Check tile at (AX, PlayerY + PLAYER_H/2)  [mid-height]
    MOV  BX, AX                   ; BX = left edge X
    MOV  DX, PlayerY
    ADD  DX, PLAYER_H / 2         ; DX = mid-height Y

    ; Convert to tile indices
    XOR  AX, AX
    MOV  AX, BX
    XOR  DX, DX
    MOV  SI, PlayerY
    ADD  SI, PLAYER_H / 2

    ; tileCol = BX / TILE_W
    MOV  AX, BX
    XOR  DX, DX
    MOV  BX, TILE_W
    DIV  BX                       ; AX = tileCol

    ; tileRow = midY / TILE_H
    MOV  BX, SI
    PUSH AX                       ; save tileCol
    MOV  AX, BX
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       ; AX = tileRow
    POP  BX                       ; BX = tileCol

    ; index = tileRow * MAP_COLS + tileCol
    PUSH BX
    MOV  BX, MAP_COLS
    MUL  BX
    POP  BX
    ADD  AX, BX
    MOV  SI, AX

    MOV  AL, MapData[SI]
    CMP  AL, 1
    JE   LeftBlk
    CLC                           ; CF=0 = free
    JMP  LeftDone
LeftBlk:
    STC                           ; CF=1 = blocked
LeftDone:
    POP  SI
    POP  DX
    POP  BX
    RET
CheckLeftCollision ENDP

; CheckRightCollision
; Same as CheckLeftCollision but checks right edge.
; INPUT:  AX = proposed new PlayerX
; OUTPUT: CF=1 blocked, CF=0 free
CheckRightCollision PROC NEAR
    PUSH BX
    PUSH DX
    PUSH SI

    ; Right edge X = AX + PLAYER_W - 1
    ADD  AX, PLAYER_W
    DEC  AX
    MOV  BX, AX                   ; BX = right edge X

    MOV  SI, PlayerY
    ADD  SI, PLAYER_H / 2

    MOV  AX, BX
    XOR  DX, DX
    MOV  BX, TILE_W
    DIV  BX                       ; AX = tileCol

    MOV  BX, SI
    PUSH AX
    MOV  AX, BX
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       ; AX = tileRow
    POP  BX                       ; BX = tileCol

    PUSH BX
    MOV  BX, MAP_COLS
    MUL  BX
    POP  BX
    ADD  AX, BX
    MOV  SI, AX

    MOV  AL, MapData[SI]
    CMP  AL, 1
    JE   RightBlk
    CLC
    JMP  RightDone
RightBlk:
    STC
RightDone:
    POP  SI
    POP  DX
    POP  BX
    RET
CheckRightCollision ENDP

; DrawPlayer
; Draws the player sprite as a filled colored rectangle.
; Uses PlayerX and PlayerY to determine screen position.
DrawPlayer PROC NEAR
    PUSH ES
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DI

    MOV  AX, VideoSeg             ; Dynamic video segment
    MOV  ES, AX

    MOV  BX, PlayerX              ; BX = X position
    MOV  DX, PlayerY              ; DX = Y position

    MOV  CX, PLAYER_H             ; draw PLAYER_H rows

DrawRowLoop:
    PUSH DX                       ; SAVE DX
    ; Offset in video memory = DX * 320 + BX
    MOV  AX, DX
    MOV  DI, 320
    MUL  DI                       ; AX = DX * 320
    ADD  AX, BX                   ; AX += X
    MOV  DI, AX                   ; ES:DI = pixel row start

    ; Fill PLAYER_W pixels with player color
    PUSH CX
    MOV  CX, PLAYER_W
    MOV  AL, PLAYER_COLOR         ; bright cyan
    REP  STOSB
    POP  CX

    POP  DX                       ; RESTORE DX
    INC  DX                       ; next pixel row
    LOOP DrawRowLoop

    POP  DI
    POP  CX
    POP  BX
    POP  AX
    POP  ES
    RET
DrawPlayer ENDP

END
