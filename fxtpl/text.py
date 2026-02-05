# Filter running on the selected text of the vim buffer
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


def handle_block(text: str) -> str:
    """Handle the block of text.

    :param text: A block of text from the vim buffer.
    :return: Processed text block.
    """
    return text  # USER_CODE


# user-code-ended {{{


def run_on_block_text():
    res = handle_block(sys.stdin.read())
    sys.stdout.write(res)


if __name__ == "__main__":
    try:
        run_on_block_text()
    except Exception as e:
        logger.exception(e)
        sys.exit(1)

# vim: set foldmethod=marker foldlevel=0:
# }}}
