'use strict';
const express = require('express');
const app = express();
const port = Number(process.env.PORT || 3000);
app.get('/healthz', (_req, res) => {
  res.status(200).json({ status: 'ok', service: 'nodejs-arc-demo' });
});
app.get('/', (_req, res) => {
  res.status(200).json({ message: 'Hello from ARC kubernetes-mode Node.js demo' });
});
if (require.main === module) {
  app.listen(port, '0.0.0.0', () => console.log(`listening on ${port}`));
}
module.exports = app;
