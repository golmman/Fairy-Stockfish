# Movegen Benchmark Plan

## Overview

Add a new `movegen_bench` command that measures raw move-generation throughput using a perft-style recursive enumeration of legal moves. The benchmark runs for a fixed time (default 10 s) and reports positions/second and legal moves/second.

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Core mechanism | **Perft** (not minimax) | Zero overhead from evaluation, TT, move ordering, pruning. Pure movegen measurement. Already proven in codebase (`search.cpp:123`). |
| Metric | **Positions/s** (total movegen calls / time) | Aligns with perft's node-counting concept. Each position visited = one call to `generate<LEGAL>()`. Minimal code. |
| Depth strategy | **Iterative deepening** | Adapts naturally to any variant's branching factor. Start at depth 1, increment until time expires. |
| Position source | Variant start FEN | Simple, reproducible. Single position per run. |
| Time limit | Configurable, default 10s | `movegen_bench [variant] [time=10]` |
| Threading | Single-threaded | As specified. |
| New file | `src/movegen_bench.cpp` | Keeps benchmark isolated from search engine and existing bench infrastructure. |

## Implementation

### 1. New file: `src/movegen_bench.cpp`

Contains the recursive perft-like counter and the timed driver.

```cpp
// Recursively count total positions visited (movegen calls) at a given depth.
// Each call to MoveList<LEGAL> constitutes one movegen.
void perft_count(Position& pos, Depth depth, uint64_t& count) {
    StateInfo st;
    MoveList<LEGAL> moves(pos);
    count++;
    if (depth <= 1)
        return;
    for (const auto& m : moves) {
        pos.do_move(m, st);
        perft_count(pos, depth - 1, count);
        pos.undo_move(m);
    }
}

// Timed driver: iterative deepening until time budget exhausted.
void movegen_bench(Position& pos, int time_sec) {
    auto start = now();
    uint64_t total_positions = 0;
    Depth depth = 1;

    while (elapsed(start) < time_sec * 1000) {
        uint64_t depth_count = 0;
        StateInfo st;
        perft_count(pos, depth, depth_count);
        total_positions += depth_count;
        if (elapsed(start) >= time_sec * 1000)
            break;
        depth++;
    }

    auto elapsed_ms = elapsed(start);
    // Output summary
    cerr << "Variant: " << Options["UCI_Variant"] << "\n";
    cerr << "Depth reached: " << depth << "\n";
    cerr << "Total positions (movegens): " << total_positions << "\n";
    cerr << "Total time (ms): " << elapsed_ms << "\n";
    cerr << "Positions/second: " << (total_positions * 1000 / elapsed_ms) << "\n";
}
```

Key points:
- `now()` and `elapsed()` are available from `misc.h` (`TimePoint`).
- `StateInfo st` is stack-allocated per recursion level; moves are done/undone sequentially so only one `StateInfo` per depth level is needed.
- The count is total recursive invocations of `perft_count` — each one generates legal moves exactly once.

### 2. Command dispatch in `src/uci.cpp`

Add a new branch in `UCI::loop()` alongside the existing `bench` handler (around line 390):

```cpp
else if (token == "movegen_bench")
{
    string variantName;
    int timeSec = 10;
    is >> variantName;
    if (variants.find(variantName) != variants.end())
    {
        Options["UCI_Variant"].set_value(variantName);
        is >> timeSec;
    }
    else if (!variantName.empty())
    {
        // Parse as optional time argument, no variant change needed
        char* end;
        long t = strtol(variantName.c_str(), &end, 10);
        if (*end == '\0' && t > 0)
            timeSec = int(t);
    }
    Position benchPos;
    StateListPtr benchStates(new std::deque<StateInfo>(1));
    benchPos.set(variants.find(string(Options["UCI_Variant"]))->second,
                 variants.find(string(Options["UCI_Variant"]))->second->startFen,
                 false, &benchStates->back(), Threads.main());
    movegen_bench(benchPos, timeSec);
    if (argc > 1) break;
}
```

### 3. Forward declaration in `src/uci.cpp`

The `movegen_bench` function is in the anonymous namespace of `movegen_bench.cpp`. It needs to be declared in `uci.cpp` — either via a header or a declaration at the top of uci.cpp. Since it's a single function used only here, a simple declaration suffices:

```cpp
// In uci.cpp anonymous namespace:
void movegen_bench(Position& pos, int time_sec);
```

### 4. Build system: `src/Makefile`

Add `movegen_bench.o` to the `SRCS` list (around line 41-46):

```
SRCS = benchmark.cpp bitbase.cpp bitboard.cpp ... movegen_bench.cpp ...
```

No other Makefile changes needed.

## Files Modified

| File | Change |
|---|---|
| `src/movegen_bench.cpp` | **New file** — perft counter + timed benchmark driver |
| `src/uci.cpp` | Add command dispatch + forward declaration (add ~25 lines) |
| `src/Makefile` | Add `movegen_bench.o` to `SRCS` (1 line) |

## Output Example

```
$ ./stockfish movegen_bench atomic
Variant: atomic
Depth reached: 6
Total positions (movegens): 14293847
Total time (ms): 10012
Positions/second: 1427381
```

## Future Considerations (out of scope for now)

- Multi-threaded movegen benchmark
- Custom FEN input instead of start position
- JIT/per-move timing breakdown
