'use strict';
const fs = require('fs');
const path = require('path');
const dist = path.join(__dirname, '..', 'dist');
fs.rmSync(dist, { recursive: true, force: true });
fs.mkdirSync(dist, { recursive: true });
fs.cpSync(path.join(__dirname, '..', 'src'), path.join(dist, 'src'), { recursive: true });
fs.copyFileSync(path.join(__dirname, '..', 'package.json'), path.join(dist, 'package.json'));
fs.writeFileSync(path.join(dist, 'BUILD_INFO.json'), JSON.stringify({
  builtAt: new Date().toISOString(), node: process.version, pipeline: 'arc-nodejs-8stage'
}, null, 2));
console.log('build ok -> dist/');
