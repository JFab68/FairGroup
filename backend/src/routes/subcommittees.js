const express = require('express');
const router = express.Router();
const { requireAuth, requireSubcommitteeLeadership } = require('../middleware/auth');
const db = require('../config/database');

router.get('/', requireAuth, async (req, res) => {
  try {
    const result = await db.query(`
      SELECT s.*,
        json_build_object('id', c.id, 'name', c.first_name || ' ' || c.last_name, 'email', c.email) as chair,
        json_build_object('id', v.id, 'name', v.first_name || ' ' || v.last_name, 'email', v.email) as vice_chair
      FROM subcommittees s
      LEFT JOIN members c ON s.chair_id = c.id
      LEFT JOIN members v ON s.vice_chair_id = v.id
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Get subcommittees error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/:id', requireAuth, async (req, res) => {
  try {
    const result = await db.query(`
      SELECT s.*,
        json_build_object('id', c.id, 'name', c.first_name || ' ' || c.last_name, 'email', c.email) as chair,
        json_build_object('id', v.id, 'name', v.first_name || ' ' || v.last_name, 'email', v.email) as vice_chair,
        json_agg(json_build_object('id', m.id, 'name', m.first_name || ' ' || m.last_name, 'email', m.email)) FILTER (WHERE m.id IS NOT NULL) as members
      FROM subcommittees s
      LEFT JOIN members c ON s.chair_id = c.id
      LEFT JOIN members v ON s.vice_chair_id = v.id
      LEFT JOIN member_subcommittees ms ON s.id = ms.subcommittee_id
      LEFT JOIN members m ON ms.member_id = m.id
      WHERE s.id = $1
      GROUP BY s.id, c.id, v.id
    `, [req.params.id]);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Get subcommittee detail error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.put('/:id', requireAuth, requireSubcommitteeLeadership, async (req, res) => {
  try {
    const { description, meeting_schedule } = req.body;
    const result = await db.query('UPDATE subcommittees SET description = $1, meeting_schedule = $2 WHERE id = $3 RETURNING *', [description, meeting_schedule, req.params.id]);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Update subcommittee error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/:id/members', requireAuth, requireSubcommitteeLeadership, async (req, res) => {
  try {
    await db.query('INSERT INTO member_subcommittees (member_id, subcommittee_id) VALUES ($1, $2)', [req.body.memberId, req.params.id]);
    res.json({ message: 'Member added' });
  } catch (error) {
    console.error('Add member to subcommittee error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.delete('/:id/members/:memberId', requireAuth, requireSubcommitteeLeadership, async (req, res) => {
  try {
    await db.query('DELETE FROM member_subcommittees WHERE member_id = $1 AND subcommittee_id = $2', [req.params.memberId, req.params.id]);
    res.json({ message: 'Member removed' });
  } catch (error) {
    console.error('Remove member from subcommittee error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
