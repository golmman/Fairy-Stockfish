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

#### Alternative: Perft

E.g. `./stockfish bench atomic 0 1 6 default perft`

`./stockfish bench <variant> <tt_size> <threads> <depth> <fen> perft`

## Hints

### Positions/second varies by variant — this is expected

The benchmark reports how many positions the move generator can process per second. This number differs between variants not because the move generator is faster or slower, but because the **game state complexity at depth** differs.

For example, atomic chess typically shows ~6× higher positions/second than standard chess. At shallow depths (perft 5–6) both variants process nodes at nearly the same speed — atomic is actually slightly slower per node due to more complex legal-move checking (extinction pseudo-royal logic) and more piece types to iterate. The gap appears at deeper ply depths (10+): in atomic, every capture removes not just the captured piece but **all adjacent non-pawn pieces** (3–9 pieces per capture via the explosion mechanic). After a few captures the board is much simpler, making subsequent move generation faster. Since the benchmark explores to depth 128 via DFS, the majority of visited positions are at deep depths where atomic is much cheaper per node.

Similarly, variants with high initial piece counts (shogi, capablanca) or complex piece movement (xiangqi, janggi) will show lower positions/second.

