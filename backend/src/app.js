const express = require('express');
const session = require('express-session');
const pgSession = require('connect-pg-simple')(session);
const helmet = require('helmet');
const cors = require('cors');
require('dotenv').config();

const db = require('./config/database');
const authRoutes = require('./routes/auth');
const memberRoutes = require('./routes/members');
const subcommitteeRoutes = require('./routes/subcommittees');
const resourceRoutes = require('./routes/resources');
const eventRoutes = require('./routes/events');
const attendanceRoutes = require('./routes/attendance');
const publicRoutes = require('./routes/public');

const app = express();

app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN, credentials: true }));

app.use(session({
  store: new pgSession({ pool: db, tableName: 'session' }),
  secret: process.env.SESSION_SECRET,
  resave: false, saveUninitialized: false,
  cookie: { secure: process.env.NODE_ENV === 'production', httpOnly: true, maxAge: 30 * 24 * 60 * 60 * 1000 }
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use('/api/auth', authRoutes);
app.use('/api/members', memberRoutes);
app.use('/api/subcommittees', subcommitteeRoutes);
app.use('/api/resources', resourceRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/public', publicRoutes);

app.get('/health', (req, res) => res.json({ status: 'OK', timestamp: new Date().toISOString() }));

module.exports = app;
