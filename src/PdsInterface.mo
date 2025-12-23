import Result "mo:core@1/Result";
import DagCbor "mo:dag-cbor@2";
import MerkleNode "mo:atproto@0/MerkleNode";
import Time "mo:core@1/Time";

module {
  public type Actor = actor {
    getInitializationStatus : query () -> async InitializationStatus;

    getLogs : query (limit : Nat, offset : Nat) -> async [LogEntry];
    clearLogs : () -> async Result.Result<(), Text>;

    getOwner : query () -> async Principal;
    setOwner : (newOwner : Principal) -> async Result.Result<(), Text>;
    getDeployer : query () -> async Principal;
    setDelegatePermissions : (entity : Principal, permissions : Permissions) -> async Result.Result<(), Text>;
    getDelegates : query () -> async [Delegate];

    createRecord : (request : CreateRecordRequest) -> async Result.Result<CreateRecordResponse, Text>;
    deleteRecord : (request : DeleteRecordRequest) -> async Result.Result<DeleteRecordResponse, Text>;
    putRecord : (request : PutRecordRequest) -> async Result.Result<PutRecordResponse, Text>;
    getRecord : query (request : GetRecordRequest) -> async Result.Result<GetRecordResponse, Text>;
    listRecords : query (request : ListRecordsRequest) -> async Result.Result<ListRecordsResponse, Text>;
    exportRepository : query () -> async Result.Result<ExportData, Text>;

    icrc120_upgrade_finished : query () -> async ICRC120UpgradeFinishedResult;
  };

  public type Delegate = {
    id : Principal;
    permissions : Permissions;
  };

  public type Permissions = {
    readLogs : Bool;
    deleteLogs : Bool;
    createRecord : Bool;
    putRecord : Bool;
    deleteRecord : Bool;
    modifyOwner : Bool;
  };

  public type InitializeRequest = {
    plcKind : PlcKind;
    hostname : Text;
    serviceSubdomain : ?Text;
  };

  public type InstallArgs = InitializeRequest and {
    owner : ?Principal;
  };

  public type InitializationStatus = {
    #notInitialized : {
      previousAttempt : ?FailedAttempt;
    };
    #initializing : {
      startTime : Time.Time;
      request : InitializeRequest;
    };
    #initialized : {
      startTime : Time.Time;
      endTime : Time.Time;
      request : InitializeRequest;
      info : ServerInfo;
    };
  };

  public type ServerInfo = {
    serviceSubdomain : ?Text;
    hostname : Text;
    plcIdentifier : Text;
  };

  public type FailedAttempt = {
    startTime : Time.Time;
    endTime : Time.Time;
    request : InitializeRequest;
    errorMessage : Text;
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

  public type ICRC120UpgradeFinishedResult = {
    #Failed : (Nat, Text);
    #Success : Nat;
    #InProgress : Nat;
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

  public type PlcKind = {
    #new : CreatePlcRequest;
    #id : Text;
    #car : Blob;
  };

  public type CreatePlcRequest = {
    alsoKnownAs : [Text];
    services : [PlcService];
  };

  public type PlcService = {
    id : Text;
    type_ : Text;
    endpoint : Text;
  };

  public type UpdatePlcRequest = {
    did : Text;
    alsoKnownAs : [Text];
    services : [PlcService];
  };
};
