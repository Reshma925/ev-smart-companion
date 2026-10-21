import { model, Schema, type InferSchemaType } from 'mongoose';

import { nonNegativeInteger } from './common.js';

const maintenanceRecordSchema = new Schema(
  {
    vehicleId: { type: String, required: true, maxlength: 64 },
    createdByUid: { type: String, required: true },
    serviceType: { type: String, required: true, trim: true, minlength: 1, maxlength: 80 },
    category: { type: String, required: true, trim: true, maxlength: 40 },
    serviceDate: { type: Date, required: true },
    nextServiceDate: { type: Date, default: null },
    odometerKm: { type: Number, min: 0, default: null },
    costPaise: { type: Number, default: null, validate: nonNegativeInteger },
    serviceCenter: { type: String, trim: true, maxlength: 120, default: '' },
    notes: { type: String, trim: true, maxlength: 1000, default: '' },
    status: { type: String, enum: ['Completed'], default: 'Completed' },
    source: { type: String, enum: ['user_entered'], default: 'user_entered' },
  },
  { timestamps: true, versionKey: false },
);

maintenanceRecordSchema.index({ vehicleId: 1, serviceDate: -1 });

export type MaintenanceRecordDocument = InferSchemaType<typeof maintenanceRecordSchema>;
export const MaintenanceRecord = model(
  'MaintenanceRecord',
  maintenanceRecordSchema,
  'maintenanceRecords',
);
