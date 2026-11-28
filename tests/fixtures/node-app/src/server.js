import { createServer } from 'node:http';

createServer((req, res) => {
  res.writeHead(req.url === '/health' ? 200 : 404).end();
}).listen(3000);
