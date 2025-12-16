<script>
    import "../index.scss";
    import { backend } from "$lib/canisters";
    import { onMount } from "svelte";
    import { authStore } from "$lib/stores/auth";
    import { initAuth, login, logout } from "$lib/auth";
    import { Principal } from "@icp-sdk/core/principal";

    // State management
    let proposals = [];
    let loading = false;
    let error = null;
    let successMessage = null;
    let activeTab = "proposals"; // "proposals" or "create"

    // Proposal creation form state
    let proposalType = "postToBluesky";
    let postMessage = "";
    let pdsCanisterId = "";
    let installMode = "install"; // "install", "reinstall", or "upgrade"
    let installTarget = "existingCanister"; // "existingCanister" or "newCanister"
    let wasmHash = "";
    let initArgs = "";
    let initArgsFormat = "candidText"; // "candidText" or "raw"
    // Upgrade-specific options
    let wasmMemoryPersistence = "keep"; // "keep" or "replace"
    let skipPreUpgrade = false;
    // NewCanisterSettings
    let initialCycleBalance = "1.0"; // In trillion cycles
    let freezingThreshold = "";
    let wasmMemoryThreshold = "";
    let controllers = "";
    let reservedCyclesLimit = "";
    let logVisibility = "";
    let wasmMemoryLimit = "";
    let memoryAllocation = "";
    let computeAllocation = "";

    // Pagination
    let currentPage = 0;
    const itemsPerPage = 10;
    let totalProposals = 0;

    // Authentication state from store
    $: isAuthenticated = $authStore.isAuthenticated;
    $: principal = $authStore.principal;
    $: authLoading = $authStore.isLoading;

    // Member state
    let isMember = false;
    let memberCheckLoading = false;
    let votingPower = 0;

    // PDS Canister state
    let configuredPdsCanisterId = null;
    let isLocal = false;
    let pdsPollingInterval = null;

    // Detect environment after mount
    onMount(async () => {
        isLocal =
            typeof window !== "undefined" &&
            (window.location.hostname === "localhost" ||
                window.location.hostname === "127.0.0.1");
        try {
            // Initialize authentication
            await initAuth();
            await loadProposals();
            await loadPdsCanisterId();

            // Start polling for PDS canister ID if not found
            if (!configuredPdsCanisterId) {
                pdsPollingInterval = setInterval(async () => {
                    await loadPdsCanisterId();
                }, 30000); // Poll every 30 seconds
            }
        } catch (e) {
            console.error("Error during onMount:", e);
        }

        // Cleanup interval on component destroy
        return () => {
            if (pdsPollingInterval) {
                clearInterval(pdsPollingInterval);
            }
        };
    });

    // Check membership when authenticated
    $: if (isAuthenticated && principal) {
        checkMembership();
    } else {
        isMember = false;
        votingPower = 0;
    }

    async function checkMembership() {
        if (!principal) return;

        memberCheckLoading = true;
        try {
            const result = await backend.getMember(
                Principal.fromText(principal)
            );
            if (result != null) {
                isMember = true;
                votingPower = Number(result.votingPower);
            } else {
                isMember = false;
                votingPower = 0;
            }
        } catch (e) {
            console.error("Error checking membership:", e);
            isMember = false;
            votingPower = 0;
        } finally {
            memberCheckLoading = false;
        }
    }

    async function loadPdsCanisterId() {
        try {
            const canisterId = await backend.getPdsCanisterId();
            if (canisterId) {
                configuredPdsCanisterId = canisterId.toText();
                // Stop polling once we have a canister ID
                if (pdsPollingInterval) {
                    clearInterval(pdsPollingInterval);
                    pdsPollingInterval = null;
                }
            } else {
                configuredPdsCanisterId = null;
            }
        } catch (e) {
            console.error("Error loading PDS canister ID:", e);
            configuredPdsCanisterId = null;
        }
    }

    function getPdsCanisterUrl(canisterId) {
        if (isLocal) {
            return `http://${canisterId}.raw.localhost:4943`;
        } else {
            return `https://${canisterId}.raw.icp0.io`;
        }
    }

    async function handleLogin() {
        try {
            await login();
            // Reload proposals after login to refresh with authenticated identity
            await loadProposals();
        } catch (e) {
            error = `Login failed: ${e.message || e}`;
            console.error("Login error:", e);
        }
    }

    async function handleLogout() {
        try {
            await logout();
            // Reload proposals after logout
            await loadProposals();
        } catch (e) {
            error = `Logout failed: ${e.message || e}`;
            console.error("Logout error:", e);
        }
    }

    async function loadProposals() {
        loading = true;
        error = null;
        try {
            const result = await backend.getProposals(
                itemsPerPage,
                currentPage * itemsPerPage
            );
            proposals = result.data;
            totalProposals = Number(result.totalCount);
        } catch (e) {
            error = `Failed to load proposals: ${e.message || e}`;
            console.error("Error loading proposals:", e);
        } finally {
            loading = false;
        }
    }

    async function createProposal() {
        error = null;
        successMessage = null;

        try {
            let proposalContent;

            if (proposalType === "postToBluesky") {
                if (!postMessage.trim()) {
                    error = "Post message cannot be empty";
                    return;
                }
                proposalContent = {
                    postToBluesky: {
                        message: postMessage,
                    },
                };
            } else if (proposalType === "setPdsCanister") {
                if (!pdsCanisterId.trim()) {
                    error = "PDS Canister ID cannot be empty";
                    return;
                }
                proposalContent = {
                    setPdsCanister: {
                        canisterId: Principal.fromText(pdsCanisterId),
                    },
                };
            } else if (proposalType === "installPds") {
                if (!wasmHash.trim() || !initArgs.trim()) {
                    error =
                        "WASM Hash and Init Args are required for install operation";
                    return;
                }

                // Convert hex string to Uint8Array for wasmHash
                let wasmHashBytes;
                try {
                    wasmHashBytes = new Uint8Array(
                        wasmHash
                            .match(/.{1,2}/g)
                            .map((byte) => parseInt(byte, 16))
                    );
                } catch (e) {
                    error =
                        "Invalid WASM Hash format. Please provide a hex string.";
                    return;
                }

                // Create initArgs variant based on format
                let initArgsValue;
                if (initArgsFormat === "candidText") {
                    initArgsValue = {
                        candidText: initArgs,
                    };
                } else {
                    let initArgsBytes;
                    try {
                        initArgsBytes = new Uint8Array(
                            initArgs
                                .match(/.{1,2}/g)
                                .map((byte) => parseInt(byte, 16))
                        );
                    } catch (e) {
                        error = "Invalid hex format for Init Args.";
                        return;
                    }
                    initArgsValue = {
                        raw: initArgsBytes,
                    };
                }

                // Build the kind variant based on install mode
                let kindVariant;
                if (installMode === "install") {
                    let installKind;
                    if (installTarget === "newCanister") {
                        // Parse log visibility
                        let logVisibilityValue = [];
                        if (logVisibility.trim() === "controllers") {
                            logVisibilityValue = [{ controllers: null }];
                        } else if (logVisibility.trim() === "public") {
                            logVisibilityValue = [{ public_: null }];
                        } else if (
                            logVisibility.trim().startsWith("allowedViewers:")
                        ) {
                            const viewers = logVisibility
                                .substring(15)
                                .split(",")
                                .map((p) => p.trim())
                                .filter((p) => p)
                                .map((p) => Principal.fromText(p));
                            if (viewers.length > 0) {
                                logVisibilityValue = [
                                    { allowedViewers: viewers },
                                ];
                            }
                        }

                        // Parse controllers
                        let controllersValue = [];
                        if (controllers.trim()) {
                            const controllersList = controllers
                                .split(",")
                                .map((p) => p.trim())
                                .filter((p) => p)
                                .map((p) => Principal.fromText(p));
                            if (controllersList.length > 0) {
                                controllersValue = [controllersList];
                            }
                        }

                        installKind = {
                            newCanister: {
                                initialCycleBalance: BigInt(
                                    Math.floor(
                                        parseFloat(
                                            initialCycleBalance || "1.0"
                                        ) * 1_000_000_000_000
                                    )
                                ),
                                settings: {
                                    freezingThreshold: freezingThreshold.trim()
                                        ? [BigInt(freezingThreshold)]
                                        : [],
                                    wasmMemoryThreshold:
                                        wasmMemoryThreshold.trim()
                                            ? [BigInt(wasmMemoryThreshold)]
                                            : [],
                                    controllers: controllersValue,
                                    reservedCyclesLimit:
                                        reservedCyclesLimit.trim()
                                            ? [BigInt(reservedCyclesLimit)]
                                            : [],
                                    logVisibility: logVisibilityValue,
                                    wasmMemoryLimit: wasmMemoryLimit.trim()
                                        ? [BigInt(wasmMemoryLimit)]
                                        : [],
                                    memoryAllocation: memoryAllocation.trim()
                                        ? [BigInt(memoryAllocation)]
                                        : [],
                                    computeAllocation: computeAllocation.trim()
                                        ? [BigInt(computeAllocation)]
                                        : [],
                                },
                            },
                        };
                    } else {
                        if (!pdsCanisterId.trim()) {
                            error =
                                "PDS Canister ID required for existing canister install";
                            return;
                        }
                        installKind = {
                            existingCanister: Principal.fromText(pdsCanisterId),
                        };
                    }
                    kindVariant = {
                        install: {
                            kind: installKind,
                        },
                    };
                } else if (installMode === "reinstall") {
                    if (!pdsCanisterId.trim()) {
                        error = "PDS Canister ID required for reinstall";
                        return;
                    }
                    kindVariant = {
                        reinstall: {
                            canisterId: Principal.fromText(pdsCanisterId),
                        },
                    };
                } else if (installMode === "upgrade") {
                    if (!pdsCanisterId.trim()) {
                        error = "PDS Canister ID required for upgrade";
                        return;
                    }
                    kindVariant = {
                        upgrade: {
                            canisterId: Principal.fromText(pdsCanisterId),
                            wasmMemoryPersistence: {
                                [wasmMemoryPersistence]: null,
                            },
                            skipPreUpgrade: skipPreUpgrade,
                        },
                    };
                }

                proposalContent = {
                    installPds: {
                        kind: kindVariant,
                        wasmHash: wasmHashBytes,
                        initArgs: initArgsValue,
                    },
                };
                console.log(
                    "Proposal content:",
                    JSON.stringify(
                        proposalContent,
                        (key, value) =>
                            typeof value === "bigint"
                                ? value.toString()
                                : value,
                        2
                    )
                );
            }

            loading = true;
            const result = await backend.createProposal(proposalContent);

            if ("ok" in result) {
                successMessage = `Proposal #${result.ok} created successfully!`;
                // Reset form
                postMessage = "";
                pdsCanisterId = "";
                installMode = "install";
                installTarget = "existingCanister";
                wasmHash = "";
                initArgs = "";
                initArgsFormat = "candidText";
                wasmMemoryPersistence = "keep";
                skipPreUpgrade = false;
                initialCycleBalance = "1.0";
                freezingThreshold = "";
                wasmMemoryThreshold = "";
                controllers = "";
                reservedCyclesLimit = "";
                logVisibility = "";
                wasmMemoryLimit = "";
                memoryAllocation = "";
                computeAllocation = "";
                // Reload proposals
                await loadProposals();
                // Reload PDS canister ID in case it changed
                await loadPdsCanisterId();
                // Switch to proposals tab
                activeTab = "proposals";
            } else {
                error = result.err;
            }
        } catch (e) {
            error = `Failed to create proposal: ${e.message || e}`;
            console.error("Error creating proposal:", e);
        } finally {
            loading = false;
        }
    }

    async function vote(proposalId, voteFor) {
        error = null;
        successMessage = null;

        try {
            loading = true;
            const result = await backend.vote(proposalId, voteFor);

            if ("ok" in result) {
                successMessage = `Vote cast successfully on proposal #${proposalId}!`;
                await loadProposals();
            } else {
                error = result.err;
            }
        } catch (e) {
            error = `Failed to vote: ${e.message || e}`;
            console.error("Error voting:", e);
        } finally {
            loading = false;
        }
    }

    function formatDate(timestamp) {
        if (!timestamp) return "N/A";
        const date = new Date(Number(timestamp) / 1000000); // Convert nanoseconds to milliseconds
        return date.toLocaleString();
    }

    function getStatusClass(status) {
        if ("open" in status) return "status-open";
        if ("adopted" in status) return "status-adopted";
        if ("rejected" in status) return "status-rejected";
        if ("executing" in status) return "status-executing";
        if ("executed" in status) return "status-adopted";
        if ("failedToExecute" in status) return "status-rejected";
        return "";
    }

    function getStatusText(status) {
        if ("open" in status) return "Open";
        if ("adopted" in status) return "Adopted";
        if ("rejected" in status) return "Rejected";
        if ("executing" in status) return "Executing";
        if ("executed" in status) return "Executed";
        if ("failedToExecute" in status) return "Failed";
        return "Unknown";
    }

    function getFailureDetails(status) {
        if ("failedToExecute" in status && status.failedToExecute.error) {
            return status.failedToExecute.error;
        }
        return null;
    }

    function canVote(status) {
        return "open" in status;
    }

    function calculateVotePercentage(votes, total) {
        if (total === 0) return 0;
        return (Number(votes) / Number(total)) * 100;
    }

    function nextPage() {
        if ((currentPage + 1) * itemsPerPage < totalProposals) {
            currentPage++;
            loadProposals();
        }
    }

    function prevPage() {
        if (currentPage > 0) {
            currentPage--;
            loadProposals();
        }
    }
