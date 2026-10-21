import { model, Schema, type InferSchemaType } from 'mongoose';

const userSchema = new Schema(
  {
    _id: { type: String, required: true }, // Firebase UID
    name: { type: String, required: true, trim: true, maxlength: 128 },
    email: { type: String, required: true, trim: true, lowercase: true, maxlength: 254 },
    phone: { type: String, trim: true, maxlength: 32, default: '' },
    city: { type: String, trim: true, maxlength: 80, default: '' },
    dateOfBirth: { type: Date, default: null },
    profileImageUrl: { type: String, trim: true, maxlength: 512, default: '' },
    preferredDrivingMode: { type: String, trim: true, maxlength: 40, default: '' },
    preferredChargingMode: { type: String, trim: true, maxlength: 40, default: '' },
    notificationPreference: { type: String, trim: true, maxlength: 40, default: '' },
    distanceUnit: { type: String, enum: ['km', 'mi'], default: 'km' },
    notificationsEnabled: { type: Boolean, default: true },
    locationEnabled: { type: Boolean, default: false },
    // The connected vehicle; the Flutter UserModel calls this vehicleId.
    vehicleId: { type: String, trim: true, maxlength: 64, default: null },
    vehicleRegistrationNumber: { type: String, trim: true, maxlength: 32, default: '' },
  },
  { timestamps: true, versionKey: false },
);

userSchema.index({ email: 1 });

export type UserDocument = InferSchemaType<typeof userSchema>;
export const User = model('User', userSchema, 'users');
