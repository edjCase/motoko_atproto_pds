import { writable } from 'svelte/store';

function createAuthStore() {
    const { subscribe, set, update } = writable({
        isAuthenticated: false,
        principal: null,
        authClient: null,
        isLoading: true,
    });

    return {
        subscribe,
        setAuthClient: (authClient) => update(state => ({ ...state, authClient })),
        setAuthenticated: (isAuthenticated, principal = null) =>
            update(state => ({ ...state, isAuthenticated, principal, isLoading: false })),
        setLoading: (isLoading) => update(state => ({ ...state, isLoading })),
        reset: () => set({ isAuthenticated: false, principal: null, authClient: null, isLoading: false }),
    };
}

export const authStore = createAuthStore();