</script>

<main>
    <div class="terminal-container">
        <div style="margin-bottom: 20px;">
            <div
                style="margin: 0; display: flex; justify-content: space-between; align-items: center; padding-bottom: 10px;"
            >
                <div style="font-size: 1.8em; font-weight: bold;">
                    DAO Governance Terminal<span class="blink">_</span>
                </div>

                <div style="text-align: center;">
                    <div
                        style="color: #00ff00; font-size: 1.2em; margin-bottom: 5px; font-weight: bold;"
                    >
                        PDS Canister
                    </div>
                    {#if configuredPdsCanisterId}
                        <div
                            style="display: flex; align-items: center; gap: 8px; justify-content: center;"
                        >
                            <span
                                style="color: #00aaff; font-family: monospace; font-size: 1em;"
                            >
                                {configuredPdsCanisterId}
                            </span>
                            <a
                                href={getPdsCanisterUrl(
                                    configuredPdsCanisterId
                                )}
                                target="_blank"
                                rel="noopener noreferrer"
                                style="color: #00ff00; text-decoration: none; font-size: 0.9em; padding: 4px 8px; border: 1px solid #00ff00; background: rgba(0, 255, 0, 0.1); border-radius: 3px; line-height: 1; display: inline-block; cursor: pointer;"
                                title="Open PDS Canister in new tab"
                            >
                                ↗
                            </a>
                        </div>
                    {:else}
                        <div
                            style="color: #888888; font-family: monospace; font-size: 0.85em;"
                        >
                            Not Configured
                        </div>
                    {/if}
                </div>
            </div>
        </div>

        <!-- Authentication Section -->
        <div class="auth-section">
            {#if authLoading}
                <div class="auth-info">
                    <div>
                        <strong
                            >🔄 Checking Authentication<span class="blink"
                                >...</span
                            ></strong
                        >
                        <p class="auth-loading-text">Please wait</p>
                    </div>
                </div>
            {:else if isAuthenticated}
                <div class="auth-info">
                    <div>
                        <strong>🔐 Authenticated</strong>
                        <p class="principal-display">Principal: {principal}</p>
                        {#if memberCheckLoading}
                            <p class="member-status">
                                Checking membership<span class="blink">...</span
                                >
                            </p>
                        {:else if isMember}
                            <p class="member-status member-active">
                                ✓ DAO Member | Voting Power: {votingPower}
                            </p>
                        {:else}
                            <p class="member-status member-inactive">
                                ⚠ Not a DAO member
                            </p>
                        {/if}
                    </div>
                    <button class="auth-button" on:click={handleLogout}>
                        Logout
                    </button>
                </div>
            {:else}
                <div class="auth-info">
                    <p><strong>⚠ Not Authenticated</strong></p>
                    <p>Using anonymous principal. Login for full access.</p>
                    <button class="auth-button primary" on:click={handleLogin}>
                        Login with Internet Identity
                    </button>
                </div>
            {/if}
        </div>

        <!-- Messages -->
        {#if error}
            <div class="error">
                <strong>ERROR:</strong>
                {error}
            </div>
        {/if}

        {#if successMessage}
            <div class="success">
                <strong>SUCCESS:</strong>
                {successMessage}
            </div>
        {/if}

        <!-- Tabs -->
        <div class="tabs">
            <button
                class="tab"
                class:active={activeTab === "proposals"}
                on:click={() => (activeTab = "proposals")}
            >
                View Proposals
            </button>
            <button
                class="tab"
                class:active={activeTab === "create"}
                on:click={() => (activeTab = "create")}
            >
                Create Proposal
            </button>
        </div>

        <!-- Proposals Tab -->
        {#if activeTab === "proposals"}
            <div class="section">
                <h2>Active Proposals</h2>

                {#if loading && proposals.length === 0}
                    <div class="loading">
                        Loading proposals<span class="blink">...</span>
                    </div>
                {:else if proposals.length === 0}
                    <div class="empty-state">
                        <p>No proposals found. Create one to get started!</p>
                    </div>
                {:else}
                    {#each proposals as proposal (proposal.id)}
                        <div class="proposal-card">
                            <div class="proposal-header">
                                <div>
                                    <div class="proposal-title">
                                        {proposal.title}
                                    </div>
                                    <div class="proposal-id">
                                        Proposal #{proposal.id}
                                    </div>
                                </div>
                                <div
                                    class="proposal-status {getStatusClass(
                                        proposal.status
                                    )}"
                                >
                                    {getStatusText(proposal.status)}
                                </div>
                            </div>

                            <div
                                class="proposal-description"
                                style="white-space: pre-wrap;"
                            >
                                {proposal.description}
                            </div>

                            <!-- Show failure details if proposal failed -->
                            {#if getFailureDetails(proposal.status)}
                                <div class="error" style="margin-top: 10px;">
                                    <strong>Execution Error:</strong>
                                    {getFailureDetails(proposal.status)}
                                </div>
                            {/if}

                            <div class="vote-info">
                                <div class="vote-stat">
                                    <span class="vote-label">Votes For:</span>
                                    <span class="vote-value"
                                        >{proposal.votesFor}</span
                                    >
                                </div>
                                <div class="vote-stat">
                                    <span class="vote-label"
                                        >Votes Against:</span
                                    >
                                    <span class="vote-value"
                                        >{proposal.votesAgainst}</span
                                    >
                                </div>
                                <div class="vote-stat">
                                    <span class="vote-label"
                                        >Total Voting Power:</span
                                    >
                                    <span class="vote-value"
                                        >{proposal.totalVotingPower}</span
                                    >
                                </div>
                            </div>

                            <!-- Vote visualization -->
                            {#if proposal.totalVotingPower > 0}
                                <div class="vote-bar">
                                    <div
                                        class="vote-bar-fill"
                                        style="width: {calculateVotePercentage(
                                            proposal.votesFor,
                                            proposal.totalVotingPower
                                        )}%"
                                    ></div>
                                </div>
                            {/if}

                            <!-- Voting buttons -->
                            {#if isAuthenticated && isMember && canVote(proposal.status)}
                                <div class="vote-buttons">
                                    <button
                                        class="primary"
                                        on:click={() => vote(proposal.id, true)}
                                        disabled={loading}
                                    >
                                        Vote For
                                    </button>
                                    <button
                                        class="danger"
                                        on:click={() =>
                                            vote(proposal.id, false)}
                                        disabled={loading}
                                    >
                                        Vote Against
                                    </button>
                                </div>
                            {:else if !isAuthenticated && canVote(proposal.status)}
                                <div class="auth-required-message">
                                    🔒 Login required to vote on proposals
                                </div>
                            {:else if isAuthenticated && !isMember && canVote(proposal.status)}
                                <div class="auth-required-message">
                                    👥 You must be a DAO member to vote on
                                    proposals
                                </div>
                            {/if}

                            <div class="timestamp">
                                Started: {formatDate(proposal.timeStart)}
                                {#if proposal.timeEnd}
                                    | Ended: {formatDate(proposal.timeEnd)}
                                {/if}
                            </div>
                        </div>
                    {/each}

                    <!-- Pagination -->
                    <div class="vote-buttons">
                        <button
                            on:click={prevPage}
                            disabled={currentPage === 0 || loading}
                        >
                            ← Previous
                        </button>
                        <span style="color: #00ff00; padding: 10px;">
                            Page {currentPage + 1} of {Math.ceil(
                                totalProposals / itemsPerPage
                            ) || 1}
                        </span>
                        <button
                            on:click={nextPage}
                            disabled={(currentPage + 1) * itemsPerPage >=
                                totalProposals || loading}
                        >
                            Next →
                        </button>
                    </div>
                {/if}
            </div>
        {/if}

        <!-- Create Proposal Tab -->
        {#if activeTab === "create"}
            <div class="section">
                <h2>Create New Proposal</h2>

                {#if !isAuthenticated}
                    <div
                        class="auth-required-message"
                        style="margin-bottom: 20px;"
                    >
                        🔒 You must be logged in to create proposals. Please
                        login with Internet Identity to continue.
                    </div>
                {:else if !isMember}
                    <div
                        class="auth-required-message"
                        style="margin-bottom: 20px;"
                    >
                        👥 You must be a DAO member to create proposals. Only
                        DAO members have governance rights.
                    </div>
                {/if}

                <form
                    on:submit|preventDefault={createProposal}
                    class:disabled={!isAuthenticated || !isMember}
                >
                    <div class="form-group">
                        <label for="proposalType">Proposal Type:</label>
                        <select
                            id="proposalType"
                            bind:value={proposalType}
                            disabled={!isAuthenticated || !isMember}
                        >
                            <option value="postToBluesky"
                                >Post to Bluesky</option
                            >
                            <option value="setPdsCanister"
                                >Set PDS Canister</option
                            >
                            <option value="installPds">Install PDS</option>
                        </select>
                    </div>

                    {#if proposalType === "postToBluesky"}
                        <div class="form-group">
                            <label for="postMessage">Post Message:</label>
                            <textarea
                                id="postMessage"
                                bind:value={postMessage}
                                placeholder="Enter the message to post to Bluesky (max 300 characters)"
                                maxlength="300"
                                disabled={!isAuthenticated || !isMember}
                            ></textarea>
                            <small style="color: #00aa00;"
                                >{postMessage.length}/300 characters</small
                            >
                        </div>
                    {/if}

                    {#if proposalType === "setPdsCanister"}
                        <div class="form-group">
                            <label for="pdsCanisterId">PDS Canister ID:</label>
                            <input
                                type="text"
                                id="pdsCanisterId"
                                bind:value={pdsCanisterId}
                                placeholder="e.g., rrkah-fqaaa-aaaaa-aaaaq-cai"
                                disabled={!isAuthenticated || !isMember}
                            />
                            <small style="color: #00aa00;"
                                >Set the PDS canister to an existing canister
                                without modifying it</small
                            >
                        </div>
                    {/if}

                    {#if proposalType === "installPds"}
                        <div class="form-group">
                            <label for="installMode">Install Mode:</label>
                            <select
                                id="installMode"
                                bind:value={installMode}
                                disabled={!isAuthenticated || !isMember}
                            >
                                <option value="install"
                                    >Install (fresh installation)</option
                                >
                                <option value="reinstall"
                                    >Reinstall (wipe and reinstall)</option
                                >
                                <option value="upgrade"
                                    >Upgrade (preserve state)</option
                                >
                            </select>
                        </div>

                        <div class="form-group">
                            <label for="wasmHash">WASM Hash (hex):</label>
                            <input
                                type="text"
                                id="wasmHash"
                                bind:value={wasmHash}
                                placeholder="e.g., 1a2b3c4d5e6f..."
                                disabled={!isAuthenticated || !isMember}
                            />
                            <small style="color: #00aa00;"
                                >Enter the WASM module hash as a hex string</small
                            >
                        </div>

                        <div class="form-group">
                            <label for="initArgsFormat">Init Args Format:</label
                            >
                            <select
                                id="initArgsFormat"
                                bind:value={initArgsFormat}
                                disabled={!isAuthenticated || !isMember}
                            >
                                <option value="candidText">Candid Text</option>
                                <option value="raw">Raw (Hex-encoded)</option>
                            </select>
                            <small style="color: #00aa00;">
                                {#if initArgsFormat === "candidText"}
                                    Enter as Candid text - will be sent as-is to
                                    backend
                                {:else}
                                    Enter as hex bytes - will be converted to
                                    binary
                                {/if}
                            </small>
                        </div>

                        <div class="form-group">
                            <label for="initArgs">
                                {#if initArgsFormat === "candidText"}
                                    Init Args (Candid Text):
                                {:else}
                                    Init Args (Hex):
                                {/if}
                            </label>
                            <textarea
                                id="initArgs"
                                bind:value={initArgs}
                                placeholder={initArgsFormat === "candidText"
                                    ? 'e.g., (record { hostname = "mydao.bsky.social"; serviceSubdomain = opt "service"; plcIdentifier = "did:plc:..."; })'
                                    : "e.g., 4449444c..."}
                                disabled={!isAuthenticated || !isMember}
                            ></textarea>
                            <small style="color: #00aa00;">
                                {#if initArgsFormat === "candidText"}
                                    Enter initialization arguments as Candid
                                    text
                                {:else}
                                    Enter initialization arguments as hex string
                                {/if}
                            </small>
                        </div>

                        {#if installMode === "install"}
                            <div class="form-group">
                                <label for="installTarget"
                                    >Install Target:</label
                                >
                                <select
                                    id="installTarget"
                                    bind:value={installTarget}
                                    disabled={!isAuthenticated || !isMember}
                                >
                                    <option value="existingCanister"
                                        >Existing Canister</option
                                    >
                                    <option value="newCanister"
                                        >New Canister</option
                                    >
                                </select>
                            </div>

                            {#if installTarget === "newCanister"}
                                <div class="form-group">
                                    <label for="initialCycleBalance"
                                        >Initial Cycle Balance (Trillion
                                        Cycles):</label
                                    >
                                    <input
                                        type="number"
                                        id="initialCycleBalance"
                                        bind:value={initialCycleBalance}
                                        placeholder="1.0"
                                        step="0.1"
                                        min="0.5"
                                        disabled={!isAuthenticated || !isMember}
                                    />
                                    <small style="color: #00aa00;"
                                        >Cycles to allocate to the new canister
                                        (deducted from DAO). Default: 1.0
                                        trillion</small
                                    >
                                </div>

                                <div class="form-group">
                                    <label for="freezingThreshold"
                                        >Freezing Threshold (optional):</label
                                    >
                                    <input
                                        type="number"
                                        id="freezingThreshold"
                                        bind:value={freezingThreshold}
                                        placeholder="Leave empty for default"
                                        disabled={!isAuthenticated || !isMember}
                                    />
                                    <small style="color: #00aa00;"
                                        >Cycles threshold before freezing</small
                                    >
                                </div>

                                <div class="form-group">
                                    <label for="controllers"
                                        >Controllers (optional):</label
                                    >
                                    <input
                                        type="text"
                                        id="controllers"
                                        bind:value={controllers}
                                        placeholder="e.g., aaaaa-aa, bbbbb-bb (comma-separated)"
                                        disabled={!isAuthenticated || !isMember}
                                    />
                                    <small style="color: #00aa00;"
                                        >Comma-separated principal IDs</small
                                    >
                                </div>

                                <div class="form-group">
                                    <label for="memoryAllocation"
                                        >Memory Allocation (optional):</label
                                    >
                                    <input
                                        type="number"
                                        id="memoryAllocation"
                                        bind:value={memoryAllocation}
                                        placeholder="Leave empty for default"
                                        disabled={!isAuthenticated || !isMember}
                                    />
                                    <small style="color: #00aa00;"
                                        >Memory allocation in bytes</small
                                    >
                                </div>

                                <div class="form-group">
                                    <label for="computeAllocation"
                                        >Compute Allocation (optional):</label
                                    >
                                    <input
                                        type="number"
                                        id="computeAllocation"
                                        bind:value={computeAllocation}
                                        placeholder="0-100"
                                        disabled={!isAuthenticated || !isMember}
                                    />
                                    <small style="color: #00aa00;"
                                        >Percentage (0-100)</small
                                    >
                                </div>

                                <div class="form-group">
                                    <label for="wasmMemoryLimit"
                                        >WASM Memory Limit (optional):</label
                                    >
                                    <input
                                        type="number"
                                        id="wasmMemoryLimit"
                                        bind:value={wasmMemoryLimit}
                                        placeholder="Leave empty for default"
                                        disabled={!isAuthenticated || !isMember}
                                    />
                                    <small style="color: #00aa00;"
                                        >WASM memory limit in bytes</small
                                    >
                                </div>

                                <div class="form-group">
                                    <label for="wasmMemoryThreshold"
                                        >WASM Memory Threshold (optional):</label
                                    >
                                    <input
                                        type="number"
                                        id="wasmMemoryThreshold"
                                        bind:value={wasmMemoryThreshold}
                                        placeholder="Leave empty for default"
                                        disabled={!isAuthenticated || !isMember}
                                    />
                                    <small style="color: #00aa00;"
                                        >WASM memory threshold in bytes</small
                                    >
                                </div>

                                <div class="form-group">
                                    <label for="reservedCyclesLimit"
                                        >Reserved Cycles Limit (optional):</label
                                    >
                                    <input
                                        type="number"
                                        id="reservedCyclesLimit"
                                        bind:value={reservedCyclesLimit}
                                        placeholder="Leave empty for default"
                                        disabled={!isAuthenticated || !isMember}
                                    />
                                    <small style="color: #00aa00;"
                                        >Reserved cycles limit</small
                                    >
                                </div>

                                <div class="form-group">
                                    <label for="logVisibility"
                                        >Log Visibility (optional):</label
                                    >
                                    <input
                                        type="text"
                                        id="logVisibility"
                                        bind:value={logVisibility}
                                        placeholder="controllers | public | allowedViewers:principal1,principal2"
                                        disabled={!isAuthenticated || !isMember}
                                    />
                                    <small style="color: #00aa00;"
                                        >Leave empty for default, or specify:
                                        controllers, public, or
                                        allowedViewers:principal1,principal2</small
                                    >
                                </div>
                            {:else}
                                <div class="form-group">
                                    <label for="pdsCanisterId"
                                        >PDS Canister ID:</label
                                    >
                                    <input
                                        type="text"
                                        id="pdsCanisterId"
                                        bind:value={pdsCanisterId}
                                        placeholder="e.g., rrkah-fqaaa-aaaaa-aaaaq-cai"
                                        disabled={!isAuthenticated || !isMember}
                                    />
                                </div>
                            {/if}
                        {:else if installMode !== "install"}
                            <div class="form-group">
                                <label for="pdsCanisterId"
                                    >PDS Canister ID:</label
                                >
                                <input
                                    type="text"
                                    id="pdsCanisterId"
                                    bind:value={pdsCanisterId}
                                    placeholder="e.g., rrkah-fqaaa-aaaaa-aaaaq-cai"
                                    disabled={!isAuthenticated || !isMember}
                                />
                            </div>
                        {/if}

                        {#if installMode === "upgrade"}
                            <div class="form-group">
                                <label for="wasmMemoryPersistence"
                                    >WASM Memory Persistence:</label
                                >
                                <select
                                    id="wasmMemoryPersistence"
                                    bind:value={wasmMemoryPersistence}
                                    disabled={!isAuthenticated || !isMember}
                                >
                                    <option value="keep">Keep</option>
                                    <option value="replace">Replace</option>
                                </select>
                            </div>

                            <div class="form-group">
                                <label>
                                    <input
                                        type="checkbox"
                                        bind:checked={skipPreUpgrade}
                                        disabled={!isAuthenticated || !isMember}
                                    />
                                    Skip Pre-Upgrade
                                </label>
                                <small style="color: #00aa00;"
                                    >Skip the pre_upgrade hook during upgrade</small
                                >
                            </div>
                        {/if}
                    {/if}

                    <button
                        type="submit"
                        class="primary"
                        disabled={loading || !isAuthenticated || !isMember}
                    >
                        {loading ? "Creating..." : "Create Proposal"}
                    </button>
                </form>
            </div>
        {/if}
    </div>
</main>
