import ServerInfo "../ServerInfo";
import Runtime "mo:core@1/Runtime";
import Time "mo:core@1/Time";
import Option "mo:core@1/Option";
import DID "mo:did@3";

module {
  public type StableData = State;

  public type State = {
    #notInitialized : {
      previousAttempt : ?FailedAttempt;
    };
    #initializing : {
      request : InitializeRequest;
      startTime : Time.Time;
    };
    #initialized : {
      startTime : Time.Time;
      endTime : Time.Time;
      request : InitializeRequest;
      info : ServerInfo.ServerInfo;
    };
  };

  public type InitializeRequest = {
    plcKind : PlcKind;
    hostname : Text;
    serviceSubdomain : ?Text;
  };

  public type FailedAttempt = {
    startTime : Time.Time;
    endTime : Time.Time;
    request : InitializeRequest;
    errorMessage : Text;
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

  public class Handler(stableData : ?StableData) {
    var state = Option.get(stableData, #notInitialized({ previousAttempt = null }));

    public func getState() : State {
      state;
    };

    public func get() : ServerInfo.ServerInfo {
      let #initialized({ info }) = state else Runtime.trap("Server is not initialized");
      info;
    };

    public func set(newState : State) : () {
      state := newState;
    };

    public func toStableData() : StableData = state;
  };
};
