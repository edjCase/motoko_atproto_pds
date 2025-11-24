import Result "mo:core@1/Result";
import Text "mo:core@1/Text";
import Debug "mo:core@1/Debug";
import Error "mo:core@1/Error";
import Principal "mo:core@1/Principal";
import PdsInterface "../../../../../src/PdsInterface";
import { ic } "mo:ic@3";
import List "mo:core@1/List";

module {

  public type ProposalData = {
    id : Principal;
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
    wasmModule : Blob;
    initArgs : Blob;
    initializeOptions : InitializeOptions;
  };

  public func onAdopt(
    proposal : ProposalData,
    updatePdsCanisterId : (Principal) -> (),
  ) : async* Result.Result<(), Text> {
    switch (proposal.kind) {
      case (#set) {
        // Simply set the PDS canister ID
        updatePdsCanisterId(proposal.id);
        #ok;
      };
      case (#initialize(initOptions)) {
        // Update the PDS canister ID after successful initialization
        updatePdsCanisterId(proposal.id);
        // Initialize an existing PDS canister
        await* initialize(proposal.id, initOptions);
      };
      case (#installAndInitialize(installOptions)) {

        // Update the PDS canister ID after successful initialization
        updatePdsCanisterId(proposal.id);

        switch (await* install(proposal.id, installOptions)) {
          case (#ok(_)) ();
          case (#err(error)) return #err(error);
        };

        // Initialize an existing PDS canister
        await* initialize(proposal.id, installOptions.initializeOptions);
      };
    };
  };

  func install(
    pdsCanisterId : Principal,
    installOptions : InstallAndInitializeOptions,
  ) : async* Result.Result<(), Text> {
    try {
      // Install the WASM module on the target canister
      await ic.install_code({
        canister_id = pdsCanisterId;
        mode = #install;
        wasm_module = installOptions.wasmModule;
        arg = installOptions.initArgs;
        sender_canister_version = null;
      });

      #ok;
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
    proposal : ProposalData
  ) : Result.Result<(), [Text]> {
    var errors = List.empty<Text>();

    // Validate the canister ID (basic check that it's not null)
    if (proposal.id == Principal.anonymous()) {
      List.add(errors, "Invalid canister ID - cannot be anonymous principal");
    };

    // Validate based on the kind of operation
    switch (proposal.kind) {
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
        if (installOptions.wasmModule.size() == 0) {
          List.add(errors, "WASM module cannot be empty for install operation");
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
