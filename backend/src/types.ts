export type AuthUser = {
  uid: string;
  email: string | null;
  emailVerified: boolean;
};

export type ValidatedRequest = {
  body?: unknown;
  params?: unknown;
  query?: unknown;
};

declare module 'express-serve-static-core' {
  interface Request {
    user?: AuthUser;
    valid?: ValidatedRequest;
  }
}
