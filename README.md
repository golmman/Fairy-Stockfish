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

| #   | Depth 1 | Depth 2 | Depth 3 | Depth 4 | Depth 5  | Depth 6    | FEN                                                                     |
| --- | ------- | ------- | ------- | ------- | -------- | ---------- | ----------------------------------------------------------------------- |
| 1   | 20      | 400     | 8902    | 197326  | 4864979  | 118926425  | `rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1`              |
| 2   | 37      | 1191    | 43364   | 1402237 | 51225398 | 1667574955 | `rnbqkbnr/ppp2pp1/4p2p/3p4/3PP3/7N/PPP2PPP/RNBQKB1R w KQkq - 0 4`       |
| 3   | 5       | 156     | 4848    | 150519  | 4643560  | 146715064  | `rnb1kb1r/p5p1/2pNp2p/1p1q1p2/3P1Pn1/N5P1/PPP4P/R1BQKB1R b KQkq - 6 10` |
| 4   | 21      | 546     | 10566   | 269557  | 5470489  | 139075307  | `r4b1r/p1N1k1p1/2pNp2p/5p2/1n1P1P2/6PP/PP6/R1B1K3 b Q - 4 17`           |
| 5   | 18      | 233     | 4307    | 63774   | 1178188  | 19292503   | `r1k4r/p4Np1/N1p1p2p/5p2/3P1P2/6PP/8/5K2 w - - 0 22`                    |
| 6   | 15      | 260     | 4114    | 70412   | 1123137  | 20277102   | `r1k1r3/p5p1/N1p4p/2N2p2/5P2/6PP/8/5K2 w - - 2 25`                      |
| 7   | 11      | 202     | 2388    | 41979   | 510726   | 9323466    | `r1k5/p7/N1p5/2N4p/7P/8/5r2/4K3 w - - 0 31`                             |
| 8   | 12      | 90      | 1037    | 10737   | 120067   | 1581592    | `r2k4/p7/N1p5/7p/7P/8/2K5/8 w - - 2 34`                                 |
| 9   | 11      | 227     | 2472    | 48708   | 530284   | 10261578   | `3r4/8/8/5k1p/4KN1P/p1p5/8/8 w - - 6 44`                                |
| 10  | 10      | 386     | 3513    | 124504  | 1106412  | 38665634   | `5r2/8/4k1N1/4K2p/7P/p7/8/2q5 w - - 0 48`                               |
| 11  | 3       | 166     | 1136    | 60502   | 448630   | 22312112   | `8/4N3/8/4K2p/1r3qkP/8/8/q7 w - - 16 59`                                |
| 12  | 57      | 463     | 25637   | 210798  | 11357575 | 96323713   | `8/4N3/8/7p/1r3q1P/6K1/7k/q7 b - - 21 61`                               |
| -   | -       | -       | -       | -       | -        | -          | `rnbqkbnr/ppp4p/4p1p1/3pNp2/7Q/4P3/PPPP1PPP/RNB1KB1R b KQkq - 1 5`      |
| -   | -       | -       | -       | -       | -        | -          | `r1b1Brk1/ppp5/6pp/3p4/5p2/P3PP2/1P4PP/R4RK1 b - - 1 15`                |
| -   | -       | -       | -       | -       | -        | -          | `r4r1k/pp3B2/4b1pp/2p1P3/1P3p2/P2p1P2/6PP/R4RK1 w - - 0 20`             |
| -   | -       | -       | -       | -       | -        | -          | `r4r1k/pp3B2/4b1pp/4P3/5p2/P4P2/6PP/2Rq1RK1 w - - 0 22`                 |
| -   | -       | -       | -       | -       | -        | -          | `5r1k/pp3B2/4b1pp/4P3/5p2/P4P2/6PP/6K1 w - - 0 25`                      |
| -   | -       | -       | -       | -       | -        | -          | `5r1k/p7/4P1pp/8/8/P4P2/1p5P/6K1 w - - 0 31`                            |
| -   | -       | -       | -       | -       | -        | -          | `5r1k/p3P3/6pp/8/8/P4P2/7P/1q4K1 w - - 0 32`                            |
| -   | -       | -       | -       | -       | -        | -          | `5r1k/p3P3/6pp/8/8/P4P2/6KP/1q6 b - - 1 32`                             |
| -   | -       | -       | -       | -       | -        | -          | `r1bqkbnr/pppp2pp/2n5/4ppB1/1P1P4/7N/P1P1PPPP/RN1QKB1R b KQkq - 1 4`    |
| -   | -       | -       | -       | -       | -        | -          | `r1b1kbnr/pppp1Np1/2n5/5p1p/1P1Pp3/4P3/P1P2PPP/RN1QKB1R b KQkq - 1 7`   |
| -   | -       | -       | -       | -       | -        | -          | `r1b2rk1/ppp3p1/5n2/3p3p/1PBPpp2/4PP1P/P1P3P1/RN1QK2R w KQ - 0 12`      |
| -   | -       | -       | -       | -       | -        | -          | `r1b2rk1/ppp5/5n2/3p2pp/1PBP4/4P2P/P1P5/RN1Q1R1K w - - 0 15`            |
| -   | -       | -       | -       | -       | -        | -          | `r1b4k/pp6/8/3p2pp/1P6/2P1P2P/P7/RQ5K b - - 0 20`                       |
| -   | -       | -       | -       | -       | -        | -          | `5r1k/pp6/8/3p1bpp/1P6/2P1P2P/P7/R4QK1 b - - 4 22`                      |
| -   | -       | -       | -       | -       | -        | -          | `7k/pp6/8/1PP5/6pp/7P/P3b3/4R1K1 b - - 0 28`                            |
| -   | -       | -       | -       | -       | -        | -          | `8/pp6/7k/1PP4R/P7/7p/7K/5b2 b - - 6 33`                                |
| -   | -       | -       | -       | -       | -        | -          | `8/8/7k/P6R/8/7p/4b2K/8 b - - 7 42`                                     |
| -   | -       | -       | -       | -       | -        | -          | `8/8/8/8/5R2/6kp/7K/8 b - - 3 47`                                       |
| -   | -       | -       | -       | -       | -        | -          | `r1bqk2r/pp4pp/2p5/1B1p1pNQ/1b3P2/2N1P3/PP3nPP/R1B1K2R b KQkq - 2 11`   |
| -   | -       | -       | -       | -       | -        | -          | `r1b2rk1/1p4pp/p1p5/1B3p2/Pb1p1P2/2N1P1PP/1P3n2/R1B2RK1 b - - 0 15`     |
| -   | -       | -       | -       | -       | -        | -          | `r4rk1/1p4pp/p1p1b3/5p2/PbB2P2/BPN1P1PP/3p1n2/R4RK1 b - - 3 18`         |
| -   | -       | -       | -       | -       | -        | -          | `r5k1/1p4pp/p1p5/8/P4P2/BP4PP/5n2/R2r2K1 w - - 1 22`                    |
| -   | -       | -       | -       | -       | -        | -          | `r5k1/7p/p2B2p1/1pp2P2/P7/1P1n2PP/8/6K1 b - - 0 26`                     |
| -   | -       | -       | -       | -       | -        | -          | `r5k1/7p/p2B4/2p3P1/Pp5P/1P5n/8/6K1 w - - 1 30`                         |
| -   | -       | -       | -       | -       | -        | -          | `r5k1/7p/p2B3P/6P1/Ppp2n2/1P6/8/5K2 b - - 0 32`                         |
| -   | -       | -       | -       | -       | -        | -          | `r7/5k1P/p2B4/8/Pp3n2/1Pp5/8/5K2 w - - 1 35`                            |
| -   | -       | -       | -       | -       | -        | -          | `8/5k2/p7/8/Pp3n2/1P6/1Bp5/5K2 b - - 1 37`                              |
| -   | -       | -       | -       | -       | -        | -          | `8/5k2/p7/8/P7/1P1n4/2p5/5K2 w - - 0 39`                                |
| -   | -       | -       | -       | -       | -        | -          | `8/5k2/p7/8/P7/1P1n1K2/8/2q5 b - - 1 40`                                |
