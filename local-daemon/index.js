const CacheManager = require('./src/CacheManager');
const TrackerClient = require('./src/TrackerClient');
const ProxyServer = require('./src/ProxyServer');
const P2PServer = require('./src/P2PServer');
const ApiServer = require('./src/ApiServer');

// Simple argument parser
const args = process.argv.slice(2);
const getArg = (name) => {
  const prefix = `--${name}=`;
  const arg = args.find(a => a.startsWith(prefix));
  return arg ? arg.substring(prefix.length) : null;
};

// Prioritize CLI args -> Env Vars -> Defaults
const TRACKER_URL = getArg('tracker') || process.env.TRACKER_URL || 'ws://localhost:8080';
const DAEMON_PORT = parseInt(getArg('daemon') || process.env.DAEMON_PORT || 9000, 10);
const PROXY_PORT = parseInt(getArg('proxy') || process.env.PROXY_PORT || 8081, 10);
const API_PORT = parseInt(getArg('api') || process.env.API_PORT || 8082, 10);
const CACHE_DIR = getArg('cache') || process.env.CACHE_DIR || null;

async function bootstrap() {
  console.log('=== Local Daemon Bootstrapping ===');

  // 1. Initialize the Cache Manager
  const cacheManager = new CacheManager(CACHE_DIR);
  await cacheManager.init();

  // 2. Initialize the Tracker Client
  const trackerClient = new TrackerClient(TRACKER_URL, DAEMON_PORT);

  // 3. Initialize the HTTP Proxy Server
  const proxyServer = new ProxyServer(PROXY_PORT, cacheManager, trackerClient);
  proxyServer.start();

  // 4. Initialize and start the gRPC P2P Server
  const p2pServer = new P2PServer(DAEMON_PORT, cacheManager);
  p2pServer.start();

  // 5. Initialize the API Server
  const apiServer = new ApiServer(API_PORT, cacheManager, trackerClient, proxyServer);
  apiServer.start();

  // 6. Connect to the Central Tracker
  // Pass a callback to run once connected
  trackerClient.connect(() => {
    // 7. Sync REAL existing inventory from disk to the tracker
    const inventoryGroups = cacheManager.getInventoryGroups();
    const cacheKeys = Object.keys(inventoryGroups);

    if (cacheKeys.length === 0) {
      console.log('[BOOT] No existing chunks found to sync.');
    } else {
      console.log(`[BOOT] Syncing ${cacheKeys.length} distinct cache keys to tracker...`);
      for (const cacheKey of cacheKeys) {
        const chunkIndices = inventoryGroups[cacheKey];
        trackerClient.syncInventory(cacheKey, chunkIndices);
      }
    }
  });
}

// Handle unexpected errors to keep the daemon alive
process.on('uncaughtException', (err) => {
  console.error('[DAEMON FATAL] Uncaught Exception:', err);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('[DAEMON FATAL] Unhandled Rejection at:', promise, 'reason:', reason);
});

// Start the daemon
bootstrap();
