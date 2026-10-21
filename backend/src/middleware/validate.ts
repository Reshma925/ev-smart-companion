import type { Request, RequestHandler } from 'express';
import { z } from 'zod';

type Schemas = {
  body?: z.ZodObject;
  params?: z.ZodObject;
  query?: z.ZodObject;
};

/**
 * Validates body, params and query with strict schemas (unknown fields are
 * rejected) and stores the parsed values on req.valid. Express 5 makes
 * req.query read-only, so handlers read from req.valid instead.
 */
export function validate(schemas: Schemas): RequestHandler {
  const body = schemas.body?.strict();
  const params = schemas.params?.strict();
  const query = schemas.query?.strict();
  return (req, _res, next) => {
    req.valid = {
      body: body ? body.parse(req.body ?? {}) : undefined,
      params: params ? params.parse(req.params) : undefined,
      query: query ? query.parse(req.query) : undefined,
    };
    next();
  };
}

export function validBody<T extends z.ZodObject>(req: Request, _schema: T): z.infer<T> {
  return req.valid?.body as z.infer<T>;
}

export function validParams<T extends z.ZodObject>(req: Request, _schema: T): z.infer<T> {
  return req.valid?.params as z.infer<T>;
}

export function validQuery<T extends z.ZodObject>(req: Request, _schema: T): z.infer<T> {
  return req.valid?.query as z.infer<T>;
}
