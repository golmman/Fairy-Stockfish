#!/bin/bash
# Compare atomic move generation between Fairy-Stockfish and leucippus.
# Translates tests from leucippus/src/move_generator/legal_moves.rs

STOCKFISH="../src/stockfish"
ENGINE_DIR="../src"
PASS=0
FAIL=0

error()
{
  echo "testing failed on line $1"
  exit 1
}
trap 'error ${LINENO}' ERR

listmoves()
{
  echo "listmoves atomic $1" | "$STOCKFISH" 2>/dev/null | sort
}

count_moves()
{
  echo "listmoves atomic $1" | "$STOCKFISH" 2>/dev/null | wc -l | tr -d ' '
}

check()
{
  local name="$1"
  local fen="$2"
  local expected_count="$3"
  shift 3

  local actual_count=$(count_moves "$fen")
  local actual_moves=$(listmoves "$fen")

  if [ "$actual_count" != "$expected_count" ]; then
    echo "FAIL: $name (expected $expected_count moves, got $actual_count)"
    echo "  FEN: $fen"
    echo "  Actual moves:"
    echo "$actual_moves" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
    return
  fi

  for move in "$@"; do
    if ! echo "$actual_moves" | grep -qx "$move"; then
      echo "FAIL: $name (missing expected move: $move)"
      echo "  FEN: $fen"
      echo "  Actual moves:"
      echo "$actual_moves" | sed 's/^/    /'
      FAIL=$((FAIL + 1))
      return
    fi
  done

  echo "PASS: $name"
  PASS=$((PASS + 1))
}

check_empty()
{
  local name="$1"
  local fen="$2"

  local count=$(count_moves "$fen")
  if [ "$count" != "0" ]; then
    echo "FAIL: $name (expected 0 moves, got $count)"
    echo "  FEN: $fen"
    listmoves "$fen" | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $name"
    PASS=$((PASS + 1))
  fi
}

# Build the engine if needed
if [ ! -x "$STOCKFISH" ]; then
  echo "Building engine..."
  make -j2 ARCH=x86-64 build -C "$ENGINE_DIR"
fi

echo ""
echo "=== Atomic move generation tests ==="
echo ""

# ---- starting position ----
check "starting position (white)" \
  "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" \
  20 \
  a2a3 a2a4 b1a3 b1c3 b2b3 b2b4 c2c3 c2c4 d2d3 d2d4 \
  e2e3 e2e4 f2f3 f2f4 g1f3 g1h3 g2g3 g2g4 h2h3 h2h4

# ---- complex castling ----
check "complex castling (black)" \
  "r3k2r/1K6/8/2R5/3bp1p1/BPP2p2/P2P1PP1/8 b kq - 27 35" \
  34 \
  a8a3 a8a4 a8a5 a8a6 a8a7 a8b8 a8c8 a8d8 \
  d4c3 d4c5 d4e3 d4e5 d4f2 d4f6 d4g7 \
  e4e3 \
  e8c8 e8d7 e8d8 e8e7 e8f7 e8f8 e8g8 \
  f3g2 g4g3 \
  h8f8 h8g8 h8h1 h8h2 h8h3 h8h4 h8h5 h8h6 h8h7

# ---- no moves (king exploded) ----
check_empty "king exploded (black)" \
  "3K3R/8/8/8/8/8/8/3n4 b - - 0 1"

check_empty "stalemate (black)" \
  "3K3R/8/1B6/8/5N2/8/7n/7k b - - 1 1"

check_empty "checkmate (black)" \
  "3K3R/8/1BB5/8/5N2/8/7n/7k b - - 2 1"

# ---- simple positions ----
check "knight prevents check via pin (black)" \
  "2BK3n/8/8/8/8/8/8/7k b - - 0 1" \
  5 \
  h1g1 h1g2 h1h2 h8f7 h8g6

check "knight prevents check via pin (white)" \
  "2bk3N/8/8/8/8/8/8/7K w - - 0 1" \
  5 \
  h1g1 h1g2 h1h2 h8f7 h8g6

check "knight pinned by bishop (black)" \
  "2BK3R/8/8/8/8/7n/8/7k b - - 0 1" \
  3 \
  h1g1 h1g2 h1h2

check "knight pinned by bishop (white)" \
  "2bk3r/8/8/8/8/7N/8/7K w - - 0 1" \
  3 \
  h1g1 h1g2 h1h2

