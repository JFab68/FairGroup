const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const db = require('../config/database');

router.post('/signup', [
  body('first_name').notEmpty().trim().escape(),
  body('last_name').notEmpty().trim().escape(),
  body('email').isEmail().normalizeEmail(),
  body('phone').optional().trim().escape(),
  body('county_or_city').optional().trim().escape(),
  body('system_impact').isIn(['Yes', 'No', 'Prefer not to say']),
  body('involvement_interest').optional().trim()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    const { first_name, last_name, email, phone, county_or_city, system_impact, involvement_interest } = req.body;

    await db.query('INSERT INTO public_contacts (first_name, last_name, email, phone, county_or_city, system_impact, involvement_interest) VALUES ($1, $2, $3, $4, $5, $6, $7)', [first_name, last_name, email, phone, county_or_city, system_impact, involvement_interest]);

    res.status(201).json({ message: 'Thank you, we'll follow up with more information.' });
  } catch (error) {
    console.error('Public signup error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
