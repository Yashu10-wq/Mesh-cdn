const http = require('http');

class ApiServer {
  constructor(port, cacheManager, trackerClient, proxyServer) {
    this.port = port;
    this.cacheManager = cacheManager;
    this.trackerClient = trackerClient;
    this.proxyServer = proxyServer;
    this.server = null;
  }

  start() {
    this.server = http.createServer(async (req, res) => {
      // CORS headers
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Range');
      
      if (req.method === 'OPTIONS') {
        res.writeHead(204);
        res.end();
        return;
      }

      if (req.url === '/api/stats' && req.method === 'GET') {
        const stats = {
          cacheChunks: this.cacheManager.ledger.size,
          activePeers: this.trackerClient.localPeers.size + (this.trackerClient.isConnected ? 1 : 0),
          bandwidthSavedBytes: this.proxyServer.bandwidthSavedBytes,
          p2pHitRate: 85.0, // Mocked for now
          recentDownloads: this.proxyServer.recentDownloads || []
        };
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(stats));
        return;
      }

      if (req.url === '/api/peers' && req.method === 'GET') {
        const peers = [];
        if (this.trackerClient.isConnected) {
          peers.push({
            peerId: 'tracker-server',
            ip: '127.0.0.1',
            daemonPort: 8080,
            chunksHeld: 0,
            latencyMs: 5.0,
            status: 'online'
          });
          const trackerPeers = await this.trackerClient.getPeers();
          for (const p of trackerPeers) {
            peers.push({
              peerId: p.peerId,
              ip: p.ip,
              daemonPort: p.daemonPort,
              chunksHeld: p.chunksHeld || 0,
              latencyMs: Math.floor(Math.random() * 20) + 5.0, // Mock latency for visual
              status: 'online'
            });
          }
        } else {
          for (const [peerId, meta] of this.trackerClient.localPeers.entries()) {
            peers.push({
              peerId: peerId,
              ip: meta.ip,
              daemonPort: meta.daemonPort,
              chunksHeld: 0,
              latencyMs: 12.0,
              status: 'online'
            });
          }
        }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(peers));
        return;
      }

      if (req.url === '/api/cache' && req.method === 'GET') {
        const chunks = [];
        for (const [key, meta] of this.cacheManager.ledger.entries()) {
          chunks.push({
            cacheKey: key.split('_')[0].substring(0, 8) + '...',
            chunkIndex: parseInt(key.split('_')[1], 10),
            fileLabel: key,
            sizeMB: 1.0,
            cachedAt: new Date().toISOString(),
            hash: meta.hash || 'N/A'
          });
        }
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(chunks));
        return;
      }

      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not Found');
    });

    this.server.listen(this.port, () => {
      console.log(`[API] UI Data Server running on http://localhost:${this.port}`);
    });
  }
}

module.exports = ApiServer;
