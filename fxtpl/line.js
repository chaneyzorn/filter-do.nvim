// Filter running on each line of the vim buffer
// The wrapper code will be folded to focus on the user code {{{

import { Console } from "node:console";
import { createWriteStream } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, basename, join } from "node:path";
import { stdin, stdout } from "node:process";

function dateTimeStr() {
  const date = new Date();
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");
  const seconds = String(date.getSeconds()).padStart(2, "0");
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
}

function setupLogger() {
  const filePath = fileURLToPath(import.meta.url);
  const dirPath = dirname(filePath);
  const scriptName = basename(filePath);

  const logFileName = "filter_do.log";
  const logFilePath = process.env.FX_LOG || join(dirPath, logFileName);

  const logStream = createWriteStream(logFilePath, { flags: "a" });
  const logger = new Console({ stdout: logStream, stderr: logStream });
  logger.log = function (message, ...optionalParams) {
    const msg = `${dateTimeStr()} - ${scriptName} - ${message}`;
    Console.prototype.log.call(this, msg, ...optionalParams);
  };
  return logger;
}

const logger = setupLogger();

// }}}

/**
 * Handle each line of the text.
 *
 * @param {string} line - One line of text from the vim buffer, typically ending with a newline character.
 * @param {number} linenr - The line number in the Vim buffer.
 * @returns {string} Processed text line.
 *   - Return empty string to delete this line.
 *   - Include `\n` to insert multiple lines of text.
 *   - Remove the trailing `\n` to join the next line.
 */
async function handleOneLine(line, linenr) {
  return line; // USER_CODE
}

// user code ended {{{

function* lineIter(chunk) {
  let index = 0;
  while (index < chunk.length) {
    let ending = true;
    let lineEndIndex = chunk.indexOf("\n", index);
    if (lineEndIndex === -1) {
      lineEndIndex = chunk.length;
      ending = false;
    } else {
      lineEndIndex++;
    }
    const line = chunk.slice(index, lineEndIndex);
    index = lineEndIndex;
    yield { line, ending };
  }
}

async function* readLinesFromStdin() {
  stdin.setEncoding("utf8");
  let buffer = "";
  for await (const chunk of stdin) {
    for (const item of lineIter(buffer + chunk)) {
      if (item.ending) {
        yield item.line;
        buffer = "";
      } else {
        buffer = item.line;
      }
    }
  }
  if (buffer) {
    yield buffer;
  }
}

async function runOneEachLine() {
  let cur_row = Number.parseInt(process.env.START_ROW || "1", 10);
  for await (const line of readLinesFromStdin()) {
    const res = await handleOneLine(line, cur_row);
    stdout.write(res);
    cur_row++;
  }
}

try {
  await runOneEachLine();
} catch (e) {
  logger.log(e.stack);
  process.exit(1);
}

// vim: set foldmethod=marker foldlevel=0:
// }}}
