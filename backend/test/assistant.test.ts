// Ported from the original learning-assistant tests.
import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

import { logger } from '../src/logger.js';
import { apiApp, fakeFetch, jsonResponse } from './fixtures.js';
import { bearer } from './helpers.js';

const ASK = '/v1/assistant/ask';
const geminiAnswer = (text: string) =>
  jsonResponse({ steps: [{ type: 'model_output', content: [{ type: 'text', text }] }] });

describe('learning assistant', () => {
  it('rejects empty and excessively long questions, topics and context', async () => {
    const gemini = fakeFetch(() => geminiAnswer('unused'));
    const app = apiApp({ geminiFetch: gemini.fetch });
    for (const body of [
      { message: '   ' },
      { message: 'x'.repeat(2001) },
      { message: 'ok', topic: 't'.repeat(121) },
      { message: 'ok', context: 'c'.repeat(2001) },
      { message: 'ok', extra: true },
    ]) {
      const response = await request(app).post(ASK).set(bearer('alice')).send(body);
      expect(response.status).toBe(400);
    }
    expect(gemini.requests).toHaveLength(0);
  });

  it('uses the server-side key and the same message/topic/context contract', async () => {
    const gemini = fakeFetch(() => geminiAnswer('Regenerative braking recovers energy.'));
    const response = await request(apiApp({ geminiFetch: gemini.fetch }))
      .post(ASK)
      .set(bearer('alice'))
      .send({ message: 'What is regen?', topic: 'Braking', context: '{"batteryPercent":80}' });
    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      success: true,
      answer: 'Regenerative braking recovers energy.',
    });

    const sent = gemini.requests[0];
    expect(sent?.url).toBe('https://generativelanguage.googleapis.com/v1beta/interactions');
    expect((sent?.init?.headers as Record<string, string>)['x-goog-api-key']).toBe(
      'test-only-gemini-key',
    );
    const body = JSON.parse(String(sent?.init?.body)) as Record<string, unknown>;
    expect(body.model).toBe('gemini-flash-latest');
    expect(body.store).toBe(false);
    expect(body.input).toBe(
      'Learning topic: Braking\n\nLearning context: {"batteryPercent":80}\n\nLearner question: What is regen?',
    );
    expect(String(body.system_instruction)).toContain('Do not diagnose vehicle faults');
    expect(JSON.stringify(response.body)).not.toContain('test-only-gemini-key');
  });

  it('sends a question without context and parses output_text', async () => {
    const gemini = fakeFetch(() => jsonResponse({ output_text: '  Charging basics.  ' }));
    const response = await request(apiApp({ geminiFetch: gemini.fetch }))
      .post(ASK)
      .set(bearer('alice'))
      .send({ message: 'How does charging work?' });
    expect(response.body.answer).toBe('Charging basics.');
    const body = JSON.parse(String(gemini.requests[0]?.init?.body)) as { input: string };
    expect(body.input).toBe(
      'Learning topic: EV learning\n\nLearner question: How does charging work?',
    );
  });

  it('logs provider errors without logging the API key and returns a safe message', async () => {
    const errorSpy = vi.spyOn(logger, 'error');
    const gemini = fakeFetch(() =>
      jsonResponse({ error: { message: 'Bad key test-only-gemini-key rejected' } }, 403),
    );
    const response = await request(apiApp({ geminiFetch: gemini.fetch }))
      .post(ASK)
      .set(bearer('alice'))
      .send({ message: 'Hello?' });
    expect(response.status).toBe(503);
    expect(response.body.error).toEqual({
      code: 'assistant_unavailable',
      message: 'The EV learning assistant is temporarily unavailable.',
    });
    const logged = JSON.stringify(errorSpy.mock.calls);
    expect(logged).toContain('[REDACTED]');
    expect(logged).not.toContain('test-only-gemini-key');
    errorSpy.mockRestore();
  });

  it('reports network failures and empty output as temporarily unavailable', async () => {
    for (const handler of [
      () => {
        throw new TypeError('fetch failed');
      },
      () => jsonResponse({ steps: [] }),
      () => new Response('not json', { status: 200 }),
    ]) {
      const response = await request(apiApp({ geminiFetch: fakeFetch(handler).fetch }))
        .post(ASK)
        .set(bearer('alice'))
        .send({ message: 'Hello?' });
      expect(response.status).toBe(503);
    }
  });

  it('limits each user to 20 questions per minute', async () => {
    const app = apiApp({ geminiFetch: fakeFetch(() => geminiAnswer('ok')).fetch });
    for (let i = 0; i < 20; i++) {
      expect(
        (await request(app).post(ASK).set(bearer('alice')).send({ message: 'q' })).status,
      ).toBe(200);
    }
    const limited = await request(app).post(ASK).set(bearer('alice')).send({ message: 'q' });
    expect(limited.status).toBe(429);
    // Another user is not affected.
    expect((await request(app).post(ASK).set(bearer('bob')).send({ message: 'q' })).status).toBe(
      200,
    );
  });
});
