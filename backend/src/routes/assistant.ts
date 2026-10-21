import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import { z } from 'zod';

import { currentUser } from '../middleware/auth.js';
import { HttpError } from '../middleware/errors.js';
import { validate, validBody } from '../middleware/validate.js';
import {
  askLearningAssistant,
  MAX_CONTEXT_LENGTH,
  MAX_QUESTION_LENGTH,
  MAX_TOPIC_LENGTH,
  type AssistantConfig,
} from '../services/assistant.js';

const askSchema = z.object({
  message: z
    .string()
    .trim()
    .min(1, 'Enter a question to continue.')
    .max(MAX_QUESTION_LENGTH, 'Question is too long.'),
  topic: z.string().trim().min(1).max(MAX_TOPIC_LENGTH, 'Topic is too long.').optional(),
  context: z
    .string()
    .max(MAX_CONTEXT_LENGTH, 'Context must be at most 2,000 characters.')
    .optional(),
});

export function assistantRouter(config: AssistantConfig, perMinuteLimit = 20) {
  const router = Router();
  router.post(
    '/assistant/ask',
    rateLimit({
      windowMs: 60 * 1000,
      limit: perMinuteLimit,
      standardHeaders: 'draft-8',
      legacyHeaders: false,
      // Runs after requireAuth, so the limit is per signed-in user, not per IP.
      keyGenerator: (req) => currentUser(req).uid,
      handler: (_req, _res, next) =>
        next(
          new HttpError(
            429,
            'rate_limited',
            'You are asking questions too quickly. Please wait a minute.',
          ),
        ),
    }),
    validate({ body: askSchema }),
    async (req, res) => {
      const answer = await askLearningAssistant(config, validBody(req, askSchema));
      res.json({ success: true, answer });
    },
  );
  return router;
}
