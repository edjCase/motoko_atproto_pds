import ProposalEngine "mo:dao-proposal-engine@2/ProposalEngine";
import ExtendedProposalEngine "mo:dao-proposal-engine@2/ExtendedProposalEngine";
import Principal "mo:core@1/Principal";
import Result "mo:core@1/Result";
import Text "mo:core@1/Text";
import Array "mo:core@1/Array";
import DaoInterface "./DaoInterface";
import PostToBlueskyProposal "./Proposals/PostToBlueskyProposal";
import SetPdsCanisterProposal "./Proposals/SetPdsCanisterProposal";
import BTree "mo:stableheapbtreemap@1/BTree";
import PureMap "mo:core@1/pure/Map";
import ICRC120 "mo:icrc120-mo@0";
import ClassPlus "mo:class-plus@0";
import Iter "mo:core@1/Iter";
import TimerTool "mo:timer-tool@0";
import Log "mo:stable-local-log@0";
import Logger "Logger";
import WasmStore "WasmStore";

module {

  public type StableData = ICRC120.State;

  public class Orchestrator<system>(
    deployer : Principal,
    daoPrincipal : Principal,
    timerTool : TimerTool.TimerTool,
    logger : Logger.Logger,
    wasmStore : WasmStore.WasmStore,
    initialState : ?StableData,
  ) {
    var state : ICRC120.State = switch (initialState) {
      case (?s) s;
      case (null) ICRC120.initialState();
    };

    let initManager = ClassPlus.ClassPlusInitializationManager(
      deployer,
      daoPrincipal,
      true,
    );

    private func getEnvironment() : ICRC120.Environment {
      {
        add_record = null;
        advanced = null;
        can_admin_canister = func(context : { caller : Principal; canisterId : Principal }) : async* Bool {
          context.caller == deployer;
        };
        can_install_canister = null;
        get_wasm_chunk = func(hash : Blob, chunkId : Nat, expectedHash : ?Blob) : async* Result.Result<Blob, Text> {
          switch (await* wasmStore.getChunk(hash, chunkId, expectedHash)) {
            case (#ok(chunk)) #ok(chunk);
            case (#err(err)) switch (err) {
              case (#hashMismatch) #err("Wasm chunk hash mismatch");
              case (#wasmNotFound) #err("Wasm not found");
              case (#indexOutOfBounds) #err("Wasm chunk index out of bounds");
            };
          };
        };
        get_wasm_store = func(hash : Blob) : async* Result.Result<(Principal, [Blob]), Text> {
          let ?wasmData = await* wasmStore.getWasm(hash) else {
            return #err("Wasm not found");
          };
          let chunks = Array.map<WasmStore.Chunk, Blob>(
            wasmData.chunks,
            func(chunk : WasmStore.Chunk) : Blob {
              chunk.bytes;
            },
          );
          // TODO what is the principal?
          #ok((daoPrincipal, chunks));
        };
        tt = timerTool;
        log = logger.factory();
      };
    };

    public let factory = ICRC120.Init<system>({
      manager = initManager;
      initialState = state;
      args = null;
      pullEnvironment = ?getEnvironment;
      onInitialize = null;
      onStorageChange = func(newState) {
        state := newState;
      };
    });

    public func toStableData() : StableData {
      state;
    };

  };
};
