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
EXTRN MoveLeft2    : BYTE         ; input.asm
EXTRN MoveRight2   : BYTE         ; input.asm
EXTRN DoJump2      : BYTE         ; input.asm
EXTRN VideoSeg     : WORD         ; main.asm - dynamic video segment

; Public symbols
PUBLIC InitPlayer
PUBLIC UpdatePlayer
PUBLIC DrawPlayer
PUBLIC PlayerX                    ; other modules may read position
PUBLIC PlayerY
PUBLIC InitPlayer2
PUBLIC UpdatePlayer2
PUBLIC DrawPlayer2
PUBLIC Player2X
PUBLIC Player2Y

.DATA

; Player sprite dimensions
PLAYER_W  EQU 14                  ; sprite width  (pixels)
PLAYER_H  EQU 20                  ; sprite height (pixels)

; Movement constants
MOVE_SPEED  EQU 3                 ; pixels per frame horizontally
JUMP_VEL    EQU 11                 ; initial upward velocity (pixels/frame)
GRAVITY     EQU 1                 ; downward acceleration per frame
PUSH_DIST   EQU 2                 ; push distance when players collide (pixels)

; Screen boundaries
SCREEN_W    EQU 320
SCREEN_H    EQU 200

; Player state variables
PlayerX     DW  80                ; current X position (pixels)
PlayerY     DW  160               ; current Y position (pixels)
VelocityY   DW  0                 ; vertical velocity (signed; up=negative)
OnGround    DB  0                 ; 1 if player is standing on solid tile
Player2X    DW  240               ; current X position (pixels)
Player2Y    DW  160               ; current Y position (pixels)
Velocity2Y  DW  0                 ; vertical velocity
OnGround2   DB  0
PLAYER2_COLOR EQU 0Ch             ; bright red

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
    
    ; Also check collision with Player2
    POP  AX
    PUSH AX
    CALL CheckLeftCollisionWithPlayer2  ; returns CF=1 if would collide with P2
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
    
    ; Also check collision with Player2
    POP  AX
    PUSH AX
    CALL CheckRightCollisionWithPlayer2  ; returns CF=1 if would collide with P2
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

    ; Check collision with Player2 (push mechanic)
    CALL CheckPlayerCollisionP1

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

; CheckPlayerCollisionP1
; Checks if Player1 is colliding with Player2.
; If so, separate them by pushing them apart.
; Uses rectangle collision detection.
CheckPlayerCollisionP1 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; Check if bounding boxes overlap:
    ; Rect1: PlayerX to PlayerX+PLAYER_W, PlayerY to PlayerY+PLAYER_H
    ; Rect2: Player2X to Player2X+PLAYER_W, Player2Y to Player2Y+PLAYER_H
    
    ; Check horizontal overlap: Player1.left < Player2.right AND Player1.right > Player2.left
    MOV  AX, PlayerX
    MOV  BX, Player2X
    ADD  BX, PLAYER_W
    CMP  AX, BX                   ; if Player1.left >= Player2.right, no overlap
    JGE  NoCollisionP1
    
    MOV  CX, PlayerX
    ADD  CX, PLAYER_W
    MOV  DX, Player2X
    CMP  CX, DX                   ; if Player1.right <= Player2.left, no overlap
    JLE  NoCollisionP1
    
    ; Check vertical overlap: Player1.top < Player2.bottom AND Player1.bottom > Player2.top
    MOV  AX, PlayerY
    MOV  BX, Player2Y
    ADD  BX, PLAYER_H
    CMP  AX, BX                   ; if Player1.top >= Player2.bottom, no overlap
    JGE  NoCollisionP1
    
    MOV  CX, PlayerY
    ADD  CX, PLAYER_H
    MOV  DX, Player2Y
    CMP  CX, DX                   ; if Player1.bottom <= Player2.top, no overlap
    JLE  NoCollisionP1
    
    ; Collision detected! Push players apart
    ; Determine direction: if Player1 is to the left of Player2, push left/right
    MOV  AX, PlayerX
    ADD  AX, PLAYER_W / 2         ; Player1 center X
    MOV  BX, Player2X
    ADD  BX, PLAYER_W / 2         ; Player2 center X
    
    CMP  AX, BX
    JLE  PushLeft_P1              ; Player1 is left of Player2, push both left/right
    
    ; Player1 is right of Player2: push Player1 right, Player2 left
    MOV  AX, PlayerX
    ADD  AX, PUSH_DIST
    MOV  BX, SCREEN_W
    SUB  BX, PLAYER_W
    CMP  AX, BX
    JLE  SetPushRight_P1
    MOV  AX, BX
