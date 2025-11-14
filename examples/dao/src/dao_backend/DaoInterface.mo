import Principal "mo:core@1/Principal";
import Proposal "mo:dao-proposal-engine@2/Proposal";
import PostProposal "./Proposals/PostProposal";
import SetPdsCanisterProposal "./Proposals/SetPdsCanisterProposal";

module {

  // Types for our DAO

  public type ProposalKind = {
    #post : PostProposal.ProposalData;
    #setPdsCanister : SetPdsCanisterProposal.ProposalData;
  };

  public type Member = {
    id : Principal;
    votingPower : Nat;
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

  public type Actor = actor {

  };
};
