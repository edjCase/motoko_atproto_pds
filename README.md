# AT Protocol PDS for Internet Computer

A decentralized Personal Data Server (PDS) implementation for the [AT Protocol](https://atproto.com/) (used by Bluesky and other decentralized social networks) built in Motoko for the Internet Computer blockchain.

## Overview

This project provides a canister-based PDS that enables DAOs (Decentralized Autonomous Organizations) to create and manage their own AT Protocol identities and post to Bluesky and other AT Protocol networks. Unlike traditional PDS implementations designed for individual users, this is specifically architected for organizational use where a DAO collectively controls the identity and content.

### Key Features

- **Full AT Protocol Implementation**: Complete support for the AT Protocol repository operations, including creating, updating, and deleting records
- **DAO-Centric Design**: Purpose-built for DAOs to collectively manage social media presence
- **ICRC-120 Support**: Automated deployment and management using the ICRC-120 standard
- **Flexible Permission System**: Direct control or delegated permissions to other entities
- **Certified Assets**: Secure serving of DID documents and well-known files
- **Repository Management**: Full IPLD/CAR-based repository with commit history

## Architecture

The PDS canister implements the following AT Protocol endpoints:

### XRPC Endpoints
- `com.atproto.repo.*` - Repository operations (create, put, delete, list records)
- `com.atproto.sync.*` - Sync operations (getRepo, listBlobs, listRepos)
- `com.atproto.identity.*` - Identity resolution
- `app.bsky.actor.*` - Actor profile operations

### Well-Known Routes
- `/.well-known/did.json` - DID document for identity verification
- `/xrpc/com.atproto.server.describeServer` - Server information

## Known Limitations & Workarounds

### WebSocket Requirement

**Issue**: AT Protocol relays require a WebSocket connection via `com.atproto.sync.subscribeRepos` to crawl and index PDS servers. The Internet Computer does not natively support WebSocket connections.

**Solution**: A reverse proxy architecture that routes WebSocket requests separately from regular HTTP requests.

#### Architecture Overview

```
AT Protocol Relay
       ↓
Custom Domain (e.g., pds.edjcase.com)
       ↓
Reverse Proxy (Cloudflare Worker)
       ↓
       ├─→ WebSocket Server (/xrpc/com.atproto.sync.subscribeRepos)
       │   └─→ Polls PDS Canister for events
       │
       └─→ PDS Canister (all other requests)
           └─→ IC Gateway ({canisterId}.raw.icp0.io)
```

#### Important: Domain Registration

⚠️ **Do NOT register your custom domain with DNS directly to the Internet Computer.** The reverse proxy must handle the domain routing, otherwise WebSocket connections will fail. Configure your DNS to point to the reverse proxy instead.

#### Implementation Steps

1. **Deploy the WebSocket Server**
   
   Use the reference implementation: **[atproto_pds_ws_server](https://github.com/edjCase/atproto_pds_ws_server/)**
   
   This Node.js application polls your PDS canister for new events and serves them over WebSocket connections.

2. **Configure Your Custom Domain**
   
   Point your custom domain (e.g., `pds.edjcase.com`) to your reverse proxy service (like Cloudflare).

3. **Set Up the Reverse Proxy**
   
   Example using **Cloudflare Workers**:
   
   - Create a Cloudflare Worker
   - Add a route for your domain: `pds.edjcase.com/*`
   - Deploy the following worker code:

   ```javascript
   export default {
     async fetch(request, env) {
       const url = new URL(request.url);
       
       // Special WebSocket path - route to WebSocket server
       if (url.pathname === '/xrpc/com.atproto.sync.subscribeRepos') {
         const targetUrl = 'https://{websocketServerUrl}' + url.pathname + url.search;
         return fetch(targetUrl, {
           method: request.method,
           headers: request.headers,
           body: request.body,
         });
       }
       
       // All other paths - route to IC gateway
       const icUrl = 'https://{canisterId}.raw.icp0.io' + url.pathname + url.search;
       
       return fetch(icUrl, {
         method: request.method,
         headers: request.headers,
         body: request.body,
         redirect: 'follow'
       });
     }
   }
   ```
   
   **Replace the placeholders**:
   - `{websocketServerUrl}` - URL of your deployed WebSocket server
   - `{canisterId}` - Your PDS canister ID

4. **Configure Your PDS**
   
   When initializing your PDS canister, use your custom domain (e.g., `pds.edjcase.com`) as the hostname.

#### How It Works

1. **Regular Requests**: All standard AT Protocol requests go directly to your PDS canister via the IC gateway
2. **WebSocket Requests**: The `com.atproto.sync.subscribeRepos` endpoint is intercepted and routed to the WebSocket server
3. **Event Polling**: The WebSocket server continuously polls the PDS canister for new repository events
4. **Event Streaming**: When new events occur, they're pushed through the WebSocket connection to the AT Protocol relay

This architecture bridges the gap between the Internet Computer's HTTP-only interface and the AT Protocol's WebSocket requirements, enabling full relay crawling and indexing support.

## Example DAO Implementation

The [`examples/dao`](examples/dao) directory contains a complete reference implementation of a DAO that controls a PDS instance.

### Features

- **ICRC-120 Compatible**: Automated canister deployment and management
- **Proposal-Based Governance**: All actions require DAO member approval
- **Flexible Permissions**: Delegate specific permissions to entities for automated operations
- **Multiple Proposal Types**:
  - Post to Bluesky
  - Install/upgrade PDS canister
  - Set delegate permissions
  - Set PDS canister reference
  - Custom calls for extensibility

### Deployment

The DAO example uses a proposal system where members can:
1. Create proposals for actions (posting, configuration changes, etc.)
2. Vote on proposals using their voting power
3. Execute adopted proposals automatically

See the [DAO README](examples/dao/README.md) for detailed setup instructions.

## Getting Started

### Prerequisites

- [DFX](https://internetcomputer.org/docs/current/developer-docs/setup/install) (Internet Computer SDK)
- [Mops](https://mops.one/) (Motoko package manager)
- Node.js (for the WebSocket proxy server)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/edjCase/motoko_atproto_pds.git
cd motoko_atproto_pds
```

2. Install dependencies:
```bash
mops install
```

3. Start the local replica:
```bash
dfx start --background
```

4. Deploy the PDS:
```bash
# For local deployment with a new DID
./scripts/deploy_local.sh new

# For local deployment with an existing PLC DID
./scripts/deploy_local.sh did:plc:your_existing_did

# For IC deployment with a new DID
./scripts/deploy_ic.sh new your-domain.com

# For IC deployment with custom subdomain
./scripts/deploy_ic.sh new your-domain.com auto pds

# For IC deployment with an existing PLC DID
./scripts/deploy_ic.sh did:plc:your_existing_did your-domain.com
```

The deployment scripts automatically:
- Create or use existing canister
- Generate or use the specified PLC DID
- Configure the hostname based on the network and parameters
- Initialize the PDS with the correct parameters

### Configuration

The PDS initialization requires the following parameters (handled automatically by `deploy.sh`):

```motoko
{
  plcKind: PlcKind;       // PLC directory configuration (new or existing DID)
  hostname: Text;          // Your PDS hostname
  serviceSubdomain: ?Text; // Optional subdomain for the service
  owner: ?Principal;       // Optional owner principal (defaults to deployer)
}
```

### Setting up the WebSocket Proxy

For your PDS to be crawled by AT Protocol relays, see the [WebSocket Requirement](#websocket-requirement) section above for detailed setup instructions.

## Utility Scripts

The `scripts/` directory contains helpful utilities for managing your PDS:

### `deploy_local.sh`

Deploys the PDS canister to the local network with initialization parameters.

```bash
./scripts/deploy_local.sh <plc_did> [mode]
```

**Arguments:**
- `<plc_did>`: Either `new` to create a new DID, or an existing `did:plc:...` identifier
- `[mode]`: Optional deployment mode (`auto`, `install`, `reinstall`, or `upgrade`)

**Examples:**
```bash
# Deploy locally with a new DID
./scripts/deploy_local.sh new

# Deploy locally with an existing DID
./scripts/deploy_local.sh did:plc:abcd1234

# Reinstall on local network
./scripts/deploy_local.sh new reinstall
```

### `deploy_ic.sh`

Deploys the PDS canister to the Internet Computer mainnet with initialization parameters.

```bash
./scripts/deploy_ic.sh <plc_did> <hostname> [mode] [serviceSubdomain]
```

**Arguments:**
- `<plc_did>`: Either `new` to create a new DID, or an existing `did:plc:...` identifier
- `<hostname>`: Required. The base hostname (e.g., `example.com`)
- `[mode]`: Optional deployment mode (`auto`, `install`, `reinstall`, or `upgrade`)
- `[serviceSubdomain]`: Optional. The service subdomain (e.g., `pds`). If empty/null, uses only the hostname

**Examples:**
```bash
# Deploy to IC with a new DID and subdomain
./scripts/deploy_ic.sh new example.com auto pds
# Results in: pds.example.com

# Deploy to IC without subdomain
./scripts/deploy_ic.sh new example.com
# Results in: example.com

# Deploy with an existing DID
./scripts/deploy_ic.sh did:plc:abcd1234 example.com auto myservice

# Reinstall with upgrade mode
./scripts/deploy_ic.sh new example.com reinstall pds
```

### `post_to_feed.sh`

Create a Bluesky post directly from the command line.

```bash
./scripts/post_to_feed.sh <network> <message>
```

**Arguments:**
- `<network>`: Target network (`local` or `ic`)
- `<message>`: The text content of your post

**Example:**
```bash
./scripts/post_to_feed.sh local "Hello from the Internet Computer!"
```

### `request_crawl.sh`

Request the Bluesky relay to crawl your PDS for indexing.

```bash
./scripts/request_crawl.sh
```

This script sends a crawl request to `bsky.network` for the hostname configured in the script. Edit the `hostname` variable in the script to match your PDS domain.

**Note:** Your PDS must have the WebSocket proxy properly configured for crawling to succeed.

## API Reference

### Repository Operations

#### Create Record
```motoko
createRecord(request: CreateRecordRequest) -> Result<CreateRecordResponse, Text>
```

#### Put Record
```motoko
putRecord(request: PutRecordRequest) -> Result<PutRecordResponse, Text>
```

#### Delete Record
```motoko
deleteRecord(request: DeleteRecordRequest) -> Result<DeleteRecordResponse, Text>
```

#### Get Record
```motoko
getRecord(request: GetRecordRequest) -> Result<GetRecordResponse, Text>
```

#### List Records
```motoko
listRecords(request: ListRecordsRequest) -> Result<ListRecordsResponse, Text>
```

### Permission Management

#### Set Owner
```motoko
setOwner(newOwner: Principal) -> Result<(), Text>
```

#### Set Delegate Permissions
```motoko
setDelegatePermissions(entity: Principal, permissions: Permissions) -> Result<(), Text>
```

Permissions include:
- `readLogs`: Read server logs
- `deleteLogs`: Clear server logs
- `createRecord`: Create new records
- `putRecord`: Update existing records
- `deleteRecord`: Delete records
- `modifyOwner`: Change ownership

## Project Structure

```
src/
├── main.mo                         # Main canister entry point
├── PdsInterface.mo                 # Public API interface
├── XrpcRouter.mo                   # XRPC endpoint routing
├── RestApiRouter.mo                # REST API routing
├── WellKnownRouter.mo              # .well-known routes
├── HtmlRouter.mo                   # HTML interface routes
├── DID.mo                          # DID document handling
├── ServerInfo.mo                   # Server information
├── CarUtil.mo                      # CAR file utilities
└── Handlers/
    ├── RepositoryHandler.mo        # Repository operations
    ├── RepositoryMessageHandler.mo # Event handling
    ├── KeyHandler.mo               # Cryptographic key management
    ├── PermissionHandler.mo        # Access control
    ├── DIDDirectoryHandler.mo      # DID directory operations
    └── ServerInfoHandler.mo        # Server metadata

examples/dao/
├── src/backend/
│   ├── main.mo                     # DAO canister
│   ├── Orchestrator.mo             # Deployment orchestration
│   ├── Logger.mo                   # Logging system
│   ├── WasmStore.mo                # WASM module storage
│   └── Proposals/                  # Proposal type implementations
└── src/frontend/                   # Web UI for DAO management
```

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Dependencies

- [motoko_atproto](https://github.com/edjCase/motoko_atproto) - AT Protocol libraries for Motoko
- [Liminal](https://mops.one/liminal) - HTTP server framework
- [certified-assets](https://mops.one/certified-assets) - Certified asset serving
- [dao-proposal-engine](https://mops.one/dao-proposal-engine) - (Example code) DAO governance framework

## License

MIT License - see [LICENSE](LICENSE) file for details

## Resources

- [AT Protocol Documentation](https://atproto.com/)
- [Internet Computer Documentation](https://internetcomputer.org/docs)
- [Motoko Documentation](https://internetcomputer.org/docs/current/motoko/main/motoko)

## Support

For questions and support:
- Open an issue on GitHub
- Check the [AT Protocol Discord](https://discord.gg/atproto)
- Visit the [Internet Computer Forum](https://forum.dfinity.org/)

---