SetPushRight_P1:
    MOV  PlayerX, AX
    
    MOV  AX, Player2X
    SUB  AX, PUSH_DIST
    CMP  AX, 0
    JGE  SetPushLeft_P2
    MOV  AX, 0
SetPushLeft_P2:
    MOV  Player2X, AX
    JMP  NoCollisionP1
    
PushLeft_P1:
    ; Player1 is left of Player2: push Player1 left, Player2 right
    MOV  AX, PlayerX
    SUB  AX, PUSH_DIST
    CMP  AX, 0
    JGE  SetPushLeft_P1_2
    MOV  AX, 0
SetPushLeft_P1_2:
    MOV  PlayerX, AX
    
    MOV  AX, Player2X
    ADD  AX, PUSH_DIST
    MOV  BX, SCREEN_W
    SUB  BX, PLAYER_W
    CMP  AX, BX
    JLE  SetPushRight_P2
    MOV  AX, BX
SetPushRight_P2:
    MOV  Player2X, AX
    
NoCollisionP1:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
CheckPlayerCollisionP1 ENDP

; CheckPlayerCollisionP2
; Checks if Player2 is colliding with Player1.
; If so, separate them by pushing them apart.
; Uses rectangle collision detection.
CheckPlayerCollisionP2 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; Check if bounding boxes overlap:
    ; Rect1: Player2X to Player2X+PLAYER_W, Player2Y to Player2Y+PLAYER_H
    ; Rect2: PlayerX to PlayerX+PLAYER_W, PlayerY to PlayerY+PLAYER_H
    
    ; Check horizontal overlap: Player2.left < Player1.right AND Player2.right > Player1.left
    MOV  AX, Player2X
    MOV  BX, PlayerX
    ADD  BX, PLAYER_W
    CMP  AX, BX                   ; if Player2.left >= Player1.right, no overlap
    JGE  NoCollisionP2
    
    MOV  CX, Player2X
    ADD  CX, PLAYER_W
    MOV  DX, PlayerX
    CMP  CX, DX                   ; if Player2.right <= Player1.left, no overlap
    JLE  NoCollisionP2
    
    ; Check vertical overlap: Player2.top < Player1.bottom AND Player2.bottom > Player1.top
    MOV  AX, Player2Y
    MOV  BX, PlayerY
    ADD  BX, PLAYER_H
    CMP  AX, BX                   ; if Player2.top >= Player1.bottom, no overlap
    JGE  NoCollisionP2
    
    MOV  CX, Player2Y
    ADD  CX, PLAYER_H
    MOV  DX, PlayerY
    CMP  CX, DX                   ; if Player2.bottom <= Player1.top, no overlap
    JLE  NoCollisionP2
    
    ; Collision detected! Push players apart
    ; Determine direction: if Player2 is to the left of Player1, push left/right
    MOV  AX, Player2X
    ADD  AX, PLAYER_W / 2         ; Player2 center X
    MOV  BX, PlayerX
    ADD  BX, PLAYER_W / 2         ; Player1 center X
    
    CMP  AX, BX
    JLE  PushLeft_P2              ; Player2 is left of Player1, push both left/right
    
    ; Player2 is right of Player1: push Player2 right, Player1 left
    MOV  AX, Player2X
    ADD  AX, PUSH_DIST
    MOV  BX, SCREEN_W
    SUB  BX, PLAYER_W
    CMP  AX, BX
    JLE  SetPushRight_P2_2
    MOV  AX, BX
SetPushRight_P2_2:
    MOV  Player2X, AX
    
    MOV  AX, PlayerX
    SUB  AX, PUSH_DIST
    CMP  AX, 0
    JGE  SetPushLeft_P1_3
    MOV  AX, 0
SetPushLeft_P1_3:
    MOV  PlayerX, AX
    JMP  NoCollisionP2
    
