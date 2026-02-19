export type MockUser = {
  id: string;
  userName: string;
  firstName: string;
  lastName: string;
  email: string;
  phoneNumber: string;
  city: string;
  countryCode: string;
  department: string;
  jobTitle: string;
  status: string;
  workplace: string;
  createdAt: string;
  updatedAt: string;
  licenseTier: string;
  subscriptionId: string;
  subscriptionIsOwner: boolean;
};

const USERS: MockUser[] = [
  {
    id: "019576a1b2c3d4e5f6a7b8c9d0e1f2a3",
    userName: "kari.jonsson",
    firstName: "Kari",
    lastName: "Jonsson",
    email: "kari.jonsson@example.com",
    phoneNumber: "+354-555-0123",
    city: "Reykjavik",
    countryCode: "IS",
    department: "Engineering",
    jobTitle: "Software Engineer",
    status: "ACTIVE",
    workplace: "ACME Corp",
    createdAt: "2023-10-01T12:00:00Z",
    updatedAt: "2023-11-23T12:00:00Z",
    licenseTier: "FULL",
    subscriptionId: "169lhoSs940S24gWp",
    subscriptionIsOwner: true,
  },
  {
    id: "019576a2b3c4d5e6f7a8b9c0d1e2f3a4",
    userName: "anna.svensson",
    firstName: "Anna",
    lastName: "Svensson",
    email: "anna.svensson@example.com",
    phoneNumber: "+46-555-0124",
    city: "Stockholm",
    countryCode: "SE",
    department: "Marketing",
    jobTitle: "Marketing Manager",
    status: "ACTIVE",
    workplace: "Tech Solutions",
    createdAt: "2023-10-02T12:00:00Z",
    updatedAt: "2023-11-24T12:00:00Z",
    licenseTier: "TRIAL",
    subscriptionId: "169lhoSs9Yr734xYs",
    subscriptionIsOwner: false,
  },
  {
    id: "019576a3b4c5d6e7f8a9b0c1d2e3f4a5",
    userName: "john.doe",
    firstName: "John",
    lastName: "Doe",
    email: "john.doe@example.com",
    phoneNumber: "+1-555-0125",
    city: "New York",
    countryCode: "US",
    department: "Sales",
    jobTitle: "Sales Representative",
    status: "ACTIVE",
    workplace: "Global Corp",
    createdAt: "2023-10-03T12:00:00Z",
    updatedAt: "2023-11-25T12:00:00Z",
    licenseTier: "FULL",
    subscriptionId: "169lhoSs940S24gWp",
    subscriptionIsOwner: false,
  },
  {
    id: "019576a4b5c6d7e8f9a0b1c2d3e4f5a6",
    userName: "jane.smith",
    firstName: "Jane",
    lastName: "Smith",
    email: "jane.smith@example.com",
    phoneNumber: "+1-555-0126",
    city: "Los Angeles",
    countryCode: "US",
    department: "Design",
    jobTitle: "UI/UX Designer",
    status: "ACTIVE",
    workplace: "Creative Agency",
    createdAt: "2023-10-04T12:00:00Z",
    updatedAt: "2023-11-26T12:00:00Z",
    licenseTier: "FULL",
    subscriptionId: "169lhoSs9Yr734xYs",
    subscriptionIsOwner: false,
  },
  {
    id: "019576a5b6c7d8e9f0a1b2c3d4e5f6a7",
    userName: "bob.johnson",
    firstName: "Bob",
    lastName: "Johnson",
    email: "bob.johnson@example.com",
    phoneNumber: "+1-555-0127",
    city: "San Francisco",
    countryCode: "US",
    department: "Engineering",
    jobTitle: "Backend Developer",
    status: "ACTIVE",
    workplace: "Innovative Tech",
    createdAt: "2023-10-05T12:00:00Z",
    updatedAt: "2023-11-27T12:00:00Z",
    licenseTier: "FULL",
    subscriptionId: "169lhoSs9Yr734xYs",
    subscriptionIsOwner: false,
  },
  {
    id: "stubbed-ledidi-user-id",
    userName: "stubbed-cognito-username",
    firstName: "Stubbed",
    lastName: "Cognito",
    email: "stubbed-cognito-username@example.com",
    phoneNumber: "+1-555-0128",
    city: "San Francisco",
    countryCode: "US",
    department: "Engineering",
    jobTitle: "Backend Developer",
    status: "ACTIVE",
    workplace: "Innovative Tech",
    createdAt: "2023-10-05T12:00:00Z",
    updatedAt: "2023-11-27T12:00:00Z",
    licenseTier: "FULL",
    subscriptionId: "stubbed-customer-id",
    subscriptionIsOwner: false,
  },
  {
    id: "019576a7b8c9d0e1f2a3b4c5d6e7f8a9",
    userName: "supportAdmin",
    firstName: "Support",
    lastName: "Admin",
    email: "support.admin@example.com",
    phoneNumber: "+4756745321",
    city: "Oslo",
    countryCode: "NO",
    department: "Support",
    jobTitle: "Support Administrator",
    status: "ACTIVE",
    workplace: "Ledidi",
    createdAt: "2023-10-06T12:00:00Z",
    updatedAt: "2023-11-28T12:00:00Z",
    licenseTier: "FULL",
    subscriptionId: "ledidi-support-subscription",
    subscriptionIsOwner: true,
  },
  {
    id: "019576a8b9c0d1e2f3a4b5c6d7e8f9a0",
    userName: "systemAdmin",
    firstName: "System",
    lastName: "Admin",
    email: "system.admin@ledidi.com",
    phoneNumber: "+4756745322",
    city: "Oslo",
    countryCode: "NO",
    department: "IT",
    jobTitle: "System Administrator",
    status: "ACTIVE",
    workplace: "Ledidi",
    createdAt: "2023-10-07T12:00:00Z",
    updatedAt: "2023-11-29T12:00:00Z",
    licenseTier: "FULL",
    subscriptionId: "ledidi-system-admin-subscription",
    subscriptionIsOwner: true,
  },
];

export function findByUserName(userName: string): MockUser | undefined {
  return USERS.find((u) => u.userName === userName);
}

export function findByEmail(email: string): MockUser | undefined {
  return USERS.find((u) => u.email === email);
}

export function findByIds(ids: string[]): MockUser[] {
  return USERS.filter((u) => ids.includes(u.id) || ids.includes(u.userName));
}

export function allUsers(): MockUser[] {
  return USERS;
}
