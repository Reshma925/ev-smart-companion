import { z } from 'zod';

export const vehicleIdParams = z.object({
  vehicleId: z.string().regex(/^[A-Za-z0-9_-]{1,64}$/, 'Invalid vehicle ID.'),
});

/** Accepts any ISO-8601 date or date-time string and returns a Date. */
export const isoDate = z
  .string()
  .trim()
  .max(40)
  .refine((value) => !Number.isNaN(Date.parse(value)), 'must be an ISO-8601 date')
  .transform((value) => new Date(value));

export const text = (max: number) => z.string().trim().max(max);
export const requiredText = (max: number) => z.string().trim().min(1, 'is required').max(max);

export const vehicleDetails = {
  registrationNumber: requiredText(32),
  model: requiredText(256),
  ownerName: requiredText(256),
  vin: requiredText(64),
};

/** Money in rupees with at most two decimals. */
export const rupees = z
  .number()
  .finite()
  .min(0)
  .max(10_000_000)
  .refine(
    (value) => Math.abs(value * 100 - Math.round(value * 100)) < 1e-7,
    'must have at most two decimals',
  );
