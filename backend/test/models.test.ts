import { Types } from 'mongoose';
import { beforeAll, describe, expect, it } from 'vitest';

import {
  CardTransaction,
  ChargingCard,
  ChargingSession,
  ControlsPreferences,
  MaintenanceRecord,
  PaypalOrder,
  ProfilePhoto,
  User,
  Vehicle,
} from '../src/models/index.js';

const allModels = [
  CardTransaction,
  ChargingCard,
  ChargingSession,
  ControlsPreferences,
  MaintenanceRecord,
  PaypalOrder,
  ProfilePhoto,
  User,
  Vehicle,
];

beforeAll(async () => {
  for (const model of allModels) await model.createIndexes();
});

function vehicle(id: string, registrationNumber: string, vin: string) {
  return {
    _id: id,
    registrationNumber,
    model: 'EV Smart X1',
    ownerName: 'Owner',
    vin,
  };
}

function card(overrides: Record<string, unknown> = {}) {
  return {
    uid: 'user-a',
    vehicleId: 'EV001',
    cardType: 'EV Charging Card',
    maskedCardNumber: 'XXXX XXXX XXXX 1234',
    cardLastFour: '1234',
    cardHolderName: 'Card Holder',
    expiryDate: new Date('2030-01-01'),
    ...overrides,
  };
}

describe('vehicles', () => {
  it('normalises registration and VIN', async () => {
    const created = await Vehicle.create(vehicle('EV001', 'tn01 ab 1234', 'evvin001'));
    expect(created.registrationNumber).toBe('TN01AB1234');
    expect(created.vin).toBe('EVVIN001');
    expect(created.ownerUid).toBeNull();
  });

  it('rejects a duplicate registration number', async () => {
    await Vehicle.create(vehicle('EV001', 'TN01AB1234', 'EVVIN001'));
    await expect(Vehicle.create(vehicle('EV002', 'TN01 AB1234', 'EVVIN002'))).rejects.toThrow(
      /duplicate key/,
    );
  });

  it('rejects a duplicate VIN', async () => {
    await Vehicle.create(vehicle('EV001', 'TN01AB1234', 'EVVIN001'));
    await expect(Vehicle.create(vehicle('EV002', 'TN02CD5678', 'evvin001'))).rejects.toThrow(
      /duplicate key/,
    );
  });

  it('claims a vehicle only once', async () => {
    await Vehicle.create(vehicle('EV001', 'TN01AB1234', 'EVVIN001'));
    const claim = (uid: string) =>
      Vehicle.findOneAndUpdate(
        { _id: 'EV001', ownerUid: null, isActive: true },
        { ownerUid: uid },
        { new: true },
      );
    expect((await claim('user-a'))?.ownerUid).toBe('user-a');
    expect(await claim('user-b')).toBeNull();
  });
});

describe('charging cards', () => {
  it('stores a valid masked card with a zero balance', async () => {
    const created = await ChargingCard.create(card());
    expect(created.balancePaise).toBe(0);
    expect(created.currency).toBe('INR');
    expect(created.status).toBe('ACTIVE');
  });

  it('rejects a negative balance', async () => {
    await expect(ChargingCard.create(card({ balancePaise: -100 }))).rejects.toThrow(/balancePaise/);
  });

  it('rejects a balance that is not whole paise', async () => {
    await expect(ChargingCard.create(card({ balancePaise: 10.5 }))).rejects.toThrow(/balancePaise/);
  });

  it('rejects a masked number that reveals more than four characters', async () => {
    await expect(
      ChargingCard.create(card({ maskedCardNumber: '4111 1111 1111 1234' })),
    ).rejects.toThrow(/maskedCardNumber/);
  });

  it('refuses to store a full card number, CVV or PIN', async () => {
    await expect(ChargingCard.create(card({ cardNumber: '4111111111111234' }))).rejects.toThrow(
      /cardNumber/,
    );
    await expect(ChargingCard.create(card({ cvv: '123' }))).rejects.toThrow(/cvv/);
  });

  it('allows one card per user and vehicle', async () => {
    await ChargingCard.create(card());
    await expect(ChargingCard.create(card({ cardLastFour: '9999' }))).rejects.toThrow(
      /duplicate key/,
    );
  });
});

