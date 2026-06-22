const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const path = require('path');
const crypto = require('crypto');

const PROTO_PATH = path.join(__dirname, 'proto', 'peer.proto');
const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true
});
const peerProto = grpc.loadPackageDefinition(packageDefinition).peer;

class P2PServer {
  constructor(port, cacheManager) {
    this.port = port;
    this.cacheManager = cacheManager;
    this.server = new grpc.Server();

    this.server.addService(peerProto.PeerNode.service, {
      GetChunk: this.getChunk.bind(this)
    });
  }

  async getChunk(call, callback) {
    const { cacheKey, chunkIndex } = call.request;

    console.log(`[P2P SERVER] Received gRPC request for ${cacheKey}_${chunkIndex}`);

    const buffer = await this.cacheManager.getChunk(cacheKey, chunkIndex);

    if (buffer) {
      // Compute hash on the fly to guarantee integrity to the requesting peer
      const computedHash = crypto.createHash('sha256').update(buffer).digest('hex');
      
      callback(null, {
        chunkData: buffer,
        expectedHash: computedHash
      });
    } else {
      console.warn(`[P2P SERVER] Chunk not found for ${cacheKey}_${chunkIndex}`);
      callback({
        code: grpc.status.NOT_FOUND,
        details: 'Chunk not found in local cache'
      });
    }
  }

  start() {
    this.server.bindAsync(
      `0.0.0.0:${this.port}`,
      grpc.ServerCredentials.createInsecure(),
      (error, port) => {
        if (error) {
          console.error('[P2P SERVER] Failed to bind gRPC server:', error);
          return;
        }
        this.server.start();
        console.log(`[P2P SERVER] gRPC PeerNode listening on port ${port}`);
      }
    );
  }
}

module.exports = P2PServer;
