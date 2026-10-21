import { model, Schema, type InferSchemaType } from 'mongoose';

// Refresh tokens are opaque `<id>.<secret>` strings. Only a SHA-256 hash of
// the secret is stored. Each refresh replaces the token (rotation); using a
// replaced token again revokes the whole family (reuse detection).
const refreshTokenSchema = new Schema(
  {
    _id: { type: String, required: true },
    userId: { type: String, required: true },
    familyId: { type: String, required: true },
    secretHash: { type: String, required: true },
    expiresAt: { type: Date, required: true },
    revokedAt: { type: Date, default: null },
    replacedBy: { type: String, default: null },
  },
  { timestamps: true, versionKey: false },
);

refreshTokenSchema.index({ userId: 1 });
refreshTokenSchema.index({ familyId: 1 });
// MongoDB removes expired tokens automatically.
refreshTokenSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export type RefreshTokenDocument = InferSchemaType<typeof refreshTokenSchema>;
export const RefreshToken = model('RefreshToken', refreshTokenSchema, 'refreshTokens');
