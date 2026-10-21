import mongoose from 'mongoose';

import { CardTransaction } from '../models/cardTransaction.js';
import { ChargingCard } from '../models/chargingCard.js';
import { ChargingSession } from '../models/chargingSession.js';
import { badRequest, conflict, isDuplicateKeyError, notFound } from './errors.js';
import type { CardTransactionRecord, ChargingCardRecord } from './serialize.js';
import { requireOwnedVehicle } from './vehicles.js';

export function maskedFromLastFour(lastFour: string): string {
  return `XXXX XXXX XXXX ${lastFour}`;
}

function requireConsistentMask(cardLastFour: string, maskedCardNumber: string) {
  if (maskedCardNumber !== maskedFromLastFour(cardLastFour)) {
    throw badRequest('maskedCardNumber must be XXXX XXXX XXXX followed by cardLastFour.');
  }
}

export async function getCard(uid: string, vehicleId: string): Promise<ChargingCardRecord | null> {
  await requireOwnedVehicle(uid, vehicleId, { requireActive: false });
  return ChargingCard.findOne({ uid, vehicleId }).lean<ChargingCardRecord>();
}

export type RegisterCardInput = {
  cardType: string;
  cardLastFour: string;
  maskedCardNumber: string;
  cardHolderName: string;
  expiryDate: Date;
  currency?: string;
};

export async function registerCard(
  uid: string,
  vehicleId: string,
  input: RegisterCardInput,
): Promise<ChargingCardRecord> {
  const vehicle = await requireOwnedVehicle(uid, vehicleId);
  requireConsistentMask(input.cardLastFour, input.maskedCardNumber);
  try {
    const [card] = await ChargingCard.create([
      {
        uid,
        vehicleId,
        cardType: input.cardType,
        cardLastFour: input.cardLastFour,
        maskedCardNumber: input.maskedCardNumber,
        cardHolderName: input.cardHolderName,
        expiryDate: input.expiryDate,
        currency: input.currency ?? 'INR',
        balancePaise: 0,
        status: 'ACTIVE',
        vehicleModel: vehicle.model,
        vehicleRegistrationNumber: vehicle.registrationNumber,
        vehicleVin: vehicle.vin,
      },
    ]);
    return card!.toObject() as ChargingCardRecord;
  } catch (error) {
    if (isDuplicateKeyError(error)) {
      throw conflict('A charging card is already registered for this vehicle.', 'card_exists');
    }
    throw error;
  }
}

export type UpdateCardInput = {
  cardType: string;
  cardHolderName: string;
  expiryDate: Date;
  cardLastFour?: string;
  maskedCardNumber?: string;
};

/** Balance, status and currency can never change here. */
export async function updateCard(
  uid: string,
  vehicleId: string,
  input: UpdateCardInput,
): Promise<ChargingCardRecord> {
  const vehicle = await requireOwnedVehicle(uid, vehicleId);
  const updates: Record<string, unknown> = {
    cardType: input.cardType,
    cardHolderName: input.cardHolderName,
    expiryDate: input.expiryDate,
    vehicleModel: vehicle.model,
    vehicleRegistrationNumber: vehicle.registrationNumber,
    vehicleVin: vehicle.vin,
  };
  if (input.cardLastFour !== undefined || input.maskedCardNumber !== undefined) {
    if (input.cardLastFour === undefined || input.maskedCardNumber === undefined) {
      throw badRequest('Send cardLastFour and maskedCardNumber together.');
    }
    requireConsistentMask(input.cardLastFour, input.maskedCardNumber);
    updates.cardLastFour = input.cardLastFour;
    updates.maskedCardNumber = input.maskedCardNumber;
  }
  const card = await ChargingCard.findOneAndUpdate({ uid, vehicleId }, updates, {
    new: true,
    runValidators: true,
  }).lean<ChargingCardRecord>();
  if (!card) throw notFound('No charging card is registered for this vehicle.', 'card_not_found');
  return card;
}

