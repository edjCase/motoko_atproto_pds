import { AuthClient } from '@icp-sdk/auth/client';
import { authStore } from './stores/auth';
import { updateBackendActor } from './canisters';

const isProd = process.env.DFX_NETWORK === 'ic';

const identityProvider = isProd
    ? 'https://identity.ic0.app'
    : `http://${process.env.CANISTER_ID_INTERNET_IDENTITY}.localhost:4943`;

let authClient = null;

export async function initAuth() {
    authStore.setLoading(true);
    authClient = await AuthClient.create();
    authStore.setAuthClient(authClient);

    const isAuthenticated = await authClient.isAuthenticated();

    if (isAuthenticated) {
        const identity = authClient.getIdentity();
        const principal = identity.getPrincipal().toString();
        authStore.setAuthenticated(true, principal);
        // Update backend actor with authenticated identity
        updateBackendActor(identity);
    } else {
        authStore.setLoading(false);
    }
} export async function login() {
    if (!authClient) {
        await initAuth();
    }

    return new Promise((resolve, reject) => {
        authClient.login({
            identityProvider,
            onSuccess: async () => {
                const identity = authClient.getIdentity();
                const principal = identity.getPrincipal().toString();
                authStore.setAuthenticated(true, principal);
                // Update backend actor with authenticated identity
                updateBackendActor(identity);
                resolve();
            },
            onError: (error) => {
                console.error('Login failed:', error);
                reject(error);
            },
        });
    });
}

export async function logout() {
    if (!authClient) {
        return;
    }

    await authClient.logout();
    authStore.setAuthenticated(false, null);
    // Reset backend actor to anonymous identity
    updateBackendActor(null);
}
