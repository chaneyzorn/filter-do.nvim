import os
import sys


class Env:
    def __getattr__(self, name):
        return os.environ.get(name)


env = Env()


# USER_SNIPPET_BEGIN: handle_one_line
def handle_one_line(line: str, linenr: int) -> str:
    """Handle each line of the text.

    :param line: One line of text from the vim buffer, typically ending with a newline character.
    :param linenr: The line number in the Vim buffer.
    :return: Processed text line.
        - Return empty string to delete this line.
        - Include `\n` to insert multiple lines of text.
        - Remove the trailing `\n` to join the next line.
    """
    return line  # USER_INPUT: handle_one_line


# USER_SNIPPET_END: handle_one_line


# USER_SNIPPET_BEGIN: handle_block
def handle_block(block: str) -> str:
    """Handle the text block.

    :param block: A block of text from the vim buffer.
    :return: Processed text block.
    """
    return block  # USER_INPUT: handle_block


# USER_SNIPPET_END: handle_one_line


def get_range() -> tuple[int, int, int, int]:
    res = []
    default_range = [
        ("START_LNR", 1),
        ("START_COL", 1),
        ("END_LNR", 1),
        ("END_COL", -1),
    ]
    for key, default in default_range:
        if value := os.environ.get(key):
            res.append(int(value))
        else:
            res.append(default)
    return tuple(res)


def line_do():
    start_lnr, start_col, end_lnr, end_col = get_range()

    cur_lnr = start_lnr
    while line := sys.stdin.readline():
        head, tail = "", ""
        if cur_lnr == end_lnr:
            line, tail = line[0:end_col], line[end_col:-1]
        if cur_lnr == start_lnr:
            head, line = line[0 : start_col - 1], line[start_col - 1 : -1]

        res = handle_one_line(line, cur_lnr) or ""

        sys.stdout.write("".join([head, res, tail]))
        cur_lnr += 1


def block_do():
    _, start_col, _, end_col = get_range()

    block = sys.stdin.read()
    head, target, tail = (
        block[0 : start_col - 1],
        block[start_col - 1 : end_col],
        block[end_col:-1],
    )

    res = handle_block(target)

    sys.stdout.write("".join([head, res, tail]))


def main():
    call_target = sys.argv[-1]
    if call_target == "line_do":
        line_do()
    elif call_target == "block_do":
        block_do()
    else:
        line_do()


if __name__ == "__main__":
    main()
