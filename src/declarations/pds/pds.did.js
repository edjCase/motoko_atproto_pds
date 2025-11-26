export const idlFactory = ({ IDL }) => {
  const Value__1 = IDL.Rec();
  const Result = IDL.Variant({ 'ok' : IDL.Null, 'err' : IDL.Text });
  const PlcService = IDL.Record({
    'id' : IDL.Text,
    'endpoint' : IDL.Text,
    'type' : IDL.Text,
  });
  const CreatePlcRequest = IDL.Record({
    'services' : IDL.Vec(PlcService),
    'alsoKnownAs' : IDL.Vec(IDL.Text),
  });
  const Result_2 = IDL.Variant({ 'ok' : IDL.Text, 'err' : IDL.Text });
  const CIDText = IDL.Text;
  const CID__1 = IDL.Record({ 'hash' : IDL.Vec(IDL.Nat8) });
  const Codec = IDL.Variant({
    'raw' : IDL.Null,
    'rsaPub' : IDL.Null,
    'blake2b256' : IDL.Null,
    'blake2s256' : IDL.Null,
    'secp256k1Pub' : IDL.Null,
    'x25519Pub' : IDL.Null,
    'sha2256' : IDL.Null,
    'sha2512' : IDL.Null,
    'sha3256' : IDL.Null,
    'sha3512' : IDL.Null,
    'p521Pub' : IDL.Null,
    'x448Pub' : IDL.Null,
    'bls12381G1Pub' : IDL.Null,
    'bls12381G2Pub' : IDL.Null,
    'dagCbor' : IDL.Null,
    'dagJson' : IDL.Null,
    'ed25519Pub' : IDL.Null,
    'ed448Pub' : IDL.Null,
    'dagPb' : IDL.Null,
    'p256Pub' : IDL.Null,
    'p384Pub' : IDL.Null,
  });
  const HashAlgorithm = IDL.Variant({
    'blake2b256' : IDL.Null,
    'blake2s256' : IDL.Null,
    'sha2256' : IDL.Null,
    'sha2512' : IDL.Null,
    'sha3256' : IDL.Null,
    'sha3512' : IDL.Null,
    'none' : IDL.Null,
  });
  const CID__2 = IDL.Record({
    'hash' : IDL.Vec(IDL.Nat8),
    'codec' : Codec,
    'hashAlgorithm' : HashAlgorithm,
  });
  const CID = IDL.Variant({ 'v0' : CID__1, 'v1' : CID__2 });
  Value__1.fill(
    IDL.Variant({
      'cid' : CID,
      'int' : IDL.Int,
      'map' : IDL.Vec(IDL.Tuple(IDL.Text, Value__1)),
      'float' : IDL.Float64,
      'array' : IDL.Vec(Value__1),
      'bool' : IDL.Bool,
      'null' : IDL.Null,
      'text' : IDL.Text,
      'bytes' : IDL.Vec(IDL.Nat8),
    })
  );
  const CreateRecordRequest = IDL.Record({
    'validate' : IDL.Opt(IDL.Bool),
    'collection' : IDL.Text,
    'swapCommit' : IDL.Opt(CIDText),
    'rkey' : IDL.Opt(IDL.Text),
    'record' : Value__1,
  });
  const ValidationStatus = IDL.Variant({
    'valid' : IDL.Null,
    'unknown' : IDL.Null,
  });
  const TIDText = IDL.Text;
  const CommitMeta = IDL.Record({ 'cid' : CIDText, 'rev' : TIDText });
  const CreateRecordResponse = IDL.Record({
    'cid' : CIDText,
    'validationStatus' : ValidationStatus,
    'rkey' : IDL.Text,
    'commit' : IDL.Opt(CommitMeta),
  });
  const Result_7 = IDL.Variant({
    'ok' : CreateRecordResponse,
    'err' : IDL.Text,
  });
  const DeleteRecordRequest = IDL.Record({
    'collection' : IDL.Text,
    'swapCommit' : IDL.Opt(CIDText),
    'rkey' : IDL.Text,
    'swapRecord' : IDL.Opt(CIDText),
  });
  const DeleteRecordResponse = IDL.Record({ 'commit' : IDL.Opt(CommitMeta) });
  const Result_6 = IDL.Variant({
    'ok' : DeleteRecordResponse,
    'err' : IDL.Text,
  });
  const Commit = IDL.Record({
    'did' : CIDText,
    'rev' : TIDText,
    'sig' : IDL.Vec(IDL.Nat8),
    'data' : CIDText,
    'prev' : IDL.Opt(CIDText),
    'version' : IDL.Nat,
  });
  const TreeEntry = IDL.Record({
    'keySuffix' : IDL.Vec(IDL.Nat8),
    'subtreeCID' : IDL.Opt(CID),
    'prefixLength' : IDL.Nat,
    'valueCID' : CID,
  });
  const Node = IDL.Record({
    'entries' : IDL.Vec(TreeEntry),
    'leftSubtreeCID' : IDL.Opt(CID),
  });
  const ExportData = IDL.Record({
    'records' : IDL.Vec(IDL.Tuple(CIDText, Value__1)),
    'commits' : IDL.Vec(IDL.Tuple(CIDText, Commit)),
    'nodes' : IDL.Vec(IDL.Tuple(CIDText, Node)),
  });
  const Result_5 = IDL.Variant({ 'ok' : ExportData, 'err' : IDL.Text });
  const LogLevel = IDL.Variant({
    'warning' : IDL.Null,
    'info' : IDL.Null,
    'verbose' : IDL.Null,
    'error' : IDL.Null,
    'debug' : IDL.Null,
    'fatal' : IDL.Null,
  });
  const LogEntry = IDL.Record({
    'time' : IDL.Int,
    'level' : LogLevel,
    'message' : IDL.Text,
  });
  const GetRecordRequest = IDL.Record({
    'cid' : IDL.Opt(CIDText),
    'collection' : IDL.Text,
    'rkey' : IDL.Text,
  });
  const GetRecordResponse = IDL.Record({ 'cid' : CIDText, 'value' : Value__1 });
  const Result_4 = IDL.Variant({ 'ok' : GetRecordResponse, 'err' : IDL.Text });
  const Header = IDL.Tuple(IDL.Text, IDL.Text);
  const RawQueryHttpRequest = IDL.Record({
    'url' : IDL.Text,
    'method' : IDL.Text,
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(Header),
    'certificate_version' : IDL.Opt(IDL.Nat16),
  });
  const StreamingToken = IDL.Vec(IDL.Nat8);
  const StreamingCallbackResponse = IDL.Record({
    'token' : IDL.Opt(StreamingToken),
    'body' : IDL.Vec(IDL.Nat8),
  });
  const StreamingCallback = IDL.Func(
      [StreamingToken],
      [StreamingCallbackResponse],
      ['query'],
    );
  const CallbackStreamingStrategy = IDL.Record({
    'token' : StreamingToken,
    'callback' : StreamingCallback,
  });
  const StreamingStrategy = IDL.Variant({
    'Callback' : CallbackStreamingStrategy,
  });
  const RawQueryHttpResponse = IDL.Record({
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(Header),
    'upgrade' : IDL.Opt(IDL.Bool),
    'streaming_strategy' : IDL.Opt(StreamingStrategy),
    'status_code' : IDL.Nat16,
  });
  const RawUpdateHttpRequest = IDL.Record({
    'url' : IDL.Text,
    'method' : IDL.Text,
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(Header),
  });
  const RawUpdateHttpResponse = IDL.Record({
    'body' : IDL.Vec(IDL.Nat8),
    'headers' : IDL.Vec(Header),
    'streaming_strategy' : IDL.Opt(StreamingStrategy),
    'status_code' : IDL.Nat16,
  });
  const PlcKind = IDL.Variant({
    'id' : IDL.Text,
    'car' : IDL.Vec(IDL.Nat8),
    'new' : CreatePlcRequest,
  });
  const InitializeRequest = IDL.Record({
    'plc' : PlcKind,
    'hostname' : IDL.Text,
    'serviceSubdomain' : IDL.Opt(IDL.Text),
  });
  const ListRecordsRequest = IDL.Record({
    'reverse' : IDL.Opt(IDL.Bool),
    'collection' : IDL.Text,
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat),
    'rkeyStart' : IDL.Opt(IDL.Text),
    'rkeyEnd' : IDL.Opt(IDL.Text),
  });
  const ListRecord = IDL.Record({
    'cid' : CIDText,
    'collection' : IDL.Text,
    'value' : Value__1,
    'rkey' : IDL.Text,
  });
  const ListRecordsResponse = IDL.Record({
    'records' : IDL.Vec(ListRecord),
    'cursor' : IDL.Opt(IDL.Text),
  });
  const Result_3 = IDL.Variant({
    'ok' : ListRecordsResponse,
    'err' : IDL.Text,
  });
  const PutRecordRequest = IDL.Record({
    'validate' : IDL.Opt(IDL.Bool),
    'collection' : IDL.Text,
    'swapCommit' : IDL.Opt(CIDText),
    'rkey' : IDL.Text,
    'swapRecord' : IDL.Opt(CIDText),
    'record' : Value__1,
  });
  const PutRecordResponse = IDL.Record({
    'cid' : CIDText,
    'validationStatus' : IDL.Opt(ValidationStatus),
    'commit' : IDL.Opt(CommitMeta),
  });
  const Result_1 = IDL.Variant({ 'ok' : PutRecordResponse, 'err' : IDL.Text });
  const UpdatePlcRequest = IDL.Record({
    'did' : IDL.Text,
    'services' : IDL.Vec(PlcService),
    'alsoKnownAs' : IDL.Vec(IDL.Text),
  });
  const Pds = IDL.Service({
    'clearLogs' : IDL.Func([], [Result], []),
    'createPlcDid' : IDL.Func([CreatePlcRequest], [Result_2], []),
    'createRecord' : IDL.Func([CreateRecordRequest], [Result_7], []),
    'deleteRecord' : IDL.Func([DeleteRecordRequest], [Result_6], []),
    'exportRepoData' : IDL.Func([], [Result_5], ['query']),
    'getDeployer' : IDL.Func([], [IDL.Principal], ['query']),
    'getLogs' : IDL.Func([IDL.Nat, IDL.Nat], [IDL.Vec(LogEntry)], ['query']),
    'getOwner' : IDL.Func([], [IDL.Principal], ['query']),
    'getRecord' : IDL.Func([GetRecordRequest], [Result_4], ['query']),
    'http_request' : IDL.Func(
        [RawQueryHttpRequest],
        [RawQueryHttpResponse],
        ['query'],
      ),
    'http_request_update' : IDL.Func(
        [RawUpdateHttpRequest],
        [RawUpdateHttpResponse],
        [],
      ),
    'initialize' : IDL.Func([InitializeRequest], [Result], []),
    'listRecords' : IDL.Func([ListRecordsRequest], [Result_3], ['query']),
    'postToBluesky' : IDL.Func([IDL.Text], [Result_2], []),
    'putRecord' : IDL.Func([PutRecordRequest], [Result_1], []),
    'setOwner' : IDL.Func([IDL.Principal], [Result], []),
    'updatePlcDid' : IDL.Func([UpdatePlcRequest], [Result], []),
  });
  return Pds;
};
export const init = ({ IDL }) => {
  return [IDL.Record({ 'owner' : IDL.Opt(IDL.Principal) })];
};
