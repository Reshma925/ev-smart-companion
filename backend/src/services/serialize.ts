// JSON shapes match the Flutter fromMap() field names. Money is converted from
// paise to rupees and dates are ISO-8601 strings.
import type { Types } from 'mongoose';

import { paiseToRupees } from '../models/common.js';

type WithTimestamps = { createdAt?: Date | null; updatedAt?: Date | null };

const iso = (value: Date | null | undefined) => (value ? value.toISOString() : null);
const rupees = (value: number | null | undefined) =>
  value === null || value === undefined ? null : paiseToRupees(value);

export type UserRecord = WithTimestamps & {
  _id: string;
  name: string;
  email: string;
  phone?: string | null;
  city?: string | null;
  dateOfBirth?: Date | null;
  profileImageUrl?: string | null;
  preferredDrivingMode?: string | null;
  preferredChargingMode?: string | null;
  notificationPreference?: string | null;
  distanceUnit?: string | null;
  notificationsEnabled?: boolean | null;
  locationEnabled?: boolean | null;
  vehicleId?: string | null;
  vehicleRegistrationNumber?: string | null;
};

export function userJson(user: UserRecord) {
  return {
    uid: user._id,
    name: user.name,
    email: user.email,
    phone: user.phone ?? '',
    city: user.city ?? '',
    dateOfBirth: iso(user.dateOfBirth),
    profileImageUrl: user.profileImageUrl ?? '',
    preferredDrivingMode: user.preferredDrivingMode ?? '',
    preferredChargingMode: user.preferredChargingMode ?? '',
    notificationPreference: user.notificationPreference ?? '',
    distanceUnit: user.distanceUnit ?? 'km',
    notificationsEnabled: user.notificationsEnabled ?? true,
    locationEnabled: user.locationEnabled ?? false,
    vehicleId: user.vehicleId ?? null,
    vehicleRegistrationNumber: user.vehicleRegistrationNumber ?? '',
    createdAt: iso(user.createdAt),
    updatedAt: iso(user.updatedAt),
  };
}

export type VehicleRecord = WithTimestamps & {
  _id: string;
  registrationNumber: string;
  model: string;
  ownerName: string;
  vin: string;
  bluetoothDeviceId?: string | null;
  bluetoothDeviceName?: string | null;
  isActive?: boolean | null;
  batteryCapacityKwh?: number | null;
  maximumRangeKm?: number | null;
  connectorType?: string | null;
  ownerUid?: string | null;
};

/** Vehicle metadata only: live measurements come from BLE, never from here. */
export function vehicleJson(vehicle: VehicleRecord) {
  return {
    id: vehicle._id,
    model: vehicle.model,
    registrationNumber: vehicle.registrationNumber,
    ownerName: vehicle.ownerName,
    vin: vehicle.vin,
    bluetoothDeviceId: vehicle.bluetoothDeviceId ?? '',
    bluetoothDeviceName: vehicle.bluetoothDeviceName ?? '',
    isActive: vehicle.isActive === true,
    batteryCapacityKwh: vehicle.batteryCapacityKwh ?? null,
    maximumRangeKm: vehicle.maximumRangeKm ?? null,
    connectorType: vehicle.connectorType ?? '',
    createdAt: iso(vehicle.createdAt),
  };
}

export type MaintenanceRecordRecord = WithTimestamps & {
  _id: Types.ObjectId;
  vehicleId: string;
  serviceType: string;
  category: string;
  serviceDate: Date;
  nextServiceDate?: Date | null;
  odometerKm?: number | null;
  costPaise?: number | null;
  serviceCenter?: string | null;
  notes?: string | null;
  status?: string | null;
  source?: string | null;
};

