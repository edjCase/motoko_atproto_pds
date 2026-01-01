# AT Protocol PDS DAO

A Decentralized Autonomous Organization (DAO) implementation for managing an [AT Protocol PDS](../../README.md) (Personal Data Server) on the Internet Computer. This example demonstrates how a collective can govern a Bluesky/AT Protocol identity through proposal-based decision making.

## Overview

This DAO enables multiple members to collectively control a PDS instance, allowing them to:
- Post to Bluesky and other AT Protocol networks via proposals
- Deploy and manage PDS canisters
- Configure permissions and delegates
- Vote on all organizational actions

Unlike traditional social media accounts controlled by individuals, this DAO-based approach enables organizations, communities, and collectives to manage their social presence democratically.

## Features

- **ICRC-120 Compliance**: Full support for automated canister deployment and orchestration
- **Proposal-Based Governance**: All actions require member approval
- **Multi-Member Voting**: Weighted voting system with configurable thresholds
- **Flexible Proposal Types**:
  - Post to Bluesky
  - Install/upgrade PDS canisters
  - Configure delegate permissions
  - Set PDS canister references
  - Custom inter-canister calls
- **Chunked WASM Upload**: Support for large PDS WASM modules via chunk-based upload
- **Web Interface**: Frontend for easy proposal management and voting

## Architecture

The DAO consists of two canisters:

### Backend Canister
- Manages DAO membership and voting
- Stores WASM modules for PDS deployment
- Executes adopted proposals
- Provides ICRC-120 orchestration

### Frontend Canister (Optional)
- Web UI for creating proposals
- Voting interface
- Member management
- Proposal history and status

## Getting Started

### Prerequisites

