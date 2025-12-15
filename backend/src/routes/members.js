const express = require('express');
const router = express.Router();
const { requireAuth, requireRole } = require('../middleware/auth');
const db = require('../config/database');

router.get('/me', requireAuth, async (req, res) => {
  try {
    const result = await db.query('SELECT id, first_name, last_name, email, phone, role FROM members WHERE id = $1', [req.session.memberId]);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get member error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.put('/me', requireAuth, async (req, res) => {
  try {
    const { first_name, last_name, phone } = req.body;
    const result = await db.query('UPDATE members SET first_name = $1, last_name = $2, phone = $3 WHERE id = $4 RETURNING *', [first_name, last_name, phone, req.session.memberId]);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update member error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/', requireAuth, requireRole('admin'), async (req, res) => {
  try {
    const result = await db.query(`
      SELECT m.*, array_agg(s.name) as subcommittees
      FROM members m
      LEFT JOIN member_subcommittees ms ON m.id = ms.member_id
      LEFT JOIN subcommittees s ON ms.subcommittee_id = s.id
      GROUP BY m.id
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Get all members error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
