import { model, Schema, type InferSchemaType } from 'mongoose';

import { maskedCardNumberPattern, nonNegativeInteger } from './common.js';

// Never stores a full card number, CVV, PIN or payment password: only the
// masked number and its last four characters.
const chargingCardSchema = new Schema(
  {
    uid: { type: String, required: true },
    vehicleId: { type: String, required: true, maxlength: 64 },
    cardType: { type: String, required: true, trim: true, minlength: 1, maxlength: 40 },
    maskedCardNumber: { type: String, required: true, match: maskedCardNumberPattern },
    cardLastFour: { type: String, required: true, match: /^[A-Za-z0-9]{4}$/ },
    cardHolderName: { type: String, required: true, trim: true, minlength: 1, maxlength: 80 },
    expiryDate: { type: Date, required: true },
    balancePaise: { type: Number, required: true, default: 0, validate: nonNegativeInteger },
    currency: { type: String, required: true, default: 'INR', match: /^[A-Z]{3}$/ },
    status: { type: String, required: true, default: 'ACTIVE', maxlength: 20 },
    // Snapshot of the vehicle, kept in sync when the vehicle configuration changes.
    vehicleModel: { type: String, default: '', maxlength: 128 },
    vehicleRegistrationNumber: { type: String, default: '', maxlength: 32 },
    vehicleVin: { type: String, default: '', maxlength: 64 },
    lastRechargePaise: { type: Number, default: null, validate: nonNegativeInteger },
    lastRechargeAt: { type: Date, default: null },
  },
  { timestamps: true, versionKey: false, strict: 'throw' },
);

chargingCardSchema.index({ uid: 1, vehicleId: 1 }, { unique: true });

export type ChargingCardDocument = InferSchemaType<typeof chargingCardSchema>;
export const ChargingCard = model('ChargingCard', chargingCardSchema, 'chargingCards');
