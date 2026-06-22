const WebSocket = require('ws');
const crypto = require('crypto');
const dgram = require('dgram');
const shortHash = (hash) => hash ? hash.substring(0, 8) + '...' : '';
const mdns = require('multicast-dns');

/**
 * TrackerClient
 * 
 * Manages the connection to the Central Tracker.
 * Handles automatic reconnects, registration, and inventory synchronization.
 * Implements mDNS zero-config LAN fallback for offline swarm discovery.
 */
class TrackerClient {
  constructor(trackerUrl, daemonPort) {
    this.trackerUrl = trackerUrl;
    this.daemonPort = daemonPort;
    this.peerId = crypto.randomUUID();
    this.ws = null;
    this.reconnectInterval = null;
    this.isConnected = false;
    this.pendingRequests = new Map();

    // mDNS Fallback State
    this.mdnsInstance = null;
    this.localPeers = new Map(); // Maps peerId -> { peerId, ip, daemonPort }
    this.mdnsBroadcastInterval = null;
  }

  /**
   * Connects to the tracker server.
   * If the connection fails or drops, it sets up an automatic retry.
   */
  connect(onConnectedCallback = null) {
    if (this.ws) {
      this.ws.removeAllListeners();
      try {
        this.ws.close();
      } catch (e) {}
    }

    console.log(`[TRACKER] Attempting to connect to ${this.trackerUrl} as ${this.peerId}...`);
    this.ws = new WebSocket(this.trackerUrl);

    this.ws.on('open', () => {
      console.log(`[TRACKER] Connected successfully.`);
      this.isConnected = true;
      
      // Stop the reconnect interval if it was running
      if (this.reconnectInterval) {
        clearInterval(this.reconnectInterval);
        this.reconnectInterval = null;
      }

      // We are online, pause mDNS noise
      this._stopMdnsFallback();

      // Register with the tracker
      this._send({
        type: 'REGISTER_PEER',
        peerId: this.peerId,
        ip: '127.0.0.1', 
        daemonPort: this.daemonPort
      });

      if (onConnectedCallback) {
        onConnectedCallback();
      }
    });

    this.ws.on('message', (data) => {
      try {
        const message = JSON.parse(data);
        if (message.type === 'CHUNK_LOCATION' && message.requestId) {
          if (this.pendingRequests.has(message.requestId)) {
            const resolve = this.pendingRequests.get(message.requestId);
            this.pendingRequests.delete(message.requestId);
            resolve(message.seeders || []);
          }
        } else if (message.type === 'PEER_LIST' && message.requestId) {
          if (this.pendingRequests.has(message.requestId)) {
            const resolve = this.pendingRequests.get(message.requestId);
            this.pendingRequests.delete(message.requestId);
            resolve(message.peers || []);
          }
        }
      } catch (err) {
        console.error(`[TRACKER ERROR] Failed to parse message:`, err);
      }
    });

    // Respond to server pings to keep the connection alive
    this.ws.on('ping', () => {
      this.ws.pong();
    });

    this.ws.on('close', () => {
      console.warn(`[TRACKER] Connection closed.`);
      this._handleDisconnect();
    });

    this.ws.on('error', (err) => {
      console.error(`[TRACKER ERROR] Connection error:`, err.message);
      this._handleDisconnect();
    });
  }

  /**
   * Internal handler to trigger reconnects and activate LAN fallback.
   */
  _handleDisconnect() {
    this.isConnected = false;
    
    if (!this.reconnectInterval) {
      console.log(`[TRACKER] Initiating auto-reconnect every 5 seconds...`);
      this.reconnectInterval = setInterval(() => {
        if (!this.isConnected) {
          this.connect();
        }
      }, 5000);
    }

    // Activate the mDNS offline fallback
    this._startMdnsFallback();
  }

  // ─── mDNS LAN Fallback Discovery ───────────────────────────────────────────

