/**
 * MemoryTracker
 * 
 * 100% stateless, RAM-based chunk registry for O(1) lookups.
 * Maps CacheKey -> ChunkIndex -> Set of peer connections.
 */
class MemoryTracker {
  constructor() {
    // Primary O(1) Map: CacheKey -> (Map: ChunkIndex -> Set<WebSocket>)
    this.registry = new Map();

    // Reverse Map for O(1) cleanup on disconnect: WebSocket -> Set<{cacheKey, chunkIndex}>
    // Using the WebSocket object as the key directly (Node.js Map allows object keys)
    this.peerInventory = new Map();
  }

  /**
   * Registers a new peer connection, binding their IP, ID, and Daemon Port to the WebSocket instance.
   * @param {WebSocket} ws - The live WebSocket connection.
   * @param {string} peerId - The unique ID of the daemon peer.
   * @param {string} ip - The IP address of the peer.
   * @param {number} daemonPort - The daemon port the peer is listening on for local connections.
   */
  registerPeer(ws, peerId, ip, daemonPort) {
    ws.peerId = peerId;
    ws.ip = ip;
    ws.daemonPort = daemonPort;

    // Initialize the reverse lookup set for this socket
    if (!this.peerInventory.has(ws)) {
      this.peerInventory.set(ws, new Set());
    }

    console.log(`[REGISTER] Peer ${peerId} registered at ${ip}:${daemonPort}`);
  }

  /**
   * Updates the inventory of chunks the peer is currently hosting.
   * @param {WebSocket} ws - The peer's WebSocket connection.
   * @param {string} cacheKey - The SHA-256 hash of the video/file.
   * @param {Array<number>} chunkIndices - Array of chunk indices the peer has.
   */
  updateInventory(ws, cacheKey, chunkIndices) {
    if (!ws.peerId) {
      console.warn(`[WARNING] Unregistered peer tried to update inventory.`);
      return;
    }

    // Ensure the CacheKey exists in the registry
    if (!this.registry.has(cacheKey)) {
      this.registry.set(cacheKey, new Map());
    }

    const shortHash = (hash) => hash ? hash.substring(0, 8) + '...' : '';
    const chunkMap = this.registry.get(cacheKey);
    const peerSet = this.peerInventory.get(ws);

    for (const chunkIndex of chunkIndices) {
      // Ensure the ChunkIndex exists in the chunkMap
      if (!chunkMap.has(chunkIndex)) {
        chunkMap.set(chunkIndex, new Set());
      }

      // Add the WebSocket to the Set of seeders for this chunk
      const seeders = chunkMap.get(chunkIndex);
      if (!seeders.has(ws)) {
        seeders.add(ws);
        // Track it in reverse map for easy cleanup
        peerSet.add(`${cacheKey}:${chunkIndex}`);
      }
    }

    console.log(`[UPDATE] Peer ${ws.peerId} mapped to ${chunkIndices.length} chunks for ${shortHash(cacheKey)}`);
  }

  /**
   * Finds all seeders for a specific chunk instantly.
   * @param {string} cacheKey - The SHA-256 hash of the video/file.
   * @param {number} chunkIndex - The specific chunk index to find.
   * @returns {Array<{peerId: string, ip: string, daemonPort: number}>} List of seeders.
   */
  findChunk(cacheKey, chunkIndex) {
    if (!this.registry.has(cacheKey)) {
      return [];
    }

    const chunkMap = this.registry.get(cacheKey);
    if (!chunkMap.has(chunkIndex)) {
      return [];
    }

    const seeders = chunkMap.get(chunkIndex);
    const result = [];

    // O(K) where K is the number of seeders for this specific chunk
    for (const ws of seeders) {
      // Only return valid, registered peers
      if (ws.peerId && ws.ip && ws.daemonPort) {
        result.push({
          peerId: ws.peerId,
          ip: ws.ip,
          daemonPort: ws.daemonPort
        });
      }
    }

    return result;
  }

  /**
   * Instantly purges a disconnected peer from all registries.
   * O(N) where N is the number of chunks this specific peer held.
   * @param {WebSocket} ws - The disconnected WebSocket.
   */
  removePeer(ws) {
    if (!this.peerInventory.has(ws)) return;

    const peerId = ws.peerId || 'Unknown';
    const inventory = this.peerInventory.get(ws);

    for (const item of inventory) {
      const [cacheKey, chunkIndexStr] = item.split(':');
      const chunkIndex = parseInt(chunkIndexStr, 10);

      // Clean up the main registry
      const chunkMap = this.registry.get(cacheKey);
      if (chunkMap) {
        const seeders = chunkMap.get(chunkIndex);
        if (seeders) {
          seeders.delete(ws);
          
          // Memory optimization: if no one is seeding this chunk, remove the set
          if (seeders.size === 0) {
            chunkMap.delete(chunkIndex);
          }
        }

        // Memory optimization: if no chunks exist for this cacheKey, remove the map
        if (chunkMap.size === 0) {
          this.registry.delete(cacheKey);
        }
      }
    }

    // Clean up reverse map
    this.peerInventory.delete(ws);
    console.log(`[DISCONNECT] Peer ${peerId} disconnected. Cleaned up ${inventory.size} chunk references.`);
  }
}

module.exports = MemoryTracker;
