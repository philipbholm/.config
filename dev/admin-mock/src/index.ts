import { startGrpcServer } from "./grpc-server.js";
import { startGraphQLServer } from "./graphql-server.js";

const GRAPHQL_PORT = 4000;
const GRPC_PORT = 50051;

async function main() {
  console.log("Starting admin-mock...");

  await startGrpcServer(GRPC_PORT);
  await startGraphQLServer(GRAPHQL_PORT);

  console.log("admin-mock is ready.");
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
