/** Money is stored as whole paise (₹1 = 100) and returned to the app in rupees. */
export function rupeesToPaise(rupees: number): number {
  return Math.round(rupees * 100);
}

export function paiseToRupees(paise: number): number {
  return paise / 100;
}

/** Optional fields may be null; `required` handles presence separately. */
export const nonNegativeInteger = {
  validator: (value: number | null | undefined) =>
    value === null || value === undefined || (Number.isInteger(value) && value >= 0),
  message: '{PATH} must be a whole number of at least 0',
};

export const maskedCardNumberPattern = /^XXXX XXXX XXXX [A-Za-z0-9]{4}$/;

export function normalizeRegistration(value: string): string {
  return value.replace(/\s+/g, '').toUpperCase();
}

export function normalizeVin(value: string): string {
  return value.replace(/\s+/g, '').toUpperCase();
}
