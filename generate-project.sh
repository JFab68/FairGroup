#!/bin/bash
set -e

echo "Creating FAIR Group project structure..."

# Create directory structure
mkdir -p backend/src/{config,controllers,middleware,models,routes,services,utils}
mkdir -p backend/migrations
mkdir -p frontend/src/{components/{common,auth,public,members,subcommittees,resources,events,attendance},pages/{public,auth,members,admin},hooks,services}
mkdir -p shared/constants

# Function to create file with content
create_file() {
    local file_path="$1"
    local content="$2"
    echo "Creating $file_path..."
    echo "$content" > "$file_path"
}

# Backend package.json
create_file "backend/package.json" '{
  "name": "fair-group-backend",
  "version": "1.0.0",
  "main": "src/server.js",
  "scripts": {
    "dev": "nodemon src/server.js",
    "start": "node src/server.js",
    "migrate": "node scripts/run-migrations.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "express-session": "^1.17.3",
    "connect-pg-simple": "^9.0.0",
    "dotenv": "^16.3.1",
    "express-validator": "^7.0.1",
    "multer": "^1.4.5-lts.1",
    "csv-parse": "^5.5.0",
    "csv-stringify": "^6.4.2",
    "helmet": "^7.1.0",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}'

# Backend .env.example
create_file "backend/.env.example" 'NODE_ENV=development
PORT=5000
DATABASE_URL=postgresql://user:pass@localhost:5432/fairgroup
SESSION_SECRET=your-super-secure-session-secret-change-this
JWT_SECRET=your-jwt-secret-change-this
CORS_ORIGIN=http://localhost:5173
BCRYPT_ROUNDS=12'

# Backend src/server.js
create_file "backend/src/server.js" "const app = require('./app');
const db = require('./config/database');

const PORT = process.env.PORT || 5000;