PushLeft_P2:
    ; Player2 is left of Player1: push Player2 left, Player1 right
    MOV  AX, Player2X
    SUB  AX, PUSH_DIST
    CMP  AX, 0
    JGE  SetPushLeft_P2_2
    MOV  AX, 0
SetPushLeft_P2_2:
    MOV  Player2X, AX
    
    MOV  AX, PlayerX
    ADD  AX, PUSH_DIST
    MOV  BX, SCREEN_W
    SUB  BX, PLAYER_W
    CMP  AX, BX
    JLE  SetPushRight_P1_2
    MOV  AX, BX
SetPushRight_P1_2:
    MOV  PlayerX, AX
    
NoCollisionP2:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
CheckPlayerCollisionP2 ENDP

; CheckLeftCollisionWithPlayer2
; Checks if Player1 moving to proposed X (in AX) would collide with Player2
; INPUT: AX = proposed new PlayerX
; OUTPUT: CF=1 if would collide, CF=0 if free
CheckLeftCollisionWithPlayer2 PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    
    ; Check if rect at (AX, PlayerY) to (AX+PLAYER_W, PlayerY+PLAYER_H)
    ; overlaps with Player2 at (Player2X, Player2Y) to (Player2X+PLAYER_W, Player2Y+PLAYER_H)
    
    ; Horizontal: AX < Player2X+PLAYER_W AND AX+PLAYER_W > Player2X
    MOV  BX, Player2X
    ADD  BX, PLAYER_W
    CMP  AX, BX
    JGE  NoColP1L
    
    MOV  CX, AX
    ADD  CX, PLAYER_W
    MOV  DX, Player2X
    CMP  CX, DX
    JLE  NoColP1L
    
    ; Vertical: PlayerY < Player2Y+PLAYER_H AND PlayerY+PLAYER_H > Player2Y
    MOV  BX, PlayerY
    MOV  CX, Player2Y
    ADD  CX, PLAYER_H
    CMP  BX, CX
    JGE  NoColP1L
    
    MOV  DX, PlayerY
    ADD  DX, PLAYER_H
    MOV  CX, Player2Y
    CMP  DX, CX
    JLE  NoColP1L
    
    STC                           ; collision detected
    JMP  DoneColP1L
NoColP1L:
    CLC                           ; no collision
DoneColP1L:
    POP  DX
    POP  CX
    POP  BX
    RET
CheckLeftCollisionWithPlayer2 ENDP

; CheckRightCollisionWithPlayer2
; Checks if Player1 moving to proposed X (in AX) would collide with Player2
; INPUT: AX = proposed new PlayerX
; OUTPUT: CF=1 if would collide, CF=0 if free
CheckRightCollisionWithPlayer2 PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    
    ; Check if rect at (AX, PlayerY) to (AX+PLAYER_W, PlayerY+PLAYER_H)
    ; overlaps with Player2
    
    ; Horizontal: AX < Player2X+PLAYER_W AND AX+PLAYER_W > Player2X
    MOV  BX, Player2X
    ADD  BX, PLAYER_W
    CMP  AX, BX
    JGE  NoColP1R
    
    MOV  CX, AX
    ADD  CX, PLAYER_W
    MOV  DX, Player2X
    CMP  CX, DX
    JLE  NoColP1R
    
    ; Vertical: PlayerY < Player2Y+PLAYER_H AND PlayerY+PLAYER_H > Player2Y
    MOV  BX, PlayerY
    MOV  CX, Player2Y
    ADD  CX, PLAYER_H
    CMP  BX, CX
    JGE  NoColP1R
    
    MOV  DX, PlayerY
    ADD  DX, PLAYER_H
    MOV  CX, Player2Y
    CMP  DX, CX
    JLE  NoColP1R
    
    STC                           ; collision detected
    JMP  DoneColP1R
NoColP1R:
    CLC                           ; no collision
DoneColP1R:
    POP  DX
    POP  CX
    POP  BX
    RET
CheckRightCollisionWithPlayer2 ENDP

