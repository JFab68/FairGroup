# FAIR Group Website - Setup Guide

## Critical Fixes Applied

All critical security vulnerabilities have been fixed:
- ✅ SQL injection vulnerabilities (missing query placeholders)
- ✅ Missing database imports in all route files
- ✅ Secure SESSION_SECRET and JWT_SECRET generated
- ✅ Error handling added to all routes
- ✅ Validation errors fixed in auth and public routes

## Prerequisites

- **Node.js 18+** - [Download](https://nodejs.org/)
- **PostgreSQL 14+** - [Download](https://www.postgresql.org/download/)

## Database Setup

### Step 1: Install and Start PostgreSQL

Make sure PostgreSQL is running on port **5433** (as configured in `.env`).

### Step 2: Create the Database

```bash
# Connect to PostgreSQL
psql -U postgres

# Create the database
CREATE DATABASE fairgroup;

# Exit psql
\q
```

### Step 3: Run Migrations

```bash
# Run the migrations from the project root
psql -U postgres -d fairgroup -p 5433 -f migrations.sql
```

If you need to change the port or credentials, update `backend/.env`:
```
DATABASE_URL=postgresql://postgres:your-password@localhost:5433/fairgroup
```

## Backend Setup

### Step 1: Install Dependencies

```bash
cd backend
npm install
```

### Step 2: Verify Environment Variables

The `backend/.env` file should already be configured with secure secrets:
- ✅ SESSION_SECRET (generated)
- ✅ JWT_SECRET (generated)
- ✅ Database connection string

### Step 3: Create Test User

```bash
# Create an admin user for testing
node create-test-user.js
```

This will create a test admin account:
- **Email**: `admin@fairgroup.org`
- **Password**: `admin123`
- **Role**: admin

⚠️ **IMPORTANT**: Change this password after first login!

### Step 4: Start Backend Server

```bash
npm run dev
```

The backend will run on **http://localhost:5000**

## Frontend Setup

### Step 1: Install Dependencies

```bash
cd frontend
npm install
```

### Step 2: Start Frontend Server

```bash
npm run dev
```

The frontend will run on **http://localhost:5173**

## Testing the Application

1. **Open your browser** to http://localhost:5173
2. **Click "Login"** in the navigation
3. **Enter credentials**:
   - Email: `admin@fairgroup.org`
   - Password: `admin123`
4. **You should now be logged in** as an admin!

## Common Issues

### Issue: "Cannot connect to database"
**Solution**:
- Verify PostgreSQL is running: `pg_isready -p 5433`
- Check the DATABASE_URL in `backend/.env`
- Ensure the database exists: `psql -U postgres -l | grep fairgroup`

### Issue: "Invalid credentials" when logging in
**Solution**:
- Make sure you ran `node create-test-user.js`
- Check if the user exists: `psql -U postgres -d fairgroup -c "SELECT email, role FROM members;"`
- Verify the password is 'admin123' or create a new user

### Issue: "Port already in use"
**Solution**:
- Backend (5000): Change PORT in `backend/.env`
- Frontend (5173): Change port in `frontend/vite.config.js`
- PostgreSQL (5433): Change port in `backend/.env` DATABASE_URL

### Issue: SQL errors in console
**Solution**: All SQL injection issues have been fixed. If you still see errors:
- Make sure you're using the latest version of the code
- Check that migrations.sql ran successfully
- Verify all tables exist: `psql -U postgres -d fairgroup -c "\dt"`

## Next Steps

### Create Additional Users

You can create more users by:
1. Going to the admin panel (when logged in as admin)
2. Or using SQL:

```sql
-- Connect to database
psql -U postgres -d fairgroup -p 5433

-- Insert a member (password will need to be hashed)
-- Use the create-test-user.js script as a template
```

### Set Up Subcommittees

The database schema supports 6 subcommittees. You can create them via SQL or add an admin UI:

```sql
INSERT INTO subcommittees (name, description, chair_id, vice_chair_id, meeting_schedule)
VALUES
  ('Subcommittee 1', 'Description here', NULL, NULL, 'Weekly on Mondays'),
  ('Subcommittee 2', 'Description here', NULL, NULL, 'Bi-weekly on Wednesdays');
```

## Production Deployment

Before deploying to production:

1. **Change all default passwords**
2. **Set NODE_ENV=production** in backend/.env
3. **Use a production PostgreSQL instance** (not localhost)
4. **Set up SSL certificates** for HTTPS
5. **Configure a reverse proxy** (nginx, Apache)
6. **Set up proper backup strategy** for database
7. **Add rate limiting** to prevent abuse
8. **Set up monitoring and logging**

## Security Notes

- ✅ All SQL queries now use parameterized queries (prevents SQL injection)
- ✅ Passwords are hashed with bcrypt (12 rounds)
- ✅ Sessions stored in PostgreSQL (not in-memory)
- ✅ CORS configured to only allow frontend origin
- ✅ Helmet.js provides security headers
- ⚠️ Add CSRF protection before production
- ⚠️ Add rate limiting on auth endpoints
- ⚠️ Implement password reset functionality

## Architecture

- **Backend**: Node.js + Express + PostgreSQL (port 5000)
- **Frontend**: React 18 + Vite (port 5173)
- **Authentication**: Session-based with bcrypt
- **Authorization**: Role-based (admin, chair, vice_chair, member)

## Need Help?

Check the comprehensive documentation in `fair-group-project.md` for detailed information about:
- API endpoints
- Database schema
- Component structure
- Feature specifications
