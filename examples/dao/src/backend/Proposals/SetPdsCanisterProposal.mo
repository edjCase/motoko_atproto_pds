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
    canisterId : Principal;
    kind : {
      #set;
      #install : InstallOptions;
    };
  };

  public type InstallOptions = {
    kind : {
      #install;
      #reinstall;
      #upgrade;
    };
    wasmHash : Blob;
    initArgs : {
      #raw : Blob;
      #candidText : Text;
    };
  };

  public type UpgradeOptions = InstallOptions;

  public func onAdopt(
    daoPrincipal : Principal,
    proposalData : ProposalData,
    orchestratorFactory : () -> ICRC120.ICRC120,
    updatePdsCanisterId : (Principal) -> (),
  ) : async* Result.Result<(), Text> {
    switch (proposalData.kind) {
      case (#set) {
        // Simply set the PDS canister ID
        updatePdsCanisterId(proposalData.canisterId);
        #ok;
      };
      case (#install(installOptions)) {

        let _requestId = switch (await* install(daoPrincipal, proposalData.canisterId, orchestratorFactory, installOptions)) {
          case (#ok(requestId)) requestId;
          case (#err(error)) return #err(error);
        };
        // Update the PDS canister ID after successful initialization
        updatePdsCanisterId(proposalData.canisterId);
        #ok;
      };
    };
  };

  func install(
    daoPrincipal : Principal,
    pdsCanisterId : Principal,
    orchestratorFactory : () -> ICRC120.ICRC120,
    installOptions : InstallOptions,
  ) : async* Result.Result<Nat, Text> {
    try {
      let args = switch (installOptions.initArgs) {
        case (#raw(blob)) blob;
        case (#candidText(text)) switch (Candid.fromText(text)) {
          case (#ok(value)) Blob.fromArray(Candid.toBytes(value));
          case (#err(errMsg)) return #err("Failed to encode Candid text to blob: " # errMsg);
        };
      };
      let upgradeOptions = [{
        canister_id = pdsCanisterId;
        hash = installOptions.wasmHash;
        args = args;
        stop = true;
        restart = true;
        snapshot = false;
        timeout = 600_000_000_000; /* 10 minutes for DAO operations */
        mode = switch (installOptions.kind) {
          case (#install) #install;
          case (#reinstall) #reinstall;
          case (#upgrade) #upgrade(
            ?{
              wasm_memory_persistence = ?#keep;
              skip_pre_upgrade = ?true;
            }
          );
        };
        parameters = null;
      }];

      Debug.print("Upgrade options: " # debug_show (upgradeOptions));

      let results = await orchestratorFactory().icrc120_upgrade_to(daoPrincipal, upgradeOptions);
      switch (results[0]) {
        case (#Ok(requestId)) #ok(requestId);
        case (#Err(#Unauthorized)) #err("Not authorized for this operation");
        case (#Err(#WasmUnavailable)) #err("Wasm module not found");
        case (#Err(#InvalidPayment)) #err("Invalid payment for upgrade");
        case (#Err(#Generic(msg))) #err("Operation failed: " # msg);
      };
    } catch (error) {
      let errorMsg = "Error installing PDS canister: " # Error.message(error);
      Debug.print(errorMsg);
      #err(errorMsg);
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

    // Validate based on the kind of operation
    switch (proposalData.kind) {
      case (#set) {
        // No additional validation needed for simple set operation
      };
      case (#install(installOptions)) {
        if (installOptions.wasmHash.size() == 0) {
          List.add(errors, "WASM hash cannot be empty for install operation");
        };
        switch (installOptions.initArgs) {
          case (#raw(blob)) switch (Candid.fromBytes(blob.vals())) {
            case (null) List.add(errors, "Invalid Candid bytes for initialization arguments.");
            case (?_) {}; // TODO validate current schema?
          };
          case (#candidText(text)) switch (Candid.fromText(text)) {
            case (#err(err)) List.add(errors, "Invalid Candid text for initialization arguments. Error: " # err);
            case (#ok(_)) {}; // TODO validate current schema?
          };
        };
      };
    };
    if (List.size(errors) > 0) {
      #err(List.toArray(errors));
    } else {
      #ok;
    };
  };
};
