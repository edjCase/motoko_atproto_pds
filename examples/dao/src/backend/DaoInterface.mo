import Principal "mo:core@1/Principal";
import Proposal "mo:dao-proposal-engine@2/Proposal";
import PostToBlueskyProposal "./Proposals/PostToBlueskyProposal";
import SetPdsCanisterProposal "./Proposals/SetPdsCanisterProposal";

module {

  // Types for our DAO

  public type ProposalKind = {
    #postToBluesky : PostToBlueskyProposal.ProposalData;
    #setPdsCanister : SetPdsCanisterProposal.ProposalData;
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

  public type Actor = actor {

  };
};