check "queen pinned but can explode king (black)" \
  "2BK3R/8/8/8/8/7q/8/7k b - - 0 1" \
  10 \
  h1g1 h1g2 h1h2 h3c8 h3h2 h3h4 h3h5 h3h6 h3h7 h3h8

check "queen pinned but can explode king (white)" \
  "2bk3r/8/8/8/8/7Q/8/7K w - - 0 1" \
  10 \
  h1g1 h1g2 h1h2 h3c8 h3h2 h3h4 h3h5 h3h6 h3h7 h3h8

check "king escapes check (black)" \
  "2BK4/8/8/P7/p7/7k/8/8 b - - 0 1" \
  4 \
  h3g2 h3g3 h3h2 h3h4

check "king escapes check (white)" \
  "2bk4/8/8/p7/P7/7K/8/8 w - - 0 1" \
  4 \
  h3g2 h3g3 h3h2 h3h4

check "king escapes check or block with rook (black)" \
  "2BK4/8/8/P7/p7/7k/8/2r5 b - - 0 1" \
  5 \
  c1c8 h3g2 h3g3 h3h2 h3h4

check "king escapes check or block with rook (white)" \
  "2bk4/8/8/p7/P7/7K/8/2R5 w - - 0 1" \
  5 \
  c1c8 h3g2 h3g3 h3h2 h3h4

check "pawn capture would explode own king (white)" \
  "2bk4/8/8/p4n2/P3pp2/4P2K/8/8 w - - 0 1" \
  3 \
  h3g2 h3g4 h3h2

check "knight capture would explode own king (black)" \
  "3K4/8/8/8/7n/8/6N1/7k b - - 0 1" \
  5 \
  h1g1 h1h2 h4f3 h4f5 h4g6

check "knight capture would explode own king (white)" \
  "3k4/8/8/8/7N/8/6n1/7K w - - 0 1" \
  5 \
  h1g1 h1h2 h4f3 h4f5 h4g6

check "kings touch (black)" \
  "3K4/4k3/8/8/8/8/8/N6n b - - 0 1" \
  9 \
  e7d6 e7d7 e7e6 e7e8 e7f6 e7f7 e7f8 h1f2 h1g3

check "kings touch (white)" \
  "3k4/4K3/8/8/8/8/8/n6N w - - 0 1" \
  9 \
  e7d6 e7d7 e7e6 e7e8 e7f6 e7f7 e7f8 h1f2 h1g3

check "kings touch + queen gives check (black)" \
  "3K4/4k3/4Q3/8/8/8/8/7n b - - 0 1" \
  5 \
  e7d7 e7e8 e7f8 h1f2 h1g3

check "kings touch + queen gives check (white)" \
  "3k4/4K3/4q3/8/8/8/8/7N w - - 0 1" \
  5 \
  e7d7 e7e8 e7f8 h1f2 h1g3

# ---- castling tests ----
check "castling prevented because in check (white)" \
  "4k3/8/8/8/8/8/2n5/R3K2R w KQ - 0 1" \
  5 \
  e1d1 e1d2 e1e2 e1f1 e1f2

check "castling prevented because squares attacked (white)" \
  "4k3/8/8/8/8/p3n2p/P6P/R3K2R w KQ - 0 1" \
  8 \
  a1b1 a1c1 a1d1 e1d2 e1e2 e1f2 h1f1 h1g1

check "long castling prevented (white)" \
  "2r1k3/8/8/8/8/p6p/P6P/R3K2R w KQ - 0 1" \
  11 \
  a1b1 a1c1 a1d1 e1d1 e1d2 e1e2 e1f1 e1f2 e1g1 h1f1 h1g1

check "short castling prevented (white)" \
  "4k1r1/8/8/8/8/p6p/P6P/R3K2R w KQ - 0 1" \
  11 \
  a1b1 a1c1 a1d1 e1c1 e1d1 e1d2 e1e2 e1f1 e1f2 h1f1 h1g1

check "short castling allowed when kings touch (white)" \
  "6r1/8/8/8/8/p6p/P4k1P/R3K2R w KQ - 0 1" \
  11 \
  a1b1 a1c1 a1d1 e1c1 e1d1 e1d2 e1e2 e1f1 e1g1 h1f1 h1g1

# ---- summary ----
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
echo ""
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
