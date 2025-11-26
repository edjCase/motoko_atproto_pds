import Result "mo:core@1/Result";
import DagCbor "mo:dag-cbor@2";
import MerkleNode "mo:atproto@0/MerkleNode";

module {
  public type Actor = actor {

    initialize : (request : InitializeRequest) -> async Result.Result<(), Text>;
    getLogs : query (limit : Nat, offset : Nat) -> async [LogEntry];
    clearLogs : () -> async Result.Result<(), Text>;

    getOwner : query () -> async Principal;
    setOwner : (newOwner : Principal) -> async Result.Result<(), Text>;
    getDeployer : query () -> async Principal;

    postToBluesky : (message : Text) -> async Result.Result<Text, Text>;

    createRecord : (request : CreateRecordRequest) -> async Result.Result<CreateRecordResponse, Text>;
    deleteRecord : (request : DeleteRecordRequest) -> async Result.Result<DeleteRecordResponse, Text>;
    putRecord : (request : PutRecordRequest) -> async Result.Result<PutRecordResponse, Text>;
    getRecord : query (request : GetRecordRequest) -> async Result.Result<GetRecordResponse, Text>;
    listRecords : query (request : ListRecordsRequest) -> async Result.Result<ListRecordsResponse, Text>;
    exportRepoData : query () -> async Result.Result<ExportData, Text>;

    createPlcDid : (request : CreatePlcRequest) -> async Result.Result<Text, Text>;
    updatePlcDid : (request : UpdatePlcRequest) -> async Result.Result<(), Text>;
  };

  public type LogLevel = {
    #verbose;
    #debug_;
    #info;
    #warning;
    #error;
    #fatal;
  };

  public type LogEntry = {
    time : Int;
    level : LogLevel;
    message : Text;
  };

  public type CIDText = Text;
  public type TIDText = Text;

  public type Commit = {
    sig : Blob; // signature
    did : CIDText;
    version : Nat;
    data : CIDText; // Points to MST root
    rev : TIDText; // Timestamp/revision
    prev : ?CIDText; // Previous commit
  };

  public type ExportData = {
    commits : [(CIDText, Commit)];
    records : [(CIDText, DagCbor.Value)];
    nodes : [(CIDText, MerkleNode.Node)];
  };

  public type ListRecordsRequest = {
    collection : Text;
    limit : ?Nat;
    cursor : ?Text;
    rkeyStart : ?Text;
    rkeyEnd : ?Text;
    reverse : ?Bool;
  };

  public type ListRecordsResponse = {
    cursor : ?Text;
    records : [ListRecord];
  };

  public type ListRecord = {
    collection : Text;
    rkey : Text;
    cid : CIDText;
    value : DagCbor.Value;
  };

  public type GetRecordRequest = {
    collection : Text;
    rkey : Text;
    cid : ?CIDText;
  };

  public type GetRecordResponse = {
    cid : CIDText;
    value : DagCbor.Value;
  };

  public type CreateRecordRequest = {
    collection : Text;
    rkey : ?Text;
    record : DagCbor.Value;
    validate : ?Bool;
    swapCommit : ?CIDText;
  };

  public type CommitMeta = {
    cid : CIDText;
    rev : TIDText;
  };

  public type ValidationStatus = {
    #valid;
    #unknown;
  };

  public type CreateRecordResponse = {
    rkey : Text;
    cid : CIDText;
    commit : ?CommitMeta;
    validationStatus : ValidationStatus;
  };

  public type DeleteRecordRequest = {
    collection : Text;
    rkey : Text;
    swapCommit : ?CIDText;
    swapRecord : ?CIDText;
  };

  public type DeleteRecordResponse = {
    commit : ?CommitMeta;
  };

  public type PutRecordRequest = {
    collection : Text;
    rkey : Text;
    record : DagCbor.Value;
    validate : ?Bool;
    swapCommit : ?CIDText;
    swapRecord : ?CIDText;
  };

  public type PutRecordResponse = {
    cid : CIDText;
    commit : ?CommitMeta;
    validationStatus : ?ValidationStatus;
  };

  public type InitializeRequest = {
    plc : PlcKind;
    hostname : Text;
    serviceSubdomain : ?Text;
  };

  public type PlcKind = {
    #new : CreatePlcRequest;
    #id : Text;
    #car : Blob;
  };

  public type CreatePlcRequest = {
    alsoKnownAs : [Text];
    services : [PlcService];
  };

  public type UpdatePlcRequest = {
    did : Text;
    alsoKnownAs : [Text];
    services : [PlcService];
  };

  public type PlcService = {
    id : Text;
    type_ : Text;
    endpoint : Text;
  };
};
