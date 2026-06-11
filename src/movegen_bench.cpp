/*
  Stockfish, a UCI chess playing engine derived from Glaurung 2.1
  Copyright (C) 2004-2022 The Stockfish developers (see AUTHORS file)

  Stockfish is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Stockfish is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <iostream>

#include "movegen.h"
#include "misc.h"
#include "position.h"
#include "types.h"
#include "uci.h"

using namespace std;

namespace Stockfish {
namespace {

constexpr int MAX_PLY = 128;

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

} // namespace

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

} // namespace Stockfish
