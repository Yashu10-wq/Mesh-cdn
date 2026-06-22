const fs = require('fs');
const fsp = require('fs/promises');
const path = require('path');
const crypto = require('crypto');

/**
 * CacheManager
 * 
 * Manages the `.mesh_cache/` directory using native Node.js FS.
 * Implements a strict 2GB LRU (Least Recently Used) policy (max ~2000 chunks).
 * Uses SHA-256 for integrity verification.
 */
class CacheManager {
  constructor(cacheDirName = null) {
    const defaultCacheDir = cacheDirName || process.env.CACHE_DIR || '.mesh_cache';
    this.cacheDir = path.resolve(defaultCacheDir);
    // Using an ES6 Map to maintain insertion order for LRU implementation
    // Key: fileName (e.g., '{cacheKey}_{chunkIndex}.bin')
    // Value: { cacheKey, chunkIndex, size }
    this.ledger = new Map();
    
    // Key: cacheKey (string)
    // Value: { contentLength: number }
    this.fileMetadataMap = new Map();
    
    this.MAX_CHUNKS = 2000; // ~2GB assuming 1MB chunks
  }

  /**
   * Initializes the cache directory and populates the in-memory ledger
   * by reading existing files.
   */
  async init() {
    try {
      await fsp.mkdir(this.cacheDir, { recursive: true });
      const files = await fsp.readdir(this.cacheDir);
      
      for (const file of files) {
        if (!file.endsWith('.bin')) continue;
        
        // Expected format: cacheKey_chunkIndex.bin
        const baseName = file.replace('.bin', '');
        const lastUnderscore = baseName.lastIndexOf('_');
        
        if (lastUnderscore !== -1) {
          const cacheKey = baseName.substring(0, lastUnderscore);
          const chunkIndexStr = baseName.substring(lastUnderscore + 1);
          const chunkIndex = parseInt(chunkIndexStr, 10);
          
          if (!isNaN(chunkIndex)) {
            // Get stats to ensure size tracking (optional but good practice)
            const stats = await fsp.stat(path.join(this.cacheDir, file));
            this.ledger.set(file, { cacheKey, chunkIndex, size: stats.size });
          }
        }
      }
      
      console.log(`[CACHE] Initialized with ${this.ledger.size} chunks.`);
      await this.enforceLRULimit(); // Ensure we are within limits on startup
    } catch (err) {
      console.error('[CACHE ERROR] Failed to initialize cache:', err);
    }
  }

  /**
   * Generates the standard file name for a chunk.
   */
  _getFileName(cacheKey, chunkIndex) {
    return `${cacheKey}_${chunkIndex}.bin`;
  }

  /**
   * Verifies the buffer hash against the expected hash.
   */
  _verifyHash(buffer, expectedHash) {
    const hash = crypto.createHash('sha256').update(buffer).digest('hex');
    return hash === expectedHash;
  }

  /**
   * Saves a chunk to the local file system.
   * If expectedHash is provided, verifies it first.
   * 
   * @param {string} cacheKey - The video/file identifier.
   * @param {number} chunkIndex - The chunk index.
   * @param {Buffer} buffer - The raw binary chunk data.
   * @param {string} [expectedHash] - Optional SHA-256 hash to verify against.
   * @returns {string|null} The computed SHA-256 hash if saved successfully, or null if verification failed.
   */
  async saveChunk(cacheKey, chunkIndex, buffer, expectedHash) {
    const computedHash = crypto.createHash('sha256').update(buffer).digest('hex');

    if (expectedHash && computedHash !== expectedHash) {
      console.error(`[CACHE ERROR] Hash mismatch for chunk ${cacheKey}_${chunkIndex}`);
      return null;
    }

    const fileName = this._getFileName(cacheKey, chunkIndex);
    const filePath = path.join(this.cacheDir, fileName);

    try {
      await fsp.writeFile(filePath, buffer);
      
      // Update LRU ledger
      // If it already exists, remove it first to push it to the end (most recently used)
      if (this.ledger.has(fileName)) {
        this.ledger.delete(fileName);
      }
      
      this.ledger.set(fileName, { cacheKey, chunkIndex, size: buffer.length });
      console.log(`[CACHE] Saved chunk ${fileName}`);

      // Enforce the strict 2GB limit
      await this.enforceLRULimit();
      return computedHash;
    } catch (err) {
      console.error(`[CACHE ERROR] Failed to write chunk ${fileName}:`, err);
      return null;
    }
  }

  /**
   * Sets metadata for a specific cache key (e.g., Content-Length).
   */
  setMetadata(cacheKey, metadata) {
    this.fileMetadataMap.set(cacheKey, metadata);
  }

  /**
   * Retrieves metadata for a specific cache key.
   */
  getMetadata(cacheKey) {
    return this.fileMetadataMap.get(cacheKey);
  }

  /**
   * Checks if a chunk exists in the cache ledger without reading it.
   */
  hasChunk(cacheKey, chunkIndex) {
    const fileName = this._getFileName(cacheKey, chunkIndex);
    return this.ledger.has(fileName);
  }

  /**
   * Retrieves a chunk from the file system.
   * 
   * @param {string} cacheKey 
   * @param {number} chunkIndex 
   * @returns {Buffer|null} The chunk data, or null if not found.
   */
  async getChunk(cacheKey, chunkIndex) {
    const fileName = this._getFileName(cacheKey, chunkIndex);
    
    if (!this.ledger.has(fileName)) {
      return null;
    }

    const filePath = path.join(this.cacheDir, fileName);

    try {
      const buffer = await fsp.readFile(filePath);
      
      // Update LRU: move to the end (most recently used)
      const data = this.ledger.get(fileName);
      this.ledger.delete(fileName);
      this.ledger.set(fileName, data);
      
      return buffer;
    } catch (err) {
      console.error(`[CACHE ERROR] Failed to read chunk ${fileName}:`, err);
      // If file read fails but ledger says it exists, clean up ledger
      this.ledger.delete(fileName);
      return null;
    }
  }

  /**
   * Enforces the 2000 chunk LRU limit. Silently deletes the oldest chunks.
   */
  async enforceLRULimit() {
    while (this.ledger.size > this.MAX_CHUNKS) {
      // The Map iterator returns elements in insertion order.
      // So the first element is the oldest (Least Recently Used).
      const oldestKey = this.ledger.keys().next().value;
      const filePath = path.join(this.cacheDir, oldestKey);

      try {
        await fsp.unlink(filePath);
        console.log(`[CACHE] Evicted oldest chunk: ${oldestKey}`);
      } catch (err) {
        // If file doesn't exist, ignore the error, just remove from ledger
        if (err.code !== 'ENOENT') {
          console.error(`[CACHE ERROR] Failed to delete evicted chunk ${oldestKey}:`, err);
        }
      }

      this.ledger.delete(oldestKey);
    }
  }

  /**
   * Groups the current ledger into a structure suitable for UPDATE_INVENTORY.
   * Format: Map<cacheKey, Array<chunkIndex>>
   * 
   * @returns {Object} A plain object mapping cacheKeys to arrays of chunk indices.
   */
  getInventoryGroups() {
    const groups = {};
    for (const { cacheKey, chunkIndex } of this.ledger.values()) {
      if (!groups[cacheKey]) {
        groups[cacheKey] = [];
      }
      groups[cacheKey].push(chunkIndex);
    }
    return groups;
  }
}

module.exports = CacheManager;