; CheckLeftCollisionWithPlayer1
; Checks if Player2 moving to proposed X (in AX) would collide with Player1
; INPUT: AX = proposed new Player2X
; OUTPUT: CF=1 if would collide, CF=0 if free
CheckLeftCollisionWithPlayer1 PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    
    ; Check if rect at (AX, Player2Y) to (AX+PLAYER_W, Player2Y+PLAYER_H)
    ; overlaps with Player1
    
    ; Horizontal: AX < PlayerX+PLAYER_W AND AX+PLAYER_W > PlayerX
    MOV  BX, PlayerX
    ADD  BX, PLAYER_W
    CMP  AX, BX
    JGE  NoColP2L
    
    MOV  CX, AX
    ADD  CX, PLAYER_W
    MOV  DX, PlayerX
    CMP  CX, DX
    JLE  NoColP2L
    
    ; Vertical: Player2Y < PlayerY+PLAYER_H AND Player2Y+PLAYER_H > PlayerY
    MOV  BX, Player2Y
    MOV  CX, PlayerY
    ADD  CX, PLAYER_H
    CMP  BX, CX
    JGE  NoColP2L
    
    MOV  DX, Player2Y
    ADD  DX, PLAYER_H
    MOV  CX, PlayerY
    CMP  DX, CX
    JLE  NoColP2L
    
    STC                           ; collision detected
    JMP  DoneColP2L
NoColP2L:
    CLC                           ; no collision
DoneColP2L:
    POP  DX
    POP  CX
    POP  BX
    RET
CheckLeftCollisionWithPlayer1 ENDP

; CheckRightCollisionWithPlayer1
; Checks if Player2 moving to proposed X (in AX) would collide with Player1
; INPUT: AX = proposed new Player2X
; OUTPUT: CF=1 if would collide, CF=0 if free
CheckRightCollisionWithPlayer1 PROC NEAR
    PUSH BX
    PUSH CX
    PUSH DX
    
    ; Check if rect at (AX, Player2Y) to (AX+PLAYER_W, Player2Y+PLAYER_H)
    ; overlaps with Player1
    
    ; Horizontal: AX < PlayerX+PLAYER_W AND AX+PLAYER_W > PlayerX
    MOV  BX, PlayerX
    ADD  BX, PLAYER_W
    CMP  AX, BX
    JGE  NoColP2R
    
    MOV  CX, AX
    ADD  CX, PLAYER_W
    MOV  DX, PlayerX
    CMP  CX, DX
    JLE  NoColP2R
    
    ; Vertical: Player2Y < PlayerY+PLAYER_H AND Player2Y+PLAYER_H > PlayerY
    MOV  BX, Player2Y
    MOV  CX, PlayerY
    ADD  CX, PLAYER_H
    CMP  BX, CX
    JGE  NoColP2R
    
    MOV  DX, Player2Y
    ADD  DX, PLAYER_H
    MOV  CX, PlayerY
    CMP  DX, CX
    JLE  NoColP2R
    
    STC                           ; collision detected
    JMP  DoneColP2R
NoColP2R:
    CLC                           ; no collision
DoneColP2R:
    POP  DX
    POP  CX
    POP  BX
    RET
CheckRightCollisionWithPlayer1 ENDP

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


; --- PLAYER 2 ---

InitPlayer2 PROC NEAR
    MOV  Player2X, 240              ; start at X=80 (25% across screen)
    MOV  Player2Y, 160             ; start near bottom, above ground
    MOV  Velocity2Y, 0             ; no vertical movement at start
    MOV  OnGround2, 0              ; assume falling until collision check
    RET
InitPlayer2 ENDP

