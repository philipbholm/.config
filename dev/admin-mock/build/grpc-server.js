import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";
import path from "path";
import { fileURLToPath } from "url";
import { findByUserName, findByEmail, findByIds, } from "./users.js";
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROTO_PATH = path.resolve(__dirname, "../api/admin.proto");
function userToProto(u) {
    return {
        id: u.id,
        first_name: u.firstName,
        last_name: u.lastName,
        email_addresses: [u.email],
        user_name: u.userName,
    };
}
const serviceImpl = {
    GetUsersByIds(call, callback) {
        const users = findByIds(call.request.ids ?? []).map(userToProto);
        callback(null, { users });
    },
    GetUserByEmailAddress(call, callback) {
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
    GetUserByToken(_call, callback) {
        const u = findByUserName("stubbed-cognito-username");
        callback(null, { id: u.id, user_name: u.userName });
    },
    ResetUserPassword(_call, callback) {
        callback(null, { success: true });
    },
    ResetUserMfa(_call, callback) {
        callback(null, { success: true });
    },
};
export async function startGrpcServer(port) {
    const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
        keepCase: true,
        longs: String,
        enums: String,
        defaults: true,
        oneofs: true,
    });
    const proto = grpc.loadPackageDefinition(packageDefinition);
    const server = new grpc.Server();
    server.addService(proto.admin.AdminService.service, serviceImpl);
    return new Promise((resolve, reject) => {
        server.bindAsync(`0.0.0.0:${port}`, grpc.ServerCredentials.createInsecure(), (err) => {
            if (err) {
                reject(err);
                return;
            }
            console.log(`gRPC server listening on port ${port}`);
            resolve();
        });
    });
}
