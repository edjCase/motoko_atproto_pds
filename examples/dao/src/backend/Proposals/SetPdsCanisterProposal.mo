import Result "mo:core@1/Result";
import Text "mo:core@1/Text";
import Debug "mo:core@1/Debug";
import Error "mo:core@1/Error";
import Principal "mo:core@1/Principal";
import PdsInterface "../../../../../src/PdsInterface";
import { ic } "mo:ic@3";
import List "mo:core@1/List";
import ICRC120 "mo:icrc120-mo@0";

module {

  public type ProposalData = {
    canisterId : Principal;
    kind : {
      #set;
      #initialize : InitializeOptions;
      #installAndInitialize : InstallAndInitializeOptions;
    };
  };

  public type InitializeOptions = {
    hostname : Text;
    serviceSubdomain : ?Text;
    plcIdentifier : Text;
  };

  public type InstallAndInitializeOptions = {
    wasmHash : Blob;
    initArgs : {
      #raw : Blob;
      #candidText : Text;
    };
    initializeOptions : InitializeOptions;
  };

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
      case (#initialize(initOptions)) {
        // Update the PDS canister ID after successful initialization
        updatePdsCanisterId(proposalData.canisterId);
        // Initialize an existing PDS canister
        await* initialize(proposalData.canisterId, initOptions);
      };
      case (#installAndInitialize(installOptions)) {

        // Update the PDS canister ID after successful initialization
        updatePdsCanisterId(proposalData.canisterId);

        let _requestId = switch (await* install(daoPrincipal, proposalData.canisterId, orchestratorFactory, installOptions)) {
          case (#ok(requestId)) requestId;
          case (#err(error)) return #err(error);
        };

        // TODO validate request completion
        // var tries = 0;
        // label l loop {
        //   let events = await orchestratorFactory().icrc120_get_events({
        //     filter = ?{
        //       canister = ?proposalData.canisterId;
        //       event_types = ?[#upgrade_finished];
        //       start_time = null;
        //       end_time = null;
        //     };
        //     prev = null;
        //     take = ?10;
        //   });

        //   // Find events related to this request
        //   for (event in events.vals()) {
        //     switch (event.event_type) {
        //       case (#upgrade_finished) {
        //         if (event.details.id == requestId) {
        //           break l;
        //         };
        //       };
        //       case (_) ();
        //     };
        //   };
        //   // TODO sleep possible?
        //   tries += 1;
        //   if (tries >= 30) {
        //     return #err("Timeout waiting for PDS canister upgrade to complete");
        //   };
        // };

        // Initialize an existing PDS canister
        await* initialize(proposalData.canisterId, installOptions.initializeOptions);
      };
    };
  };

  func install(
    daoPrincipal : Principal,
    pdsCanisterId : Principal,
    orchestratorFactory : () -> ICRC120.ICRC120,
    installOptions : InstallAndInitializeOptions,
  ) : async* Result.Result<Nat, Text> {
    try {
      let upgradeOptions = [{
        canister_id = pdsCanisterId;
        hash = installOptions.wasmHash;
        args = installOptions.initArgs;
        stop = true;
        restart = true;
        snapshot = true; /* Always snapshot for DAO operations */
        timeout = 600_000_000_000; /* 10 minutes for DAO operations */
        mode = #install;
        parameters = null;
      }];

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

  func initialize(pdsCanisterId : Principal, initOptions : InitializeOptions) : async* Result.Result<(), Text> {
    try {
      let pdsActor = actor (Principal.toText(pdsCanisterId)) : PdsInterface.Actor;

      let initRequest : PdsInterface.InitializeRequest = {
        hostname = initOptions.hostname;
        serviceSubdomain = initOptions.serviceSubdomain;
        plc = #id(initOptions.plcIdentifier);
      };

      let initResult = await pdsActor.initialize(initRequest);
      switch (initResult) {
        case (#ok(_)) {
          #ok;
        };
        case (#err(error)) {
          #err("Failed to initialize PDS canister: " # error);
        };
      };
    } catch (error) {
      let errorMsg = "Error initializing PDS canister: " # Error.message(error);
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
      case (#initialize(initOptions)) {
        if (Text.size(initOptions.hostname) == 0) {
          List.add(errors, "Hostname cannot be empty for initialize operation");
        };
        if (Text.size(initOptions.plcIdentifier) == 0) {
          List.add(errors, "PLC identifier cannot be empty for initialize operation");
        };
      };
      case (#installAndInitialize(installOptions)) {
        if (installOptions.wasmHash.size() == 0) {
          List.add(errors, "WASM hash cannot be empty for install operation");
        };
        if (Text.size(installOptions.initializeOptions.hostname) == 0) {
          List.add(errors, "Hostname cannot be empty for install and initialize operation");
        };
        if (Text.size(installOptions.initializeOptions.plcIdentifier) == 0) {
          List.add(errors, "PLC identifier cannot be empty for install and initialize operation");
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