; UpdatePlayer2
; Called once per frame. Reads input flags, moves player,
; applies gravity, and checks collision with map tiles.
UpdatePlayer2 PROC NEAR
    ; Horizontal Movement
    ; Check MoveLeft2 flag
    CMP  MoveLeft2, 1
    JNE  CheckRight_P2

    ; Move left: subtract MOVE_SPEED from X
    MOV  AX, Player2X
    SUB  AX, MOVE_SPEED
    ; Clamp to left screen edge (don't go below 0)
    CMP  AX, 0
    JGE  SetLeftX_P2
    MOV  AX, 0
SetLeftX_P2:
    ; Check if tile to the left is solid before moving
    PUSH AX
    CALL CheckLeftCollision_P2       ; returns CF=1 if blocked
    JC   LeftBlocked_P2
    
    ; Also check collision with Player1
    POP  AX
    PUSH AX
    CALL CheckLeftCollisionWithPlayer1  ; returns CF=1 if would collide with P1
    JC   LeftBlocked_P2
    
    POP  AX
    MOV  Player2X, AX
    JMP  CheckRight_P2
LeftBlocked_P2:
    POP  AX                       ; discard, don't move

CheckRight_P2:
    CMP  MoveRight2, 1
    JNE  DoneHorizontal_P2

    ; Move right: add MOVE_SPEED to X
    MOV  AX, Player2X
    ADD  AX, MOVE_SPEED
    ; Clamp to right screen edge
    MOV  BX, SCREEN_W
    SUB  BX, PLAYER_W             ; max X = screen width - sprite width
    CMP  AX, BX
    JLE  SetRightX_P2
    MOV  AX, BX
SetRightX_P2:
    PUSH AX
    CALL CheckRightCollision_P2      ; returns CF=1 if blocked
    JC   RightBlocked_P2
    
    ; Also check collision with Player1
    POP  AX
    PUSH AX
    CALL CheckRightCollisionWithPlayer1  ; returns CF=1 if would collide with P1
    JC   RightBlocked_P2
    
    POP  AX
    MOV  Player2X, AX
    JMP  DoneHorizontal_P2
RightBlocked_P2:
    POP  AX

DoneHorizontal_P2:

    ; Jumping
    CMP  DoJump2, 1
    JNE  DoneJump_P2
    CMP  OnGround2, 1              ; can only jump if on the ground
    JNE  DoneJump_P2
    MOV  Velocity2Y, -JUMP_VEL    ; negative = upward in screen coords
    MOV  OnGround2, 0              ; no longer on ground
    MOV  DoJump2, 0                ; consume the jump flag
DoneJump_P2:

    ; Check collision with Player1 (push mechanic)
    CALL CheckPlayerCollisionP2

    ; Gravity & Vertical Movement
    ; Add gravity to velocity (pulls downward = positive Y)
    MOV  AX, Velocity2Y
    ADD  AX, GRAVITY
    MOV  Velocity2Y, AX

    ; Apply velocity to Y position
    MOV  AX, Player2Y
    ADD  AX, Velocity2Y
    MOV  Player2Y, AX

    ; Floor / Ceiling Clamp
    ; Clamp to top of screen
    CMP  Player2Y, 0
    JGE  CheckFloor_P2
    MOV  Player2Y, 0
    MOV  Velocity2Y, 0             ; hit ceiling, stop upward motion

CheckFloor_P2:
    ; Clamp to bottom of screen
    MOV  AX, SCREEN_H
    SUB  AX, PLAYER_H             ; max Y = screen - sprite height
    CMP  Player2Y, AX
    JLE  CheckTileBelow_P2
    MOV  Player2Y, AX
    MOV  Velocity2Y, 0
    MOV  OnGround2, 1

CheckTileBelow_P2:
    ; Check if a map tile is directly beneath the player
    CALL CheckGroundCollision_P2     ; sets OnGround2, adjusts Player2Y

    RET
UpdatePlayer2 ENDP

; CheckGroundCollision_P2
; Checks the two bottom corners of the player sprite against
; the map tile grid. If solid tile found, snaps player on top.
; Modifies: Player2Y, Velocity2Y, OnGround2
CheckGroundCollision_P2 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI

    ; Bottom-center pixel of player = Player2Y + PLAYER_H
    MOV  AX, Player2Y
    ADD  AX, PLAYER_H             ; AX = bottom Y of sprite

    ; Convert bottom Y to tile row: tileRow = AX / TILE_H
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       ; AX = tile row, DX = remainder

    ; Convert player center X to tile column
    MOV  SI, Player2X
    ADD  SI, PLAYER_W / 2         ; center X
    XOR  DX, DX
    MOV  BX, TILE_W
    MOV  AX, SI
    DIV  BX                       ; AX = tile column

    ; Bounds check: row must be < MAP_ROWS, col < MAP_COLS
    CMP  AX, MAP_COLS
    JAE  NoGroundHit_P2
    PUSH AX                       ; save column
    MOV  AX, Player2Y
    ADD  AX, PLAYER_H
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       ; AX = row again
    CMP  AX, MAP_ROWS
    JAE  NoGroundHitPop_P2

    ; Compute index into MapData: index = row * MAP_COLS + col
    MOV  BX, MAP_COLS
    MUL  BX                       ; AX = row * MAP_COLS
    POP  SI                       ; SI = column
    ADD  AX, SI
    MOV  SI, AX                   ; SI = final index

    ; Read tile type
    MOV  AL, MapData[SI]
    CMP  AL, 1
    JNE  NoGroundHit2_P2             ; tile is empty, no collision

    ; Collision! Snap player Y so feet sit on top of tile.
    ; tileTopY = tileRow * TILE_H
    ; We already have row in AX/DX from earlier division;
    ; recompute for clarity:
    MOV  AX, Player2Y
    ADD  AX, PLAYER_H
    XOR  DX, DX
    MOV  BX, TILE_H
    DIV  BX                       ; AX = row
    MUL  BX                       ; AX = row * TILE_H  (tile top Y)
    SUB  AX, PLAYER_H             ; player Y = tile top - sprite height
    MOV  Player2Y, AX
    MOV  Velocity2Y, 0
    MOV  OnGround2, 1
    JMP  GroundDone_P2

NoGroundHitPop_P2:
    POP  AX
    JMP  NoGroundHit_P2
NoGroundHit2_P2:
NoGroundHit_P2:
    ; No tile below – player is in the air
    MOV  OnGround2, 0

GroundDone_P2:
    POP  SI
    POP  DX
    POP  BX
    POP  AX
    RET
CheckGroundCollision_P2 ENDP

; CheckLeftCollision_P2
; Checks the tile to the left of the player.
; INPUT:  AX = proposed new Player2X (after subtracting speed)
; OUTPUT: CF=1 if blocked, CF=0 if free
CheckLeftCollision_P2 PROC NEAR
    PUSH BX
    PUSH DX
    PUSH SI

    ; Left edge pixel X = AX (proposed new X)
    ; Check tile at (AX, Player2Y + PLAYER_H/2)  [mid-height]
    MOV  BX, AX                   ; BX = left edge X
    MOV  DX, Player2Y
    ADD  DX, PLAYER_H / 2         ; DX = mid-height Y

    ; Convert to tile indices
    XOR  AX, AX
    MOV  AX, BX
    XOR  DX, DX
    MOV  SI, Player2Y
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
    JE   LeftBlk_P2
    CLC                           ; CF=0 = free
    JMP  LeftDone_P2
LeftBlk_P2:
    STC                           ; CF=1 = blocked
LeftDone_P2:
    POP  SI
    POP  DX
    POP  BX
    RET
CheckLeftCollision_P2 ENDP

; CheckRightCollision_P2
; Same as CheckLeftCollision_P2 but checks right edge.
; INPUT:  AX = proposed new Player2X
; OUTPUT: CF=1 blocked, CF=0 free
CheckRightCollision_P2 PROC NEAR
    PUSH BX
    PUSH DX
    PUSH SI

    ; Right edge X = AX + PLAYER_W - 1
    ADD  AX, PLAYER_W
    DEC  AX
    MOV  BX, AX                   ; BX = right edge X

    MOV  SI, Player2Y
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
    JE   RightBlk_P2
    CLC
    JMP  RightDone_P2
RightBlk_P2:
    STC
RightDone_P2:
    POP  SI
    POP  DX
    POP  BX
    RET
CheckRightCollision_P2 ENDP

; DrawPlayer2
; Draws the player sprite as a filled colored rectangle.
; Uses Player2X and Player2Y to determine screen position.
DrawPlayer2 PROC NEAR
    PUSH ES
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DI

    MOV  AX, VideoSeg             ; Dynamic video segment
    MOV  ES, AX

    MOV  BX, Player2X              ; BX = X position
    MOV  DX, Player2Y              ; DX = Y position

    MOV  CX, PLAYER_H             ; draw PLAYER_H rows

DrawRowLoop_P2:
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
    MOV  AL, PLAYER2_COLOR         ; bright cyan
    REP  STOSB
    POP  CX

    POP  DX                       ; RESTORE DX
    INC  DX                       ; next pixel row
    LOOP DrawRowLoop_P2

    POP  DI
    POP  CX
    POP  BX
    POP  AX
    POP  ES
    RET
DrawPlayer2 ENDP


END