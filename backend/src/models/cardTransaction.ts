import { model, Schema, Types, type InferSchemaType } from 'mongoose';

import { nonNegativeInteger } from './common.js';

// Field values follow the original backend: type "credit" (PayPal recharge)
// or "debit" (confirmed charging session), status "completed".
const cardTransactionSchema = new Schema(
  {
    cardId: { type: Types.ObjectId, required: true, ref: 'ChargingCard' },
    uid: { type: String, required: true },
    vehicleId: { type: String, required: true, maxlength: 64 },
    type: { type: String, required: true, enum: ['credit', 'debit'] },
    amountPaise: { type: Number, required: true, validate: nonNegativeInteger },
    balanceBeforePaise: { type: Number, required: true, validate: nonNegativeInteger },
    balanceAfterPaise: { type: Number, required: true, validate: nonNegativeInteger },
    currency: { type: String, required: true, match: /^[A-Z]{3}$/ },
    status: { type: String, required: true, default: 'completed', maxlength: 20 },
    description: { type: String, default: '', maxlength: 200 },
    timestamp: { type: Date, required: true },
    // Debit (charging session) details.
    stationId: { type: String, maxlength: 128 },
    stationName: { type: String, maxlength: 200 },
    operator: { type: String, maxlength: 200 },
    sessionReferenceId: { type: String, maxlength: 128 },
    // Credit (PayPal Sandbox) details.
    paymentProvider: { type: String, maxlength: 40 },
    paymentMethod: { type: String, maxlength: 40 },
    paypalOrderId: { type: String, maxlength: 128 },
    paypalCaptureId: { type: String, maxlength: 128 },
    paypalAmountCents: { type: Number, validate: nonNegativeInteger },
    paypalCurrency: { type: String, match: /^[A-Z]{3}$/ },
    conversionType: { type: String, maxlength: 40 },
    demoExchangeRate: { type: Number, min: 0 },
  },
  { timestamps: true, versionKey: false },
);

cardTransactionSchema.index({ cardId: 1, createdAt: -1 });
// No double credit or double debit, even under concurrent requests.
cardTransactionSchema.index({ paypalOrderId: 1 }, { unique: true, sparse: true });
cardTransactionSchema.index({ paypalCaptureId: 1 }, { unique: true, sparse: true });
cardTransactionSchema.index({ sessionReferenceId: 1 }, { unique: true, sparse: true });

export type CardTransactionDocument = InferSchemaType<typeof cardTransactionSchema>;
export const CardTransaction = model('CardTransaction', cardTransactionSchema, 'cardTransactions');
