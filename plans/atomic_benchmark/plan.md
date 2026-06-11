# Movegen Benchmark Plan

## Overview

Add a new `movegen_bench` command that measures raw move-generation throughput using a perft-style recursive enumeration of legal moves. The benchmark runs for a fixed time (default 10 s) and reports positions/second and legal moves/second.

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Core mechanism | **Perft** (not minimax) | Zero overhead from evaluation, TT, move ordering, pruning. Pure movegen measurement. Already proven in codebase (`search.cpp:123`). |
| Metric | **Positions/s** (total movegen calls / time) | Aligns with perft's node-counting concept. Each position visited = one call to `generate<LEGAL>()`. Minimal code. |
| Depth strategy | **Time-bounded DFS with max ply limit** | Single-pass recursive tree exploration that checks time every 1024 nodes. Stops cleanly within budget. Avoids iterative deepening overshoot (chess depth 7 = 34s) and stack overflow. |
| Position source | Variant start FEN | Simple, reproducible. Single position per run. |
| Time limit | Configurable, default 10s | `movegen_bench [variant] [time=10]` |
| Threading | Single-threaded | As specified. |
| New file | `src/movegen_bench.cpp` | Keeps benchmark isolated from search engine and existing bench infrastructure. |

## Implementation

### 1. New file: `src/movegen_bench.cpp`

Contains the time-bounded recursive perft counter and the driver.

```cpp
constexpr int MAX_PLY = 128;  // Prevents stack overflow from deep DFS

// Recursively count total positions visited (movegen calls).
// Checks time every 1024 nodes to stay within budget.
// Stops recursing beyond MAX_PLY to prevent stack overflow.
void perft_time(Position& pos, TimePoint start, int64_t time_limit_ms,
                uint64_t& count, int ply) {
    if ((count & 1023) == 0 && now() - start >= time_limit_ms)
        return;
    if (ply >= MAX_PLY)
        return;

    StateInfo st;
    MoveList<LEGAL> moves(pos);
    count++;

    for (const auto& m : moves)
    {
        pos.do_move(m, st);
        perft_time(pos, start, time_limit_ms, count, ply + 1);
        pos.undo_move(m);
        if ((count & 1023) == 0 && now() - start >= time_limit_ms)
            break;
    }
}

void movegen_bench(Position& pos, int time_sec) {
    TimePoint start = now();
    int64_t time_limit_ms = int64_t(time_sec) * 1000;
    uint64_t count = 0;

    perft_time(pos, start, time_limit_ms, count, 0);

    TimePoint elapsed = now() - start + 1;

    sync_cout << "Variant: " << string(Options["UCI_Variant"])
              << "\nTotal positions (movegens): " << count
              << "\nTotal time (ms): " << elapsed
              << "\nPositions/second: " << (count * 1000 / elapsed)
              << sync_endl;
}
```

Key points:
- Time checked every 1024 nodes via `(count & 1023) == 0` — keeps `now()` call overhead negligible (~0.05%).
- `MAX_PLY = 128` limits recursion depth to prevent stack overflow. Each level allocates a `MoveList` (1024 × 12 bytes = 12 KB). At 128 levels: ~1.5 MB, well within default 8 MB macOS stack.
- Early return at time expiry is clean: no move is `do_move`'d at that level yet, so no `undo_move` needed.
- `break` after `undo_move` in the loop stops sibling exploration — position state is always correct.

### 2. Command dispatch in `src/uci.cpp`

Add a new branch in `UCI::loop()` after the `bench` handler (around line 390):

```cpp
else if (token == "movegen_bench")
{
    string arg;
    int timeSec = 10;
    if (is >> arg)
    {
        if (variants.find(arg) != variants.end())
        {
            Options["UCI_Variant"] = arg;
            if (is >> arg)
            {
                char* end;
                long t = strtol(arg.c_str(), &end, 10);
                if (*end == '\0' && t > 0)
                    timeSec = int(t);
            }
        }
        else
        {
            char* end;
            long t = strtol(arg.c_str(), &end, 10);
            if (*end == '\0' && t > 0)
                timeSec = int(t);
        }
    }
    Position benchPos;
    StateListPtr benchStates(new std::deque<StateInfo>(1));
    auto var = variants.find(string(Options["UCI_Variant"]));
    benchPos.set(var->second, var->second->startFen,
                 false, &benchStates->back(), Threads.main());
    movegen_bench(benchPos, timeSec);
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
$ echo "movegen_bench atomic 3" | ./stockfish
Variant: atomic
Total positions (movegens): 8057098
Total time (ms): 3105
Positions/second: 2594851
```

## Future Considerations (out of scope for now)

- Multi-threaded movegen benchmark
- Custom FEN input instead of start position
- JIT/per-move timing breakdown
