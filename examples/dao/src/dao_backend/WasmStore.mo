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
import Runtime "mo:core@1/Runtime";
import Sha256 "mo:sha2@0/Sha256";
import List "mo:core@1/List";
import Blob "mo:core@1/Blob";

module {

  public type WasmHash = Blob;
  public type Chunk = {
    bytes : Blob;
    hash : Blob; // SHA-256 hash of the bytes
  };
  public type WasmData = {
    chunks : [Chunk];
    size : Nat; // total size in bytes
    hash : Blob; // SHA-256 hash of the wasm
  };

  public type FinalizeChunksError = {
    #chunksNotFound;
    #chunksMissing : [Nat];
    #hashMismatch;
  };

  public type GetChunkError = {
    #hashMismatch;
    #wasmNotFound;
    #indexOutOfBounds;
  };

  public type WasmStore = {
    getChunk : (wasmHash : WasmHash, index : Nat, expectedHashOrNull : ?Blob) -> async* Result.Result<Blob, GetChunkError>;
    getWasm : (wasmHash : WasmHash) -> async* ?WasmData;
  };

  public class RemoteWasmStore<system>() {
    public func getChunk(wasmHash : WasmHash, index : Nat, expectedHashOrNull : ?Blob) : async* Result.Result<Blob, GetChunkError> {
      #err(#wasmNotFound);
    };

    public func getWasm(wasmHash : WasmHash) : async* ?WasmData {
      null;
    };
  };

  public type LocalStableData = {
    wasmMap : PureMap.Map<WasmHash, WasmData>;
  };

  public class LocalWasmStore<system>(
    stableData : ?LocalStableData
  ) : WasmStore {
    var chunkMap = PureMap.empty<WasmHash, List.List<?Blob>>(); // temporary storage for uploading chunks
    var wasmMap = switch (stableData) {
      case (?data) data.wasmMap;
      case (null) PureMap.empty<WasmHash, WasmData>();
    };

    public func addChunk(wasmHash : WasmHash, index : Nat, chunk : Blob) : () {
      let chunks : List.List<?Blob> = switch (PureMap.get(chunkMap, Blob.compare, wasmHash)) {
        case (?existingChunks) existingChunks;
        case (null) List.empty<?Blob>();
      };
      while (List.size(chunks) <= index) {
        List.add(chunks, null);
      };
      List.put(chunks, index, ?chunk);
    };

    public func finalizeChunks(wasmHash : WasmHash) : Result.Result<(), FinalizeChunksError> {
      let chunkOrNullList = switch (PureMap.get(chunkMap, Blob.compare, wasmHash)) {
        case (?chunkList) chunkList;
        case (null) return #err(#chunksNotFound);
      };
      let missingIndices = List.empty<Nat>();
      for ((i, chunkOrNull) in List.enumerate(chunkOrNullList)) {
        if (chunkOrNull == null) {
          List.add(missingIndices, i);
        };
      };
      if (List.size(missingIndices) > 0) {
        return #err(#chunksMissing(List.toArray(missingIndices)));
      };

      let chunksArray = Array.tabulate(
        List.size(chunkOrNullList),
        func(i : Nat) : Chunk {
          let ?chunkBlob = List.at(chunkOrNullList, i) else Runtime.unreachable();
          {
            bytes = chunkBlob;
            hash = Sha256.fromBlob(#sha256, chunkBlob);
          };
        },
      );
      let digest = Sha256.Digest(#sha256);
      var totalSize : Nat = 0;
      for (chunk in chunksArray.vals()) {
        totalSize += Blob.size(chunk.bytes);
        // TODO need to make async to compute hash of all chunks to avoid instruction limit?
        digest.writeBlob(chunk.bytes);
      };
      let actualWasmHash = digest.sum();
      if (actualWasmHash != wasmHash) {
        return #err(#hashMismatch);
      };

      wasmMap := PureMap.add(
        wasmMap,
        Blob.compare,
        wasmHash,
        {
          chunks = chunksArray;
          size = totalSize;
          hash = wasmHash;
        },
      );
      #ok;
    };

    public func getChunk(wasmHash : WasmHash, index : Nat, expectedHashOrNull : ?Blob) : async* Result.Result<Blob, GetChunkError> {
      let ?wasmData = PureMap.get(wasmMap, Blob.compare, wasmHash) else return #err(#wasmNotFound);
      if (wasmData.chunks.size() <= index) {
        return #err(#indexOutOfBounds);
      };
      let chunk = wasmData.chunks[index];
      switch (expectedHashOrNull) {
        case (?expectedHash) if (chunk.hash != expectedHash) {
          return #err(#hashMismatch);
        };
        case (null) ();
      };
      #ok(chunk.bytes);
    };

    public func getWasm(wasmHash : WasmHash) : async* ?WasmData {
      PureMap.get(wasmMap, Blob.compare, wasmHash);
    };

    public func toStableData() : LocalStableData {
      {
        wasmMap = wasmMap;
      };
    };
  };
};
