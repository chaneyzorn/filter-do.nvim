// Filter running on the selected text of the vim buffer
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
 * Handle the block of text.
 *
 * @param {string} text - A block of text from the vim buffer.
 * @returns {string} Processed text block.
 */
async function handleBlock(text) {
  return text; // USER_CODE
}

// user-code-ended {{{

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
  const res = await handleBlock(block);
  stdout.write(res);
}

try {
  await runOnBlockText();
} catch (e) {
  logger.log(e.stack);
  process.exit(1);
}

// vim: set foldmethod=marker foldlevel=0:
// }}}
