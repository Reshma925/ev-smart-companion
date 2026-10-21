import { model, Schema, type InferSchemaType } from 'mongoose';

export const MAX_PROFILE_PHOTO_BYTES = 300 * 1024;

// Replaces Firebase Storage for profile photos.
const profilePhotoSchema = new Schema(
  {
    _id: { type: String, required: true }, // Firebase UID
    contentType: { type: String, required: true, enum: ['image/jpeg', 'image/png'] },
    data: {
      type: Buffer,
      required: true,
      validate: {
        validator: (value: Buffer) => value.length > 0 && value.length <= MAX_PROFILE_PHOTO_BYTES,
        message: `Profile photo must be at most ${MAX_PROFILE_PHOTO_BYTES / 1024} KB`,
      },
    },
  },
  { timestamps: true, versionKey: false },
);

export type ProfilePhotoDocument = InferSchemaType<typeof profilePhotoSchema>;
export const ProfilePhoto = model('ProfilePhoto', profilePhotoSchema, 'profilePhotos');
