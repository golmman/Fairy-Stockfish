# Implementation Plan: Command-Line Atomic Move List Generator

## Goal

Add a new command-line option that accepts a FEN string of an atomic chess position and outputs all legal moves in UCI notation.

## Usage

```bash
./stockfish listmoves atomic "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
```

Output (one move per line):
```
a2a3
b2b3
c2c3
...
```

## Architecture

### 1. New Command Handler: `listmoves`

**File:** `src/uci.cpp` — `UCI::loop()` dispatch section (around line 388-402, after existing debug commands)

The handler will:

1. Read a variant name token (e.g., `"atomic"`, `"nocheckatomic"`, `"atomar"`)
2. Concatenate all remaining tokens into a FEN string (same pattern as `position()` FEN parsing at `uci.cpp:64-66`)
3. Look up the variant in the global `variants` map (via `variants.find(name)`)
4. Create a local `StateListPtr` and `Position`, and call `pos.set(variant, fen, false, &state, Threads.main())`
5. Generate legal moves via `MoveList<LEGAL>(pos)`
6. Print each move via `UCI::move(pos, m)`, one per line, to stdout

**Edge cases & error handling:**
- **Missing variant name:** Print error message and return
- **Unknown variant name:** Catch `std::out_of_range` from `variants.find()->second` or check with `variants.find(name) != variants.end()`; print error
- **Invalid FEN:** `pos.set()` will throw or assert; wrap in try-catch or check return; print error
- **No legal moves (checkmate/stalemate):** Print nothing (empty output) or a comment — empty output is unambiguous
- **Non-atomic variant:** The command works for any variant (generality is a feature), but the primary use case is atomic

### 2. Code Changes

#### 2a. Add handler in `src/uci.cpp`

Insert before the "Unknown command" fallback (line 416):

```cpp
else if (token == "listmoves")
{
    string variantName, fen, fenToken;
    is >> variantName;
    if (variantName.empty())
    {
        sync_cout << "Error: missing variant name" << sync_endl;
        continue;
    }
    auto it = variants.find(variantName);
    if (it == variants.end())
    {
        sync_cout << "Error: unknown variant '" << variantName << "'" << sync_endl;
        continue;
    }
    while (is >> fenToken)
        fen += fenToken + " ";
    if (fen.empty())
    {
        sync_cout << "Error: missing FEN string" << sync_endl;
        continue;
    }
    StateListPtr localStates(new std::deque<StateInfo>(1));
    Position localPos;
    try {
        localPos.set(
            it->second,
            fen,
            false,              // isChess960 = false
            &localStates->back(),
            Threads.main()
        );
    } catch (std::exception& e) {
        sync_cout << "Error: invalid FEN — " << e.what() << sync_endl;
        continue;
    }
    for (const auto& m : MoveList<LEGAL>(localPos))
        sync_cout << UCI::move(localPos, m) << sync_endl;
}
```

#### 2b. Required `#include` additions

`src/uci.cpp` already includes:
- `"movegen.h"` (line 27) — for `MoveList`
- `"position.h"` (line 28) — for `Position`
- `"thread.h"` (line 30) — for `Threads`

No new includes needed.

#### 2c. Protocol note

Set `CurrentProtocol` to a UCI-compatible value (or use UCI move formatting explicitly) to ensure `UCI::move()` outputs standard coordinate notation. The simplest approach: before the move loop, set a protocol that uses standard algebraic output.

Alternatively, use `UCI::move()` which checks `CurrentProtocol`; the default is `UCI_GENERAL` which produces standard `e2e4`-style output — this is what we want.

## Files Modified

| File | Change |
|------|--------|
| `src/uci.cpp` | Add `listmoves` command handler in `UCI::loop()` dispatch |

## Files Referenced (no changes needed)

| File | Purpose |
|------|---------|
| `src/variant.h` | `VariantMap`, `Variant` class, `variants` global |
| `src/movegen.h` | `MoveList<LEGAL>` template |
| `src/uci.h` | `UCI::move()` declaration |
| `src/position.h` | `Position::set()` declaration |
| `src/benchmark.cpp` | Precedent for `variants.find()` usage |

## Prior Art

- **`position()` handler** (`uci.cpp:50-79`): FEN parsing pattern (`while (is >> token)` concatenation)
- **`bench()` handler** (`uci.cpp:181-221`): Precedent for creating local `Position`/`StateListPtr` and calling `pos.set()`
- **`perft()` function** (`search.cpp:124-148`): Precedent for iterating `MoveList<LEGAL>` and printing via `UCI::move()`
- **`benchmark.cpp:118`**: Precedent for `variants.find(token) != variants.end()` check

## Testing

Run manually:

```bash
# Build
cd src && make -j2 ARCH=x86-64 build

# Test with standard atomic starting position
./stockfish listmoves atomic "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

# Test with a mid-game atomic position
./stockfish listmoves atomic "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 11"

# Test with nocheckatomic variant
./stockfish listmoves nocheckatomic "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

# Test error: unknown variant
./stockfish listmoves nonexistent "fen"

# Test error: missing FEN
./stockfish listmoves atomic

# Test error: missing variant
./stockfish listmoves
```

### Automated validation

Cross-reference against perft move counts for atomic chess by comparing with the existing `bench` infrastructure:

```bash
# Perft 1 on atomic should produce same move count as listmoves
./stockfish "position fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" "go perft 1"
```
