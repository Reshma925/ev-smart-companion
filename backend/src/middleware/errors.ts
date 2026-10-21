import type { ErrorRequestHandler, RequestHandler } from 'express';
import mongoose from 'mongoose';
import { ZodError } from 'zod';

import { logger } from '../logger.js';

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

export const notFound: RequestHandler = (_req, _res, next) => {
  next(new HttpError(404, 'not_found', 'The requested resource was not found.'));
};

export function zodMessage(error: ZodError): string {
  const issue = error.issues[0];
  if (!issue) return 'The request is invalid.';
  if (issue.code === 'unrecognized_keys') {
    return `Unknown field(s): ${issue.keys.join(', ')}.`;
  }
  const field = issue.path.join('.');
  return field ? `${field}: ${issue.message}` : issue.message;
}

export function createErrorHandler(options: {
  exposeInternalErrors: boolean;
}): ErrorRequestHandler {
  return (error: unknown, _req, res, next) => {
    if (res.headersSent) {
      next(error);
      return;
    }
    if (error instanceof HttpError) {
      res.status(error.status).json({ error: { code: error.code, message: error.message } });
      return;
    }
    if (error instanceof ZodError) {
      res.status(400).json({ error: { code: 'invalid_request', message: zodMessage(error) } });
      return;
    }
    if (
      error instanceof mongoose.Error.ValidationError ||
      error instanceof mongoose.Error.CastError
    ) {
      res.status(400).json({
        error: { code: 'invalid_request', message: 'The request contains invalid values.' },
      });
      return;
    }
    const type = (error as { type?: unknown } | null)?.type;
    if (type === 'entity.parse.failed') {
      res
        .status(400)
        .json({ error: { code: 'invalid_json', message: 'The request body is not valid JSON.' } });
      return;
    }
    if (type === 'entity.too.large') {
      res
        .status(413)
        .json({ error: { code: 'payload_too_large', message: 'The request body is too large.' } });
      return;
    }
    logger.error({ err: error }, 'Unhandled request error');
    res.status(500).json({
      error: {
        code: 'internal_error',
        message:
          options.exposeInternalErrors && error instanceof Error
            ? error.message
            : 'Something went wrong. Please try again.',
      },
    });
  };
}
