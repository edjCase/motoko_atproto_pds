import { createActor } from '../bindings/dao_backend';
import { HttpAgent } from "@icp-sdk/core/agent";

export const canisterId = process.env.CANISTER_ID_DAO_BACKEND;

let isProd = process.env.DFX_NETWORK === "ic";

const url = isProd ? "https://icp-api.io" : "http://localhost:4943";
// Created once globally at app initialization
const agent = await HttpAgent.create({
    host: url
});
if (!isProd) {
    await agent.fetchRootKey();
}


// Created once globally and exported for use throughout the app
export const backend = createActor(canisterId, {
    agent,
});
