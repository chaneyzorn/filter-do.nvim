# Filter running on each line of the vim buffer
# The wrapper code will be folded to focus on the user code {{{

import logging
import os
import sys


def setup_logger():
    script_name = os.path.basename(__file__)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    log_file_name = "filter_do.log"
    log_file_path = os.getenv("FX_LOG", os.path.join(script_dir, log_file_name))

    formatter = logging.Formatter(f"%(asctime)s - {script_name} - %(message)s")
    file_handler = logging.FileHandler(log_file_path)
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(formatter)

    logger = logging.getLogger(__name__)
    logger.setLevel(logging.INFO)
    logger.addHandler(file_handler)
    return logger


logger = setup_logger()

# }}}


def handle_one_line(line: str, linenr: int) -> str:
    """Handle each line of the text.

    :param line: One line of text from the vim buffer, typically ending with a newline character.
    :param linenr: The line number in the Vim buffer.
    :return: Processed text line.
        - Return empty string to delete this line.
        - Include `\n` to insert multiple lines of text.
        - Remove the trailing `\n` to join the next line.
    """
    return line  # USER_CODE


# user code ended {{{


def run_on_each_line():
    cur_row = int(os.getenv("START_ROW", "1"))
    while line := sys.stdin.readline():
        res = handle_one_line(line, cur_row) or ""
        sys.stdout.write(res)
        cur_row += 1


if __name__ == "__main__":
    try:
        run_on_each_line()
    except Exception as e:
        logger.exception(e)
        sys.exit(1)

# vim: set foldmethod=marker foldlevel=0:
# }}}
