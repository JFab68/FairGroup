const express = require('express');
const router = express.Router();
const { requireAuth } = require('../middleware/auth');
const db = require('../config/database');

router.get('/', requireAuth, async (req, res) => {
  try {
    const { scope, subcommittee_id } = req.query;
    let query = `SELECT r.*, m.first_name || ' ' || m.last_name as created_by_name FROM resources r JOIN members m ON r.created_by = m.id WHERE 1=1`;
    const params = [];
    if (scope) {
      query += ` AND r.scope = $${params.length + 1}`;
      params.push(scope);
    }
    if (subcommittee_id) {
      query += ` AND r.subcommittee_id = $${params.length + 1}`;
      params.push(subcommittee_id);
    }
    const result = await db.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Get resources error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/', requireAuth, async (req, res) => {
  try {
    const { title, description, url, category, scope, subcommittee_id } = req.body;
    const result = await db.query(
      'INSERT INTO resources (title, description, url, category, scope, subcommittee_id, created_by) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [title, description, url, category, scope, subcommittee_id, req.session.memberId]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create resource error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;