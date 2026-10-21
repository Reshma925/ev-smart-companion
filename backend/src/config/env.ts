import { z } from 'zod';

const required = z.string().trim().min(1);

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(8081),
  MONGODB_URI: required.refine(
    (value) => value.startsWith('mongodb://') || value.startsWith('mongodb+srv://'),
    'must start with mongodb:// or mongodb+srv://',
  ),
  MONGODB_DB_NAME: required,
  FIREBASE_PROJECT_ID: required,
  CORS_ORIGINS: required,
  GEMINI_API_KEY: required,
  GEMINI_MODEL: required,
  PAYPAL_CLIENT_ID: required,
  PAYPAL_CLIENT_SECRET: required,
  PAYPAL_API_BASE: z.url().refine((value) => value.startsWith('https://'), 'must use https://'),
  DEMO_EXCHANGE_RATE_INR_TO_USD: z.coerce.number().positive(),
});

export const envVariableNames = Object.keys(envSchema.shape) as (keyof typeof envSchema.shape)[];

export type Env = {
  nodeEnv: 'development' | 'test' | 'production';
  port: number;
  mongodbUri: string;
  mongodbDbName: string;
  firebaseProjectId: string;
  corsOrigins: string[];
  geminiApiKey: string;
  geminiModel: string;
  paypalClientId: string;
  paypalClientSecret: string;
  paypalApiBase: string;
  demoExchangeRateInrToUsd: number;
};

export type EnvResult = { ok: true; env: Env } | { ok: false; problems: string[] };

/** Validates the environment. Problems name the variable, never its value. */
export function parseEnv(source: NodeJS.ProcessEnv): EnvResult {
  const result = envSchema.safeParse(source);
  if (!result.success) {
    const problems = result.error.issues.map((issue) => {
      const name = String(issue.path[0] ?? 'environment');
      return source[name] === undefined || source[name] === ''
        ? `${name} is missing`
        : `${name} is invalid (${issue.message})`;
    });
    return { ok: false, problems };
  }
  const value = result.data;
  return {
    ok: true,
    env: {
      nodeEnv: value.NODE_ENV,
      port: value.PORT,
      mongodbUri: value.MONGODB_URI,
      mongodbDbName: value.MONGODB_DB_NAME,
      firebaseProjectId: value.FIREBASE_PROJECT_ID,
      corsOrigins: value.CORS_ORIGINS.split(',')
        .map((origin) => origin.trim())
        .filter(Boolean),
      geminiApiKey: value.GEMINI_API_KEY,
      geminiModel: value.GEMINI_MODEL,
      paypalClientId: value.PAYPAL_CLIENT_ID,
      paypalClientSecret: value.PAYPAL_CLIENT_SECRET,
      paypalApiBase: value.PAYPAL_API_BASE.replace(/\/+$/, ''),
      demoExchangeRateInrToUsd: value.DEMO_EXCHANGE_RATE_INR_TO_USD,
    },
  };
}

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const result = parseEnv(source);
  if (!result.ok) {
    console.error('Invalid backend configuration. Fix these in backend/.env:');
    for (const problem of result.problems) console.error(`  - ${problem}`);
    process.exit(1);
  }
  return result.env;
}
