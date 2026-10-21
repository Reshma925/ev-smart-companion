import cors from 'cors';
import express, { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import helmet from 'helmet';
import { pinoHttp } from 'pino-http';

import { logger } from './logger.js';
import { requireAuth, type TokenVerifier } from './middleware/auth.js';
import { createErrorHandler, HttpError, notFound } from './middleware/errors.js';
import './types.js';

export type AppOptions = {
  nodeEnv: 'development' | 'test' | 'production';
  corsOrigins: string[];
  verifyIdToken: TokenVerifier;
  /** Feature routers mounted under /v1 behind requireAuth. */
  routers?: Router[];
  globalRateLimit?: number;
};

export function createApp(options: AppOptions) {
  const app = express();
  app.disable('x-powered-by');
  // Render terminates TLS in one proxy hop; trust it so rate limits see the client IP.
  if (options.nodeEnv === 'production') app.set('trust proxy', 1);

  app.use(helmet());
  app.use(
    cors({
      origin(origin, callback) {
        // Mobile apps send no Origin header; browsers must be on the allow list.
        callback(null, !origin || options.corsOrigins.includes(origin));
      },
      allowedHeaders: ['Authorization', 'Content-Type'],
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
      maxAge: 600,
    }),
  );
  app.use(pinoHttp({ logger, autoLogging: { ignore: (req) => req.url === '/health' } }));
  app.use(
    rateLimit({
      windowMs: 15 * 60 * 1000,
      limit: options.globalRateLimit ?? 300,
      standardHeaders: 'draft-8',
      legacyHeaders: false,
      handler: (_req, _res, next) =>
        next(new HttpError(429, 'rate_limited', 'Too many requests. Please wait and try again.')),
    }),
  );
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  const v1 = Router();
  v1.use(requireAuth(options.verifyIdToken));
  for (const router of options.routers ?? []) v1.use(router);
  app.use('/v1', v1);

  app.use(notFound);
  app.use(createErrorHandler({ exposeInternalErrors: options.nodeEnv !== 'production' }));
  return app;
}
