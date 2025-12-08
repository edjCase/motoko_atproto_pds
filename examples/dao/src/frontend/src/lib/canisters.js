import { createActor } from '../bindings/backend';
import { HttpAgent } from "@icp-sdk/core/agent";

export const canisterId = process.env.CANISTER_ID_BACKEND;

const isProd = process.env.DFX_NETWORK === "ic";
const url = isProd ? "https://icp-api.io" : "http://localhost:4943";

// Backend actor - will be updated when identity changes
let backendActor = null;

// Initialize with anonymous identity
async function initializeBackend(identity = null) {
    const agent = await HttpAgent.create({
        host: url,
        identity,
    });

    if (!isProd) {
        await agent.fetchRootKey();
    }

    backendActor = createActor(canisterId, {
        agent,
    });
}

// Initialize on module load with anonymous identity
await initializeBackend();

// Export the backend actor via a getter to ensure we always get the current instance
export const backend = new Proxy({}, {
    get(target, prop) {
        return backendActor[prop];
    }
});

// Function to update the backend actor when identity changes
export function updateBackendActor(identity) {
    return initializeBackend(identity);
}
