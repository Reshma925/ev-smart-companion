import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { existsSync, realpathSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const projectId = 'smart-ev-learning-companion';
const vehicles = [
  {
    id: 'EV001',
    registrationNumber: 'TN01AB1234',
    model: 'EV Smart X1',
    ownerName: 'Registered Vehicle Owner 1',
    vin: 'EVVIN001',
    bluetoothDeviceId: 'EV-SIM-001',
    bluetoothDeviceName: 'EV-Simulator-01',
    isActive: true,
  },
  {
    id: 'EV002',
    registrationNumber: 'TN02CD5678',
    model: 'EV Smart X2',
    ownerName: 'Registered Vehicle Owner 2',
    vin: 'EVVIN002',
    bluetoothDeviceId: 'EV-SIM-002',
    bluetoothDeviceName: 'EV-Simulator-02',
    isActive: true,
  },
];

function sameFields(actual, expected) {
  return Object.entries(expected).every(([key, value]) => actual[key] === value);
}

function hasApplicationDefaultCredentials() {
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS);
  }
  return existsSync(
    resolve(process.env.HOME ?? '', '.config/gcloud/application_default_credentials.json'),
  );
}

async function runWithAdminSdk() {
  const app = initializeApp({
    credential: applicationDefault(),
    projectId,
  });
  const db = getFirestore(app);

  for (const { id, ...data } of vehicles) {
    const ref = db.collection('vehicles').doc(id);
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(ref);
      transaction.set(ref, {
        ...data,
        createdAt: existing.get('createdAt') ?? FieldValue.serverTimestamp(),
      }, { merge: true });
      console.log(`${existing.exists ? 'Updated' : 'Created'}: vehicles/${id}`);
    });
  }

  // Verify stored documents and the same normalized active-vehicle query used by the app.
  for (const { id, ...expected } of vehicles) {
    const snapshot = await db.collection('vehicles').doc(id).get();
    if (!snapshot.exists || !sameFields(snapshot.data(), expected)) {
      throw new Error(`Verification failed for vehicles/${id}.`);
    }
    if (!snapshot.get('createdAt')) {
      throw new Error(`vehicles/${id} is missing createdAt.`);
    }

    const matches = await db
      .collection('vehicles')
      .where('registrationNumber', '==', expected.registrationNumber)
      .where('isActive', '==', true)
      .limit(2)
      .get();
    if (matches.size !== 1 || matches.docs[0].id !== id) {
      throw new Error(`Registration lookup verification failed for vehicles/${id}.`);
    }
    console.log(`Verified: vehicles/${id} and ${expected.registrationNumber}`);
  }

  const invalid = await db
    .collection('vehicles')
    .where('registrationNumber', '==', 'XX99INVALID')
    .where('isActive', '==', true)
    .limit(2)
    .get();
  if (!invalid.empty) {
    throw new Error('Expected XX99INVALID to match no active vehicle.');
  }
  console.log('Verified: XX99INVALID returns no active vehicle.');
  await app.delete();
}

function firebaseCliAuth() {
  const command = process.platform === 'win32' ? 'where' : 'which';
  const cliShim = execFileSync(command, ['firebase'], { encoding: 'utf8' })
    .trim()
    .split(/\r?\n/)[0];
  const cliEntry = realpathSync(cliShim);
  const cliLib = dirname(dirname(cliEntry));
  const requireFromCli = createRequire(cliEntry);
  const auth = requireFromCli(resolve(cliLib, 'auth.js'));
  const scopesModule = requireFromCli(resolve(cliLib, 'scopes.js'));
  const account = auth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error('No Firebase CLI login found. Run firebase login first.');
  }
  return auth
    .getAccessToken(account.tokens.refresh_token, [scopesModule.CLOUD_PLATFORM])
    .then((tokens) => tokens.access_token);
}

function encodeFirestoreValue(value) {
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  throw new TypeError(`Unsupported seed value type: ${typeof value}`);
}

async function firestoreRestRequest(token, url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = body.error?.message ?? `Firestore API returned HTTP ${response.status}`;
    throw new Error(message);
  }
  return body;
}