  _startMdnsFallback() {
    if (this.mdnsInstance) return; // Already running

    console.log(`[mDNS FALLBACK] Tracker offline. Activating LAN zero-config discovery...`);
    this.mdnsInstance = mdns();
    this.localPeers.clear();

    // Listen for query responses from other daemons
    this.mdnsInstance.on('response', (response) => {
      let ip = null;
      let daemonPort = null;
      let discoveredPeerId = null;

      // Extract the required fields from the DNS records
      for (const answer of response.answers) {
        if (answer.type === 'A' && answer.name === '_microcdn._tcp.local') {
          ip = answer.data;
        } else if (answer.type === 'SRV' && answer.name === '_microcdn._tcp.local') {
          daemonPort = answer.data.port;
        } else if (answer.type === 'TXT' && answer.name === '_microcdn._tcp.local') {
          // data is a Buffer
          discoveredPeerId = answer.data.toString('utf8');
        }
      }

      // If we got a complete profile of a peer that isn't us
      if (ip && daemonPort && discoveredPeerId && discoveredPeerId !== this.peerId) {
        if (!this.localPeers.has(discoveredPeerId)) {
          console.log(`[mDNS FALLBACK] Discovered local peer: ${discoveredPeerId} at ${ip}:${daemonPort}`);
          this.localPeers.set(discoveredPeerId, { peerId: discoveredPeerId, ip, daemonPort });
        }
      }
    });

    // Periodically broadcast our own presence and query for others
    this.mdnsBroadcastInterval = setInterval(() => {
      // 1. Broadcast our presence
      this.mdnsInstance.respond({
        answers: [
          {
            name: '_microcdn._tcp.local',
            type: 'A',
            ttl: 120,
            data: '127.0.0.1' // In a real app, resolve local IPv4 (e.g. os.networkInterfaces())
          },
          {
            name: '_microcdn._tcp.local',
            type: 'SRV',
            ttl: 120,
            data: { port: this.daemonPort, weight: 0, priority: 10, target: 'microcdn.local' }
          },
          {
            name: '_microcdn._tcp.local',
            type: 'TXT',
            ttl: 120,
            data: Buffer.from(this.peerId)
          }
        ]
      });

      // 2. Query for other daemons
      this.mdnsInstance.query({
        questions: [{ name: '_microcdn._tcp.local', type: 'ANY' }]
      });

    }, 3000); // Poll/Broadcast every 3 seconds while disconnected

    // Send an immediate query on startup
    this.mdnsInstance.query({
      questions: [{ name: '_microcdn._tcp.local', type: 'ANY' }]
    });
  }

  _stopMdnsFallback() {
    if (!this.mdnsInstance) return;

    console.log(`[mDNS FALLBACK] Tracker restored. Pausing LAN discovery broadcasts.`);
    clearInterval(this.mdnsBroadcastInterval);
    this.mdnsBroadcastInterval = null;
    
    this.mdnsInstance.destroy();
    this.mdnsInstance = null;
    this.localPeers.clear();
  }

  // ────────────────────────────────────────────────────────────────────────────

  /**
   * Helper to safely send JSON strings over the WebSocket.
   */
  _send(payload) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(payload));
    } else {
      console.warn(`[TRACKER WARNING] Cannot send message, WebSocket is not open.`);
    }
  }

  /**
   * Sends the UPDATE_INVENTORY payload to the central tracker.
   */
  syncInventory(cacheKey, chunkIndices) {
    this._send({
      type: 'UPDATE_INVENTORY',
      cacheKey: cacheKey,
      chunkIndices: chunkIndices
    });
    // In an offline scenario, we could optionally broadcast inventory via mDNS,
    // but the sequential attempt strategy handles it efficiently enough for a LAN.
    if (this.isConnected) {
      console.log(`[TRACKER] Synced inventory for ${shortHash(cacheKey)} (${chunkIndices.length} chunks)`);
    } else {
      console.log(`[TRACKER] Offline. Inventory sync deferred.`);
    }
  }

  /**
   * Finds seeders for a specific chunk.
   * Seamlessly falls back to returning local LAN peers if disconnected.
   */
  findSeeders(cacheKey, chunkIndex) {
    if (!this.isConnected) {
      const peers = Array.from(this.localPeers.values());
      console.log(`[mDNS FALLBACK] Tracker offline. Supplying ${peers.length} discovered LAN peers as fallback.`);
      return Promise.resolve(peers);
    }

    return new Promise((resolve) => {
      const requestId = crypto.randomUUID();
      
      const timeoutId = setTimeout(() => {
        if (this.pendingRequests.has(requestId)) {
          this.pendingRequests.delete(requestId);
          console.warn(`[TRACKER] Timeout waiting for FIND_CHUNK response`);
          resolve([]);
        }
      }, 3000); // 3 second timeout

      this.pendingRequests.set(requestId, (seeders) => {
        clearTimeout(timeoutId);
        resolve(seeders);
      });

      this._send({
        type: 'FIND_CHUNK',
        cacheKey: cacheKey,
        chunkIndex: chunkIndex,
        requestId: requestId
      });
    });
  }

  /**
   * Fetches the complete list of peers currently connected to the central tracker.
   */
  getPeers() {
    if (!this.isConnected) {
      return Promise.resolve(Array.from(this.localPeers.values()));
    }

    return new Promise((resolve) => {
      const requestId = crypto.randomUUID();
      
      const timeoutId = setTimeout(() => {
        if (this.pendingRequests.has(requestId)) {
          this.pendingRequests.delete(requestId);
          console.warn(`[TRACKER] Timeout waiting for PEER_LIST response`);
          resolve([]);
        }
      }, 3000);

      this.pendingRequests.set(requestId, (peers) => {
        clearTimeout(timeoutId);
        resolve(peers);
      });

      this._send({
        type: 'GET_PEERS',
        requestId: requestId
      });
    });
  }
}

module.exports = TrackerClient;