db.connect()
  .then(() => {
    console.log('Database connected');
    app.listen(PORT, () => {
      console.log(\`Server running on port \${PORT}\`);
    });
  })
  .catch(err => {
    console.error('Database connection failed:', err);
    process.exit(1);
  });"

# Backend src/app.js
create_file "backend/src/app.js" "const express = require('express');
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

module.exports = app;"

# Backend config/database.js
create_file "backend/src/config/database.js" "const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false });
module.exports = pool;"

# Backend middleware/auth.js
create_file "backend/src/middleware/auth.js" "const db = require('../config/database');
exports.requireAuth = (req, res, next) => { if (!req.session?.memberId) return res.status(401).json({ error: 'Authentication required' }); next(); };
exports.requireRole = (...roles) => (req, res, next) => { if (!req.session || !roles.includes(req.session.role)) return res.status(403).json({ error: 'Insufficient permissions' }); next(); };
exports.requireSubcommitteeLeadership = async (req, res, next) => { if (req.session.role === 'admin') return next(); const { subcommitteeId } = req.params; const subcommittee = await db.query('SELECT chair_id, vice_chair_id FROM subcommittees WHERE id = $1', [subcommitteeId]); if (!subcommittee.rows.length) return res.status(404).json({ error: 'Subcommittee not found' }); const { chair_id, vice_chair_id } = subcommittee.rows[0]; if (chair_id === req.session.memberId || vice_chair_id === req.session.memberId) return next(); return res.status(403).json({ error: 'Subcommittee leadership required' }); };"

# Backend routes/auth.js
create_file "backend/src/routes/auth.js" "const express = require('express'); const router = express.Router(); const { body, validationResult } = require('express-validator'); const bcrypt = require('bcryptjs'); const db = require('../config/database');
router.post('/login', [body('email').isEmail(), body('password').notEmpty()], async (req, res) => { if (!validationResult(req).isEmpty()) return res.status(400).json({ errors: errors.array() }); const { email, password } = req.body; try { const result = await db.query('SELECT * FROM members WHERE email = $1 AND status = $2', [email, 'active']); if (!result.rows.length) return res.status(401).json({ error: 'Invalid credentials' }); const member = result.rows[0]; if (!await bcrypt.compare(password, member.password_hash)) return res.status(401).json({ error: 'Invalid credentials' }); req.session.memberId = member.id; req.session.role = member.role; res.json({ id: member.id, name: \`\${member.first_name} \${member.last_name}\`, role: member.role, email: member.email }); } catch (error) { res.status(500).json({ error: 'Server error' }); } });
router.post('/logout', (req, res) => { req.session.destroy(() => res.json({ message: 'Logged out' })); });
module.exports = router;"

# Backend routes/members.js
create_file "backend/src/routes/members.js" "const express = require('express'); const router = express.Router(); const { requireAuth, requireRole } = require('../middleware/auth');
router.get('/me', requireAuth, async (req, res) => { const result = await db.query('SELECT id, first_name, last_name, email, phone, role FROM members WHERE id = $1', [req.session.memberId]); res.json(result.rows[0]); });
router.put('/me', requireAuth, async (req, res) => { const { first_name, last_name, phone } = req.body; const result = await db.query('UPDATE members SET first_name = $1, last_name = $2, phone = $3 WHERE id = $4 RETURNING *', [first_name, last_name, phone, req.session.memberId]); res.json(result.rows[0]); });
router.get('/', requireAuth, requireRole('admin'), async (req, res) => { const result = await db.query(\` SELECT m.*, array_agg(s.name) as subcommittees FROM members m LEFT JOIN member_subcommittees ms ON m.id = ms.member_id LEFT JOIN subcommittees s ON ms.subcommittee_id = s.id GROUP BY m.id \`); res.json(result.rows); });
module.exports = router;"

# Backend routes/subcommittees.js
create_file "backend/src/routes/subcommittees.js" "const express = require('express'); const router = express.Router(); const { requireAuth, requireSubcommitteeLeadership } = require('../middleware/auth');
router.get('/', requireAuth, async (req, res) => { const result = await db.query(\` SELECT s.*, json_build_object('id', c.id, 'name', c.first_name || ' ' || c.last_name, 'email', c.email) as chair, json_build_object('id', v.id, 'name', v.first_name || ' ' || v.last_name, 'email', v.email) as vice_chair FROM subcommittees s LEFT JOIN members c ON s.chair_id = c.id LEFT JOIN members v ON s.vice_chair_id = v.id \`); res.json(result.rows); });
router.get('/:id', requireAuth, async (req, res) => { const result = await db.query(\` SELECT s.*, json_build_object('id', c.id, 'name', c.first_name || ' ' || c.last_name, 'email', c.email) as chair, json_build_object('id', v.id, 'name', v.first_name || ' ' || v.last_name, 'email', v.email) as vice_chair, json_agg(json_build_object('id', m.id, 'name', m.first_name || ' ' || m.last_name, 'email', m.email)) FILTER (WHERE m.id IS NOT NULL) as members FROM subcommittees s LEFT JOIN members c ON s.chair_id = c.id LEFT JOIN members v ON s.vice_chair_id = v.id LEFT JOIN member_subcommittees ms ON s.id = ms.subcommittee_id LEFT JOIN members m ON ms.member_id = m.id WHERE s.id = $1 GROUP BY s.id, c.id, v.id \`, [req.params.id]); res.json(result.rows[0]); });
router.put('/:id', requireAuth, requireSubcommitteeLeadership, async (req, res) => { const { description, meeting_schedule } = req.body; const result = await db.query('UPDATE subcommittees SET description = $1, meeting_schedule = $2 WHERE id = $3 RETURNING *', [description, meeting_schedule, req.params.id]); res.json(result.rows[0]); });
router.post('/:id/members', requireAuth, requireSubcommitteeLeadership, async (req, res) => { await db.query('INSERT INTO member_subcommittees (member_id, subcommittee_id) VALUES ($1, $2)', [req.body.memberId, req.params.id]); res.json({ message: 'Member added' }); });
router.delete('/:id/members/:memberId', requireAuth, requireSubcommitteeLeadership, async (req, res) => { await db.query('DELETE FROM member_subcommittees WHERE member_id = $1 AND subcommittee_id = $2', [req.params.memberId, req.params.id]); res.json({ message: 'Member removed' }); });
module.exports = router;"

# Backend routes/resources.js
create_file "backend/src/routes/resources.js" "const express = require('express'); const router = express.Router(); const { requireAuth } = require('../middleware/auth');
router.get('/', requireAuth, async (req, res) => { const { scope, subcommittee_id } = req.query; let query = 'SELECT r.*, m.first_name || ' ' || m.last_name as created_by_name FROM resources r JOIN members m ON r.created_by = m.id WHERE 1=1'; const params = []; if (scope) { query += ' AND r.scope = $1'; params.push(scope); } if (subcommittee_id) { query += ` AND r.subcommittee_id = ${params.length + 1}`; params.push(subcommittee_id); } const result = await db.query(query, params); res.json(result.rows); });
router.post('/', requireAuth, async (req, res) => { const { title, description, url, category, scope, subcommittee_id } = req.body; const result = await db.query('INSERT INTO resources (title, description, url, category, scope, subcommittee_id, created_by) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *', [title, description, url, category, scope, subcommittee_id, req.session.memberId]); res.status(201).json(result.rows[0]); });
module.exports = router;"

# Backend routes/events.js
create_file "backend/src/routes/events.js" "const express = require('express'); const router = express.Router(); const { requireAuth } = require('../middleware/auth');
router.get('/', requireAuth, async (req, res) => { const { filter } = req.query; let query = \` SELECT e.*, s.name as subcommittee_name FROM events e LEFT JOIN subcommittees s ON e.associated_subcommittee_id = s.id \`; if (filter === 'my-subcommittees') { query += \` WHERE e.associated_subcommittee_id IN ( SELECT subcommittee_id FROM member_subcommittees WHERE member_id = $1 ) OR e.associated_subcommittee_id IS NULL\`; } query += \` ORDER BY e.start_datetime ASC\`; const result = await db.query(query, filter === 'my-subcommittees' ? [req.session.memberId] : []); res.json(result.rows); });
router.post('/', requireAuth, async (req, res) => { const { title, description, start_datetime, end_datetime, location, associated_subcommittee_id } = req.body; if (associated_subcommittee_id) { const subcommittee = await db.query('SELECT chair_id, vice_chair_id FROM subcommittees WHERE id = $1', [associated_subcommittee_id]); if (!subcommittee.rows.length) return res.status(404).json({ error: 'Subcommittee not found' }); const { chair_id, vice_chair_id } = subcommittee.rows[0]; if (req.session.role !== 'admin' && chair_id !== req.session.memberId && vice_chair_id !== req.session.memberId) return res.status(403).json({ error: 'Only subcommittee leadership can create meetings' }); } else if (req.session.role !== 'admin') return res.status(403).json({ error: 'Only admins can create group-wide events' }); const result = await db.query('INSERT INTO events (title, description, start_datetime, end_datetime, location, associated_subcommittee_id, created_by) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *', [title, description, start_datetime, end_datetime, location, associated_subcommittee_id, req.session.memberId]); res.status(201).json(result.rows[0]); });
module.exports = router;"

# Backend routes/attendance.js
create_file "backend/src/routes/attendance.js" "const express = require('express'); const router = express.Router(); const { requireAuth, requireSubcommitteeLeadership } = require('../middleware/auth');
router.get('/:eventId', requireAuth, async (req, res) => { const result = await db.query(\` SELECT a.*, m.first_name, m.last_name, m.email FROM attendance a JOIN members m ON a.member_id = m.id WHERE a.event_id = $1 \`, [req.params.eventId]); res.json(result.rows); });
router.post('/:eventId', requireAuth, requireSubcommitteeLeadership, async (req, res) => { const { memberId, status, notes } = req.body; const eventCheck = await db.query('SELECT associated_subcommittee_id FROM events WHERE id = $1', [req.params.eventId]); if (!eventCheck.rows.length) return res.status(404).json({ error: 'Event not found' }); const subcommitteeId = eventCheck.rows[0].associated_subcommittee_id; if (!subcommitteeId) return res.status(400).json({ error: 'Attendance only for subcommittee meetings' }); const membership = await db.query('SELECT 1 FROM member_subcommittees WHERE member_id = $1 AND subcommittee_id = $2', [memberId, subcommitteeId]); if (!membership.rows.length) return res.status(400).json({ error: 'Member not in this subcommittee' }); const result = await db.query(\`INSERT INTO attendance (event_id, member_id, status, notes, recorded_by) VALUES ($1, $2, $3, $4, $5) ON CONFLICT (event_id, member_id) DO UPDATE SET status = $3, notes = $4, recorded_by = $5, created_at = NOW() RETURNING *\`, [req.params.eventId, memberId, status, notes, req.session.memberId]); res.json(result.rows[0]); });
module.exports = router;"

# Backend routes/public.js
create_file "backend/src/routes/public.js" "const express = require('express'); const router = express.Router(); const { body, validationResult } = require('express-validator');
router.post('/signup', [body('first_name').notEmpty().trim().escape(), body('last_name').notEmpty().trim().escape(), body('email').isEmail().normalizeEmail(), body('phone').optional().trim().escape(), body('county_or_city').optional().trim().escape(), body('system_impact').isIn(['Yes', 'No', 'Prefer not to say']), body('involvement_interest').optional().trim()], async (req, res) => { if (!validationResult(req).isEmpty()) return res.status(400).json({ errors: errors.array() }); const { first_name, last_name, email, phone, county_or_city, system_impact, involvement_interest } = req.body; await db.query('INSERT INTO public_contacts (first_name, last_name, email, phone, county_or_city, system_impact, involvement_interest) VALUES ($1, $2, $3, $4, $5, $6, $7)', [first_name, last_name, email, phone, county_or_city, system_impact, involvement_interest]); res.status(201).json({ message: 'Thank you, we’ll follow up with more information.' }); });
module.exports = router;"

# Frontend package.json
create_file "frontend/package.json" '{
  "name": "fair-group-frontend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.18.0",
    "axios": "^1.6.0",
    "react-query": "^3.39.3",
    "date-fns": "^2.30.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.1.0",
    "vite": "^4.5.0"
  }
}'

# Frontend .env.example
create_file "frontend/.env.example" "VITE_API_URL=http://localhost:5000/api"

# Frontend vite.config.js
create_file "frontend/vite.config.js" "import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
export default defineConfig({ plugins: [react()], server: { port: 5173, proxy: { '/api': { target: 'http://localhost:5000', changeOrigin: true } } } })"

# Frontend index.html
create_file "frontend/index.html" '<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>FAIR Group</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>'

# Frontend src/main.jsx
create_file "frontend/src/main.jsx" "import React from 'react'; import ReactDOM from 'react-dom/client'; import { BrowserRouter } from 'react-router-dom'; import { QueryClient, QueryClientProvider } from 'react-query'; import { AuthProvider } from './hooks/useAuth'; import App from './App'; import './index.css'; const queryClient = new QueryClient(); ReactDOM.createRoot(document.getElementById('root')).render(<React.StrictMode><BrowserRouter><QueryClientProvider client={queryClient}><AuthProvider><App /></AuthProvider></QueryClientProvider></BrowserRouter></React.StrictMode>);"

# Frontend src/App.jsx
create_file "frontend/src/App.jsx" "import { Routes, Route } from 'react-router-dom'; import { useAuth } from './hooks/useAuth'; import ProtectedRoute from './components/common/ProtectedRoute'; import Header from './components/common/Header'; import Footer from './components/common/Footer'; import Home from './pages/public/Home'; import Signup from './pages/public/Signup'; import Login from './pages/auth/Login'; import MemberDashboard from './pages/members/Dashboard'; import SubcommitteeIndex from './components/subcommittees/SubcommitteeIndex'; import SubcommitteeDetail from './components/subcommittees/SubcommitteeDetail'; import ResourceList from './components/resources/ResourceList'; import EventCalendar from './components/events/EventCalendar'; import AdminMembers from './pages/admin/MemberAdmin'; function App() { const { member } = useAuth(); return (<div className=\"app\"><Header /><main><Routes><Route path=\"/\" element={<Home />} /><Route path=\"/signup\" element={<Signup />} /><Route path=\"/login\" element={<Login />} /><Route path=\"/members/dashboard\" element={<ProtectedRoute><MemberDashboard /></ProtectedRoute>} /><Route path=\"/subcommittees\" element={<ProtectedRoute><SubcommitteeIndex /></ProtectedRoute>} /><Route path=\"/subcommittees/:id\" element={<ProtectedRoute><SubcommitteeDetail /></ProtectedRoute>} /><Route path=\"/resources\" element={<ProtectedRoute><ResourceList /></ProtectedRoute>} /><Route path=\"/calendar\" element={<ProtectedRoute><EventCalendar /></ProtectedRoute>} /><Route path=\"/admin/members\" element={<ProtectedRoute requiredRoles={['admin']}><AdminMembers /></ProtectedRoute>} /></Routes></main><Footer /></div>); } export default App;"

# Frontend src/index.css
create_file "frontend/src/index.css" "/* FAIR Group Styles */ :root { --navy: #1e3a8a; --maroon: #7f1d1d; --neutral: #f9fafb; --text: #111827; --border: #d1d5db; } * { margin: 0; padding: 0; box-sizing: border-box; } body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; line-height: 1.6; color: var(--text); background: white; } .app { min-height: 100vh; display: flex; flex-direction: column; } main { flex: 1; max-width: 1200px; margin: 0 auto; padding: 2rem 1rem; width: 100%; } h1, h2, h3 { font-family: 'Georgia', serif; font-weight: bold; margin-bottom: 1rem; color: var(--navy); } h1 { font-size: 2.5rem; } h2 { font-size: 2rem; } h3 { font-size: 1.5rem; } .btn-primary { background: var(--maroon); color: white; padding: 0.75rem 1.5rem; border: none; border-radius: 4px; font-weight: 600; cursor: pointer; text-decoration: none; display: inline-block; transition: background 0.2s; } .btn-primary:hover { background: #991b1b; } .form-group { margin-bottom: 1rem; } label { display: block; margin-bottom: 0.25rem; font-weight: 600; } input, select, textarea { width: 100%; padding: 0.5rem; border: 1px solid var(--border); border-radius: 4px; font-size: 1rem; } table { width: 100%; border-collapse: collapse; margin-top: 1rem; } th, td { text-align: left; padding: 0.75rem; border-bottom: 1px solid var(--border); } th { background: var(--neutral); font-weight: 600; } .loading { text-align: center; padding: 2rem; font-style: italic; }"

# Frontend hooks/useAuth.jsx
create_file "frontend/src/hooks/useAuth.jsx" "import { createContext, useContext, useState, useEffect } from 'react'; import api from '../services/api'; const AuthContext = createContext(null); export const AuthProvider = ({ children }) => { const [member, setMember] = useState(null); const [loading, setLoading] = useState(true); useEffect(() => { api.get('/api/members/me').then(res => setMember(res.data)).catch(() => setMember(null)).finally(() => setLoading(false)); }, []); const login = async (email, password) => { const res = await api.post('/api/auth/login', { email, password }); setMember(res.data); return res.data; }; const logout = async () => { await api.post('/api/auth/logout'); setMember(null); }; const hasRole = (...roles) => member && roles.includes(member.role); return <AuthContext.Provider value={{ member, login, logout, hasRole, loading }}>{children}</AuthContext.Provider>; }; export const useAuth = () => useContext(AuthContext);"

# Frontend services/api.js
create_file "frontend/src/services/api.js" "import axios from 'axios'; const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api'; const api = axios.create({ baseURL: API_URL, withCredentials: true, headers: { 'Content-Type': 'application/json' } }); api.interceptors.response.use(response => response, error => { if (error.response?.status === 401) window.location.href = '/login'; return Promise.reject(error); }); export default api;"

# Frontend components/common/Header.jsx
create_file "frontend/src/components/common/Header.jsx" "import { Link, useNavigate } from 'react-router-dom'; import { useAuth } from '../../hooks/useAuth'; const Header = () => { const { member, logout } = useAuth(); const navigate = useNavigate(); const handleLogout = async () => { await logout(); navigate('/'); }; return (<header style={{ background: 'var(--navy)', color: 'white', padding: '1rem 0', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}><div style={{ maxWidth: '1200px', margin: '0 auto', padding: '0 1rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}><Link to={member ? '/members/dashboard' : '/'} style={{ color: 'white', textDecoration: 'none', fontSize: '1.5rem', fontWeight: 'bold' }}>FAIR Group</Link><nav>{member ? (<div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}><span>Welcome, {member.name}</span><Link to='/members/dashboard' style={{ color: 'white' }}>Dashboard</Link><Link to='/subcommittees' style={{ color: 'white' }}>Subcommittees</Link><Link to='/calendar' style={{ color: 'white' }}>Calendar</Link><Link to='/resources' style={{ color: 'white' }}>Resources</Link>{member.role === 'admin' && <Link to='/admin/members' style={{ color: 'white' }}>Admin</Link>}<button onClick={handleLogout} style={{ background: 'var(--maroon)', color: 'white', border: 'none', padding: '0.5rem 1rem', borderRadius: '4px', cursor: 'pointer' }}>Logout</button></div>) : (<div style={{ display: 'flex', gap: '1rem' }}><Link to='/' style={{ color: 'white' }}>Home</Link><Link to='/signup' style={{ color: 'white' }}>Get Involved</Link><Link to='/login' style={{ color: 'white' }}>Login</Link></div>)}</nav></div></header>); }; export default Header;"

# Frontend components/common/Footer.jsx
create_file "frontend/src/components/common/Footer.jsx" "const Footer = () => { return (<footer style={{ background: 'var(--neutral)', padding: '2rem 0', marginTop: '4rem', borderTop: '1px solid var(--border)', textAlign: 'center' }}><div style={{ maxWidth: '1200px', margin: '0 auto', padding: '0 1rem' }}><p>&copy; 2024 FAIR Group - Fairness and Accountability Integrated Responsibly</p><p>Convened by Representative Powell in the Arizona House</p></div></footer>); }; export default Footer;"

# Frontend components/common/ProtectedRoute.jsx
create_file "frontend/src/components/common/ProtectedRoute.jsx" "import { Navigate } from 'react-router-dom'; import { useAuth } from '../../hooks/useAuth'; export const ProtectedRoute = ({ children, requiredRoles }) => { const { member, loading } = useAuth(); if (loading) return <div className='loading'>Loading...</div>; if (!member) return <Navigate to='/login' />; if (requiredRoles && !requiredRoles.some(role => member.role === role)) return <Navigate to='/members/dashboard' />; return children; }; export default ProtectedRoute;"

# Frontend pages/public/Home.jsx
create_file "frontend/src/pages/public/Home.jsx" "import { Link } from 'react-router-dom'; import Hero from '../../components/public/Hero'; const Home = () => { return (<div className='public-home'><Hero /><section className='who-we-are' style={{ marginTop: '3rem' }}><h2>Who We Are</h2><p>The FAIR Group (Fairness and Accountability Integrated Responsibly) is a working group convened by <strong>Representative Powell</strong> in the Arizona House. We bring together:</p><ul style={{ marginLeft: '2rem', marginTop: '1rem' }}><li>Concerned Arizona residents</li><li>System-impacted people (formerly and currently incarcerated)</li><li>Families and advocates</li><li>Government staff and agency representatives</li><li>Lawmakers and criminal legal system professionals</li></ul><p style={{ marginTop: '1rem' }}>We center diverse perspectives and system-impacted leadership to find common ground.</p></section><section className='what-we-do' style={{ marginTop: '3rem' }}><h2>What We Do</h2><p>We operate through <strong>six working subcommittees</strong>, each focused on a different stage of Arizona's criminal legal system. Our goal: practical, bipartisan solutions for the 2027 legislative session.</p></section><section className='cta' style={{ marginTop: '3rem', textAlign: 'center' }}><Link to='/signup' className='btn-primary'>Stay informed and get involved</Link></section></div>); }; export default Home;"

# Frontend components/public/Hero.jsx
create_file "frontend/src/components/public/Hero.jsx" "const Hero = () => { return (<section style={{ background: 'linear-gradient(135deg, var(--navy) 0%, #2563eb 100%)', color: 'white', padding: '4rem 2rem', textAlign: 'center', borderRadius: '8px' }}><h1 style={{ color: 'white', fontSize: '3rem', marginBottom: '1rem' }}>FAIR Group</h1><p style={{ fontSize: '1.25rem', maxWidth: '800px', margin: '0 auto' }}><strong>Fairness and Accountability Integrated Responsibly</strong></p><p style={{ fontSize: '1rem', marginTop: '1rem', maxWidth: '800px', margin: '1rem auto 0' }}>This is a working group of Arizona residents, system-impacted people, families, organizations, government staff, and lawmakers collaborating to improve Arizona's criminal legal system by finding common ground and developing policy solutions for the 2027 legislative session.</p></section>); }; export default Hero;"

# Frontend components/public/SignupForm.jsx
create_file "frontend/src/components/public/SignupForm.jsx" "import { useState } from 'react'; import api from '../../services/api'; const SignupForm = () => { const [formData, setFormData] = useState({ first_name: '', last_name: '', email: '', phone: '', county_or_city: '', system_impact: 'Prefer not to say', involvement_interest: '' }); const [submitted, setSubmitted] = useState(false); const handleChange = (e) => { const { name, value } = e.target; setFormData(prev => ({ ...prev, [name]: value })); }; const handleSubmit = async (e) => { e.preventDefault(); try { await api.post('/api/public/signup', formData); setSubmitted(true); } catch (error) { alert('Error submitting form. Please try again.'); } }; if (submitted) { return (<div style={{ textAlign: 'center', padding: '2rem' }}><h2>Thank you!</h2><p>We'll follow up with more information.</p></div>); } return (<form onSubmit={handleSubmit} style={{ maxWidth: '600px', margin: '0 auto' }}><div className='form-group'><label>First Name *</label><input name='first_name' value={formData.first_name} onChange={handleChange} required /></div><div className='form-group'><label>Last Name *</label><input name='last_name' value={formData.last_name} onChange={handleChange} required /></div><div className='form-group'><label>Email *</label><input type='email' name='email' value={formData.email} onChange={handleChange} required /></div><div className='form-group'><label>Phone (optional)</label><input type='tel' name='phone' value={formData.phone} onChange={handleChange} /></div><div className='form-group'><label>County or City (optional)</label><input name='county_or_city' value={formData.county_or_city} onChange={handleChange} /></div><div className='form-group'><label>I am directly or indirectly impacted by the criminal legal system</label><select name='system_impact' value={formData.system_impact} onChange={handleChange}><option value='Yes'>Yes</option><option value='No'>No</option><option value='Prefer not to say'>Prefer not to say</option></select></div><div className='form-group'><label>How would you like to be involved or what interests you about FAIR Group?</label><textarea name='involvement_interest' value={formData.involvement_interest} onChange={handleChange} rows='4' /></div><button type='submit' className='btn-primary'>Submit</button></form>); }; export default SignupForm;"

# Frontend pages/auth/Login.jsx
create_file "frontend/src/pages/auth/Login.jsx" "import { useState } from 'react'; import { useNavigate } from 'react-router-dom'; import { useAuth } from '../../hooks/useAuth'; const Login = () => { const [email, setEmail] = useState(''); const [password, setPassword] = useState(''); const [error, setError] = useState(''); const { login } = useAuth(); const navigate = useNavigate(); const handleSubmit = async (e) => { e.preventDefault(); try { await login(email, password); navigate('/members/dashboard'); } catch (err) { setError('Invalid email or password'); } }; return (<div style={{ maxWidth: '400px', margin: '0 auto', padding: '2rem' }}><h2>Member Login</h2>{error && <p style={{ color: 'var(--maroon)' }}>{error}</p>}<form onSubmit={handleSubmit}><div className='form-group'><label>Email</label><input type='email' value={email} onChange={(e) => setEmail(e.target.value)} required /></div><div className='form-group'><label>Password</label><input type='password' value={password} onChange={(e) => setPassword(e.target.value)} required /></div><button type='submit' className='btn-primary'>Login</button></form></div>); }; export default Login;"

# Frontend pages/members/Dashboard.jsx
create_file "frontend/src/pages/members/Dashboard.jsx" "import { Link } from 'react-router-dom'; import { useAuth } from '../../hooks/useAuth'; const MemberDashboard = () => { const { member } = useAuth(); return (<div><h1>Welcome, {member.name}</h1><p>FAIR Group is currently focused on developing policy solutions for the 2027 legislative session.</p><div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '1.5rem', marginTop: '2rem' }}><Link to='/calendar' style={{ padding: '2rem', border: '1px solid var(--border)', borderRadius: '8px', textDecoration: 'none', color: 'inherit' }}><h3>📅 Master Calendar</h3><p>View all FAIR Group and subcommittee meetings</p></Link><Link to='/subcommittees' style={{ padding: '2rem', border: '1px solid var(--border)', borderRadius: '8px', textDecoration: 'none', color: 'inherit' }}><h3>👥 Subcommittees</h3><p>Access your subcommittee workspaces</p></Link><Link to='/resources' style={{ padding: '2rem', border: '1px solid var(--border)', borderRadius: '8px', textDecoration: 'none', color: 'inherit' }}><h3>📁 Resources</h3><p>Helpful documents and links</p></Link><Link to='/members/profile' style={{ padding: '2rem', border: '1px solid var(--border)', borderRadius: '8px', textDecoration: 'none', color: 'inherit' }}><h3>👤 My Profile</h3><p>Update your information</p></Link></div></div>); }; export default MemberDashboard;"

# Frontend components/subcommittees/SubcommitteeIndex.jsx
create_file "frontend/src/components/subcommittees/SubcommitteeIndex.jsx" "import { useQuery } from 'react-query'; import { Link } from 'react-router-dom'; import api from '../../services/api'; const SubcommitteeIndex = () => { const { data: subcommittees, isLoading } = useQuery('subcommittees', () => api.get('/api/subcommittees').then(res => res.data)); if (isLoading) return <div>Loading...</div>; return (<div><h1>Subcommittees</h1><div style={{ display: 'grid', gap: '1.5rem', marginTop: '2rem' }}>{subcommittees?.map(sc => (<div key={sc.id} style={{ padding: '1.5rem', border: '1px solid var(--border)', borderRadius: '8px' }}><h3>{sc.name}</h3><p>{sc.description}</p><p><strong>Chair:</strong> {sc.chair?.name || 'TBD'}</p><p><strong>Vice Chair:</strong> {sc.vice_chair?.name || 'TBD'}</p><p><strong>Schedule:</strong> {sc.meeting_schedule}</p><Link to={\`/subcommittees/\${sc.id}\`} className='btn-primary' style={{ marginTop: '1rem', display: 'inline-block' }}>View Details</Link></div>))}</div></div>); }; export default SubcommitteeIndex;"

# Frontend components/subcommittees/SubcommitteeDetail.jsx
create_file "frontend/src/components/subcommittees/SubcommitteeDetail.jsx" "import { useParams } from 'react-router-dom'; import { useQuery } from 'react-query'; import api from '../../services/api'; import { useAuth } from '../../hooks/useAuth'; const SubcommitteeDetail = () => { const { id } = useParams(); const { member } = useAuth(); const { data: subcommittee, isLoading } = useQuery(['subcommittee', id], () => api.get(\`/api/subcommittees/\${id}\`).then(res => res.data)); if (isLoading) return <div>Loading...</div>; const canManage = member.role === 'admin' || member.id === subcommittee.chair?.id || member.id === subcommittee.vice_chair?.id; return (<div><h1>{subcommittee.name}</h1><p>{subcommittee.description}</p><section style={{ marginTop: '2rem' }}><h3>Leadership</h3><p><strong>Chair:</strong> {subcommittee.chair?.name} ({subcommittee.chair?.email})</p><p><strong>Vice Chair:</strong> {subcommittee.vice_chair?.name} ({subcommittee.vice_chair?.email})</p></section><section style={{ marginTop: '2rem' }}><h3>Meeting Schedule</h3><p>{subcommittee.meeting_schedule}</p>{canManage && <button className='btn-primary' style={{ marginTop: '1rem' }}>Edit Schedule</button>}</section><section style={{ marginTop: '2rem' }}><h3>Members ({subcommittee.members?.length || 0})</h3><ul style={{ listStyle: 'none', padding: 0 }}>{subcommittee.members?.map(m => (<li key={m.id} style={{ padding: '0.5rem 0' }}>{m.name} ({m.email})</li>))}</ul>{canManage && <button className='btn-primary'>Manage Members</button>}</section></div>); }; export default SubcommitteeDetail;"

# Frontend components/events/EventCalendar.jsx
create_file "frontend/src/components/events/EventCalendar.jsx" "import { useState } from 'react'; import { useQuery } from 'react-query'; import { format } from 'date-fns'; import api from '../../services/api'; import { useAuth } from '../../hooks/useAuth'; const EventCalendar = () => { const [filter, setFilter] = useState('all'); const { member } = useAuth(); const { data: events, isLoading } = useQuery(['events', filter], () => api.get(\`/api/events?filter=\${filter}\`).then(res => res.data)); if (isLoading) return <div>Loading...</div>; return (<div><h1>Master Calendar</h1><div style={{ marginBottom: '1.5rem' }}><label>Filter: </label><select value={filter} onChange={(e) => setFilter(e.target.value)}><option value='all'>All Events</option><option value='my-subcommittees'>My Subcommittees Only</option></select></div><div style={{ display: 'grid', gap: '1rem' }}>{events?.map(event => (<div key={event.id} style={{ padding: '1rem', border: '1px solid var(--border)', borderRadius: '8px' }}><h3>{event.title}</h3><p>{format(new Date(event.start_datetime), 'PPpp')}</p><p>{event.location}</p>{event.subcommittee_name && <p><strong>Subcommittee:</strong> {event.subcommittee_name}</p>}<p>{event.description}</p></div>))}</div></div>); }; export default EventCalendar;"

# Frontend components/attendance/AttendanceTaker.jsx
create_file "frontend/src/components/attendance/AttendanceTaker.jsx" "import { useState } from 'react'; import { useQuery, useMutation, useQueryClient } from 'react-query'; import api from '../../services/api'; const AttendanceTaker = ({ eventId, subcommitteeId }) => { const queryClient = useQueryClient(); const [attendance, setAttendance] = useState({}); const { data: members } = useQuery(['subcommittee-members', subcommitteeId], () => api.get(\`/api/subcommittees/\${subcommitteeId}\`).then(res => res.data.members)); const { data: existingAttendance } = useQuery(['attendance', eventId], () => api.get(\`/api/attendance/\${eventId}\`).then(res => res.data)); const mutation = useMutation(({ memberId, status, notes }) => api.post(\`/api/attendance/\${eventId}\`, { memberId, status, notes }), { onSuccess: () => queryClient.invalidateQueries(['attendance', eventId]) }); const handleStatusChange = (memberId, status) => { setAttendance(prev => ({ ...prev, [memberId]: status })); mutation.mutate({ memberId, status }); }; if (!members) return <div>Loading members...</div>; return (<div className='attendance-taker' style={{ marginTop: '2rem' }}><h3>Record Attendance</h3><table><thead><tr><th>Member</th><th>Status</th><th>Notes</th></tr></thead><tbody>{members.map(member => (<tr key={member.id}><td>{member.name}</td><td><select value={attendance[member.id] || existingAttendance?.find(a => a.member_id === member.id)?.status || ''} onChange={(e) => handleStatusChange(member.id, e.target.value)}><option value=''>Select</option><option value='Present'>Present</option><option value='Absent'>Absent</option><option value='Conflict'>Conflict</option></select></td><td><input type='text' placeholder='Optional notes' onBlur={(e) => mutation.mutate({ memberId: member.id, status: attendance[member.id], notes: e.target.value })} /></td></tr>))}</tbody></table></div>); }; export default AttendanceTaker;"

# Frontend pages/admin/MemberAdmin.jsx
create_file "frontend/src/pages/admin/MemberAdmin.jsx" "import { useState } from 'react'; import { useQuery } from 'react-query'; import api from '../../services/api'; const MemberAdmin = () => { const { data: members, isLoading, refetch } = useQuery('members', () => api.get('/api/members').then(res => res.data)); if (isLoading) return <div>Loading...</div>; return (<div><h1>Member Management</h1><table><thead><tr><th>Name</th><th>Email</th><th>Role</th><th>Status</th><th>Subcommittees</th><th>Actions</th></tr></thead><tbody>{members?.map(member => (<tr key={member.id}><td>\${member.first_name} \${member.last_name}</td><td>{member.email}</td><td>{member.role}</td><td>{member.status}</td><td>{member.subcommittees?.join(', ') || 'None'}</td><td><button className='btn-primary' style={{ padding: '0.25rem 0.5rem', fontSize: '0.875rem' }}>Edit</button></td></tr>))}</tbody></table></div>); }; export default MemberAdmin;"

# Root README.md
create_file "README.md" "# FAIR Group Website\n\n## Quick Start\n\n### Prerequisites\n- Node.js 18+\n- PostgreSQL 14+\n\n### Setup\n1. Save this script as \`generate-project.sh\`\n2. \`chmod +x generate-project.sh && ./generate-project.sh\`\n3. \`cd backend && npm install && npm run migrate\`\n4. \`cd frontend && npm install\`\n5. Create admin user via SQL\n6. Run both servers: \`npm run dev\` in separate terminals\n\n## Features\nPublic site, member auth, 6 subcommittees, chair powers, attendance tracking, CSV tools\n\n## Tech Stack\nBackend: Node.js, Express, PostgreSQL | Frontend: React, React Query"

echo "✅ Project structure created!"
echo "Next steps: 1) cd backend && npm install && npm run migrate 2) cd frontend && npm install 3) Create admin user 4) Run both servers"