export function maintenanceJson(record: MaintenanceRecordRecord) {
  return {
    id: record._id.toString(),
    vehicleId: record.vehicleId,
    serviceType: record.serviceType,
    category: record.category,
    serviceDate: iso(record.serviceDate),
    nextServiceDate: iso(record.nextServiceDate),
    odometerKm: record.odometerKm ?? null,
    cost: rupees(record.costPaise),
    serviceCenter: record.serviceCenter ?? '',
    notes: record.notes ?? '',
    status: record.status ?? 'Completed',
    source: record.source ?? 'user_entered',
    createdAt: iso(record.createdAt),
    updatedAt: iso(record.updatedAt),
  };
}

export type ChargingCardRecord = WithTimestamps & {
  _id: Types.ObjectId;
  vehicleId: string;
  cardType: string;
  maskedCardNumber: string;
  cardLastFour: string;
  cardHolderName: string;
  expiryDate: Date;
  balancePaise: number;
  currency: string;
  status: string;
  vehicleModel?: string | null;
  vehicleRegistrationNumber?: string | null;
  vehicleVin?: string | null;
  lastRechargePaise?: number | null;
  lastRechargeAt?: Date | null;
};

export function chargingCardJson(card: ChargingCardRecord) {
  return {
    id: card._id.toString(),
    cardType: card.cardType,
    maskedCardNumber: card.maskedCardNumber,
    cardLastFour: card.cardLastFour,
    cardHolderName: card.cardHolderName,
    balance: paiseToRupees(card.balancePaise),
    currency: card.currency,
    status: card.status,
    vehicleId: card.vehicleId,
    vehicleModel: card.vehicleModel ?? '',
    vehicleRegistrationNumber: card.vehicleRegistrationNumber ?? '',
    vehicleVin: card.vehicleVin ?? '',
    expiryDate: iso(card.expiryDate),
    registeredAt: iso(card.createdAt),
    lastRechargeAmount: rupees(card.lastRechargePaise),
    lastRechargeDate: iso(card.lastRechargeAt),
  };
}

export type CardTransactionRecord = {
  _id: Types.ObjectId;
  cardId: Types.ObjectId;
  vehicleId: string;
  type: string;
  amountPaise: number;
  balanceBeforePaise: number;
  balanceAfterPaise: number;
  currency: string;
  status: string;
  description?: string | null;
  timestamp: Date;
  stationId?: string | null;
  stationName?: string | null;
  operator?: string | null;
  sessionReferenceId?: string | null;
  paymentProvider?: string | null;
  paymentMethod?: string | null;
  paypalOrderId?: string | null;
  paypalCaptureId?: string | null;
  paypalAmountCents?: number | null;
  paypalCurrency?: string | null;
  conversionType?: string | null;
  demoExchangeRate?: number | null;
};

export function transactionJson(transaction: CardTransactionRecord) {
  return {
    id: transaction._id.toString(),
    cardId: transaction.cardId.toString(),
    vehicleId: transaction.vehicleId,
    type: transaction.type,
    amount: paiseToRupees(transaction.amountPaise),
    balanceBefore: paiseToRupees(transaction.balanceBeforePaise),
    balanceAfter: paiseToRupees(transaction.balanceAfterPaise),
    currency: transaction.currency,
    status: transaction.status,
    description: transaction.description ?? '',
    timestamp: iso(transaction.timestamp),
    stationId: transaction.stationId ?? null,
    stationName: transaction.stationName ?? null,
    operator: transaction.operator ?? null,
    sessionReferenceId: transaction.sessionReferenceId ?? null,
    paymentProvider: transaction.paymentProvider ?? null,
    paymentMethod: transaction.paymentMethod ?? null,
    paypalOrderId: transaction.paypalOrderId ?? null,
    paypalCaptureId: transaction.paypalCaptureId ?? null,
    paypalAmount:
      transaction.paypalAmountCents === null || transaction.paypalAmountCents === undefined
        ? null
        : transaction.paypalAmountCents / 100,
    paypalCurrency: transaction.paypalCurrency ?? null,
    conversionType: transaction.conversionType ?? null,
    demoExchangeRate: transaction.demoExchangeRate ?? null,
  };
}
