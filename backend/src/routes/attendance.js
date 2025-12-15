const express = require('express');
const router = express.Router();
const { requireAuth, requireSubcommitteeLeadership } = require('../middleware/auth');
const db = require('../config/database');

router.get('/:eventId', requireAuth, async (req, res) => {
  try {
    const result = await db.query(`
      SELECT a.*, m.first_name, m.last_name, m.email
      FROM attendance a
      JOIN members m ON a.member_id = m.id
      WHERE a.event_id = $1
    `, [req.params.eventId]);
    res.json(result.rows);
  } catch (error) {
    console.error('Get attendance error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/:eventId', requireAuth, requireSubcommitteeLeadership, async (req, res) => {
  try {
    const { memberId, status, notes } = req.body;

    const eventCheck = await db.query('SELECT associated_subcommittee_id FROM events WHERE id = $1', [req.params.eventId]);
    if (!eventCheck.rows.length) return res.status(404).json({ error: 'Event not found' });

    const subcommitteeId = eventCheck.rows[0].associated_subcommittee_id;
    if (!subcommitteeId) return res.status(400).json({ error: 'Attendance only for subcommittee meetings' });

    const membership = await db.query('SELECT 1 FROM member_subcommittees WHERE member_id = $1 AND subcommittee_id = $2', [memberId, subcommitteeId]);
    if (!membership.rows.length) return res.status(400).json({ error: 'Member not in this subcommittee' });

    const result = await db.query(`
      INSERT INTO attendance (event_id, member_id, status, notes, recorded_by)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (event_id, member_id)
      DO UPDATE SET status = $3, notes = $4, recorded_by = $5, created_at = NOW()
      RETURNING *
    `, [req.params.eventId, memberId, status, notes, req.session.memberId]);

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Record attendance error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
