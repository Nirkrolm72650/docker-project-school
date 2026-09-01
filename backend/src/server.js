const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
require('dotenv').config();

const pool = require('./models/db');
const { sendEmail } = require('./services/emailService');
const { verifyToken, verifyAdmin } = require('./middleware/authMiddleware');

const app = express();
app.use(cors());
app.use(express.json());

// ==========================================
// 1. AUTHENTIFICATION & COMPTES CLIENTS
// ==========================================

// Inscription client
app.post('/api/auth/register', async (req, res) => {
  const { email, password, first_name, last_name } = req.body;
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const query = `
      INSERT INTO users (email, password_hash, first_name, last_name, role) 
      VALUES ($1, $2, $3, $4, 'client') 
      RETURNING id, email, first_name, last_name, role
    `;
    const result = await pool.query(query, [email, hashedPassword, first_name, last_name]);
    
    // Notification par email
    await sendEmail(email, 'Bienvenue sur notre E-Shop !', `Bonjour ${first_name}, votre compte client a été créé avec succès.`);

    res.status(201).json({ message: 'Compte créé avec succès', user: result.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Erreur lors de l'inscription (cet email est peut-être déjà utilisé)." });
  }
});



// Connexion (Client ou Admin) -> Renvoie un JWT
app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) return res.status(401).json({ error: 'Identifiants invalides.' });

    const user = result.rows[0];
    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) return res.status(401).json({ error: 'Identifiants invalides.' });

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role }, 
      process.env.JWT_SECRET || 'supersecret', 
      { expiresIn: '24h' }
    );

    res.json({ message: 'Connexion réussie', token, role: user.role });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erreur serveur lors de la connexion.' });
  }
});

const adminUsersRoutes = require('./routes/adminUsers');
app.use('/api/admin/users', adminUsersRoutes);

// ==========================================
// 2. PRODUITS (CRUD Public & Admin)
// ==========================================

// [GET] Lire tous les produits (Public)
app.get('/api/products', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products ORDER BY id ASC');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la récupération des produits.' });
  }
});

// [GET] Lire un produit par ID (Public)
app.get('/api/products/:id', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Produit non trouvé.' });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Erreur serveur.' });
  }
});

// [POST] Créer un produit (Admin uniquement)
app.post('/api/products', verifyAdmin, async (req, res) => {
  const { name, description, price, stock, image_url, category_id } = req.body;
  try {
    const query = `
      INSERT INTO products (name, description, price, stock, image_url, category_id) 
      VALUES ($1, $2, $3, $4, $5, $6) 
      RETURNING *
    `;
    const result = await pool.query(query, [name, description, price, stock, image_url, category_id]);
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la création du produit.' });
  }
});

// [PUT] Modifier un produit (Admin uniquement)
app.put('/api/products/:id', verifyAdmin, async (req, res) => {
  const { name, description, price, stock, image_url, category_id } = req.body;
  try {
    const query = `
      UPDATE products 
      SET name = $1, description = $2, price = $3, stock = $4, image_url = $5, category_id = $6 
      WHERE id = $7 
      RETURNING *
    `;
    const result = await pool.query(query, [name, description, price, stock, image_url, category_id, req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Produit non trouvé.' });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la mise à jour.' });
  }
});

// [DELETE] Supprimer un produit (Admin uniquement)
app.delete('/api/products/:id', verifyAdmin, async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM products WHERE id = $1 RETURNING *', [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Produit non trouvé.' });
    res.json({ message: 'Produit supprimé avec succès.' });
  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la suppression.' });
  }
});

// ==========================================
// 3. COMMANDES (Orders & Admin Back-office)
// ==========================================

