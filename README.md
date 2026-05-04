# Opcode-Shooter

Opcode-Shooter is a real-time, local 2-player 2D platformer and shooter game developed entirely in 16-bit x86 Assembly Language (MASM) for MS-DOS systems. Designed as a comprehensive project for Computer Organization and Assembly Language (COAL), it directly manipulates hardware interrupts, video memory, and system architectures to deliver a smooth gaming experience.

## Technical Highlights

- **VGA Graphics (Mode 13h):** Operates in 320x200 resolution with 256 colors, utilizing direct writes to video memory (`0A000h`).
- **Double Buffering:** Implements an off-screen buffer to eliminate screen flickering during frame updates by using string manipulation instructions (`REP MOVSW`).
- **Custom Keyboard Driver:** Replaces the default DOS hardware interrupt (INT 9h) with a custom Interrupt Service Routine (ISR) to track the state of 128 keys simultaneously. This enables robust local multiplayer support without keyboard ghosting.
- **Physics and Collision Detection:** Calculates bounding-box overlaps and tile-based intersections using base-plus-offset memory addressing to ensure entities correctly interact with solid platforms and boundaries.
- **Modular Architecture:** The codebase is split into distinct components linked together to separate game logic, state management, and rendering operations efficiently.

## Controls

The game requires a standard keyboard. Input maps directly to the active hardware scan codes.

**Player 1:**
- Movement: Arrow Keys (Left, Right)
- Jump: Up Arrow
- Fire: 'K'

**Player 2:**
- Movement: A / D
- Jump: W
- Fire: 'F'

*Note: The game relies on standard scan code mappings. Ensure your emulator passes raw keyboard data directly if running inside a modern OS layer.*

## Project Structure

The source code is contained within the `src/` directory, broken down into the following modules:

- `main.asm`: The core application entry point. Handles video mode initialization, the master game loop, match variables, double buffering loops, and graceful program exit.
- `input.asm`: Manages the custom INT 9h Keyboard handling, saving the original BIOS interrupt vector and mapping memory states for the active inputs.
- `player.asm`: Calculates the physics, bounds checking, jump cycles, collision detection, and pixel-level sprite rendering for both players.
- `bullets.asm`: Manages the arrays and properties of active projectiles, including trajectory bounds, lifespan, player damage, and rendering.
- `map.asm`: Houses the structural map data arrays, level selection routines, and the logic to paint the environmental tiles to the background buffer.
- `powerups.asm`: Handles random timed spawns for dynamic items (Shields, Health, Ultra). Ensures items only spawn in valid, empty air space utilizing grid-based division.

## Build and Execution Instructions

To compile and run Opcode-Shooter, a 16-bit DOS environment with MASM (Microsoft Macro Assembler Version 6.11 or similar) is required. DOSBox is highly recommended for running this on modern hardware.

1. Mount the project directory in your DOXBox environment:
   > mount c c:\Opcode-Shooter
   > c:
   > cd src

2. Assemble the modular components:
   > masm input.asm;
   > masm map.asm;
   > masm player.asm;
   > masm bullets.asm;
   > masm powerups.asm;
   > masm main.asm;

3. Link the generated object files to create the executable:
   > link main.obj input.obj map.obj player.obj bullets.obj powerups.obj;

4. Run the resulting program:
   > main.exe

## Academic Context

This repository is designed to demonstrate low-level computer operation principles such as memory hierarchies, direct memory access representations, vector table manipulations, addressing modes, and optimization through processor registers.
