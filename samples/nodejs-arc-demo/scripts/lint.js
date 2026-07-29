'use strict';
const fs = require('fs');
const path = require('path');
function walk(dir, out = []) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(p, out);
    else if (p.endsWith('.js')) out.push(p);
  }
  return out;
}
const files = walk(path.join(__dirname, '..', 'src')).concat(walk(path.join(__dirname, '..', 'scripts')));
let failed = false;
for (const file of files) {
  const src = fs.readFileSync(file, 'utf8');
  if (src.includes('\t')) { console.error(`lint fail: tabs in ${file}`); failed = true; }
}
if (failed) process.exit(1);
console.log(`lint ok (${files.length} files)`);