export async function listTransactions(
  uid: string,
  vehicleId: string,
  limit: number,
): Promise<CardTransactionRecord[]> {
  await requireOwnedVehicle(uid, vehicleId, { requireActive: false });
  const card = await ChargingCard.findOne({ uid, vehicleId }, { _id: 1 }).lean();
  if (!card) return [];
  return CardTransaction.find({ cardId: card._id })
    .sort({ timestamp: -1, _id: -1 })
    .limit(limit)
    .lean<CardTransactionRecord[]>();
}

export type DebitResult = {
  alreadyDebited: boolean;
  transactionId: string;
  vehicleId: string;
  balanceBeforePaise?: number;
  balanceAfterPaise: number;
};

/**
 * Ported from debitConfirmedChargingSession: debits only a trusted, confirmed
 * session, in one transaction, at most once. Insufficient balance changes nothing.
 */
export async function debitConfirmedSession(uid: string, sessionId: string): Promise<DebitResult> {
  const run = () =>
    mongoose.connection.transaction(async (session): Promise<DebitResult> => {
      const charging = await ChargingSession.findById(sessionId).session(session).lean();
      // Another user's session is reported exactly like a missing one.
      if (!charging || charging.uid !== uid) {
        throw notFound('No trusted charging-session confirmation was found.', 'session_not_found');
      }
      const vehicleId = charging.vehicleId;
      await requireOwnedVehicle(uid, vehicleId);

      if (charging.debitStatus === 'completed') {
        const existing = await CardTransaction.findOne({ sessionReferenceId: sessionId })
          .session(session)
          .lean<CardTransactionRecord>();
        if (!existing) {
          throw conflict(
            'The completed session has no charging transaction.',
            'session_inconsistent',
          );
        }
        return {
          alreadyDebited: true,
          transactionId: existing._id.toString(),
          vehicleId,
          balanceAfterPaise: existing.balanceAfterPaise,
        };
      }
      if (charging.status !== 'confirmed' || charging.debitStatus !== 'pending') {
        throw conflict(
          'The charging session is not trusted and confirmed.',
          'session_not_confirmed',
        );
      }
      const card = await ChargingCard.findOne({ uid, vehicleId }).session(session);
      if (!card) {
        throw notFound('No charging card is registered for this vehicle.', 'card_not_found');
      }
      const amountPaise = charging.amountPaise;
      if (!Number.isInteger(amountPaise) || amountPaise <= 0) {
        throw conflict(
          'The session amount or charging-card balance is invalid.',
          'session_invalid',
        );
      }
      const balanceBeforePaise = card.balancePaise;
      if (balanceBeforePaise < amountPaise) {
        throw conflict('Insufficient charging card balance.', 'insufficient_balance');
      }
      const balanceAfterPaise = balanceBeforePaise - amountPaise;
      const currency = (charging.currency ?? card.currency).trim().toUpperCase();
      if (!/^[A-Z]{3}$/.test(currency)) {
        throw conflict(
          'The confirmed charging session has an invalid currency.',
          'session_invalid',
        );
      }
      const now = new Date();
      card.balancePaise = balanceAfterPaise;
      await card.save({ session });
      const [transaction] = await CardTransaction.create(
        [
          {
            cardId: card._id,
            uid,
            vehicleId,
            type: 'debit',
            amountPaise,
            balanceBeforePaise,
            balanceAfterPaise,
            currency,
            stationId: charging.stationId ?? '',
            stationName: charging.stationName ?? '',
            operator: charging.operator ?? '',
            sessionReferenceId: sessionId,
            timestamp: charging.confirmedAt ?? now,
            status: 'completed',
            description: 'Confirmed charging session',
          },
        ],
        { session },
      );
      await ChargingSession.updateOne(
        { _id: sessionId },
        {
          debitStatus: 'completed',
          debitTransactionId: transaction!._id,
          balanceBeforePaise,
          balanceAfterPaise,
          debitedAt: now,
        },
        { session },
      );
      return {
        alreadyDebited: false,
        transactionId: transaction!._id.toString(),
        vehicleId,
        balanceBeforePaise,
        balanceAfterPaise,
      };
    });

  try {
    return await run();
  } catch (error) {
    // A concurrent request debited first: report the completed debit instead.
    if (isDuplicateKeyError(error)) return run();
    throw error;
  }
}
