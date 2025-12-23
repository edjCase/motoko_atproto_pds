import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export type CID = { 'v0' : CID__1 } |
  { 'v1' : CID__2 };
export type CIDText = string;
export interface CID__1 { 'hash' : Uint8Array | number[] }
export interface CID__2 {
  'hash' : Uint8Array | number[],
  'codec' : Codec,
  'hashAlgorithm' : HashAlgorithm,
}
export interface CallbackStreamingStrategy {
  'token' : StreamingToken,
  'callback' : [Principal, string],
}
export type Codec = { 'raw' : null } |
  { 'rsaPub' : null } |
  { 'blake2b256' : null } |
  { 'blake2s256' : null } |
  { 'secp256k1Pub' : null } |
  { 'x25519Pub' : null } |
  { 'sha2256' : null } |
  { 'sha2512' : null } |
  { 'sha3256' : null } |
  { 'sha3512' : null } |
  { 'p521Pub' : null } |
  { 'x448Pub' : null } |
  { 'bls12381G1Pub' : null } |
  { 'bls12381G2Pub' : null } |
  { 'dagCbor' : null } |
  { 'dagJson' : null } |
  { 'ed25519Pub' : null } |
  { 'ed448Pub' : null } |
  { 'dagPb' : null } |
  { 'p256Pub' : null } |
  { 'p384Pub' : null };
export interface Commit {
  'did' : CIDText,
  'rev' : TIDText,
  'sig' : Uint8Array | number[],
  'data' : CIDText,
  'prev' : [] | [CIDText],
  'version' : bigint,
}
export interface CommitMeta { 'cid' : CIDText, 'rev' : TIDText }
export interface CreatePlcRequest {
  'services' : Array<PlcService>,
  'alsoKnownAs' : Array<string>,
}
export interface CreateRecordRequest {
  'validate' : [] | [boolean],
  'collection' : string,
  'swapCommit' : [] | [CIDText],
  'rkey' : [] | [string],
  'record' : Value__1,
}
export interface CreateRecordResponse {
  'cid' : CIDText,
  'validationStatus' : ValidationStatus,
  'rkey' : string,
  'commit' : [] | [CommitMeta],
}
export interface Delegate { 'id' : Principal, 'permissions' : Permissions }
export interface DeleteRecordRequest {
  'collection' : string,
  'swapCommit' : [] | [CIDText],
  'rkey' : string,
  'swapRecord' : [] | [CIDText],
}
export interface DeleteRecordResponse { 'commit' : [] | [CommitMeta] }
export interface ExportData {
  'records' : Array<[CIDText, Value__1]>,
  'commits' : Array<[CIDText, Commit]>,
  'nodes' : Array<[CIDText, Node]>,
}
export interface FailedAttempt {
  'startTime' : Time,
  'endTime' : Time,
  'request' : InitializeRequest,
  'errorMessage' : string,
}
export interface GetRecordRequest {
  'cid' : [] | [CIDText],
  'collection' : string,
  'rkey' : string,
}
export interface GetRecordResponse { 'cid' : CIDText, 'value' : Value__1 }
export type HashAlgorithm = { 'blake2b256' : null } |
  { 'blake2s256' : null } |
  { 'sha2256' : null } |
  { 'sha2512' : null } |
  { 'sha3256' : null } |
  { 'sha3512' : null } |
  { 'none' : null };
export type Header = [string, string];
export type ICRC120UpgradeFinishedResult = { 'Failed' : [bigint, string] } |
  { 'Success' : bigint } |
  { 'InProgress' : bigint };
export type InitializationStatus = {
    'initialized' : {
      'startTime' : Time,
      'endTime' : Time,
      'request' : InitializeRequest,
      'info' : ServerInfo,
    }
  } |
  { 'notInitialized' : { 'previousAttempt' : [] | [FailedAttempt] } } |
  { 'initializing' : { 'startTime' : Time, 'request' : InitializeRequest } };
export interface InitializeRequest {
  'hostname' : string,
  'serviceSubdomain' : [] | [string],
  'plcKind' : PlcKind,
}
export interface InstallArgs {
  'owner' : [] | [Principal],
  'hostname' : string,
  'serviceSubdomain' : [] | [string],
  'plcKind' : PlcKind,
}
export interface ListRecord {
  'cid' : CIDText,
  'collection' : string,
  'value' : Value__1,
  'rkey' : string,
}
export interface ListRecordsRequest {
  'reverse' : [] | [boolean],
  'collection' : string,
  'cursor' : [] | [string],
  'limit' : [] | [bigint],
  'rkeyStart' : [] | [string],
  'rkeyEnd' : [] | [string],
}
export interface ListRecordsResponse {
  'records' : Array<ListRecord>,
  'cursor' : [] | [string],
}
export interface LogEntry {
  'time' : bigint,
  'level' : LogLevel,
  'message' : string,
}
export type LogLevel = { 'warning' : null } |
  { 'info' : null } |
  { 'verbose' : null } |
  { 'error' : null } |
  { 'debug' : null } |
  { 'fatal' : null };
