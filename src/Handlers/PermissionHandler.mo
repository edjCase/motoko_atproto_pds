import PureMap "mo:core@1/pure/Map";
import Runtime "mo:core@1/Runtime";
import Principal "mo:core@1/Principal";
import Iter "mo:core@1/Iter";

module {

    public type StableData = {
        owner : Principal;
        delegates : PureMap.Map<Principal, DelegateInfo>;
    };

    public type DelegateInfo = {
        permissions : Permissions;
    };

    public type Delegate = DelegateInfo and {
        id : Principal;
    };

    public type Permissions = {
        readLogs : Bool;
        deleteLogs : Bool;
        createRecord : Bool;
        putRecord : Bool;
        deleteRecord : Bool;
        modifyOwner : Bool;
    };

    public type Action = {
        #readLogs;
        #deleteLogs;
        #createRecord;
        #putRecord;
        #deleteRecord;
        #modifyOwner;
    };

    public class Handler(stableData : StableData) {
        var owner = stableData.owner;
        var delegates = stableData.delegates;

        public func authorizeActionOrTrap(entity : Principal, action : Action) : () {
            if (not isActionAuthorized(entity, action)) {
                Runtime.trap("Permission denied for action '" # debug_show (action) # "' for entity '" # debug_show (entity) # "'.");
            };
        };

        public func isActionAuthorized(entity : Principal, action : Action) : Bool {
            if (entity == owner) {
                return true;
            };
            let ?delegate = PureMap.get(delegates, Principal.compare, entity) else return false;
            switch (action) {
                case (#readLogs) delegate.permissions.readLogs;
                case (#deleteLogs) delegate.permissions.deleteLogs;
                case (#createRecord) delegate.permissions.createRecord;
                case (#putRecord) delegate.permissions.putRecord;
                case (#deleteRecord) delegate.permissions.deleteRecord;
                case (#modifyOwner) delegate.permissions.modifyOwner;
            };
        };

        public func authorizeIsOwnerOrTrap(entity : Principal) : () {
            if (entity != owner) {
                Runtime.trap("Permission denied: entity '" # debug_show (entity) # "' is not the owner.");
            };
        };

        public func isOwner(entity : Principal) : Bool {
            return entity == owner;
        };

        public func setPermissions(entity : Principal, permissions : Permissions) : () {
            delegates := PureMap.add(
                delegates,
                Principal.compare,
                entity,
                {
                    permissions = permissions;
                },
            );
        };

        public func getOwner() : Principal {
            return owner;
        };

        public func getDelegates() : [Delegate] {
            PureMap.entries(delegates)
            |> Iter.map(
                _,
                func((id, info) : (Principal, DelegateInfo)) : Delegate = {
                    id = id;
                    permissions = info.permissions;
                },
            )
            |> Iter.toArray(_);
        };

        public func setOwner(newOwner : Principal) : () {
            owner := newOwner;
        };

        public func toStableData() : StableData {
            return {
                owner = owner;
                delegates = delegates;
            };
        };
    };
};
