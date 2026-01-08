import ProposalEngine "mo:dao-proposal-engine@2/ProposalEngine";
import Principal "mo:core@1/Principal";
import Result "mo:core@1/Result";
import Text "mo:core@1/Text";
import Array "mo:core@1/Array";
import DaoInterface "./DaoInterface";
import PostToBlueskyProposal "./Proposals/PostToBlueskyProposal";
import SetPdsCanisterProposal "./Proposals/SetPdsCanisterProposal";
import InstallPdsProposal "./Proposals/InstallPdsProposal";
import SetDelegatePermissionsProposal "./Proposals/SetDelegatePermissionsProposal";
import CustomCallProposal "./Proposals/CustomCallProposal";
import BTree "mo:stableheapbtreemap@1/BTree";
import PureMap "mo:core@1/pure/Map";
import Iter "mo:core@1/Iter";
import TimerTool "mo:timer-tool@0";
import Orchestrator "Orchestrator";
import Logger "Logger";
import WasmStore "WasmStore";
import Nat "mo:core@1/Nat";
import Debug "mo:core@1/Debug";
import PdsInterface "../../../../src/PdsInterface";
import Runtime "mo:core@1/Runtime";

shared ({ caller = deployer }) persistent actor class Dao() : async DaoInterface.Actor = this {

  transient let daoPrincipal = Principal.fromActor(this);

  var orchestratorStableData : ?Orchestrator.StableData = null;
  var loggerStableData : ?Logger.StableData = null;
  var wasmStoreStableData : ?WasmStore.LocalStableData = null;
  var timerState : ?TimerTool.State = null;

  // Stable storage for upgrades
  var stableProposalData : ProposalEngine.StableData<DaoInterface.ProposalKind> = {
    proposals = BTree.init<Nat, ProposalEngine.ProposalData<DaoInterface.ProposalKind>>(null);
    proposalDuration = ?#days(7); // 7 day voting period
    votingThreshold = #percent({ percent = 50; quorum = ?25 }); // 50% threshold with 25% quorum
    allowVoteChange = true; // Allow members to change their votes
  };

  // DAO configuration
  var membersMap = PureMap.singleton<Principal, DaoInterface.MemberData>(
    deployer,
    { votingPower = 1 },
  );
  var pdsCanisterIdOrNull : ?Principal = null; // Will be set by DAO

  transient let timerTool = TimerTool.TimerTool(
    null,
    deployer,
    daoPrincipal,
    null,
    ?{
      advanced = null;
      syncUnsafe = null;
      reportExecution = null;
      reportError = ?(
        func(err : { action : TimerTool.ActionDetail; awaited : Bool; error : TimerTool.Error }) : ?Nat {
          Debug.print("TimerTool error: " # debug_show (err));
          null;
        }
      );
      reportBatch = null;
    },
    func(newState : TimerTool.State) {
      timerState := ?newState;
    },
  );

  transient let wasmStore = WasmStore.LocalWasmStore<system>(wasmStoreStableData);

  transient let logger = Logger.Logger<system>(
    deployer,
    daoPrincipal,
    timerTool,
    loggerStableData,
  );

  transient let orchestrator = Orchestrator.Orchestrator<system>(
    deployer,
    daoPrincipal,
    timerTool,
    logger,
    wasmStore,
    orchestratorStableData,
  );
  // System functions for upgrades
  system func preupgrade() {
    orchestratorStableData := ?orchestrator.toStableData();
    loggerStableData := ?logger.toStableData();
    wasmStoreStableData := ?wasmStore.toStableData();
  };

  // Helper function to update PDS canister ID
  func updatePdsCanisterId(newCanisterId : Principal) : () {
    pdsCanisterIdOrNull := ?newCanisterId;
  };

  // Proposal execution handlers
  func onProposalAdopt(
    proposal : ProposalEngine.Proposal<DaoInterface.ProposalKind>
  ) : async* Result.Result<(), Text> {
    switch (proposal.content) {
      case (#postToBluesky(postProposal)) {
        switch (pdsCanisterIdOrNull) {
          case (null) return #err("PDS canister ID is not set. Cannot post to AT Protocol.");
          case (?canisterId) await* PostToBlueskyProposal.onAdopt(canisterId, postProposal.message);
        };
      };
      case (#setPdsCanister(setPdsProposal)) {
        await* SetPdsCanisterProposal.onAdopt(setPdsProposal, updatePdsCanisterId);
      };
      case (#installPds(installPdsProposal)) {
        await* InstallPdsProposal.onAdopt(
          daoPrincipal,
          installPdsProposal,
          orchestrator.factory,
          updatePdsCanisterId,
        );
      };
      case (#setDelegatePermissions(setDelegateProposal)) { 
        switch (pdsCanisterIdOrNull) {
          case (null) return #err("PDS canister ID is not set. Cannot post to AT Protocol.");
          case (?canisterId) await* SetDelegatePermissionsProposal.onAdopt(
          canisterId,
          setDelegateProposal,
          );
        };
      };
      case (#customCall(customCallProposal)) {
        switch(await* CustomCallProposal.onAdopt(customCallProposal)){
          case (#ok(reply)) {
            // TODO how to handle reply?
            Debug.print("Custom call proposal executed successfully. Reply: " # debug_show (reply));
            #ok;
          };
          case (#err(errorMsg)) return #err(errorMsg);
        }
      };
    };
  };

  func onProposalReject(_ : ProposalEngine.Proposal<DaoInterface.ProposalKind>) : async* () {
    // No specific actions on rejection
  };

  func onProposalValidate(content : DaoInterface.ProposalKind) : async* Result.Result<(), [Text]> {
    switch (content) {
      case (#postToBluesky(postProposal)) {
        PostToBlueskyProposal.validate(postProposal);
      };
      case (#setPdsCanister(setPdsProposal)) {
        SetPdsCanisterProposal.validate(setPdsProposal);
      };
      case (#installPds(installPdsProposal)) {
        InstallPdsProposal.validate(installPdsProposal);
      };
      case (#setDelegatePermissions(setDelegateProposal)) {
        SetDelegatePermissionsProposal.validate(setDelegateProposal);
      };
      case (#customCall(customCallProposal)) {
        CustomCallProposal.validate(customCallProposal);
      };
    };
  };

  // Initialize the proposal engine
  transient let proposalEngine = ProposalEngine.ProposalEngine<system, DaoInterface.ProposalKind>(
    stableProposalData,
    onProposalAdopt,
    onProposalReject,
    onProposalValidate,
  );

  // Public methods

  public query func getPdsCanisterId() : async ?Principal {
    pdsCanisterIdOrNull;
  };

  public func addWasmChunk(request : DaoInterface.AddWasmChunkRequest) : async Result.Result<(), Text> {
    // TODO auth
    switch (wasmStore.addChunk(request.wasmHash, request.index, request.chunk)) {
      case (#ok) #ok;
      case (#err(#wasmAlreadyExists)) #err("WASM already finalized, cannot add more chunks");
    };
  };

  public func finalizeWasmChunks(wasmHash : Blob) : async Result.Result<(), Text> {
    // TODO auth
    switch (wasmStore.finalizeChunks(wasmHash)) {
      case (#ok) #ok;
      case (#err(#wasmNotFound)) #err("WASM not found");
      case (#err(#chunksMissing(missingIndices))) {
        let indicesText = missingIndices.vals() |> Iter.map<Nat, Text>(_, func(index) = Nat.toText(index));
        #err("Missing chunks at indices: " # Text.join(", ", indicesText));
      };
      case (#err(#hashMismatch)) #err("WASM hash mismatch");
    };
  };

  public func getWasmHashes() : async [Text] {
    // TODO auth
    let hashes = await* wasmStore.getHashes();
    Array.map(hashes, func(hash) = debug_show (hash));
  };

  public query (_msg) func icrc120_get_events(
    input : DaoInterface.ICRC120GetEventsFilter
  ) : async [DaoInterface.ICRC120OrchestrationEvent] {
    orchestrator.factory().icrc120_get_events(input);
  };
  // TODO remove and make it a DAO proposal
  public shared ({ caller }) func addMember(id : Principal) : async Result.Result<(), Text> {
    let isCallerMember = PureMap.containsKey(membersMap, Principal.compare, caller);
    if (not isCallerMember) {
      return #err("Only existing members can add new members");
    };
    let (newMembersMap, isNew) = PureMap.insert(
      membersMap,
      Principal.compare,
      id,
      { votingPower = 1 },
    );
    if (not isNew) {
      return #err("Member with this Principal already exists: " # Principal.toText(id));
    };
    membersMap := newMembersMap;
    #ok;
  };

  // TODO remove and make it a DAO proposal
  public shared ({ caller }) func removeMember(id : Principal) : async Result.Result<(), Text> {
    let isCallerMember = PureMap.containsKey(membersMap, Principal.compare, caller);
    if (not isCallerMember) {
      return #err("Only existing members can remove members");
    };
    if (PureMap.size(membersMap) <= 1) {
      return #err("Cannot remove the last member of the DAO");
    };
    let (newMembersMap, existed) = PureMap.delete(membersMap, Principal.compare, id);
    if (not existed) {
      return #err("Member with this Principal does not exist: " # Principal.toText(id));
    };
    membersMap := newMembersMap;
    #ok;
  };

  public query func getMember(id : Principal) : async ?DaoInterface.Member {
    let ?memberData = PureMap.get<Principal, DaoInterface.MemberData>(membersMap, Principal.compare, id) else return null;
    ?{
      memberData with
      id = id;
    };
  };

  public query func getMembers() : async [DaoInterface.Member] {
    getMembersListInternal();
  };

  private func getMembersListInternal() : [DaoInterface.Member] {
    PureMap.entries(membersMap)
    |> Iter.map(
      _,
      func((id, data) : (Principal, DaoInterface.MemberData)) : DaoInterface.Member {
        {
          data with
          id = id;
        };
      },
    )
    |> Iter.toArray(_);
  };

  public shared ({ caller }) func createProposal(proposal : DaoInterface.ProposalKind) : async Result.Result<Nat, Text> {
    let members = getMembersListInternal();
    switch (await* proposalEngine.createProposal(caller, proposal, members, #snapshot)) {
      case (#ok(proposalId)) #ok(proposalId);
      case (#err(#notEligible)) #err("Not eligible to create proposals");
      case (#err(#invalid(errors))) #err("Invalid proposal: " # Text.join(" ", errors.vals()));
    };
  };

  public shared ({ caller }) func vote(proposalId : Nat, vote : Bool) : async Result.Result<(), Text> {

    switch (await* proposalEngine.vote(proposalId, caller, vote)) {
      case (#ok) #ok;
      case (#err(#notEligible)) #err("Not eligible to vote on this proposal");
      case (#err(#alreadyVoted)) #err("Already voted on this proposal");
      case (#err(#votingClosed)) #err("Voting is closed for this proposal");
      case (#err(#proposalNotFound)) #err("Proposal not found");
    };
  };

  public query func getProposal(proposalId : Nat) : async ?DaoInterface.ProposalDetail {
    let ?proposal = proposalEngine.getProposal(proposalId) else return null;
    ?mapToDetail(proposal);
  };

  public query func getProposals(count : Nat, offset : Nat) : async DaoInterface.GetProposalsResponse {
    let pagedResult = proposalEngine.getProposals(count, offset);
    {
      pagedResult with
      data = Array.map(pagedResult.data, mapToDetail);
    };
  };

  public query func getVote(proposalId : Nat, voterId : Principal) : async ?DaoInterface.Vote {
    proposalEngine.getVote(proposalId, voterId);
  };

  public func getDelegates() : async [DaoInterface.Delegate] {
    let ?canisterId = pdsCanisterIdOrNull else return Runtime.trap("PDS canister ID is not set.");
    let pdsActor = actor (Principal.toText(canisterId)) : PdsInterface.Actor;
    await pdsActor.getDelegates();
  };

  func mapToDetail(proposal : ProposalEngine.Proposal<DaoInterface.ProposalKind>) : DaoInterface.ProposalDetail {
    let summary = proposalEngine.buildVotingSummary(proposal.id);
    let votesFor = switch (Array.find(summary.votingPowerByChoice, func(choice) = choice.choice == true)) {
      case (?choicePower) choicePower.votingPower;
      case (null) 0;
    };
    let votesAgainst = switch (Array.find(summary.votingPowerByChoice, func(choice) = choice.choice == false)) {
      case (?choicePower) choicePower.votingPower;
      case (null) 0;
    };

    // Extract title and description based on proposal type
    let (title, description) = switch (proposal.content) {
      case (#postToBluesky(postProposal)) {
        ("Post To Bluesky", "Post content to Personal Data Server for Bluesky.\n\nMessage:\n" # postProposal.message);
      };
      case (#setPdsCanister(setPdsProposal)) {
        let canisterIdText = "Canister ID: " # Principal.toText(setPdsProposal.canisterId);
        ("Set PDS Canister", canisterIdText);
      };
      case (#installPds(installPdsProposal)) {
        let wasmHashText = debug_show (installPdsProposal.wasmHash);
        let initArgsText = switch (installPdsProposal.initArgs) {
          case (#candidText(text)) "Candid Text:\n    " # text;
          case (#raw(blob)) "Raw (hex): " # debug_show (blob);
        };
        let details = "  WASM Hash: " # wasmHashText # "\n" #
        "  Init Args - " # initArgsText # "\n\n";
        switch (installPdsProposal.kind) {
          case (#install({ kind })) {
            let installDetails = switch (kind) {
              case (#newCanister(newCanister)) "Install PDS WASM in new canister with Settings:\n" # debug_show (newCanister);
              case (#existingCanister(canisterId)) "Install PDS WASM in canister: " # Principal.toText(canisterId);
            };
            ("Install PDS", installDetails # "\n" # details);
          };
          case (#reinstall({ canisterId })) {
            let reinstallDetails = "Reinstall PDS WASM in canister: " # Principal.toText(canisterId);
            ("Reinstall PDS", reinstallDetails # "\n" # details);
          };
          case (#upgrade({ canisterId })) {
            let upgradeDetails = "Upgrade PDS WASM in canister: " # Principal.toText(canisterId);
            ("Upgrade PDS", upgradeDetails # "\n" # details);
          };
        };
      };
      case (#setDelegatePermissions(setDelegateProposal)) {
        let delegateIdText = "Delegate ID: " # Principal.toText(setDelegateProposal.delegateId);
        let permissionsText = "Permissions:\n" # debug_show (setDelegateProposal.permissions);
        ("Set Delegate Permissions", delegateIdText # "\n" # permissionsText);
      };
      case (#customCall(customCallProposal)) {
        let canisterIdText = "Canister ID: " # Principal.toText(customCallProposal.canisterId);
        let methodText = "Method: " # customCallProposal.method;
        let argsText = switch (customCallProposal.args) {
          case (#candidText(text)) "Args (Candid Text):\n    " # text;
          case (#raw(blob)) "Args (Raw - hex): " # debug_show (blob);
        };
        ("Custom Call Proposal", canisterIdText # "\n" # methodText # "\n" # argsText);
      };
    };

    {
      id = proposal.id;
      title = title;
      description = description;
      status = proposal.status;
      votesFor = votesFor;
      votesAgainst = votesAgainst;
      totalVotingPower = summary.totalVotingPower;
      timeStart = proposal.timeStart;
      timeEnd = proposal.timeEnd;
    };
  };

};
