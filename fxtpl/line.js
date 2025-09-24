import { Console } from "node:console";
import { createWriteStream } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, basename, join } from "node:path";
import { stdin, stdout } from "node:process";

function setupLogger() {
  const filePath = fileURLToPath(import.meta.url);
  const dirPath = dirname(filePath);
  const scriptName = basename(filePath);

  const logFileName = "filter_do.log";
  const logFilePath = join(dirPath, logFileName);

  const logStream = createWriteStream(logFilePath, { flags: "a" });
  const logger = new Console({ stdout: logStream, stderr: logStream });
  return {
    log: (message) => {
      const timestamp = new Date().toLocaleString("sv");
      const msg = `${timestamp} - ${scriptName} - ${message}`;
      logger.log(msg);
    },
  };
}

const logger = setupLogger();

function getRange() {
  const defaultRange = [
    { key: "START_ROW", default: 1 },
    { key: "START_COL", default: 1 },
    { key: "END_ROW", default: 1 },
    { key: "END_COL", default: 2147483647 },
  ];
  return defaultRange.map(({ key, default: defaultValue }) => {
    const value = process.env[key];
    return value ? Number.parseInt(value) : defaultValue;
  });
}

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
  const [start_row, start_col, end_row, end_col] = getRange();
  let cur_row = start_row;
  for await (const line of readLinesFromStdin()) {
    let [head, target, tail] = ["", line, ""];
    if (cur_row === end_row) {
      target = line.slice(0, end_col);
      tail = line.slice(end_col);
    }
    if (cur_row === start_row) {
      head = target.slice(0, start_col - 1);
      target = target.slice(start_col - 1);
    }

    const res = await handleOneLine(line, cur_row);
    logger.log(JSON.stringify({ head, target, res, tail }));
    stdout.write([head, res, tail].join(""));
    cur_row++;
  }
}

try {
  await runOneEachLine();
} catch (e) {
  logger.log(e.stack);
  process.exit(1);
}
