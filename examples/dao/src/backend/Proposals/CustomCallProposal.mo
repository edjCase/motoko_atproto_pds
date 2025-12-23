import Result "mo:core@1/Result";
import Text "mo:core@1/Text";
import Debug "mo:core@1/Debug";
import Error "mo:core@1/Error";
import Principal "mo:core@1/Principal";
import PdsInterface "../../../../../src/PdsInterface";
import InternetComputer "mo:core@1/InternetComputer";
import List "mo:core@1/List";
import ICRC120 "mo:icrc120-mo@0";
import Candid "mo:candid@2";
import Blob "mo:core@1/Blob";
import Time "mo:core@1/Time";
import Nat "mo:core@1/Nat";
import TextX "mo:xtended-text@2/TextX";

module {

    public type ProposalData = {
      canisterId : Principal;
      method: Text;
      args : {
        #raw : [Nat8];
        #candidText : Text;
      };
    };

    public func onAdopt(
      proposalData : ProposalData,
    ) : async* Result.Result<Blob, Text> {
      let args = switch (proposalData.args) {
        case (#raw(blob)) Blob.fromArray(blob);
        case (#candidText(text)) switch (Candid.fromText(text)) {
          case (#ok(value)) Blob.fromArray(Candid.toBytes(value));
          case (#err(errMsg)) return #err("Failed to encode Candid text to blob: " # errMsg);
        };
      };
      try {
          let reply : Blob = await InternetComputer.call(
            proposalData.canisterId,
            proposalData.method,
            args,
          );
          #ok(reply);
      } catch (error) {
          #err("Error calling canister: " # Error.message(error));
      };
    };

    public func validate(
        proposalData : ProposalData
    ) : Result.Result<(), [Text]> {
        var errors = List.empty<Text>();

        // Validate the canister ID (basic check that it's not null)
        if (proposalData.canisterId == Principal.anonymous()) {
            List.add(errors, "Invalid canister ID - cannot be anonymous principal");
        };
        if (TextX.isEmptyOrWhitespace(proposalData.method)) {
            List.add(errors, "Method name cannot be empty");
        };

        if (List.size(errors) > 0) {
            #err(List.toArray(errors));
        } else {
            #ok;
        };
    };
};
