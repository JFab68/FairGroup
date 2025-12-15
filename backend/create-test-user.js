// Script to create a test admin user
// Run this with: node create-test-user.js

require('dotenv').config();
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

async function createTestUser() {
  try {
    // Create password hash
    const password = 'admin123'; // Default password - CHANGE THIS!
    const saltRounds = parseInt(process.env.BCRYPT_ROUNDS) || 12;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Insert test admin user
    const result = await pool.query(
      `INSERT INTO members (first_name, last_name, email, phone, password_hash, role, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (email) DO UPDATE
       SET password_hash = $5, role = $6, status = $7
       RETURNING id, email, role`,
      ['Admin', 'User', 'admin@fairgroup.org', '555-0100', passwordHash, 'admin', 'active']
    );

    console.log('✅ Test user created successfully!');
    console.log('📧 Email:', result.rows[0].email);
    console.log('🔑 Password:', password);
    console.log('👤 Role:', result.rows[0].role);
    console.log('\n⚠️  IMPORTANT: Change this password after first login!');

    await pool.end();
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating test user:', error.message);
    console.error('\nMake sure:');
    console.error('1. PostgreSQL is running on port 5433');
    console.error('2. Database "fairgroup" exists');
    console.error('3. migrations.sql has been run');
    process.exit(1);
  }
}

createTestUser();
