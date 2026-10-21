import { model, Schema, Types, type InferSchemaType } from 'mongoose';

import { nonNegativeInteger } from './common.js';

// Mirrors paypalRechargeOrders in functions/card_backend.js (PENDING → COMPLETED).
const paypalOrderSchema = new Schema(
  {
    _id: { type: String, required: true, maxlength: 128 }, // PayPal order ID
    uid: { type: String, required: true },
    vehicleId: { type: String, required: true, maxlength: 64 },
    cardId: { type: Types.ObjectId, required: true, ref: 'ChargingCard' },
    amountPaise: { type: Number, required: true, validate: nonNegativeInteger },
    currency: { type: String, required: true, match: /^[A-Z]{3}$/ },
    paypalAmountCents: { type: Number, required: true, validate: nonNegativeInteger },
    paypalCurrency: { type: String, required: true, match: /^[A-Z]{3}$/ },
    conversionType: { type: String, required: true, maxlength: 40 },
    demoExchangeRate: { type: Number, required: true, min: 0 },
    status: { type: String, required: true, enum: ['PENDING', 'COMPLETED'], default: 'PENDING' },
    captureId: { type: String, maxlength: 128, default: null },
    transactionId: { type: Types.ObjectId, ref: 'CardTransaction', default: null },
    balanceAfterPaise: { type: Number, default: null, validate: nonNegativeInteger },
    completedAt: { type: Date, default: null },
  },
  { timestamps: true, versionKey: false },
);

export type PaypalOrderDocument = InferSchemaType<typeof paypalOrderSchema>;
export const PaypalOrder = model('PaypalOrder', paypalOrderSchema, 'paypalOrders');
