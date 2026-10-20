require('dotenv').config();
const path = require('path');
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

initializeApp({
  credential: cert(
    require(path.resolve(__dirname, process.env.GOOGLE_APPLICATION_CREDENTIALS))
  ),
});

const Profile = mongoose.model(
  'Profile',
  new mongoose.Schema(
    {
      uid: { type: String, required: true, unique: true },
      displayName: String,
      vehicle: String,
    },
    { timestamps: true }
  )
);

// Verify the Firebase ID token and take the uid from it
async function auth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing token' });
  try {
    req.uid = (await getAuth().verifyIdToken(token)).uid;
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}

const app = express();
app.use(cors());
app.use(express.json());

app.get('/api/health', (req, res) => {
  res.json({ ok: true, db: mongoose.connection.readyState === 1 });
});

app.get('/api/profile', auth, async (req, res) => {
  res.json(await Profile.findOne({ uid: req.uid }));
});

app.put('/api/profile', auth, async (req, res) => {
  const { displayName, vehicle } = req.body;
  const doc = await Profile.findOneAndUpdate(
    { uid: req.uid },
    { displayName, vehicle },
    { upsert: true, new: true }
  );
  res.json(doc);
});

mongoose
  .connect(process.env.MONGODB_URI)
  .then(() => {
    console.log('MongoDB connected');
    app.listen(process.env.PORT || 5000, () =>
      console.log('API running on port', process.env.PORT || 5000)
    );
  })
  .catch((e) => console.error('DB connection failed:', e.message));