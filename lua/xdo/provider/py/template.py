import logging
import os
import sys


def setup_logger():
    script_name = os.path.basename(__file__)
    script_dir = os.path.dirname(os.path.abspath(__file__))

    log_file_name = "xdo_stub.log"
    log_file_path = os.path.join(script_dir, log_file_name)

    logger = logging.getLogger(__name__)
    logger.setLevel(logging.INFO)

    file_handler = logging.FileHandler(log_file_path)
    file_handler.setLevel(logging.INFO)

    formatter = logging.Formatter(f"%(asctime)s - {script_name} - %(message)s")
    file_handler.setFormatter(formatter)

    logger.addHandler(file_handler)
    return logger


logger = setup_logger()


class Env:
    def __getattr__(self, name):
        return os.environ.get(name)


env = Env()
v_block_wised = env.EX_CMD in ["Vdo", "Vdov"]
v_char_wised = env.EX_CMD in ["Xdov", "Vdov"]


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


# USER_SNIPPET_END: handle_block


def get_range() -> tuple[int, int, int, int]:
    res = []
    default_range = [
        ("START_ROW", 1),
        ("START_COL", 1),
        ("END_ROW", 1),
        ("END_COL", 2147483647),
    ]
    for key, default in default_range:
        if value := os.environ.get(key):
            res.append(int(value))
        else:
            res.append(default)
    return tuple(res)


def get_ending(content: str):
    for item in ["\r\n", "\n", "\r"]:
        if content.endswith(item):
            return item
    return ""


def line_do():
    logger.info("line do called")
    start_row, start_col, end_row, end_col = get_range()

    cur_row = start_row
    while line := sys.stdin.readline():
        head, tail = "", ""
        if cur_row == end_row:
            line, tail = line[0:end_col], line[end_col:]
        if cur_row == start_row:
            head, line = line[0 : start_col - 1], line[start_col - 1 :]

        re = handle_one_line(line, cur_row) or ""

        logger.info(f"{head=} {line=} {re=} {tail=}")
        sys.stdout.write("".join([head, re, tail]))
        cur_row += 1


def block_do():
    logger.info("block do called")

    block = sys.stdin.read()

    _, start_col, _, _ = get_range()
    tail_len = int(env.TAIL_LEN or 0)
    ending_len = len(get_ending(block))

    head = block[0 : start_col - 1]
    target = block[start_col - 1 : len(block) - tail_len - ending_len]
    tail = block[len(block) - tail_len - ending_len :]

    re = handle_block(target)
    logger.info(f"{tail_len=} {head=} {target=} {re=} {tail=}")
    sys.stdout.write("".join([head, re, tail]))


def main():
    if v_block_wised:
        block_do()
    else:
        line_do()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logger.exception(e)
        sys.exit(1)
