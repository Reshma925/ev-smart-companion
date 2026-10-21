import { HttpError } from '../middleware/errors.js';

export const badRequest = (message: string, code = 'invalid_request') =>
  new HttpError(400, code, message);

export const notFound = (message: string, code = 'not_found') => new HttpError(404, code, message);

export const conflict = (message: string, code = 'conflict') => new HttpError(409, code, message);

export const unavailable = (message: string, code = 'service_unavailable') =>
  new HttpError(503, code, message);

export const vehicleNotFound = () =>
  notFound("Vehicle not found, or you don't have access to it.", 'vehicle_not_found');

/** Mongo duplicate-key error (unique index violation). */
export function isDuplicateKeyError(error: unknown): boolean {
  return (error as { code?: unknown } | null)?.code === 11000;
}
