#!/usr/bin/env python3
# A filter for Conway's Game of Life:
# reads grid data from stdin (generates initial frame if empty)
# and outputs the next frame to stdout.
# The wrapper code will be folded to focus on the user code {{{

from random import random
import sys

DEAD_CELL_CHAR = ".."
ALIVE_CELL_CHAR = "██"

FRAME_SIMPLE = [
    [0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0],
    [0, 1, 1, 1, 0],
    [0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0],
]

FRAME_GLIDER_GUN = []
# fmt: off
glider_gun = [
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1],
    [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
]
# fmt: on
for i in range(50):
    row = [0] * 70
    if 1 <= i < 10:
        gun_row_idx = i - 1
        if gun_row_idx < len(glider_gun):
            row[1:37] = glider_gun[gun_row_idx][:36]
    FRAME_GLIDER_GUN.append(row)


def random_frame(row, col, rate=0.4):
    frame = []
    for _ in range(row):
        frame.append([int(random() <= rate) for _ in range(col)])
    return frame


FRAME_RANDOM = random_frame(50, 70)


# }}}


def init_frame():
    """
    Initialize the initial frame as a 2D array;
    0 represents dead cells;
    1 represents alive cells;
    you may also use the built-in frame directly:
    - FRAME_SIMPLE
    - FRAME_GLIDER_GUN
    - FRAME_RANDOM
    """
    return FRAME_GLIDER_GUN  # USER_CODE


# user-code-ended {{{


def get_value_by_pos(frame, pos):
    i = pos[0]
    j = pos[1]
    row_num = len(frame)
    if row_num == 0:
        return 0
    col_num = len(frame[0])
    if 0 <= i < row_num and 0 <= j < col_num:
        return frame[i][j]
    return 0


def next_frame(cur_frame):
    if not (cur_frame and cur_frame[0]):
        return []

    row_num = len(cur_frame)
    col_num = len(cur_frame[0])
    new_frame = []
    for _ in range(row_num):
        new_frame.append([0] * col_num)

    for i in range(row_num):
        for j in range(col_num):
            pos = [
                (i - 1, j - 1),
                (i - 1, j),
                (i - 1, j + 1),
                (i, j - 1),
                (i, j + 1),
                (i + 1, j - 1),
                (i + 1, j),
                (i + 1, j + 1),
            ]
            ij_value = cur_frame[i][j]
            alive_count = sum(get_value_by_pos(cur_frame, p) for p in pos)

            if ij_value == 1:
                if alive_count < 2 or alive_count > 3:
                    ij_value = 0
            else:
                if alive_count == 3:
                    ij_value = 1

            new_frame[i][j] = ij_value
    return new_frame


def parse_input(input_str):
    frame = []
    lines = input_str.strip().split("\n")
    match_len = max(len(ALIVE_CELL_CHAR), len(DEAD_CELL_CHAR))
    for line in lines:
        if not line:
            continue
        row = []
        idx = 0
        line_len = len(line)
        while idx + match_len <= line_len:
            current_chunk = line[idx : idx + match_len]
            if current_chunk == ALIVE_CELL_CHAR:
                row.append(1)
            elif current_chunk == DEAD_CELL_CHAR:
                row.append(0)
            else:
                row.append(0)
            idx += match_len
        frame.append(row)
    return frame


def frame_to_str(frame):
    lines = []
    for row in frame:
        line = "".join(
            [ALIVE_CELL_CHAR if cell == 1 else DEAD_CELL_CHAR for cell in row]
        )
        lines.append(line)
    return "\n".join(lines)


def main():
    input_data = sys.stdin.read()
    if not input_data.strip():
        frame = init_frame()
    else:
        frame = parse_input(input_data)
        frame = next_frame(frame)

    output = frame_to_str(frame)
    sys.stdout.write(output)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()


# vim: set foldmethod=marker foldlevel=0:
# }}}
