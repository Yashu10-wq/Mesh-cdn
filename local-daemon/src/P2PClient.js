const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const path = require('path');

const PROTO_PATH = path.join(__dirname, 'proto', 'peer.proto');
const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true
});
const peerProto = grpc.loadPackageDefinition(packageDefinition).peer;

class P2PClient {
  /**
   * Fetches a chunk from a specific peer via gRPC.
   * @param {string} ip - Peer IP
   * @param {number} port - Peer Daemon Port
   * @param {string} cacheKey 
   * @param {number} chunkIndex 
   * @returns {Promise<{ chunkData: Buffer, expectedHash: string }>}
   */
  static fetchChunk(ip, port, cacheKey, chunkIndex) {
    return new Promise((resolve, reject) => {
      const client = new peerProto.PeerNode(
        `${ip}:${port}`,
        grpc.credentials.createInsecure()
      );

      console.log(`[P2P CLIENT] Requesting ${cacheKey}_${chunkIndex} from ${ip}:${port}`);

      client.GetChunk({ cacheKey, chunkIndex }, (err, response) => {
        if (err) {
          console.warn(`[P2P CLIENT ERROR] Failed to fetch from ${ip}:${port}:`, err.message);
          return reject(err);
        }

        resolve({
          chunkData: response.chunkData, // This is a Buffer
          expectedHash: response.expectedHash
        });
      });
    });
  }
}

module.exports = P2PClient;
