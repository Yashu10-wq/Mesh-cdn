const http = require('http');
const url = require('url');
const crypto = require('crypto');
const P2PClient = require('./P2PClient');
const shortHash = (hash) => hash ? hash.substring(0, 8) + '...' : '';

const CHUNK_SIZE = 1048576; // 1MB

class ProxyServer {
  constructor(port, cacheManager, trackerClient) {
    this.port = port;
    this.cacheManager = cacheManager;
    this.trackerClient = trackerClient;
    this.server = null;
    this.pendingDownloads = new Map(); // Tracks in-flight chunks to prevent redundant requests
    this.bandwidthSavedBytes = 0; // Tracks bytes served from Cache or P2P
    this.recentDownloads = []; // Tracks recent chunk transfers
  }

  start() {
    this.server = http.createServer((req, res) => {
      this._handleRequest(req, res).catch(err => {
        console.error(`[PROXY ERROR] Unhandled request error:`, err);
        if (!res.headersSent) {
          res.writeHead(500, { 'Content-Type': 'text/plain' });
          res.end('Internal Server Error');
        }
      });
    });

    this.server.listen(this.port, () => {
      console.log(`[PROXY] Interceptor running on http://localhost:${this.port}`);
    });
  }

  async _handleRequest(req, res) {
    // Handle CORS Preflight and set standard headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Range, Content-Type');

    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }

    // 1. Extract the original URL robustly
    let targetUrlRaw = null;
    const urlParamIndex = req.url.indexOf('?url=');
    if (urlParamIndex !== -1) {
      const extracted = req.url.substring(urlParamIndex + 5);
      try {
        targetUrlRaw = decodeURIComponent(extracted);
      } catch (e) {
        targetUrlRaw = extracted;
      }
    }

    if (!targetUrlRaw) {
      res.writeHead(400, { 'Content-Type': 'text/plain' });
      res.end('Missing ?url= parameter');
      return;
    }

    // 2. Generate CacheKey
    const targetUrl = new url.URL(targetUrlRaw);
    const coreUrl = `${targetUrl.protocol}//${targetUrl.host}${targetUrl.pathname}`;
    const cacheKey = crypto.createHash('sha256').update(coreUrl).digest('hex');

    // 3. Parse Range Header
    const rangeHeader = req.headers.range || 'bytes=0-';

    const rangeMatch = rangeHeader.match(/bytes=(\d+)-(\d*)/);
    if (!rangeMatch) {
      res.writeHead(416, { 'Content-Type': 'text/plain' });
      res.end('Invalid Range header');
      return;
    }

    const reqStart = parseInt(rangeMatch[1], 10);
    const reqEnd = rangeMatch[2] ? parseInt(rangeMatch[2], 10) : reqStart + CHUNK_SIZE - 1;

    const chunkIndex = Math.floor(reqStart / CHUNK_SIZE);
    const chunkStartBound = chunkIndex * CHUNK_SIZE;
    const chunkEndBound = chunkStartBound + CHUNK_SIZE - 1;

    // 4. Determine File Metadata (Total Content-Length)
    let metadata = this.cacheManager.getMetadata(cacheKey);
    if (!metadata) {
      metadata = await this._fetchMetadata(targetUrlRaw);
      if (metadata) {
        this.cacheManager.setMetadata(cacheKey, metadata);
      } else {
        console.warn(`[PROXY] Failed to fetch origin metadata for ${cacheKey}. Falling back to dynamic size.`);
        // Fallback gracefully without crashing
        metadata = { contentLength: null };
      }
    }
    const totalLength = metadata.contentLength;

    // Clamp the requested end to the total file size if known
    let actualEnd = totalLength ? Math.min(reqEnd, totalLength - 1, chunkEndBound) : Math.min(reqEnd, chunkEndBound);

    // 5. Try Cache HIT
    const cachedBuffer = await this.cacheManager.getChunk(cacheKey, chunkIndex);

    if (cachedBuffer) {
      console.log(`[PROXY] Cache HIT | Hash: ${shortHash(cacheKey)} | Chunk: ${chunkIndex} | Range: ${reqStart}-${actualEnd}`);
      // Actual file might be smaller than chunk size, adjust actualEnd
      const maxPossibleEnd = chunkStartBound + cachedBuffer.length - 1;
      actualEnd = Math.min(actualEnd, maxPossibleEnd);
      
      this.bandwidthSavedBytes += (actualEnd - reqStart) + 1;
      
      // Record recent download
      this.recentDownloads.unshift({
        file: targetUrlRaw.split('/').pop().split('?')[0] || 'Unknown',
        chunk: chunkIndex,
        source: 'from Local Cache',
        time: new Date().toISOString()
      });
      if (this.recentDownloads.length > 20) this.recentDownloads.pop();
      
      this._serveBufferSlice(res, cachedBuffer, chunkStartBound, reqStart, actualEnd, totalLength);
      
      this._triggerPrefetch(targetUrlRaw, cacheKey, chunkIndex, totalLength);
      return;
    }

