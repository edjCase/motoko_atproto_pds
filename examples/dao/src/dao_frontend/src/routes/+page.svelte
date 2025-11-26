<script>
    import "../index.scss";
    import { backend } from "$lib/canisters";
    import { onMount } from "svelte";

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
    let pdsOperation = "set"; // "set", "initialize", or "installAndInitialize"
    let hostname = "";
    let serviceSubdomain = "";
    let plcIdentifier = "";

    // Pagination
    let currentPage = 0;
    const itemsPerPage = 10;
    let totalProposals = 0;

    // Authentication placeholder - will be replaced with real auth
    let currentUser = null; // Will be Principal when auth is implemented
    let isAuthenticated = false;

    onMount(async () => {
        try {
            await loadProposals();
        } catch (e) {
            console.error("Error during onMount:", e);
        }
        // TODO: Initialize authentication here
    });

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

                let kind;
                if (pdsOperation === "set") {
                    kind = { set: null };
                } else if (pdsOperation === "initialize") {
                    if (!hostname.trim() || !plcIdentifier.trim()) {
                        error =
                            "Hostname and PLC Identifier are required for initialize operation";
                        return;
                    }
                    kind = {
                        initialize: {
                            hostname,
                            serviceSubdomain: serviceSubdomain
                                ? [serviceSubdomain]
                                : [],
                            plcIdentifier,
                        },
                    };
                } else {
                    error =
                        "Install and initialize operation not yet supported in UI";
                    return;
                }

                proposalContent = {
                    setPdsCanister: {
                        id: pdsCanisterId,
                        kind,
                    },
                };
            }

            loading = true;
            const result = await backend.createProposal(proposalContent);

            if ("ok" in result) {
                successMessage = `Proposal #${result.ok} created successfully!`;
                // Reset form
                postMessage = "";
                pdsCanisterId = "";
                hostname = "";
                serviceSubdomain = "";
                plcIdentifier = "";
                // Reload proposals
                await loadProposals();
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
        <h1>DAO Governance Terminal<span class="blink">_</span></h1>

        <!-- Authentication Placeholder -->
        <div class="auth-placeholder">
            <p><strong>⚠ Authentication Coming Soon</strong></p>
            <p>
                Login functionality will be integrated here. For now, using
                anonymous principal for testing.
            </p>
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

                            <div class="proposal-description">
                                {proposal.description}
                            </div>

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
                            {#if canVote(proposal.status)}
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

                <form on:submit|preventDefault={createProposal}>
                    <div class="form-group">
                        <label for="proposalType">Proposal Type:</label>
                        <select id="proposalType" bind:value={proposalType}>
                            <option value="postToBluesky"
                                >Post to Bluesky</option
                            >
                            <option value="setPdsCanister"
                                >Set PDS Canister</option
                            >
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
                            />
                        </div>

                        <div class="form-group">
                            <label for="pdsOperation">Operation:</label>
                            <select id="pdsOperation" bind:value={pdsOperation}>
                                <option value="set"
                                    >Set (just reference existing canister)</option
                                >
                                <option value="initialize"
                                    >Initialize (set and initialize canister)</option
                                >
                            </select>
                        </div>

                        {#if pdsOperation === "initialize"}
                            <div class="form-group">
                                <label for="hostname">Hostname:</label>
                                <input
                                    type="text"
                                    id="hostname"
                                    bind:value={hostname}
                                    placeholder="e.g., mydao.bsky.social"
                                />
                            </div>

                            <div class="form-group">
                                <label for="serviceSubdomain"
                                    >Service Subdomain (optional):</label
                                >
                                <input
                                    type="text"
                                    id="serviceSubdomain"
                                    bind:value={serviceSubdomain}
                                    placeholder="e.g., service"
                                />
                            </div>

                            <div class="form-group">
                                <label for="plcIdentifier"
                                    >PLC Identifier:</label
                                >
                                <input
                                    type="text"
                                    id="plcIdentifier"
                                    bind:value={plcIdentifier}
                                    placeholder="e.g., did:plc:..."
                                />
                            </div>
                        {/if}
                    {/if}

                    <button type="submit" class="primary" disabled={loading}>
                        {loading ? "Creating..." : "Create Proposal"}
                    </button>
                </form>
            </div>
        {/if}
    </div>
</main>