- [DFX](https://internetcomputer.org/docs/current/developer-docs/setup/install) (Internet Computer SDK)
- [Mops](https://mops.one/) (Motoko package manager)
- Node.js and npm (for frontend development)

### Installation

1. Navigate to the DAO example directory:
```bash
cd examples/dao
```

2. Install dependencies:
```bash
mops install
npm install
```

3. Start the local replica:
```bash
dfx start --background
```

4. Deploy the DAO:
```bash
dfx deploy
```

**Important**: The deploying identity automatically becomes the first DAO member with voting power.

### Frontend Development

For local development with hot reloading:

```bash
npm run start
```

The frontend will be available at `http://localhost:5173` (or similar, check terminal output).

To deploy the frontend as a canister:

```bash
dfx deploy frontend
```

Access the deployed frontend at the URL provided by dfx (typically `http://<canister-id>.localhost:4943`).

## Usage

### Managing Members

#### Add a Member
```bash
./scripts/add_member.sh <network> <principal>
```

**Example:**
```bash
./scripts/add_member.sh local rrkah-fqaaa-aaaaa-aaaaq-cai
```

#### Remove a Member
```bash
./scripts/remove_member.sh <network> <principal>
```

**Example:**
```bash
./scripts/remove_member.sh local rrkah-fqaaa-aaaaa-aaaaq-cai
```

#### Replace a Member
```bash
./scripts/replace_member.sh <network> <new_principal>
```

Adds a new member and removes another member (useful for member rotation).

#### Replace Yourself
```bash
./scripts/replace_member_self.sh <network> <new_principal>
```

Convenient script to add a new member and remove your own principal (useful for handing over control).

### Managing WASM Modules

Before the DAO can deploy PDS canisters, you need to upload the PDS WASM module:

#### Upload PDS WASM
```bash
./scripts/upload_wasm.sh <network> [wasm_file_path]
```

**Examples:**
```bash
# Upload using default path (generates from parent project)
./scripts/upload_wasm.sh local

# Upload a specific WASM file
./scripts/upload_wasm.sh local /path/to/pds.wasm

# Use custom chunk size (default: 1MB)
CHUNK_SIZE=524288 ./scripts/upload_wasm.sh local
```

The script:
1. Calculates the WASM module's SHA256 hash
2. Splits the file into chunks (max 1MB each)
3. Uploads each chunk to the DAO canister
4. Finalizes the upload for use in proposals

**Note**: WASM modules can be large (>2MB), requiring chunked upload to work within Internet Computer message size limits.

### Creating Proposals

Proposals can be created via the frontend UI or programmatically. All proposals require member votes to be adopted.

#### Post to Bluesky (via script)
```bash
./scripts/post_to_feed.sh <network> <pds_canister_id> "<message>"
```

**Example:**
```bash
./scripts/post_to_feed.sh local rrkah-fqaaa-aaaaa-aaaaq-cai "Hello from our DAO!"
```

**Note**: This script posts directly to a PDS canister. To post via DAO governance, create a "Post to Bluesky" proposal through the frontend.

#### Deploy an Empty Canister

For ICRC-120 orchestration, you may need to create an empty canister first:

```bash
./scripts/deploy_empty_canister.sh
```

This creates a canister controlled by your principal on the local network with 10T cycles.

### Proposal Types

#### 1. Post to Bluesky
Creates a post on the DAO-controlled PDS.

**Fields:**
- `message`: Text content of the post

#### 2. Install PDS
Deploys or upgrades a PDS canister using a previously uploaded WASM module.

**Fields:**
- `canisterId`: Target canister principal
- `wasmHash`: SHA256 hash of the WASM module to install
- `args`: Initialization arguments (hostname, PLC config, etc.)
- `mode`: `#install`, `#reinstall`, or `#upgrade`

#### 3. Set Delegate Permissions
Grants or revokes specific permissions to external entities.

**Fields:**
- `entity`: Principal to grant permissions to
- `permissions`: Object defining allowed operations

**Permissions:**
- `readLogs`: View canister logs
- `deleteLogs`: Clear logs
- `createRecord`: Create new records
- `putRecord`: Update records
- `deleteRecord`: Delete records
- `modifyOwner`: Change ownership

#### 4. Set PDS Canister
Updates the DAO's reference to its managed PDS canister.

**Fields:**
- `canisterId`: Principal of the PDS canister

#### 5. Custom Call
Execute arbitrary inter-canister calls for extended functionality.

**Fields:**
- `canisterId`: Target canister
- `methodName`: Method to call
- `args`: Candid-encoded arguments

### Voting

Members can vote on proposals through the frontend or via CLI:

```bash
dfx canister call backend vote '(<proposal_id>, <true/false>)' --network <network>
```

**Example:**
```bash
# Vote yes on proposal #1
dfx canister call backend vote '(1, true)' --network local

# Vote no on proposal #2
dfx canister call backend vote '(2, false)' --network local
```

### Viewing Proposals

Query proposals through the frontend or CLI:

```bash
# Get specific proposal
dfx canister call backend getProposal '(<proposal_id>)' --network <network>

# List proposals (count, offset)
dfx canister call backend getProposals '(10, 0)' --network <network>
```

## Configuration

### Voting Parameters

Default settings (can be modified in `src/backend/main.mo`):

- **Proposal Duration**: 7 days
- **Voting Threshold**: 50% approval
- **Quorum**: 25% of total voting power
- **Vote Changes**: Allowed (members can change their vote)

### Member Voting Power

Currently, all members have equal voting power (1 vote each). This can be customized by modifying the `MemberData` structure.

## Project Structure

```
examples/dao/
├── dfx.json                        # Canister configuration
├── mops.toml                       # Motoko dependencies
├── package.json                    # NPM configuration
├── scripts/                        # Utility scripts
│   ├── add_member.sh              # Add DAO member
│   ├── remove_member.sh           # Remove DAO member
│   ├── replace_member.sh          # Replace a member
│   ├── replace_member_self.sh     # Replace yourself
│   ├── upload_wasm.sh             # Upload PDS WASM in chunks
│   ├── post_to_feed.sh            # Post directly to PDS
│   └── deploy_empty_canister.sh   # Create empty canister
├── src/
│   ├── backend/
│   │   ├── main.mo                # DAO canister entry point
│   │   ├── DaoInterface.mo        # Public API interface
│   │   ├── Orchestrator.mo        # ICRC-120 orchestration
│   │   ├── Logger.mo              # Event logging
│   │   ├── WasmStore.mo           # WASM module storage
│   │   └── Proposals/             # Proposal type implementations
│   │       ├── PostToBlueskyProposal.mo
│   │       ├── InstallPdsProposal.mo
│   │       ├── SetPdsCanisterProposal.mo
│   │       ├── SetDelegatePermissionsProposal.mo
│   │       └── CustomCallProposal.mo
│   └── frontend/                   # Web UI (Svelte)
│       ├── src/
│       │   ├── routes/            # Pages
│       │   ├── lib/               # Utilities
│       │   └── bindings/          # Canister bindings
│       └── static/                # Static assets
└── deps/                          # External dependencies
```

## ICRC-120 Orchestration

This DAO implements the ICRC-120 standard for canister orchestration, enabling:

- Automated PDS deployment workflows
- Upgrade management
- Event tracking
- Status reporting

Query orchestration events:

```bash
dfx canister call backend icrc120_get_events '(record { filter = null; prev = null; take = null })' --network <network>
```

## Development

### Running Tests

```bash
mops test
```

### Building

```bash
dfx build
```

### Generating Declarations

After modifying the backend:

```bash
dfx generate backend
```

## Common Workflows

### 1. Initial Setup
```bash
cd examples/dao
mops install
npm install
dfx start --background
dfx deploy
```

### 2. Add DAO Members
```bash
./scripts/add_member.sh local <principal-1>
./scripts/add_member.sh local <principal-2>
```

### 3. Upload PDS WASM
```bash
./scripts/upload_wasm.sh local
```

### 4. Create PDS Deployment Proposal
Use the frontend to create an "Install PDS" proposal with:
- The uploaded WASM hash
- Target canister ID (create via `deploy_empty_canister.sh`)
- PDS initialization arguments

### 5. Vote and Execute
Members vote through the frontend, and the proposal automatically executes when adopted.

### 6. Post via Proposal
Create a "Post to Bluesky" proposal through the frontend, vote, and it posts when adopted.

## Troubleshooting

### WASM Upload Fails
- Ensure chunk size is ≤ 1MB
- Check available canister cycles
- Verify file path is correct

### Proposal Execution Fails
- Verify the PDS WASM was uploaded successfully
- Check that target canister exists and is controlled by the DAO
- Ensure delegate permissions are set correctly

### Frontend Not Loading
- Run `npm install` in the dao directory
- Check that `dfx generate` was run after backend deployment
- Verify local replica is running

## Contributing

This example demonstrates a basic DAO implementation. Contributions for additional features are welcome:

- More proposal types
- Enhanced voting mechanisms
- Treasury management
- Multi-PDS support

## License

MIT License - see [LICENSE](../../LICENSE) for details

## Resources

- [Main PDS Documentation](../../README.md)
- [AT Protocol](https://atproto.com/)
- [ICRC-120 Standard](https://github.com/icdevs/ICEventsWG/blob/main/ICRC-120/ICRC-120.md)
- [Internet Computer DAO Resources](https://internetcomputer.org/docs/current/samples/dao)

---

Built with ❤️ for decentralized governance


