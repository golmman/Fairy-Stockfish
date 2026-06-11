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

