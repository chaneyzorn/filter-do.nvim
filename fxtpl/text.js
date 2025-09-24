import { Console } from "node:console";
import { createWriteStream } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, basename, join } from "node:path";
import { stdin, stdout } from "node:process";

const env = process.env;

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

/**
 * Handle the block of text.
 *
 * @param {string} text - A block of text from the vim buffer.
 * @returns {string} Processed text block.
 */
async function handleBlock(text) {
  return text; // USER_CODE
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

async function runOnBlockText() {
  const block = await readAllStdin();

  const start_col = Number.parseInt(env.START_COL || 1);
  const tailLen = Number.parseInt(env.TAIL_LEN || 0);
  const endingLen = getEnding(block).length;

  const head = block.slice(0, start_col - 1);
  const target = block.slice(start_col - 1, block.length - tailLen - endingLen);
  const tail = block.slice(block.length - tailLen - endingLen);

  const res = await handleBlock(target);
  logger.log(JSON.stringify({ tailLen, head, target, res, tail }));
  stdout.write([head, res, tail].join(""));
}

try {
  await runOnBlockText();
} catch (e) {
  logger.log(e.stack);
  process.exit(1);
}
