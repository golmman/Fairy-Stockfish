# Fairy-Stockfish

## Build

| Machine | Build Command                                 |
| ------- | --------------------------------------------- |
| x86     | `cd src && make -j2 ARCH=x86-64 build`        |
| Asahi   | `cd src && make -j2 ARCH=armv8 build`         |
| Mac M4  | `cd src && make -j2 ARCH=apple-silicon build` |

## New Features

### List moves of a given variant and FEN position

```
./stockfish listmoves atomic "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
```

### Move generation benchmark

Measures raw move-generation throughput for any variant using a perft-style enumeration of legal moves.

**What is perft?** Perft (performance test) is a move generation verification technique that recursively enumerates all legal moves from a position to a given depth. At every position in the tree, it calls `generate<LEGAL>()` — the same function used during search. The benchmark uses this traversal to exercise the move generator across a wide variety of board positions, reporting how many positions the move generator can process per second.

No evaluation, search, transposition table, or move ordering is involved — only pure move generation.

```
# 10-second benchmark for atomic (default):
echo "movegen_bench atomic" | ./stockfish

# 5-second benchmark for chess:
echo "movegen_bench chess 5" | ./stockfish

# Use current UCI_Variant with custom time:
echo "movegen_bench 3" | ./stockfish
```

Example output:
```
Variant: atomic
Total positions (movegens): 20367392
Total time (ms): 10003
Positions/second: 2036266
```

