const http = require('http');
const WebSocket = require('ws');
const MemoryTracker = require('./MemoryTracker');

const PORT = process.env.PORT || 8080;

// Initialize the O(1) in-memory chunk tracker
const tracker = new MemoryTracker();

// Create a basic HTTP server
const server = http.createServer((req, res) => {
  // Simple health check endpoint for uptime monitoring
  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'UP',
      uptime: process.uptime(),
      timestamp: Date.now()
    }));
    return;
  }

  // Handle 404 for any other HTTP requests
  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not Found');
});

// Create WebSocket server attached to the HTTP server
const wss = new WebSocket.Server({ server });

wss.on('connection', (ws, req) => {
  ws.isAlive = true;
  ws.on('pong', () => {
    ws.isAlive = true;
  });

  console.log(`[CONNECTION] New connection from ${req.socket.remoteAddress}`);

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      
      if (!data.type) {
        console.warn('[WARNING] Received message without type property.');
        return;
      }

      switch (data.type) {
        case 'REGISTER_PEER':
          // Expected payload: { type: 'REGISTER_PEER', peerId: '...', ip: '...', daemonPort: 9000 }
          if (data.peerId && data.ip && data.daemonPort) {
            tracker.registerPeer(ws, data.peerId, data.ip, data.daemonPort);
          } else {
            console.warn('[WARNING] REGISTER_PEER missing required fields.');
          }
          break;

        case 'UPDATE_INVENTORY':
          // Expected payload: { type: 'UPDATE_INVENTORY', cacheKey: '...', chunkIndices: [0, 1, 2] }
          if (data.cacheKey && Array.isArray(data.chunkIndices)) {
            tracker.updateInventory(ws, data.cacheKey, data.chunkIndices);
          } else {
            console.warn('[WARNING] UPDATE_INVENTORY missing required fields.');
          }
          break;

        case 'FIND_CHUNK':
          // Expected payload: { type: 'FIND_CHUNK', cacheKey: '...', chunkIndex: 0, requestId: '...' }
          if (data.cacheKey && typeof data.chunkIndex === 'number') {
            const seeders = tracker.findChunk(data.cacheKey, data.chunkIndex);
            
            // Respond instantly with the list of available peers
            const response = {
              type: 'CHUNK_LOCATION',
              requestId: data.requestId, // Echo back the requestId so client can match
              cacheKey: data.cacheKey,
              chunkIndex: data.chunkIndex,
              seeders: seeders // Array of { peerId, ip, daemonPort }
            };
            ws.send(JSON.stringify(response));
          } else {
            console.warn('[WARNING] FIND_CHUNK missing required fields.');
          }
          break;

        case 'GET_PEERS':
          if (data.requestId) {
            const peers = [];
            for (const ws of wss.clients) {
              if (ws.peerId && ws.ip && ws.daemonPort) {
                peers.push({
                  peerId: ws.peerId,
                  ip: ws.ip,
                  daemonPort: ws.daemonPort,
                  chunksHeld: tracker.peerInventory.has(ws) ? tracker.peerInventory.get(ws).size : 0
                });
              }
            }
            ws.send(JSON.stringify({
              type: 'PEER_LIST',
              requestId: data.requestId,
              peers: peers
            }));
          }
          break;

        default:
          console.warn(`[WARNING] Unknown message type: ${data.type}`);
      }
    } catch (err) {
      console.error('[ERROR] Failed to parse message or process logic:', err.message);
    }
  });

  ws.on('close', () => {
    tracker.removePeer(ws);
  });

  ws.on('error', (err) => {
    console.error('[ERROR] WebSocket error:', err.message);
    tracker.removePeer(ws);
  });
});

const interval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      console.log(`[DISCONNECT] Terminating zombie connection`);
      // Calling terminate() will automatically trigger the 'close' event,
      // which safely routes to tracker.removePeer(ws).
      return ws.terminate();
    }

    ws.isAlive = false;
    ws.ping();
  });
}, 30000);

wss.on('close', () => {
  clearInterval(interval);
});

// Start listening
server.listen(PORT, () => {
  console.log(`[STARTUP] Central Tracker running on port ${PORT}`);
  console.log(`[STARTUP] Health check available at http://localhost:${PORT}/health`);
  console.log(`[STARTUP] WebSocket server listening on ws://localhost:${PORT}`);
});