export interface Node {
  'entries' : Array<TreeEntry>,
  'leftSubtreeCID' : [] | [CID],
}
export interface Pds {
  'clearLogs' : ActorMethod<[], Result>,
  'createRecord' : ActorMethod<[CreateRecordRequest], Result_6>,
  'deleteRecord' : ActorMethod<[DeleteRecordRequest], Result_5>,
  'exportRepository' : ActorMethod<[], Result_4>,
  'getDelegates' : ActorMethod<[], Array<Delegate>>,
  'getDeployer' : ActorMethod<[], Principal>,
  'getInitializationStatus' : ActorMethod<[], InitializationStatus>,
  'getLogs' : ActorMethod<[bigint, bigint], Array<LogEntry>>,
  'getOwner' : ActorMethod<[], Principal>,
  'getRecord' : ActorMethod<[GetRecordRequest], Result_3>,
  'http_request' : ActorMethod<[RawQueryHttpRequest], RawQueryHttpResponse>,
  'http_request_update' : ActorMethod<
    [RawUpdateHttpRequest],
    RawUpdateHttpResponse
  >,
  'icrc120_upgrade_finished' : ActorMethod<[], ICRC120UpgradeFinishedResult>,
  'listRecords' : ActorMethod<[ListRecordsRequest], Result_2>,
  'putRecord' : ActorMethod<[PutRecordRequest], Result_1>,
  'setDelegatePermissions' : ActorMethod<[Principal, Permissions], Result>,
  'setOwner' : ActorMethod<[Principal], Result>,
}
export interface Permissions {
  'createRecord' : boolean,
  'deleteRecord' : boolean,
  'readLogs' : boolean,
  'putRecord' : boolean,
  'deleteLogs' : boolean,
  'modifyOwner' : boolean,
}
export type PlcKind = { 'id' : string } |
  { 'car' : Uint8Array | number[] } |
  { 'new' : CreatePlcRequest };
export interface PlcService {
  'id' : string,
  'endpoint' : string,
  'type' : string,
}
export interface PutRecordRequest {
  'validate' : [] | [boolean],
  'collection' : string,
  'swapCommit' : [] | [CIDText],
  'rkey' : string,
  'swapRecord' : [] | [CIDText],
  'record' : Value__1,
}
export interface PutRecordResponse {
  'cid' : CIDText,
  'validationStatus' : [] | [ValidationStatus],
  'commit' : [] | [CommitMeta],
}
export interface RawQueryHttpRequest {
  'url' : string,
  'method' : string,
  'body' : Uint8Array | number[],
  'headers' : Array<Header>,
  'certificate_version' : [] | [number],
}
export interface RawQueryHttpResponse {
  'body' : Uint8Array | number[],
  'headers' : Array<Header>,
  'upgrade' : [] | [boolean],
  'streaming_strategy' : [] | [StreamingStrategy],
  'status_code' : number,
}
export interface RawUpdateHttpRequest {
  'url' : string,
  'method' : string,
  'body' : Uint8Array | number[],
  'headers' : Array<Header>,
}
export interface RawUpdateHttpResponse {
  'body' : Uint8Array | number[],
  'headers' : Array<Header>,
  'streaming_strategy' : [] | [StreamingStrategy],
  'status_code' : number,
}
export type Result = { 'ok' : null } |
  { 'err' : string };
export type Result_1 = { 'ok' : PutRecordResponse } |
  { 'err' : string };
export type Result_2 = { 'ok' : ListRecordsResponse } |
  { 'err' : string };
export type Result_3 = { 'ok' : GetRecordResponse } |
  { 'err' : string };
export type Result_4 = { 'ok' : ExportData } |
  { 'err' : string };
export type Result_5 = { 'ok' : DeleteRecordResponse } |
  { 'err' : string };
export type Result_6 = { 'ok' : CreateRecordResponse } |
  { 'err' : string };
export interface ServerInfo {
  'hostname' : string,
  'serviceSubdomain' : [] | [string],
  'plcIdentifier' : string,
}
export type StreamingCallback = ActorMethod<
  [StreamingToken],
  StreamingCallbackResponse
>;
export interface StreamingCallbackResponse {
  'token' : [] | [StreamingToken],
  'body' : Uint8Array | number[],
}
export type StreamingStrategy = { 'Callback' : CallbackStreamingStrategy };
export type StreamingToken = Uint8Array | number[];
export type TIDText = string;
export type Time = bigint;
export interface TreeEntry {
  'keySuffix' : Uint8Array | number[],
  'subtreeCID' : [] | [CID],
  'prefixLength' : bigint,
  'valueCID' : CID,
}
export type ValidationStatus = { 'valid' : null } |
  { 'unknown' : null };
export type Value__1 = { 'cid' : CID } |
  { 'int' : bigint } |
  { 'map' : Array<[string, Value__1]> } |
  { 'float' : number } |
  { 'array' : Array<Value__1> } |
  { 'bool' : boolean } |
  { 'null' : null } |
  { 'text' : string } |
  { 'bytes' : Uint8Array | number[] };
export interface _SERVICE extends Pds {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
