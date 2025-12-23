import Result "mo:core@1/Result";
import Text "mo:core@1/Text";
import Debug "mo:core@1/Debug";
import Error "mo:core@1/Error";
import PdsInterface "../../../../../src/PdsInterface";
import List "mo:core@1/List";
import Principal "mo:core@1/Principal";
import DateTime "mo:datetime@1/DateTime";

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

      let now = DateTime.now();
      let createRecordRequest : PdsInterface.CreateRecordRequest = {
        collection = "app.bsky.feed.post";
        rkey = null;
        record = #map([
          ("$type", #text("app.bsky.feed.post")),
          ("text", #text(content)),
          ("createdAt", #text(now.toTextFormatted(#iso))),
        ]);
        validate = null;
        swapCommit = null;
      };

      // Make the post to AT Protocol
      switch (await pdsActor.createRecord(createRecordRequest)) {
        case (#ok(_)) #ok;
        case (#err(error)) #err("Failed to post to pds: " # error);
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
