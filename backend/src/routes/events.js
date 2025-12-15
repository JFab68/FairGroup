const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const db = require('../config/database');

router.get('/', requireAuth, async (req, res) => {
  try {
    const { filter } = req.query;
    let query = `
      SELECT e.*, s.name as subcommittee_name
      FROM events e
      LEFT JOIN subcommittees s ON e.associated_subcommittee_id = s.id
    `;

    if (filter === 'my-subcommittees') {
      query += ` WHERE e.associated_subcommittee_id IN (
        SELECT subcommittee_id FROM member_subcommittees WHERE member_id = $1
      ) OR e.associated_subcommittee_id IS NULL`;
    }

    query += ` ORDER BY e.start_datetime ASC`;

    const result = await db.query(query, filter === 'my-subcommittees' ? [req.session.memberId] : []);
    res.json(result.rows);
  } catch (error) {
    console.error('Get events error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/', requireAuth, async (req, res) => {
  try {
    const { title, description, start_datetime, end_datetime, location, associated_subcommittee_id } = req.body;

    if (associated_subcommittee_id) {
      const subcommittee = await db.query('SELECT chair_id, vice_chair_id FROM subcommittees WHERE id = $1', [associated_subcommittee_id]);
      if (!subcommittee.rows.length) return res.status(404).json({ error: 'Subcommittee not found' });
      const { chair_id, vice_chair_id } = subcommittee.rows[0];
      if (req.session.role !== 'admin' && chair_id !== req.session.memberId && vice_chair_id !== req.session.memberId) {
        return res.status(403).json({ error: 'Only subcommittee leadership can create meetings' });
      }
    } else if (req.session.role !== 'admin') {
      return res.status(403).json({ error: 'Only admins can create group-wide events' });
    }

    const result = await db.query('INSERT INTO events (title, description, start_datetime, end_datetime, location, associated_subcommittee_id, created_by) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *', [title, description, start_datetime, end_datetime, location, associated_subcommittee_id, req.session.memberId]);
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create event error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