    // 6. Cache MISS -> Try Deduplicated Fetch
    console.log(`[PROXY] Cache MISS | Hash: ${shortHash(cacheKey)} | Chunk: ${chunkIndex} | Starting download...`);
    try {
      const result = await this._downloadChunkWithDedupe(targetUrlRaw, cacheKey, chunkIndex, chunkStartBound, totalLength, false);
      if (result) {
        const { buffer, finalTotalLength, source } = result;
        const maxPossibleEnd = chunkStartBound + buffer.length - 1;
        actualEnd = Math.min(actualEnd, maxPossibleEnd);
        
        if (source === 'p2p') {
          this.bandwidthSavedBytes += (actualEnd - reqStart) + 1;
        }

        this._serveBufferSlice(res, buffer, chunkStartBound, reqStart, actualEnd, finalTotalLength);
        
        this._triggerPrefetch(targetUrlRaw, cacheKey, chunkIndex, finalTotalLength);
      }
    } catch (err) {
      console.error(`[PROXY ERROR] Failed to fetch chunk:`, err);
      if (!res.headersSent) {
        res.writeHead(502, { 'Content-Type': 'text/plain' });
        res.end('Bad Gateway');
      }
    }
  }

  _serveBufferSlice(res, chunkBuffer, chunkStartBound, reqStart, actualEnd, totalLength) {
    const sliceStart = reqStart - chunkStartBound;
    // ensure slice bounds don't go out of buffer limits
    const sliceEnd = Math.min(chunkBuffer.length, (actualEnd - chunkStartBound) + 1);

    const slice = chunkBuffer.slice(sliceStart, sliceEnd);

    const displayTotalLength = totalLength ? totalLength : '*';

    res.writeHead(206, {
      'Content-Type': 'video/mp4',
      'Content-Range': `bytes ${reqStart}-${actualEnd}/${displayTotalLength}`,
      'Accept-Ranges': 'bytes',
      'Content-Length': slice.length,
      'Access-Control-Allow-Origin': '*'
    });

    res.end(slice);
  }

  async _fetchMetadata(targetUrl) {
    try {
      const secureUrl = targetUrl.replace(/^http:\/\//i, 'https://');
      const response = await fetch(secureUrl, {
        method: 'HEAD',
        redirect: 'follow'
      });

      if (response.ok) {
        const contentLength = response.headers.get('content-length');
        if (contentLength) {
          return { contentLength: parseInt(contentLength, 10) };
        }
      }
      return null;
    } catch (err) {
      console.error(`[PROXY ERROR] HEAD request failed for ${targetUrl}:`, err.message);
      return null;
    }
  }

  async _fetchFromOrigin(targetUrl, startBound, endBound, cacheKey) {
    const secureUrl = targetUrl.replace(/^http:\/\//i, 'https://');
    const rangeStr = `bytes=${startBound}-${endBound}`;
    console.log(`[PROXY] Fetching: ${secureUrl} | Range: ${rangeStr}`);

    const response = await fetch(secureUrl, {
      method: 'GET',
      redirect: 'follow',
      headers: {
        'Range': rangeStr
      }
    });

    if (response.status !== 206 && response.status !== 200) {
      throw new Error(`Origin responded with status ${response.status}`);
    }

    let originTotalLength = null;
    const contentRange = response.headers.get('content-range');
    if (contentRange) {
      const match = contentRange.match(/\/(\d+)$/);
      if (match) {
        originTotalLength = parseInt(match[1], 10);
        if (cacheKey && !this.cacheManager.getMetadata(cacheKey)) {
          this.cacheManager.setMetadata(cacheKey, { contentLength: originTotalLength });
        }
      }
    }

    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    return { buffer, originTotalLength };
  }

  // ─── Deduplicated Download Engine ───────────────────────────────────────────

  async _downloadChunkWithDedupe(targetUrlRaw, cacheKey, chunkIndex, chunkStartBound, totalLength, isPrefetch) {
    const chunkId = `${cacheKey}_${chunkIndex}`;

    // 1. In-Flight Deduplication Lock
    if (this.pendingDownloads.has(chunkId)) {
      if (isPrefetch) {
        console.log(`[PROXY DEDUPE] Aborting prefetch for ${chunkId} (already in-flight).`);
        return null;
      } else {
        console.log(`[PROXY DEDUPE] Awaiting in-flight download for ${chunkId}...`);
        return this.pendingDownloads.get(chunkId);
      }
    }

    // 2. Start new download and store Promise
    const downloadPromise = this._fetchAndCacheChunk(targetUrlRaw, cacheKey, chunkIndex, chunkStartBound, totalLength, isPrefetch);
    this.pendingDownloads.set(chunkId, downloadPromise);

    try {
      return await downloadPromise;
    } finally {
      // 3. Safe Cleanup
      this.pendingDownloads.delete(chunkId);
    }
  }

  async _fetchAndCacheChunk(targetUrlRaw, cacheKey, chunkIndex, chunkStartBound, totalLength, isPrefetch) {
    const logPrefix = isPrefetch ? '[PROXY PREFETCH]' : '[PROXY]';

    // Tier 1: Try P2P Fallback first
    console.log(`${logPrefix} Searching swarm for Hash: ${shortHash(cacheKey)} | Chunk: ${chunkIndex}...`);
    const seeders = await this.trackerClient.findSeeders(cacheKey, chunkIndex);
    let p2pBuffer = null;
    let p2pHash = null;

    if (seeders && seeders.length > 0) {
      for (const seeder of seeders) {
        if (seeder.peerId === this.trackerClient.peerId) continue;
        try {
          const p2pResponse = await P2PClient.fetchChunk(seeder.ip, seeder.daemonPort, cacheKey, chunkIndex);
          if (p2pResponse && p2pResponse.chunkData) {
            console.log(`${logPrefix} Successfully fetched from peer ${seeder.peerId} (${seeder.ip}:${seeder.daemonPort})`);
            p2pBuffer = p2pResponse.chunkData;
            p2pHash = p2pResponse.expectedHash;
            break;
          }
        } catch (err) {
          // Silently ignore peer failures
        }
      }
    }

    if (p2pBuffer) {
      // Record recent download
      this.recentDownloads.unshift({
        file: targetUrlRaw.split('/').pop().split('?')[0] || 'Unknown',
        chunk: chunkIndex,
        source: `from ${seeders[0]?.ip || 'Unknown'}`,
        time: new Date().toISOString()
      });
      if (this.recentDownloads.length > 20) this.recentDownloads.pop();

      // Async save and broadcast
      this.cacheManager.saveChunk(cacheKey, chunkIndex, p2pBuffer, p2pHash)
        .then((computedHash) => {
          if (computedHash) {
            console.log(`${logPrefix} Chunk ${chunkIndex} cached locally from P2P.`);
            this.trackerClient.syncInventory(cacheKey, [chunkIndex]);
          }
        });
      return { buffer: p2pBuffer, finalTotalLength: totalLength, source: 'p2p' };
    }

    // Tier 2: Try Origin Fallback
    console.log(`${logPrefix} P2P MISS | Fetching Hash: ${shortHash(cacheKey)} | Chunk: ${chunkIndex} from Origin...`);
    const chunkEndBound = chunkStartBound + CHUNK_SIZE - 1;
    const fetchEndBound = totalLength ? Math.min(chunkEndBound, totalLength - 1) : chunkEndBound;

    const { buffer: downloadedBuffer, originTotalLength } = await this._fetchFromOrigin(targetUrlRaw, chunkStartBound, fetchEndBound, cacheKey);
    const finalTotalLength = originTotalLength || totalLength;

    // Record recent download
    this.recentDownloads.unshift({
      file: targetUrlRaw.split('/').pop().split('?')[0] || 'Unknown',
      chunk: chunkIndex,
      source: `from ${new url.URL(targetUrlRaw).host}`,
      time: new Date().toISOString()
    });
    if (this.recentDownloads.length > 20) this.recentDownloads.pop();

    // Async save and broadcast
    this.cacheManager.saveChunk(cacheKey, chunkIndex, downloadedBuffer, null)
      .then((computedHash) => {
        if (computedHash) {
          console.log(`${logPrefix} Chunk ${chunkIndex} cached locally from Origin.`);
          this.trackerClient.syncInventory(cacheKey, [chunkIndex]);
        }
      });

    return { buffer: downloadedBuffer, finalTotalLength, source: 'origin' };
  }

  // ─── Background Prefetching ────────────────────────────────────────────────

  _triggerPrefetch(targetUrlRaw, cacheKey, baseChunkIndex, totalLength) {
    // Fire and forget, completely detached from the current HTTP stream
    setTimeout(() => {
      this._prefetchChunk(targetUrlRaw, cacheKey, baseChunkIndex + 1, totalLength);
      this._prefetchChunk(targetUrlRaw, cacheKey, baseChunkIndex + 2, totalLength);
    }, 0);
  }

  async _prefetchChunk(targetUrlRaw, cacheKey, chunkIndex, totalLength) {
    // 1. Check if chunk is within file bounds
    const chunkStartBound = chunkIndex * CHUNK_SIZE;
    if (totalLength && chunkStartBound >= totalLength) {
      return; // Beyond EOF
    }

    // 2. Check if already in cache (O(1) synchronous check)
    if (this.cacheManager.hasChunk(cacheKey, chunkIndex)) {
      return; // Already cached locally
    }

    console.log(`[PROXY PREFETCH] Triggered background prefetch for Hash: ${shortHash(cacheKey)} | Chunk: ${chunkIndex}`);

    try {
      await this._downloadChunkWithDedupe(targetUrlRaw, cacheKey, chunkIndex, chunkStartBound, totalLength, true);
    } catch (err) {
      console.error(`[PROXY PREFETCH ERROR] Failed to prefetch chunk ${chunkIndex}:`, err.message);
    }
  }
}

module.exports = ProxyServer;
