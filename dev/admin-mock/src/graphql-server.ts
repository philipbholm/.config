import { ApolloServer } from "@apollo/server";
import { buildSubgraphSchema } from "@apollo/subgraph";
import fastifyApollo, {
  fastifyApolloDrainPlugin,
} from "@as-integrations/fastify";
import Fastify from "fastify";
import { readFileSync } from "fs";
import graphqlTag from "graphql-tag";
const gql = graphqlTag.default ?? graphqlTag;
import path from "path";
import { fileURLToPath } from "url";
import {
  allUsers,
  findByUserName,
  findByIds,
  type MockUser,
} from "./users.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function readSchema(filename: string) {
  return readFileSync(path.resolve(__dirname, "../api", filename), "utf-8");
}

function userToGraphQL(u: MockUser) {
  return {
    id: u.id,
    initials: `${u.firstName[0]}${u.lastName[0]}`,
    name: `${u.firstName} ${u.lastName}`,
    firstName: u.firstName,
    lastName: u.lastName,
    userName: u.userName,
    phoneNumbers: [{ value: u.phoneNumber }],
    emails: [{ value: u.email }],
    workplace: u.workplace,
    jobTitle: u.jobTitle,
    department: u.department,
    city: u.city,
    countryCode: u.countryCode,
    joinedOn: u.createdAt,
    status: u.status,
    subscriptionMemberships: [
      {
        subscription: { externalId: u.subscriptionId },
        isOwner: u.subscriptionIsOwner,
        licenseTier: u.licenseTier,
        status: "ACTIVE",
      },
    ],
  };
}

function buildMainServer(fastify: ReturnType<typeof Fastify>) {
  const typeDefs = gql(
    readSchema("admin.graphql") +
      '\nextend schema @link(url: "https://specs.apollo.dev/federation/v2.0", import: ["@key", "@shareable"])\n' +
      '\ntype User @key(fields: "id") {\n  id: ID!\n}\n'.replace(
        /type User \{[^}]+\}/,
        ""
      )
  );

  // Actually, we need to add federation directives properly.
  // Let's parse the schema with federation support.
  const rawSchema = readSchema("admin.graphql");
  // Add federation directives to User type
  const federatedSchema = rawSchema.replace(
    "type User {",
    'type User @key(fields: "id") {'
  );
  const federatedTypeDefs = gql`
    extend schema
      @link(
        url: "https://specs.apollo.dev/federation/v2.0"
        import: ["@key", "@shareable"]
      )
    ${federatedSchema}
  `;

  const resolvers = {
    Query: {
      listUsers: () => ({
        users: allUsers().map(userToGraphQL),
        total: allUsers().length,
      }),
      getUserFilterOptions: () => ({
        userFilterOptions: {
          statuses: ["ACTIVE", "INACTIVE"],
          workplaces: [
            ...new Set(allUsers().map((u) => u.workplace)),
          ],
        },
        subscriptionFilterOptions: {
          licenseTiers: ["FULL", "TRIAL", "COLLABORATOR", "NO_LICENSE"],
          subscriptions: [
            ...new Set(allUsers().map((u) => u.subscriptionId)),
          ],
        },
      }),
      getUserById: (_: unknown, { id }: { id: string }) => {
        const users = findByIds([id]);
        if (users.length === 0) throw new Error("User not found");
        return userToGraphQL(users[0]);
      },
      getLoggedInUser: () => ({
        user: userToGraphQL(findByUserName("stubbed-cognito-username")!),
      }),
      findCurrentLoggedInUser: () => ({
        user: userToGraphQL(findByUserName("stubbed-cognito-username")!),
      }),
      findUserIdentityByUserId: (_: unknown, { userId }: { userId: string }) => ({
        userId,
        userIdentity: {
          id: userId,
          userName: "stubbed-cognito-username",
          status: "CONFIRMED",
          disabled: false,
          createdOn: "2023-10-01T12:00:00Z",
          lastUpdatedOn: "2023-11-23T12:00:00Z",
          mfaSettings: ["AUTHENTICATOR_APP"],
          sso: false,
        },
      }),
      getPendingAuthFlowSteps: () => ({
        shouldCompleteUserDetails: false,
        shouldCompleteSubscription: false,
      }),
      listRelations: () => ({
        relations: [],
        nextCursor: null,
      }),
      getApprovalRequest: () => null,
      listApprovalRequests: () => ({
        approvalRequests: [],
        total: 0,
      }),
    },
    Mutation: {
      resetPassword: () => ({ success: true }),
      resetMfa: () => ({ success: true }),
      deactivateUser: () => ({ success: true }),
      reactivateUser: () => ({ success: true }),
      upsertMyProfile: () => ({ success: true }),
      startNewTrial: () => ({ subscriptionId: "mock-trial-sub" }),
      deleteRelations: () => ({ success: true }),
      changeApprovalStatus: () => ({ approvalRequest: null }),
    },
    User: {
      __resolveReference: (ref: { id: string }) => {
        const users = findByIds([ref.id]);
        if (users.length === 0) return null;
        return userToGraphQL(users[0]);
      },
    },
    Resource: {
      __resolveType: () => "User",
    },
    Subject: {
      __resolveType: () => "User",
    },
  };

  const schema = buildSubgraphSchema({ typeDefs: federatedTypeDefs, resolvers });
  return new ApolloServer({
    schema,
    plugins: [fastifyApolloDrainPlugin(fastify)],
  });
}

function buildPublicServer(fastify: ReturnType<typeof Fastify>) {
  const rawSchema = readSchema("admin-public.graphql");
  const typeDefs = gql`
    extend schema
      @link(
        url: "https://specs.apollo.dev/federation/v2.0"
        import: ["@key", "@shareable"]
      )
    ${rawSchema}
  `;

  const resolvers = {
    Query: {
      checkEmailDomain: () => ({ ssoProvider: null }),
      resolveAuthErrorDetails: () => ({
        title: "Authentication Error",
        description: "An error occurred during authentication.",
      }),
    },
  };

  const schema = buildSubgraphSchema({ typeDefs, resolvers });
  return new ApolloServer({
    schema,
    plugins: [fastifyApolloDrainPlugin(fastify)],
  });
}

export async function startGraphQLServer(port: number): Promise<void> {
  const fastify = Fastify({ logger: false });

  const mainServer = buildMainServer(fastify);
  const publicServer = buildPublicServer(fastify);

  await mainServer.start();
  await publicServer.start();

  await fastify.register(fastifyApollo(mainServer), { path: "/graphql" });
  await fastify.register(fastifyApollo(publicServer), { path: "/graphql-public" });

  fastify.get("/health", async () => ({ status: "ok" }));

  await fastify.listen({ port, host: "0.0.0.0" });
  console.log(`GraphQL server listening on port ${port}`);
  console.log(`  /graphql        — main admin subgraph`);
  console.log(`  /graphql-public — public admin subgraph`);
}
