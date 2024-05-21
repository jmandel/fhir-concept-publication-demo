import { readFileSync } from 'fs';
import * as jsonpatch from 'fast-json-patch';
import { Command } from 'commander';
import zlib from 'zlib';
import util from 'util';

// Promisify zlib's gunzip
const gunzip = util.promisify(zlib.gunzip);

// Define the interfaces
interface JsonConcept {
  code: string;
  [key: string]: any;
}

interface JsonPatchOperation {
  op: 'add' | 'remove' | 'replace' | 'move' | 'copy' | 'test';
  path: string;
  value?: any;
  from?: string;
}

interface JsonDiff {
  code: string;
  patches: JsonPatchOperation[];
}

// Read and parse NDJSON files, supporting gzipped files
async function readNdjsonFile(filePath: string): Promise<JsonConcept[]> {
  let data: string;
  if (filePath.endsWith('.gz')) {
    const compressedData = readFileSync(filePath);
    const decompressedData = await gunzip(compressedData);
    data = decompressedData.toString();
  } else {
    data = readFileSync(filePath, 'utf-8');
  }
  return data.split('\n').filter(line => line).map(line => JSON.parse(line));
}

// Compute the diff between two sorted arrays of JsonConcepts
function computeDiff(a: JsonConcept[], b: JsonConcept[]): JsonDiff[] {
  const diff: JsonDiff[] = [];
  let i = 0, j = 0;

  while (i < a.length && j < b.length) {
    if (a[i].code < b[j].code) {
      diff.push({ code: a[i].code, patches: [{ op: 'remove', path: '/' }] });
      i++;
    } else if (a[i].code > b[j].code) {
      diff.push({ code: b[j].code, patches: [{ op: 'add', path: '/', value: b[j] }] });
      j++;
    } else {
      const patches = jsonpatch.compare(a[i], b[j]);
      if (patches.length > 0) {
        diff.push({ code: a[i].code, patches });
      }
      i++;
      j++;
    }
  }

  // Handle remaining items in a
  while (i < a.length) {
    diff.push({ code: a[i].code, patches: [{ op: 'remove', path: '/' }] });
    i++;
  }

  // Handle remaining items in b
  while (j < b.length) {
    diff.push({ code: b[j].code, patches: [{ op: 'add', path: '/', value: b[j] }] });
    j++;
  }

  return diff;
}

// CLI setup using commander
const program = new Command();

program
  .version('1.0.0')
  .description('Compute domain-specific diff between two NDJSON files')
  .requiredOption('-a, --inputA <path>', 'Input A NDJSON file path')
  .requiredOption('-b, --inputB <path>', 'Input B NDJSON file path')
  .parse(process.argv);

const options = program.opts();

const inputA = await readNdjsonFile(options.inputA);
const inputB = await readNdjsonFile(options.inputB);
inputA.sort((x, y) => x.code.localeCompare(y.code));
inputB.sort((x, y) => x.code.localeCompare(y.code));
const diff = computeDiff(inputA, inputB);
for (const l of diff) {
  console.log(JSON.stringify(l));
}
