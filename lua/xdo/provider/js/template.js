import { Console } from "node:console";
import { createWriteStream } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, basename, join } from "node:path";
import { stdin, stdout } from "node:process";

const env = process.env;
const vBlockWised = ["Vdo", "Vdov"].includes(env.EX_CMD);
const vCharWised = ["Xdov", "Vdov"].includes(env.EX_CMD);

function setupLogger() {
  const filePath = fileURLToPath(import.meta.url);
  const dirPath = dirname(filePath);
  const scriptName = basename(filePath);

  const logFileName = "xdo_stub.log";
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

// USER_SNIPPET_BEGIN: handle_one_line
async function handle_one_line(line, linenr) {
  return line; // USER_INPUT: handle_one_line
}
// USER_SNIPPET_END: handle_one_line

// USER_SNIPPET_BEGIN: handle_block
async function handle_block(block) {
  return block; // USER_INPUT: handle_block
}
// USER_SNIPPET_END: handle_block

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

function getEnding(content) {
  const endings = ["\r\n", "\n", "\r"];
  for (const item of endings) {
    if (content.endsWith(item)) {
      return item;
    }
  }
  return "";
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

async function line_do() {
  logger.log("line do called");

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

    const re = await handle_one_line(line, cur_row);
    logger.log(JSON.stringify({ head, target, re, tail }));
    stdout.write([head, re, tail].join(""));
    cur_row++;
  }
}

async function readAllStdin() {
  return new Promise((resolve) => {
    stdin.setEncoding("utf8");
    const chunks = [];
    stdin.on("data", (chunk) => {
      chunks.push(chunk);
    });
    stdin.on("end", () => {
      const block = chunks.join("");
      resolve(block);
    });
  });
}

async function block_do() {
  logger.log("block do called");

  const block = await readAllStdin();

  const [, start_col, ,] = getRange();
  const tailLen = Number.parseInt(env.TAIL_LEN || 0);
  const endingLen = getEnding(block).length;

  const head = block.slice(0, start_col - 1);
  const target = block.slice(start_col - 1, block.length - tailLen - endingLen);
  const tail = block.slice(block.length - tailLen - endingLen);

  const re = await handle_block(target);
  logger.log(JSON.stringify({ tailLen, head, target, re, tail }));
  stdout.write([head, re, tail].join(""));
}

async function main() {
  if (vBlockWised) {
    await block_do();
  } else {
    await line_do();
  }
}

try {
  await main();
} catch (e) {
  logger.log(e.stack);
  process.exit(1);
}
