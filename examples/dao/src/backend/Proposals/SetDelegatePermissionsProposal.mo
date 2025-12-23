import Result "mo:core@1/Result";
import Text "mo:core@1/Text";
import Debug "mo:core@1/Debug";
import Error "mo:core@1/Error";
import Principal "mo:core@1/Principal";
import PdsInterface "../../../../../src/PdsInterface";
import { ic } "mo:ic@3";
import List "mo:core@1/List";
import ICRC120 "mo:icrc120-mo@0";
import Candid "mo:candid@2";
import Blob "mo:core@1/Blob";
import Time "mo:core@1/Time";
import Nat "mo:core@1/Nat";

module {

    public type ProposalData = {
        delegateId : Principal;
        permissions : PdsInterface.Permissions;
    };

    public func onAdopt(
        pdsCanisterId : Principal,
        proposalData : ProposalData,
    ) : async* Result.Result<(), Text> {
        let pdsActor = actor (Principal.toText(pdsCanisterId)) : PdsInterface.Actor;
        try {
            switch (await pdsActor.setDelegatePermissions(proposalData.delegateId, proposalData.permissions)) {
                case (#ok) #ok;
                case (#err(error)) #err("Failed to set delegate permissions: " # error);
            };
        } catch (error) {
            #err("Error calling PDS canister: " # Error.message(error));
        };
    };

    public func validate(
        proposalData : ProposalData
    ) : Result.Result<(), [Text]> {
        var errors = List.empty<Text>();

        // Validate the canister ID (basic check that it's not null)
        if (proposalData.delegateId == Principal.anonymous()) {
            List.add(errors, "Invalid delegate ID - cannot be anonymous principal");
        };

        if (List.size(errors) > 0) {
            #err(List.toArray(errors));
        } else {
            #ok;
        };
    };
};
