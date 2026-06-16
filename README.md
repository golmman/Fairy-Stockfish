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

E.g. `echo -e "setoption name UCI_Variant value atomic\nposition fen 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'\ngo perft 6" | ./stockfish`

`echo -e "setoption name UCI_Variant value atomic\nposition fen <FEN>\ngo perft <depth>" | ./stockfish`

## Hints

### Positions/second varies by variant — this is expected

The benchmark reports how many positions the move generator can process per second. This number differs between variants not because the move generator is faster or slower, but because the **game state complexity at depth** differs.

For example, atomic chess typically shows ~6× higher positions/second than standard chess. At shallow depths (perft 5–6) both variants process nodes at nearly the same speed — atomic is actually slightly slower per node due to more complex legal-move checking (extinction pseudo-royal logic) and more piece types to iterate. The gap appears at deeper ply depths (10+): in atomic, every capture removes not just the captured piece but **all adjacent non-pawn pieces** (3–9 pieces per capture via the explosion mechanic). After a few captures the board is much simpler, making subsequent move generation faster. Since the benchmark explores to depth 128 via DFS, the majority of visited positions are at deep depths where atomic is much cheaper per node.

Similarly, variants with high initial piece counts (shogi, capablanca) or complex piece movement (xiangqi, janggi) will show lower positions/second.

## Perft numbers for atomic

| #   | Depth 1 | Depth 2 | Depth 3 | Depth 4 | Depth 5  | Depth 6     | FEN                                                                     |
| --- | ------- | ------- | ------- | ------- | -------- | ----------- | ----------------------------------------------------------------------- |
| 1   | 20      | 400     | 8902    | 197326  | 4864979  | 118926425   | `rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1`              |
| 2   | 37      | 1191    | 43364   | 1402237 | 51225398 | 1667574955  | `rnbqkbnr/ppp2pp1/4p2p/3p4/3PP3/7N/PPP2PPP/RNBQKB1R w KQkq - 0 4`       |
| 3   | 5       | 156     | 4848    | 150519  | 4643560  | 146715064   | `rnb1kb1r/p5p1/2pNp2p/1p1q1p2/3P1Pn1/N5P1/PPP4P/R1BQKB1R b KQkq - 6 10` |
| 4   | 21      | 546     | 10566   | 269557  | 5470489  | 139075307   | `r4b1r/p1N1k1p1/2pNp2p/5p2/1n1P1P2/6PP/PP6/R1B1K3 b Q - 4 17`           |
| 5   | 18      | 233     | 4307    | 63774   | 1178188  | 19292503    | `r1k4r/p4Np1/N1p1p2p/5p2/3P1P2/6PP/8/5K2 w - - 0 22`                    |
| 6   | 15      | 260     | 4114    | 70412   | 1123137  | 20277102    | `r1k1r3/p5p1/N1p4p/2N2p2/5P2/6PP/8/5K2 w - - 2 25`                      |
| 7   | 11      | 202     | 2388    | 41979   | 510726   | 9323466     | `r1k5/p7/N1p5/2N4p/7P/8/5r2/4K3 w - - 0 31`                             |
| 8   | 12      | 90      | 1037    | 10737   | 120067   | 1581592     | `r2k4/p7/N1p5/7p/7P/8/2K5/8 w - - 2 34`                                 |
| 9   | 11      | 227     | 2472    | 48708   | 530284   | 10261578    | `3r4/8/8/5k1p/4KN1P/p1p5/8/8 w - - 6 44`                                |
| 10  | 10      | 386     | 3513    | 124504  | 1106412  | 38665634    | `5r2/8/4k1N1/4K2p/7P/p7/8/2q5 w - - 0 48`                               |
| 11  | 3       | 166     | 1136    | 60502   | 448630   | 22312112    | `8/4N3/8/4K2p/1r3qkP/8/8/q7 w - - 16 59`                                |
| 12  | 57      | 463     | 25637   | 210798  | 11357575 | 96323713    | `8/4N3/8/7p/1r3q1P/6K1/7k/q7 b - - 21 61`                                |
