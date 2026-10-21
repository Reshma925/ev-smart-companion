import { model, Schema, Types, type InferSchemaType } from 'mongoose';

import { nonNegativeInteger } from './common.js';

// Mirrors chargingSessions in functions/card_backend.js: a trusted session is
// status "confirmed" with debitStatus "pending", and becomes "completed" once
// debitConfirmedChargingSession has charged the card.
const chargingSessionSchema = new Schema(
  {
    _id: { type: String, required: true, match: /^[A-Za-z0-9_-]{1,128}$/ },
    uid: { type: String, required: true },
    vehicleId: { type: String, required: true, maxlength: 64 },
    stationId: { type: String, default: '', maxlength: 128 },
    stationName: { type: String, default: '', maxlength: 200 },
    operator: { type: String, default: '', maxlength: 200 },
    energyKwh: { type: Number, min: 0, default: null },
    amountPaise: { type: Number, required: true, validate: nonNegativeInteger },
    currency: { type: String, default: 'INR', match: /^[A-Z]{3}$/ },
    status: { type: String, required: true, default: 'confirmed', maxlength: 20 },
    debitStatus: {
      type: String,
      required: true,
      enum: ['pending', 'completed'],
      default: 'pending',
    },
    confirmedAt: { type: Date, default: null },
    debitTransactionId: { type: Types.ObjectId, ref: 'CardTransaction', default: null },
    balanceBeforePaise: { type: Number, default: null, validate: nonNegativeInteger },
    balanceAfterPaise: { type: Number, default: null, validate: nonNegativeInteger },
    debitedAt: { type: Date, default: null },
  },
  { timestamps: true, versionKey: false },
);

chargingSessionSchema.index({ uid: 1, createdAt: -1 });

export type ChargingSessionDocument = InferSchemaType<typeof chargingSessionSchema>;
export const ChargingSession = model('ChargingSession', chargingSessionSchema, 'chargingSessions');