// [POST] Passer une commande (Client authentifié)
app.post('/api/orders', verifyToken, async (req, res) => {
  const { items, shipping_address } = req.body; // items attendu sous la forme : [{ product_id: 1, quantity: 2 }, ...]
  const client = await pool.connect();

  try {
    await client.query('BEGIN'); // Sécurisation par transaction SQL

    let total_amount = 0;
    const evaluatedItems = [];

    for (let item of items) {
      const prodRes = await client.query('SELECT price, stock FROM products WHERE id = $1', [item.product_id]);
      if (prodRes.rows.length === 0) throw new Error(`Produit ID ${item.product_id} introuvable.`);
      
      const product = prodRes.rows[0];
      if (product.stock < item.quantity) throw new Error(`Stock insuffisant pour le produit ID ${item.product_id}.`);

      total_amount += product.price * item.quantity;
      evaluatedItems.push({ product_id: item.product_id, quantity: item.quantity, price: product.price });
    }

    // Création de la commande globale
    const orderRes = await client.query(
      'INSERT INTO orders (user_id, total_amount, shipping_address, status) VALUES ($1, $2, $3, $4) RETURNING *',
      [req.user.id, total_amount, shipping_address, 'pending']
    );
    const order = orderRes.rows[0];

    // Insertion des lignes de commande et mise à jour du stock
    for (let item of evaluatedItems) {
      await client.query(
        'INSERT INTO order_items (order_id, product_id, quantity, price_at_purchase) VALUES ($1, $2, $3, $4)',
        [order.id, item.product_id, item.quantity, item.price]
      );
      await client.query('UPDATE products SET stock = stock - $1 WHERE id = $2', [item.quantity, item.product_id]);
    }

    await client.query('COMMIT'); // Validation de la transaction

    // Envoi d'un email de confirmation de commande
    const userRes = await pool.query('SELECT email FROM users WHERE id = $1', [req.user.id]);
    if (userRes.rows.length > 0) {
      await sendEmail(userRes.rows[0].email, 'Confirmation de votre commande', `Votre commande #${order.id} d'un montant total de ${total_amount}€ a bien été prise en compte.`);
    }

    res.status(201).json({ message: 'Commande passée avec succès', order });
  } catch (err) {
    await client.query('ROLLBACK'); // Annulation en cas d'erreur
    res.status(400).json({ error: err.message });
  } finally {
    client.release();
  }
});

// [GET] Voir l'historique de ses commandes (Client)
app.get('/api/orders', verifyToken, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM orders WHERE user_id = $1 ORDER BY created_at DESC', [req.user.id]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Erreur lors de la récupération des commandes.' });
  }
});

// [GET] Voir TOUTES les commandes (Admin uniquement - Back-office)
app.get('/api/admin/orders', verifyAdmin, async (req, res) => {
  try {
    const query = `
      SELECT o.*, u.email as user_email 
      FROM orders o 
      JOIN users u ON o.user_id = u.id 
      ORDER BY o.created_at DESC
    `;
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Erreur admin commandes.' });
  }
});

// [PUT] Modifier le statut d'une commande (Admin uniquement)
// [PUT] Modifier le statut d'une commande (Admin uniquement)
app.put('/api/admin/orders/:id/status', verifyAdmin, async (req, res) => {
  const { status } = req.body; // ex: 'paid', 'shipped', 'delivered', 'cancelled'
  try {
    // 1. Mise à jour du statut en base
    const result = await pool.query('UPDATE orders SET status = $1 WHERE id = $2 RETURNING *', [status, req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Commande non trouvée.' });
    
    const updatedOrder = result.rows[0];

    // 2. Récupérer l'e-mail de l'utilisateur lié à cette commande pour le notifier
    const userRes = await pool.query('SELECT email FROM users WHERE id = $1', [updatedOrder.user_id]);
    if (userRes.rows.length > 0) {
      const userEmail = userRes.rows[0].email;
      await sendEmail(
        userEmail, 
        `Mise à jour de votre commande #${updatedOrder.id}`, 
        `Bonjour,\n\nLe statut de votre commande #${updatedOrder.id} a été mis à jour : "${updatedOrder.status}".\n\nMerci pour votre confiance !`
      );
    }

    res.json({ message: 'Statut mis à jour et email envoyé avec succès', order: updatedOrder });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Erreur lors de la mise à jour du statut.' });
  }
});



// Lancement du serveur
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Serveur Node.js démarré sur le port ${PORT}`);
});