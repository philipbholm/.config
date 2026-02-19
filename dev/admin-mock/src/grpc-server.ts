import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";
import path from "path";
import { fileURLToPath } from "url";
import {
  findByUserName,
  findByEmail,
  findByIds,
  type MockUser,
} from "./users.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROTO_PATH = path.resolve(__dirname, "../api/admin.proto");

function userToProto(u: MockUser) {
  return {
    id: u.id,
    first_name: u.firstName,
    last_name: u.lastName,
    email_addresses: [u.email],
    user_name: u.userName,
  };
}

type GrpcCallback<T> = (err: grpc.ServiceError | null, response?: T) => void;

const serviceImpl = {
  GetUsersByIds(
    call: grpc.ServerUnaryCall<{ ids: string[] }, unknown>,
    callback: GrpcCallback<unknown>,
  ) {
    const users = findByIds(call.request.ids ?? []).map(userToProto);
    callback(null, { users });
  },

  GetUserByEmailAddress(
    call: grpc.ServerUnaryCall<{ email_address: string }, unknown>,
    callback: GrpcCallback<unknown>,
  ) {
    const u = findByEmail(call.request.email_address);
    if (!u) {
      callback({
        code: grpc.status.NOT_FOUND,
        message: `User not found: ${call.request.email_address}`,
        details: `User not found: ${call.request.email_address}`,
        name: "NOT_FOUND",
        metadata: new grpc.Metadata(),
      });
      return;
    }
    callback(null, { user: userToProto(u) });
  },

  GetUserByToken(
    _call: grpc.ServerUnaryCall<unknown, unknown>,
    callback: GrpcCallback<unknown>,
  ) {
    const u = findByUserName("stubbed-cognito-username")!;
    callback(null, { id: u.id, user_name: u.userName });
  },

  ResetUserPassword(
    _call: grpc.ServerUnaryCall<unknown, unknown>,
    callback: GrpcCallback<unknown>,
  ) {
    callback(null, { success: true });
  },

  ResetUserMfa(
    _call: grpc.ServerUnaryCall<unknown, unknown>,
    callback: GrpcCallback<unknown>,
  ) {
    callback(null, { success: true });
  },
};

export async function startGrpcServer(port: number): Promise<void> {
  const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
    keepCase: true,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true,
  });
  const proto = grpc.loadPackageDefinition(packageDefinition) as any;

  const server = new grpc.Server();
  server.addService(proto.admin.AdminService.service, serviceImpl);

  return new Promise((resolve, reject) => {
    server.bindAsync(
      `0.0.0.0:${port}`,
      grpc.ServerCredentials.createInsecure(),
      (err) => {
        if (err) {
          reject(err);
          return;
        }
        console.log(`gRPC server listening on port ${port}`);
        resolve();
      },
    );
  });
}