describe('card transactions', () => {
  function transaction(overrides: Record<string, unknown> = {}) {
    return {
      cardId: new Types.ObjectId(),
      uid: 'user-a',
      vehicleId: 'EV001',
      type: 'credit',
      amountPaise: 10_000,
      balanceBeforePaise: 0,
      balanceAfterPaise: 10_000,
      currency: 'INR',
      timestamp: new Date(),
      ...overrides,
    };
  }

  it('rejects the same PayPal order or capture twice', async () => {
    await new CardTransaction(
      transaction({ paypalOrderId: 'ORDER1', paypalCaptureId: 'CAP1' }),
    ).save();
    await expect(
      new CardTransaction(transaction({ paypalOrderId: 'ORDER1', paypalCaptureId: 'CAP2' })).save(),
    ).rejects.toThrow(/duplicate key/);
    await expect(
      new CardTransaction(transaction({ paypalOrderId: 'ORDER2', paypalCaptureId: 'CAP1' })).save(),
    ).rejects.toThrow(/duplicate key/);
  });

  it('rejects the same charging session twice', async () => {
    const debit = { type: 'debit', sessionReferenceId: 'session-1' };
    await new CardTransaction(transaction(debit)).save();
    await expect(new CardTransaction(transaction(debit)).save()).rejects.toThrow(/duplicate key/);
  });

  it('allows many transactions without PayPal or session references', async () => {
    await new CardTransaction(transaction()).save();
    await new CardTransaction(transaction()).save();
    expect(await CardTransaction.countDocuments()).toBe(2);
  });

  it('rejects an unknown transaction type', async () => {
    await expect(new CardTransaction(transaction({ type: 'RECHARGE' })).save()).rejects.toThrow(
      /type/,
    );
  });
});

describe('controls preferences', () => {
  it('enforces the preference list limits', async () => {
    const tooManyKeys = Array.from({ length: 33 }, (_, index) => `key-${index}`);
    await expect(
      ControlsPreferences.create({
        _id: 'user-a:EV001',
        uid: 'user-a',
        vehicleId: 'EV001',
        preferences: { activeAlertKeys: tooManyKeys },
      }),
    ).rejects.toThrow(/at most 32/);
  });

  it('applies the Flutter defaults', async () => {
    const created = await ControlsPreferences.create({
      _id: 'user-a:EV001',
      uid: 'user-a',
      vehicleId: 'EV001',
      preferences: {},
    });
    expect(created.preferences.notificationsEnabled).toBe(true);
    expect(created.preferences.passengerProfiles).toEqual([]);
    expect(created.preferences.selectedProfileId).toBeNull();
  });
});

describe('other collections', () => {
  it('rejects negative maintenance cost', async () => {
    await expect(
      MaintenanceRecord.create({
        vehicleId: 'EV001',
        createdByUid: 'user-a',
        serviceType: 'Tyre rotation',
        category: 'Tyres',
        serviceDate: new Date(),
        costPaise: -1,
      }),
    ).rejects.toThrow(/costPaise/);
  });

  it('rejects an oversized or non-image profile photo', async () => {
    await expect(
      ProfilePhoto.create({
        _id: 'user-a',
        contentType: 'image/png',
        data: Buffer.alloc(300 * 1024 + 1),
      }),
    ).rejects.toThrow(/at most 300 KB/);
    await expect(
      new ProfilePhoto({ _id: 'user-a', contentType: 'image/gif', data: Buffer.from([1]) }).save(),
    ).rejects.toThrow(/contentType/);
  });

  it('starts charging sessions as confirmed and pending debit', async () => {
    const session = await ChargingSession.create({
      _id: 'session-1',
      uid: 'user-a',
      vehicleId: 'EV001',
      amountPaise: 25_000,
    });
    expect(session.status).toBe('confirmed');
    expect(session.debitStatus).toBe('pending');
  });

  it('starts PayPal orders as pending', async () => {
    const order = await PaypalOrder.create({
      _id: 'ORDER1',
      uid: 'user-a',
      vehicleId: 'EV001',
      cardId: new Types.ObjectId(),
      amountPaise: 10_000,
      currency: 'INR',
      paypalAmountCents: 120,
      paypalCurrency: 'USD',
      conversionType: 'demo_fixed_rate',
      demoExchangeRate: 0.012,
    });
    expect(order.status).toBe('PENDING');
  });

  it('keys users by ID and lowercases email', async () => {
    const user = await User.create({
      _id: 'uid-1',
      name: 'Driver',
      email: 'Driver@Example.com',
      passwordHash: 'hash',
    });
    // The hash is never loaded by default nor serialised.
    const loaded = await User.findById('uid-1').lean();
    expect(loaded).not.toHaveProperty('passwordHash');
    expect(user.toJSON()).not.toHaveProperty('passwordHash');
    await expect(
      User.create({ name: 'Copy', email: 'driver@example.com', passwordHash: 'h' }),
    ).rejects.toThrow(/duplicate key/);
    await expect(User.create({ name: 'No password', email: 'np@example.com' })).rejects.toThrow(
      /passwordHash/,
    );
    expect(user._id).toBe('uid-1');
    expect(user.email).toBe('driver@example.com');
    expect(user.vehicleId).toBeNull();
  });
});
