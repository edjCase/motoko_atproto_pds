import ProposalEngine "mo:dao-proposal-engine@2/ProposalEngine";
import ExtendedProposalEngine "mo:dao-proposal-engine@2/ExtendedProposalEngine";
import Principal "mo:core@1/Principal";
import Result "mo:core@1/Result";
import Text "mo:core@1/Text";
import Array "mo:core@1/Array";
import DaoInterface "./DaoInterface";
import PostToBlueskyProposal "./Proposals/PostToBlueskyProposal";
import SetPdsCanisterProposal "./Proposals/SetPdsCanisterProposal";
import BTree "mo:stableheapbtreemap@1/BTree";

shared ({ caller = deployer }) persistent actor class Dao() : async DaoInterface.Actor {

  // Stable storage for upgrades
  var stableProposalData : ProposalEngine.StableData<DaoInterface.ProposalKind> = {
    proposals = BTree.init<Nat, ProposalEngine.ProposalData<DaoInterface.ProposalKind>>(null);
    proposalDuration = ?#days(7); // 7 day voting period
    votingThreshold = #percent({ percent = 50; quorum = ?25 }); // 50% threshold with 25% quorum
    allowVoteChange = true; // Allow members to change their votes
  };

  // DAO configuration
  var members : [DaoInterface.Member] = [
    { id = deployer; votingPower = 1 } // Initial member is deployer
  ];
  var pdsCanisterId : ?Principal = null; // Will be set by owner

  // System functions for upgrades
  system func preupgrade() {
    stableProposalData := proposalEngine.toStableData();
  };

  // Helper function to update PDS canister ID
  func updatePdsCanisterId(newCanisterId : Principal) : () {
    pdsCanisterId := ?newCanisterId;
  };

  // Proposal execution handlers
  func onProposalAdopt(
    proposal : ProposalEngine.Proposal<DaoInterface.ProposalKind>
  ) : async* Result.Result<(), Text> {
    switch (proposal.content) {
      case (#postToBluesky(postProposal)) {
        switch (pdsCanisterId) {
          case (null) return #err("PDS canister ID is not set. Cannot post to AT Protocol.");
          case (?canisterId) await* PostToBlueskyProposal.onAdopt(canisterId, postProposal.message);
        };
      };
      case (#setPdsCanister(setPdsProposal)) {
        await* SetPdsCanisterProposal.onAdopt(setPdsProposal, updatePdsCanisterId);
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
    pdsCanisterId;
  };

  public query func getMembers() : async [DaoInterface.Member] {
    members;
  };

  public shared ({ caller }) func createProposal(proposal : DaoInterface.ProposalKind) : async Result.Result<Nat, Text> {

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

  public query func getProposals(count : Nat, offset : Nat) : async ExtendedProposalEngine.PagedResult<DaoInterface.ProposalDetail> {
    let pagedResult = proposalEngine.getProposals(count, offset);
    {
      pagedResult with
      data = Array.map(pagedResult.data, mapToDetail);
    };
  };

  public query func getVote(proposalId : Nat, voterId : Principal) : async ?ExtendedProposalEngine.Vote<Bool> {
    proposalEngine.getVote(proposalId, voterId);
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
        ("Post To Bluesky", "Post content to Personal Data Server for Bluesky. Content: \n" # postProposal.message);
      };
      case (#setPdsCanister(setPdsProposal)) {
        let kindText = switch (setPdsProposal.kind) {
          case (#set) "Set PDS Canister";
          case (#initialize(_)) "Initialize PDS Canister";
          case (#installAndInitialize(_)) "Install and Initialize PDS Canister";
        };
        (kindText, "PDS Canister ID: " # Principal.toText(setPdsProposal.id));
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
