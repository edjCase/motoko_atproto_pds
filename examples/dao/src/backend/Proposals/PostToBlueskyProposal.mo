import Result "mo:core@1/Result";
import Text "mo:core@1/Text";
import Debug "mo:core@1/Debug";
import Error "mo:core@1/Error";
import PdsInterface "../../../../../src/PdsInterface";
import List "mo:core@1/List";
import Principal "mo:core@1/Principal";

module {
  public type ProposalData = {
    message : Text;
  };

  public func onAdopt(
    pdsCanisterId : Principal,
    content : Text,
  ) : async* Result.Result<(), Text> {
    try {
      // Create the PDS actor reference
      let pdsActor = actor (Principal.toText(pdsCanisterId)) : PdsInterface.Actor;

      // Make the post to AT Protocol
      switch (await pdsActor.postToBluesky(content)) {
        case (#ok(_)) #ok;
        case (#err(error)) #err("Failed to post to AT Protocol: " # error);
      };
    } catch (error) {
      #err("Error calling PDS canister: " # Error.message(error));
    };
  };

  public func validate(
    proposal : ProposalData
  ) : Result.Result<(), [Text]> {
    var errors = List.empty<Text>();
    if (Text.size(proposal.message) == 0) {
      List.add(errors, "Post content cannot be empty");
    };

    if (Text.size(proposal.message) > 300) {
      List.add(errors, "Post content cannot exceed 300 characters");
    };

    if (List.size(errors) > 0) {
      #err(List.toArray(errors));
    } else {
      #ok;
    };
  };
};
