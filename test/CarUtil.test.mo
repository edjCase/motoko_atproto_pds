import Result "mo:core@1/Result";
import Runtime "mo:core@1/Runtime";
import DID "mo:did@3";
import TID "mo:tid@1";
import Blob "mo:core@1/Blob";
import DagCbor "mo:dag-cbor@2";
import { test = testAsync } "mo:test/async";
import { test } "mo:test";
import Repository "mo:atproto@0/Repository";
import Sha256 "mo:sha2@0/Sha256";
import CarUtil "../src/CarUtil";
import CAR "mo:car@1";
import Debug "mo:core@1/Debug";
import CID "mo:cid@1";

// Helper to create test TID
func createTestTID(timestamp : Nat) : TID.TID {
  {
    timestamp = timestamp;
    clockId = 0;
  };
};

// Mock signing function for tests
func mockSignFunc(data : Blob) : async* Result.Result<Blob, Text> {
  // Return a deterministic "signature" for testing
  let hash = Sha256.fromBlob(#sha256, data);
  #ok(hash);
};

// Helper to create simple CBOR value
func createTestValue(text : Text) : DagCbor.Value {
  #map([
    ("type", #text("test.record")),
    ("value", #text(text)),
  ]);
};

await testAsync(
  "from/buildRepository",
  func() : async () {

    let repoId : DID.Plc.DID = { identifier = "test123456789abcdefghijk" };
    let initialRepository : Repository.Repository = switch (await* Repository.empty(repoId, createTestTID(1000000), mockSignFunc)) {
      case (#ok(r)) r;
      case (#err(e)) Runtime.trap("Setup failed: " # e);
    };
    var repository = initialRepository;

    let firstTID = createTestTID(1000001);

    let (newRepository, _) = switch (
      await* Repository.createRecord(
        repository,
        { collection = "app.bsky.feed.post"; recordKey = "post1" },
        createTestValue("test post"),
        repoId,
        firstTID,
        mockSignFunc,
      )
    ) {
      case (#ok((r, cid))) (r, cid);
      case (#err(e)) Runtime.trap("Create failed: " # e);
    };
    repository := newRepository;

    let (newRepository2, _) = switch (
      await* Repository.createRecord(
        repository,
        { collection = "app.bsky.feed.post"; recordKey = "post2" },
        createTestValue("another post"),
        repoId,
        createTestTID(1000002),
        mockSignFunc,
      )
    ) {
      case (#ok((r, cid))) (r, cid);
      case (#err(e)) Runtime.trap("Create failed: " # e);
    };
    repository := newRepository2;

    let carFile = switch (CarUtil.fromRepository(repository, #full({ includeHistorical = false }))) {
      case (#err(err)) Runtime.trap("Error creating CAR file: " # err);
      case (#ok(carFile)) carFile;
    };
    switch (CarUtil.toRepository(carFile)) {
      case (#err(err)) Runtime.trap("Error building repository: " # err);
      case (#ok((actualRepoId, actualRepo))) {
        if (repoId != actualRepoId) {
          Runtime.trap("Root CIDs do not match");
        };
        let expectedData = Repository.exportData(repository, #full({ includeHistorical = false }));
        let actualData = Repository.exportData(actualRepo, #full({ includeHistorical = false }));
        if (expectedData != actualData) {
          Runtime.trap("Repository data does not match\nExpected: " # debug_show (expectedData) # "\nActual: " # debug_show (actualData));
        };
      };
    };

    let partial : CAR.File = switch (CarUtil.fromRepository(repository, #since(newRepository.rev))) {
      case (#err(err)) Runtime.trap("Error creating partial CAR file: " # err);
      case (#ok(f)) f;
    };

    let expectedPartial : CAR.File = {
      header = {
        version = 1;
        roots = [repository.head];
      };
      blocks = [
        {
          cid = #v1({
            codec = #dagCbor;
            hash = "\02\B5\95\E7\59\B8\23\43\6E\B7\3E\0E\6E\9F\10\E6\66\1C\24\44\4B\58\66\DE\D0\F2\6A\72\37\31\84\83";
            hashAlgorithm = #sha2256;
          });
          data = "\A6\63\64\69\64\78\20\64\69\64\3A\70\6C\63\3A\74\65\73\74\31\32\33\34\35\36\37\38\39\61\62\63\64\65\66\67\68\69\6A\6B\63\72\65\76\6D\32\32\32\32\32\32\32\79\6B\6D\34\32\32\63\73\69\67\58\20\69\FF\44\5E\4A\EC\59\B9\17\C5\E4\C7\62\11\83\EC\0B\9E\01\5D\BD\07\55\47\B8\74\58\36\55\38\44\1E\64\64\61\74\61\D8\2A\58\25\00\01\71\12\20\60\02\16\CA\D9\FA\B7\B9\23\1A\7B\BC\9A\E6\30\8B\27\C7\0D\60\72\65\50\65\12\AD\45\11\3E\D1\20\51\64\70\72\65\76\D8\2A\58\25\00\01\71\12\20\80\43\3E\F3\63\2E\7D\DC\C6\56\C9\65\6E\A3\BC\89\13\C0\DB\F8\6D\7F\0F\F3\3F\F4\DE\FA\29\FA\A2\57\67\76\65\72\73\69\6F\6E\03";
        },
        {
          cid = #v1({
            codec = #dagCbor;
            hash = "\E1\03\ED\87\91\80\D7\97\AC\AD\4A\EA\8B\53\BD\C9\87\00\F3\79\D9\79\B8\91\11\EE\0E\99\01\C7\3B\CC";
            hashAlgorithm = #sha2256;
          });
          data = "\A2\64\74\79\70\65\6B\74\65\73\74\2E\72\65\63\6F\72\64\65\76\61\6C\75\65\6C\61\6E\6F\74\68\65\72\20\70\6F\73\74";
        },
        {
          cid = #v1({
            codec = #dagCbor;
            hash = "\60\02\16\CA\D9\FA\B7\B9\23\1A\7B\BC\9A\E6\30\8B\27\C7\0D\60\72\65\50\65\12\AD\45\11\3E\D1\20\51";
            hashAlgorithm = #sha2256;
          });
          data = "\A2\61\65\82\A4\61\6B\58\18\61\70\70\2E\62\73\6B\79\2E\66\65\65\64\2E\70\6F\73\74\2F\70\6F\73\74\31\61\70\00\61\74\F6\61\76\D8\2A\58\25\00\01\71\12\20\21\4A\3A\7C\E0\B3\4B\6B\E5\AD\27\E1\88\69\6F\CB\26\07\28\52\79\F9\EC\97\8D\B1\51\10\FE\73\C2\8D\A4\61\6B\41\32\61\70\17\61\74\F6\61\76\D8\2A\58\25\00\01\71\12\20\E1\03\ED\87\91\80\D7\97\AC\AD\4A\EA\8B\53\BD\C9\87\00\F3\79\D9\79\B8\91\11\EE\0E\99\01\C7\3B\CC\61\6C\F6";
        },
      ];
    };

    if (partial != expectedPartial) {
      Runtime.trap("Partial does not match expected\nExpected: " # debug_show (expectedPartial) # "\n\nActual: " # debug_show (partial));
    }

  },
);

test(
  "CAR decode ",
  func() {
    let carBytes : Blob = "\3a\a2\65\72\6f\6f\74\73\81\d8\2a\58\25\00\01\71\12\20\bc\3e\48\45\46\05\c2\e9\1f\68\fa\07\d8\50\45\23\87\57\8f\84\05\53\7a\f1\68\f0\2e\44\f5\bd\6e\59\67\76\65\72\73\69\6f\6e\01\88\02\01\71\12\20\bc\3e\48\45\46\05\c2\e9\1f\68\fa\07\d8\50\45\23\87\57\8f\84\05\53\7a\f1\68\f0\2e\44\f5\bd\6e\59\a6\63\64\69\64\78\20\64\69\64\3a\70\6c\63\3a\75\74\61\69\6c\79\36\73\73\68\6e\69\79\75\6f\75\68\6c\77\6c\68\35\79\32\63\72\65\76\6d\33\6d\36\36\61\6e\33\6d\35\76\70\32\33\63\73\69\67\58\40\b0\63\f0\f6\06\2a\dd\b0\97\b7\2e\1e\49\a1\81\19\51\b1\18\af\32\e7\83\78\2b\49\70\fd\03\4d\70\ec\0f\ac\24\de\f8\40\5d\7b\6e\91\62\02\26\44\2d\0a\75\65\92\8b\59\2d\83\75\a1\c5\6a\4b\3a\64\e4\a2\64\64\61\74\61\d8\2a\58\25\00\01\71\12\20\58\ac\94\45\2b\e4\dc\44\60\ed\02\cc\89\0b\68\70\63\a1\65\06\36\08\7b\49\5c\f7\a1\39\83\19\0e\a9\64\70\72\65\76\d8\2a\58\25\00\01\71\12\20\a3\7d\7a\cf\b8\88\9e\bf\17\b5\7a\84\fd\6c\28\ba\af\2c\37\ef\43\39\c6\a8\4c\b5\81\fe\1f\db\57\61\67\76\65\72\73\69\6f\6e\03\7a\01\71\12\20\dd\83\ec\93\7f\11\21\10\00\06\cf\ac\f8\bf\18\43\c0\dd\01\e5\20\2c\dd\31\f4\25\d3\ce\41\21\40\f3\a3\64\74\65\78\74\6c\48\65\6c\6c\6f\20\57\6f\72\6c\64\21\65\24\74\79\70\65\72\61\70\70\2e\62\73\6b\79\2e\66\65\65\64\2e\70\6f\73\74\69\63\72\65\61\74\65\64\41\74\78\1e\32\30\32\35\2d\31\31\2d\32\31\54\32\31\3a\33\39\3a\33\31\2e\35\33\33\36\38\35\36\34\37\5a\81\01\01\71\12\20\58\ac\94\45\2b\e4\dc\44\60\ed\02\cc\89\0b\68\70\63\a1\65\06\36\08\7b\49\5c\f7\a1\39\83\19\0e\a9\a2\61\65\81\a4\61\6b\58\20\61\70\70\2e\62\73\6b\79\2e\66\65\65\64\2e\70\6f\73\74\2f\33\6d\36\36\61\6e\33\6d\35\76\70\32\32\61\70\00\61\74\f6\61\76\d8\2a\58\25\00\01\71\12\20\dd\83\ec\93\7f\11\21\10\00\06\cf\ac\f8\bf\18\43\c0\dd\01\e5\20\2c\dd\31\f4\25\d3\ce\41\21\40\f3\61\6c\f6";
    let carfile = switch (CAR.fromBytes(carBytes.vals())) {
      case (#err(err)) Runtime.trap("Failed to decode CAR: " # err);
      case (#ok(carFile)) carFile;
    };
    Debug.print("CAR");
    Debug.print("Version: " # debug_show (carfile.header.version));
    Debug.print("Roots: " # debug_show (carfile.header.roots));
    for (block in carfile.blocks.vals()) {
      Debug.print("Block CID: " # CID.toText(block.cid));
      Debug.print("Block Data: " # debug_show (block.data));
    };
  },
);
