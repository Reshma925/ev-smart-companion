import { Router } from 'express';
import mongoose from 'mongoose';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';

import { currentUser } from '../src/middleware/auth.js';
import { validate, validBody } from '../src/middleware/validate.js';
import { parseEnv } from '../src/config/env.js';
import { createApp } from '../src/app.js';
import { bearer, fakeVerifier, testApp } from './helpers.js';

const echoSchema = z.object({ name: z.string().max(10) });
const probe = Router();
probe.get('/probe', (req, res) => {
  res.json({ uid: currentUser(req).uid });
});
probe.post('/probe', validate({ body: echoSchema }), (req, res) => {
  res.json(validBody(req, echoSchema));
});

describe('app skeleton', () => {
  it('GET /health returns ok without auth or database', async () => {
    const response = await request(testApp()).get('/health');
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: 'ok' });
  });

  it('rejects /v1 requests without a token', async () => {
    const response = await request(testApp([probe])).get('/v1/probe');
    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('unauthenticated');
  });

  it('rejects /v1 requests with a bad token', async () => {
    const response = await request(testApp([probe]))
      .get('/v1/probe')
      .set('Authorization', 'Bearer not-a-real-token');
    expect(response.status).toBe(401);
  });

  it('accepts a valid token and exposes the user', async () => {
    const response = await request(testApp([probe]))
      .get('/v1/probe')
      .set(bearer('user-a'));
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ uid: 'user-a' });
  });

  it('rejects unknown body fields with 400', async () => {
    const response = await request(testApp([probe]))
      .post('/v1/probe')
      .set(bearer('user-a'))
      .send({ name: 'ok', admin: true });
    expect(response.status).toBe(400);
    expect(response.body.error.message).toContain('admin');
  });

  it('rejects malformed JSON with 400', async () => {
    const response = await request(testApp([probe]))
      .post('/v1/probe')
      .set(bearer('user-a'))
      .set('Content-Type', 'application/json')
      .send('{"name":');
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('invalid_json');
  });

  it('returns a JSON 404 for unknown routes', async () => {
    const response = await request(testApp()).get('/nope');
    expect(response.status).toBe(404);
    expect(response.body.error.code).toBe('not_found');
  });

  it('allows listed browser origins and no-origin clients only', async () => {
    const app = testApp();
    const allowed = await request(app).get('/health').set('Origin', 'http://localhost:5100');
    expect(allowed.headers['access-control-allow-origin']).toBe('http://localhost:5100');
    const blocked = await request(app).get('/health').set('Origin', 'https://evil.example');
    expect(blocked.headers['access-control-allow-origin']).toBeUndefined();
  });

  it('does not expose x-powered-by', async () => {
    const response = await request(testApp()).get('/health');
    expect(response.headers['x-powered-by']).toBeUndefined();
  });

  it('has the in-memory replica set connected for later tests', () => {
    expect(mongoose.connection.readyState).toBe(1);
  });
});

describe('production errors', () => {
  it('hide internal messages and stack traces', async () => {
    const failing = Router();
    failing.get('/boom', () => {
      throw new Error('secret internal detail at db.ts:42');
    });
    const app = createApp({
      nodeEnv: 'production',
      corsOrigins: [],
      verifyIdToken: fakeVerifier,
      routers: [failing],
    });
    const response = await request(app).get('/v1/boom').set(bearer('user-a'));
    expect(response.status).toBe(500);
    expect(response.body).toEqual({
      error: { code: 'internal_error', message: 'Something went wrong. Please try again.' },
    });
    expect(response.text).not.toContain('secret');
    expect(response.text).not.toContain('db.ts');
  });
});

describe('environment validation', () => {
  it('names missing variables without printing values', () => {
    const result = parseEnv({ MONGODB_URI: 'mongodb+srv://user:supersecret@host/' });
    expect(result.ok).toBe(false);
    if (result.ok) return;
    expect(result.problems).toContain('GEMINI_API_KEY is missing');
    expect(result.problems.join(' ')).not.toContain('supersecret');
  });
});
