import { createActor } from '../bindings/dao_backend';
import { HttpAgent } from "@icp-sdk/core/agent";
import { Principal } from "@icp-sdk/core/principal";
import { createActor } from "./api/hello-world";


export const canisterId =
    process.env.CANISTER_ID_DAO_BACKEND;

const url = process.env.DFX_NETWORK === "ic" ? "https://icp-api.io" : "http://localhost:4943";

const agent = await HttpAgent.create({
    host: url
});

const actor = createActor(canisterId, {
    agent,
});

const response = await actor.greet('world');

console.log(response);
