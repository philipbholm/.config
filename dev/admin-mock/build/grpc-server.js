import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";
import path from "path";
import { fileURLToPath } from "url";
import { findByUserName, findByEmail, findByIds, } from "./users.js";
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROTO_DIR = path.resolve(__dirname, "../api");
const WORKSPACES = [
    { id: "stubbed-workspace-1", name: "Ledidi", customer_id: "stubbed-customer-id" },
    { id: "stubbed-workspace-2", name: "Demo Workspace", customer_id: "stubbed-customer-id" },
    // The two seeded ACME workspaces registries treats as able to store PII (see
    // services/registries/src/adapters/workspace-pii-encryption-keys.ts) and the
    // registries-frontend pins as SEEDED_WORKSPACE_IDS. GetWorkspacesForUser
    // returns every workspace to every user, so listing them here is what lets a
    // codelist-enabled registry pass createRegistry's workspace-membership guard
    // locally.
    { id: "019e8f0f-90cc-776f-ae76-4190088bad27", name: "ACME Project Alpha", customer_id: "stubbed-customer-id", pii_encryption_key_configured: true },
    { id: "019e8f0f-911a-716a-8a73-3077448eeff9", name: "ACME Project Beta", customer_id: "stubbed-customer-id", pii_encryption_key_configured: true },
];
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
const workspaceServiceImpl = {
    GetWorkspacesForUser(_call, callback) {
        callback(null, { workspaces: WORKSPACES });
    },
    ListWorkspaces(_call, callback) {
        callback(null, { items: WORKSPACES });
    },
    GetWorkspacePiiEncryptionKey(call, callback) {
        const workspace = WORKSPACES.find(({ id }) => id === call.request.workspace_id);
        callback(null, {
            pii_encryption_key_id: workspace?.pii_encryption_key_configured
                ? "local-mock-encryption-key"
                : undefined,
        });
    },
};
export async function startGrpcServer(port) {
    const packageDefinition = protoLoader.loadSync([
        path.join(PROTO_DIR, "admin.proto"),
        path.join(PROTO_DIR, "admin/v1/admin_workspace.proto"),
    ], {
        keepCase: true,
        longs: String,
        enums: String,
        defaults: true,
        oneofs: true,
        includeDirs: [PROTO_DIR],
    });
    const proto = grpc.loadPackageDefinition(packageDefinition);
    const server = new grpc.Server();
    server.addService(proto.admin.AdminService.service, serviceImpl);
    server.addService(proto.admin.v1.AdminWorkspaceService.service, workspaceServiceImpl);
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
