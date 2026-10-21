import { Router } from 'express';
import { z } from 'zod';

import { currentUser } from '../middleware/auth.js';
import { validate, validBody, validParams, validQuery } from '../middleware/validate.js';
import { maskedCardNumberPattern, paiseToRupees } from '../models/common.js';
import {
  debitConfirmedSession,
  getCard,
  listTransactions,
  registerCard,
  updateCard,
} from '../services/cards.js';
import {
  captureRechargeOrder,
  createRechargeOrder,
  type PayPalConfig,
} from '../services/paypal.js';
import { chargingCardJson, transactionJson } from '../services/serialize.js';
import { isoDate, requiredText, vehicleIdParams } from './schemas.js';

const cardLastFour = z.string().regex(/^[A-Za-z0-9]{4}$/, 'must be exactly 4 letters or digits');
const maskedCardNumber = z
  .string()
  .regex(maskedCardNumberPattern, 'must look like XXXX XXXX XXXX 1234');

// Strict schemas: a full cardNumber, cvv or pin is an unknown field and gets 400.
const registerSchema = z.object({
  cardType: requiredText(40),
  cardLastFour,
  maskedCardNumber,
  cardHolderName: requiredText(80),
  expiryDate: isoDate,
  currency: z
    .string()
    .regex(/^[A-Z]{3}$/)
    .optional(),
});

const updateSchema = z.object({
  cardType: requiredText(40),
  cardHolderName: requiredText(80),
  expiryDate: isoDate,
  cardLastFour: cardLastFour.optional(),
  maskedCardNumber: maskedCardNumber.optional(),
});

const transactionsQuery = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

const createOrderSchema = z.object({ amountInr: z.number() });
const orderParams = vehicleIdParams.extend({
  orderId: z.string().regex(/^[A-Za-z0-9_-]{1,128}$/, 'Invalid PayPal order ID.'),
});
const sessionParams = z.object({
  sessionId: z.string().regex(/^[A-Za-z0-9_-]{1,128}$/, 'Invalid charging-session ID.'),
});

export function chargingCardRouter(paypal: PayPalConfig) {
  const router = Router();
  const base = '/vehicles/:vehicleId/charging-card';

  router.get(base, validate({ params: vehicleIdParams }), async (req, res) => {
    const { vehicleId } = validParams(req, vehicleIdParams);
    const card = await getCard(currentUser(req).uid, vehicleId);
    res.json({ card: card ? chargingCardJson(card) : null });
  });

  router.post(
    base,
    validate({ params: vehicleIdParams, body: registerSchema }),
    async (req, res) => {
      const { vehicleId } = validParams(req, vehicleIdParams);
      const card = await registerCard(
        currentUser(req).uid,
        vehicleId,
        validBody(req, registerSchema),
      );
      res.status(201).json({ card: chargingCardJson(card) });
    },
  );

  router.patch(
    base,
    validate({ params: vehicleIdParams, body: updateSchema }),
    async (req, res) => {
      const { vehicleId } = validParams(req, vehicleIdParams);
      const card = await updateCard(currentUser(req).uid, vehicleId, validBody(req, updateSchema));
      res.json({ card: chargingCardJson(card) });
    },
  );

  router.get(
    `${base}/transactions`,
    validate({ params: vehicleIdParams, query: transactionsQuery }),
    async (req, res) => {
      const { vehicleId } = validParams(req, vehicleIdParams);
      const { limit } = validQuery(req, transactionsQuery);
      const transactions = await listTransactions(currentUser(req).uid, vehicleId, limit);
      res.json({ transactions: transactions.map(transactionJson) });
    },
  );

  router.post(
    `${base}/paypal-orders`,
    validate({ params: vehicleIdParams, body: createOrderSchema }),
    async (req, res) => {
      const { vehicleId } = validParams(req, vehicleIdParams);
      const { amountInr } = validBody(req, createOrderSchema);
      res
        .status(201)
        .json(await createRechargeOrder(paypal, currentUser(req).uid, vehicleId, amountInr));
    },
  );

  router.post(
    `${base}/paypal-orders/:orderId/capture`,
    validate({ params: orderParams }),
    async (req, res) => {
      const { vehicleId, orderId } = validParams(req, orderParams);
      res.json(await captureRechargeOrder(paypal, currentUser(req).uid, vehicleId, orderId));
    },
  );

  router.post(
    '/charging-sessions/:sessionId/debit',
    validate({ params: sessionParams }),
    async (req, res) => {
      const { sessionId } = validParams(req, sessionParams);
      const result = await debitConfirmedSession(currentUser(req).uid, sessionId);
      res.json({
        alreadyDebited: result.alreadyDebited,
        transactionId: result.transactionId,
        vehicleId: result.vehicleId,
        ...(result.balanceBeforePaise === undefined
          ? {}
          : { balanceBefore: paiseToRupees(result.balanceBeforePaise) }),
        balanceAfter: paiseToRupees(result.balanceAfterPaise),
      });
    },
  );

  return router;
}