function decodeFirestoreValue(value) {
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return value.timestampValue;
  return undefined;
}

function decodeDocument(document) {
  return Object.fromEntries(
    Object.entries(document.fields ?? {}).map(([key, value]) => [
      key,
      decodeFirestoreValue(value),
    ]),
  );
}

async function runWithFirebaseCliAuth() {
  const token = await firebaseCliAuth();
  const baseUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  const documentRoot = `projects/${projectId}/databases/(default)/documents`;
  const writes = vehicles.map(({ id, ...data }) => ({
    update: {
      name: `${documentRoot}/vehicles/${id}`,
      fields: Object.fromEntries(
        Object.entries(data).map(([key, value]) => [key, encodeFirestoreValue(value)]),
      ),
    },
    updateMask: { fieldPaths: Object.keys(data) },
    updateTransforms: [
      { fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' },
    ],
  }));

  await firestoreRestRequest(token, `${baseUrl}:commit`, {
    method: 'POST',
    body: JSON.stringify({ writes }),
  });
  console.log('Wrote seed fields and server timestamps to vehicles/EV001 and vehicles/EV002.');

  for (const { id, ...expected } of vehicles) {
    const document = await firestoreRestRequest(token, `${baseUrl}/vehicles/${id}`);
    const actual = decodeDocument(document);
    if (!sameFields(actual, expected) || typeof actual.createdAt !== 'string') {
      throw new Error(`Verification failed for vehicles/${id}.`);
    }

    const query = {
      structuredQuery: {
        from: [{ collectionId: 'vehicles' }],
        where: {
          compositeFilter: {
            op: 'AND',
            filters: [
              {
                fieldFilter: {
                  field: { fieldPath: 'registrationNumber' },
                  op: 'EQUAL',
                  value: { stringValue: expected.registrationNumber },
                },
              },
              {
                fieldFilter: {
                  field: { fieldPath: 'isActive' },
                  op: 'EQUAL',
                  value: { booleanValue: true },
                },
              },
            ],
          },
        },
        limit: 2,
      },
    };
    const matches = await firestoreRestRequest(token, `${baseUrl}:runQuery`, {
      method: 'POST',
      body: JSON.stringify(query),
    });
    const matchDocuments = matches.filter((item) => item.document);
    if (
      matchDocuments.length !== 1 ||
      matchDocuments[0].document.name !== `${documentRoot}/vehicles/${id}`
    ) {
      throw new Error(`Registration lookup verification failed for vehicles/${id}.`);
    }
    console.log(`Verified live document and lookup: vehicles/${id} (${expected.registrationNumber})`);
  }

  const invalidQuery = {
    structuredQuery: {
      from: [{ collectionId: 'vehicles' }],
      where: {
        compositeFilter: {
          op: 'AND',
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: 'registrationNumber' },
                op: 'EQUAL',
                value: { stringValue: 'XX99INVALID' },
              },
            },
            {
              fieldFilter: {
                field: { fieldPath: 'isActive' },
                op: 'EQUAL',
                value: { booleanValue: true },
              },
            },
          ],
        },
      },
      limit: 2,
    },
  };
  const invalidMatches = await firestoreRestRequest(token, `${baseUrl}:runQuery`, {
    method: 'POST',
    body: JSON.stringify(invalidQuery),
  });
  if (invalidMatches.some((item) => item.document)) {
    throw new Error('Expected XX99INVALID to match no active vehicle.');
  }
  console.log('Verified live negative lookup: XX99INVALID returns no vehicle.');
}

async function main() {
  if (
    process.env.GOOGLE_CLOUD_PROJECT &&
    process.env.GOOGLE_CLOUD_PROJECT !== projectId
  ) {
    throw new Error(
      `Refusing to seed project ${process.env.GOOGLE_CLOUD_PROJECT}; expected ${projectId}.`,
    );
  }

  if (hasApplicationDefaultCredentials()) {
    await runWithAdminSdk();
  } else {
    await runWithFirebaseCliAuth();
  }
}

main().catch((error) => {
  console.error(`Vehicle seed failed: ${error.message ?? error}`);
  process.exitCode = 1;
});
