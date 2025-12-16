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

module {

  public type StableData = Log.State;

  public class Logger<system>(
    deployer : Principal,
    daoPrincipal : Principal,
    timerTool : TimerTool.TimerTool,
    initialState : ?StableData,
  ) {
    var state = switch (initialState) {
      case (?s) s;
      case (null) Log.initialState();
    };

    let initManager = ClassPlus.ClassPlusInitializationManager(
      deployer,
      daoPrincipal,
      true,
    );

    public let factory = Log.Init<system>({
      args = ?{
        min_level = ?#Debug;
        bufferSize = ?5000;
      };
      manager = initManager;
      initialState = state;
      pullEnvironment = ?(
        func() : Log.Environment {
          {
            tt = timerTool;
            advanced = null; // Add any advanced options if needed
            onEvict = null;
          };
        }
      );
      onInitialize = null;
      onStorageChange = func(newState : Log.State) {
        state := newState;
      };
    });

    public func toStableData() : StableData {
      state;
    };
  };
};
