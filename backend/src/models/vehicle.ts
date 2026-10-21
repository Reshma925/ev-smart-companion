import { model, Schema, type InferSchemaType } from 'mongoose';

import { normalizeRegistration, normalizeVin } from './common.js';

const vehicleSchema = new Schema(
  {
    _id: { type: String, required: true, trim: true, maxlength: 64 }, // e.g. EV001
    registrationNumber: {
      type: String,
      required: true,
      maxlength: 32,
      set: normalizeRegistration,
    },
    model: { type: String, required: true, trim: true, maxlength: 128 },
    ownerName: { type: String, required: true, trim: true, maxlength: 128 },
    vin: { type: String, required: true, maxlength: 64, set: normalizeVin },
    bluetoothDeviceId: { type: String, trim: true, maxlength: 64, default: '' },
    bluetoothDeviceName: { type: String, trim: true, maxlength: 64, default: '' },
    isActive: { type: Boolean, default: true },
    batteryCapacityKwh: {
      type: Number,
      default: null,
      validate: {
        validator: (value: number | null) => value === null || value > 0,
        message: 'batteryCapacityKwh must be greater than 0',
      },
    },
    maximumRangeKm: {
      type: Number,
      default: null,
      validate: {
        validator: (value: number | null) => value === null || value > 0,
        message: 'maximumRangeKm must be greater than 0',
      },
    },
    connectorType: { type: String, trim: true, maxlength: 40, default: '' },
    // One owner per vehicle. Claimed atomically with
    // findOneAndUpdate({ _id, ownerUid: null, isActive: true }, { ownerUid }).
    ownerUid: { type: String, default: null },
  },
  { timestamps: true, versionKey: false },
);

vehicleSchema.index({ registrationNumber: 1 }, { unique: true });
vehicleSchema.index({ vin: 1 }, { unique: true });
vehicleSchema.index({ ownerUid: 1 });

export type VehicleDocument = InferSchemaType<typeof vehicleSchema>;
export const Vehicle = model('Vehicle', vehicleSchema, 'vehicles');
