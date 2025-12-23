import Principal "mo:core@1/Principal";
import Proposal "mo:dao-proposal-engine@2/Proposal";
import PostToBlueskyProposal "./Proposals/PostToBlueskyProposal";
import SetPdsCanisterProposal "./Proposals/SetPdsCanisterProposal";
import InstallPdsProposal "./Proposals/InstallPdsProposal";
import SetDelegatePermissionsProposal "./Proposals/SetDelegatePermissionsProposal";
import CustomCallProposal "./Proposals/CustomCallProposal";
import Result "mo:core@1/Result";
import ICRC120 "mo:icrc120-mo@0";

module {


  public type Actor = actor {
    getPdsCanisterId : query () -> async ?Principal;
    addWasmChunk : (request : AddWasmChunkRequest) -> async Result.Result<(), Text>;
    finalizeWasmChunks : (wasmHash : Blob) -> async Result.Result<(), Text>;
    getWasmHashes : () -> async [Text];
    icrc120_get_events : query (input : ICRC120GetEventsFilter) -> async [ICRC120OrchestrationEvent];
    addMember : (id : Principal) -> async Result.Result<(), Text>;
    removeMember : (id : Principal) -> async Result.Result<(), Text>;
    getMember : query (id : Principal) -> async ?Member;
    getMembers : query () -> async [Member];
    createProposal : (proposal : ProposalKind) -> async Result.Result<Nat, Text>;
    vote : (proposalId : Nat, vote : Bool) -> async Result.Result<(), Text>;
    getProposal : query (proposalId : Nat) -> async ?ProposalDetail;
    getProposals : query (count : Nat, offset : Nat) -> async GetProposalsResponse;
    getVote : query (proposalId : Nat, voterId : Principal) -> async ?Vote;
    getDelegates : composite query () -> async [Delegate];
  };

  public type ICRC120GetEventsFilter = { 
    filter: ?ICRC120.CurrentTypes.GetEventsFilter;
    prev: ?Blob;
    take: ?Nat
  };

  public type ICRC120OrchestrationEvent = ICRC120.CurrentTypes.OrchestrationEvent;

  public type Delegate = {
    id : Principal;
    permissions : Permissions;
  };

  public type Permissions = {
    readLogs : Bool;
    deleteLogs : Bool;
    createRecord : Bool;
    putRecord : Bool;
    deleteRecord : Bool;
    modifyOwner : Bool;
  };

  public type Vote = {
    choice : ?Bool;
    votingPower : Nat;
  };

  public type GetProposalsResponse = {
    data : [ProposalDetail];
    offset : Nat;
    count : Nat;
    totalCount : Nat;
  };

  public type ICRC120GetEventsRequest = {
    filter : ?{
      #canisterId : Principal;
      #time : { start : Nat; end : Nat };
    };
    prev : ?Blob;
    take : ?Nat;
  };

  public type ICRC120GetEventsResponse = {
    #icrc120_canister_created : {
      id : Nat;
      time : Nat;
      canister : Principal;
    };
    #icrc120_canister_status_changed : {
      id : Nat;
      time : Nat;
      canister : Principal;
      status : {
        #running;
        #stopping;
        #stopped;
      };
    };
  };

  public type ProposalKind = {
    #postToBluesky : PostToBlueskyProposal.ProposalData;
    #setPdsCanister : SetPdsCanisterProposal.ProposalData;
    #installPds : InstallPdsProposal.ProposalData;
    #setDelegatePermissions : SetDelegatePermissionsProposal.ProposalData;
    #customCall : CustomCallProposal.ProposalData;
  };

  public type MemberData = {
    votingPower : Nat;
  };

  public type Member = MemberData and {
    id : Principal;
  };

  public type ProposalDetail = {
    id : Nat;
    title : Text;
    description : Text;
    status : Proposal.ProposalStatus;
    votesFor : Nat;
    votesAgainst : Nat;
    totalVotingPower : Nat;
    timeStart : Int;
    timeEnd : ?Int;
  };

  public type AddWasmChunkRequest = {
    wasmHash : Blob;
    index : Nat;
    chunk : Blob;
  };
};
