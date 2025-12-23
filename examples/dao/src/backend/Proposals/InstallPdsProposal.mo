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
    kind : {
      #install : {
        kind : {
          #newCanister : {
            initialCycleBalance : Nat;
            settings : NewCanisterSettings;
          };
          #existingCanister : Principal;
        };
      };
      #reinstall : {
        canisterId : Principal;
      };
      #upgrade : {
        canisterId : Principal;
        wasmMemoryPersistence : { #keep; #replace };
        skipPreUpgrade : Bool;
      };
    };
    wasmHash : Blob;
    initArgs : {
      #raw : Blob;
      #candidText : Text;
    };
  };

  public type NewCanisterSettings = {
    freezingThreshold : ?Nat;
    wasmMemoryThreshold : ?Nat;
    controllers : ?[Principal];
    reservedCyclesLimit : ?Nat;
    logVisibility : ?LogVisibility;
    wasmMemoryLimit : ?Nat;
    memoryAllocation : ?Nat;
    computeAllocation : ?Nat;
  };
  public type LogVisibility = {
    #controllers;
    #public_;
    #allowedViewers : [Principal];
  };

  public func onAdopt(
    daoPrincipal : Principal,
    proposalData : ProposalData,
    orchestratorFactory : () -> ICRC120.ICRC120,
    updatePdsCanisterId : (Principal) -> (),
  ) : async* Result.Result<(), Text> {

    let (_requestId, canisterId) = switch (await* install(daoPrincipal, orchestratorFactory, proposalData)) {
      case (#ok((requestId, canisterId))) (requestId, canisterId);
      case (#err(error)) return #err(error);
    };
    // Update the PDS canister ID after successful initialization
    updatePdsCanisterId(canisterId);
    #ok;
  };

  func install(
    daoPrincipal : Principal,
    orchestratorFactory : () -> ICRC120.ICRC120,
    installOptions : ProposalData,
  ) : async* Result.Result<(Nat, Principal), Text> {

    let args = switch (installOptions.initArgs) {
      case (#raw(blob)) blob;
      case (#candidText(text)) switch (Candid.fromText(text)) {
        case (#ok(value)) Blob.fromArray(Candid.toBytes(value));
        case (#err(errMsg)) return #err("Failed to encode Candid text to blob: " # errMsg);
      };
    };

    let (pdsCanisterId, mode) = switch (installOptions.kind) {
      case (#install({ kind })) {
        let canisterId = switch (kind) {
          case (#newCanister({ initialCycleBalance; settings })) switch (await* createCanister(settings, initialCycleBalance)) {
            case (#ok(id)) id;
            case (#err(errMsg)) return #err("Failed to create new canister: " # errMsg);
          };
          case (#existingCanister(canisterId)) canisterId;
        };
        (canisterId, #install);
      };
      case (#reinstall({ canisterId })) (canisterId, #reinstall);
      case (#upgrade({ canisterId; wasmMemoryPersistence; skipPreUpgrade })) (
        canisterId,
        #upgrade(
          ?{
            wasm_memory_persistence = ?wasmMemoryPersistence;
            skip_pre_upgrade = ?skipPreUpgrade;
          }
        ),
      );
    };

    let upgradeOptions = [{
      canister_id = pdsCanisterId;
      hash = installOptions.wasmHash;
      args = args;
      stop = true;
      restart = true;
      snapshot = false; // Currently broken
      timeout = 600_000_000_000; /* 10 minutes for DAO operations */
      mode = mode;
      parameters = null;
    }];

    try {

      let results = await orchestratorFactory().icrc120_upgrade_to(daoPrincipal, upgradeOptions);
      switch (results[0]) {
        case (#Ok(requestId)) #ok((requestId, pdsCanisterId));
        case (#Err(#Unauthorized)) #err("Not authorized for this operation");
        case (#Err(#WasmUnavailable)) #err("Wasm module not found");
        case (#Err(#InvalidPayment)) #err("Invalid payment for upgrade");
        case (#Err(#Generic(msg))) #err("Operation failed: " # msg);
      };
    } catch (error) {
      #err("Error installing PDS canister: " # Error.message(error));
    };
  };

  public func validate(
    proposalData : ProposalData
  ) : Result.Result<(), [Text]> {
    var errors = List.empty<Text>();

    // Validate based on the kind of operation
    switch (proposalData.kind) {
      case (#reinstall({ canisterId })) {
        if (canisterId == Principal.anonymous()) {
          List.add(errors, "Invalid canister ID for reinstall - cannot be anonymous principal");
        };
      };
      case (#install({ kind })) {
        switch (kind) {
          case (#newCanister(_)) {};
          case (#existingCanister(canisterId)) if (canisterId == Principal.anonymous()) {
            List.add(errors, "Invalid canister ID for install - cannot be anonymous principal");
          };
        };
      };
      case (#upgrade({ canisterId })) {
        if (canisterId == Principal.anonymous()) {
          List.add(errors, "Invalid canister ID for upgrade - cannot be anonymous principal");
        };
      };
    };
    if (proposalData.wasmHash.size() == 0) {
      List.add(errors, "WASM hash cannot be empty for install operation");
    };
    switch (proposalData.initArgs) {
      case (#raw(blob)) switch (Candid.fromBytes(blob.vals())) {
        case (null) List.add(errors, "Invalid Candid bytes for initialization arguments.");
        case (?_) {}; // TODO validate current schema?
      };
      case (#candidText(text)) switch (Candid.fromText(text)) {
        case (#err(err)) List.add(errors, "Invalid Candid text for initialization arguments. Error: " # err);
        case (#ok(_)) {}; // TODO validate current schema?
      };
    };
    if (List.size(errors) > 0) {
      #err(List.toArray(errors));
    } else {
      #ok;
    };
  };

  private func createCanister(
    canisterSettings : NewCanisterSettings,
    initialCycleBalance : Nat,
  ) : async* Result.Result<Principal, Text> {
    try {
      let cycles = 500_000_000_000 + initialCycleBalance; // Install cycles plus initial balance
      let { canister_id } = await (with cycles = cycles) ic.create_canister({
        settings = ?{
          freezing_threshold = canisterSettings.freezingThreshold;
          wasm_memory_threshold = canisterSettings.wasmMemoryThreshold;
          controllers = canisterSettings.controllers;
          reserved_cycles_limit = canisterSettings.reservedCyclesLimit;
          log_visibility = switch (canisterSettings.logVisibility) {
            case (null) null;
            case (?#controllers) ?#controllers;
            case (?#public_) ?#public_;
            case (?#allowedViewers(viewers)) ?#allowed_viewers(viewers);
          };
          wasm_memory_limit = canisterSettings.wasmMemoryLimit;
          memory_allocation = canisterSettings.memoryAllocation;
          compute_allocation = canisterSettings.computeAllocation;
        };
        sender_canister_version = null;
      });
      #ok(canister_id);
    } catch (error) {
      return #err("Failed to create canister: " # Error.message(error));
    };
  };
};
