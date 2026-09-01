const express = require('express');
const router = express.Router();
const pool = require('../models/db');
const { verifyToken, verifyAdmin } = require('../middleware/authMiddleware');

// GET : Lister tous les utilisateurs
router.get('/', verifyToken, verifyAdmin, async (req, res) => {
    try {
        const result = await pool.query('SELECT id, email, first_name, last_name, role, created_at FROM users ORDER BY id DESC');
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// PUT : Modifier le rôle (Client/Admin)
router.put('/:id/role', verifyToken, verifyAdmin, async (req, res) => {
    try {
        const { role } = req.body;
        await pool.query('UPDATE users SET role = $1 WHERE id = $2', [role, req.params.id]);
        res.json({ message: 'Rôle mis à jour' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// DELETE : Supprimer un compte
router.delete('/:id', verifyToken, verifyAdmin, async (req, res) => {
    try {
        await pool.query('DELETE FROM users WHERE id = $1', [req.params.id]);
        res.json({ message: 'Utilisateur supprimé' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

module.exports = router;