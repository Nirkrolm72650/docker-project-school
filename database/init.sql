-- ==========================================
-- E-COMMERCE DATABASE INITIALIZATION SCRIPT
-- ==========================================

-- Extension pour la génération d'UUID (optionnel, on utilise des SERIAL ici pour faire simple)
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Table des utilisateurs (Clients et Admins)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'client', -- 'client' ou 'admin'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Table des catégories de produits
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT
);

-- 3. Table des produits
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    image_url VARCHAR(255),
    category_id INT REFERENCES categories(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Table des commandes (Orders)
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id) ON DELETE CASCADE,
    total_amount DECIMAL(10, 2) NOT NULL CHECK (total_amount >= 0),
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'paid', 'shipped', 'delivered', 'cancelled'
    shipping_address TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Table de liaison Commandes <-> Produits (Order Items)
CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id) ON DELETE CASCADE,
    product_id INT REFERENCES products(id) ON DELETE SET NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    price_at_purchase DECIMAL(10, 2) NOT NULL CHECK (price_at_purchase >= 0)
);

-- ==========================================
-- JEU DE DONNÉES INITIAL (SEED DATA)
-- ==========================================

-- Insertion de catégories supplémentaires
INSERT INTO categories (name, description) VALUES 
('High-Tech', 'Ordinateurs, smartphones et accessoires connectés'),
('Vêtements', 'Mode homme et femme, tendances actuelles'),
('Maison & Déco', 'Tout pour équiper et décorer votre intérieur'),
('Sports & Loisirs', 'Équipements de fitness, outdoor et loisirs'),
('Livres & Culture', 'Romans, manuels techniques et beaux livres')
ON CONFLICT (name) DO NOTHING;

-- Insertion d'un catalogue produit varié et réaliste
INSERT INTO products (name, description, price, stock, image_url, category_id) VALUES 
-- High-Tech (Category 1)
('PC Portable Gamer X', 'Processeur ultra-rapide, 16Go RAM, Carte graphique dédiée', 1299.99, 10, 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7', 1),
('Casque Audio Sans Fil', 'Réduction de bruit active, autonomie 30h', 199.99, 25, 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e', 1),
('Smartphone Pro Max', 'Écran OLED 6.7 pouces, triple capteur photo, 256Go', 999.00, 15, 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9', 1),
('Tablette Tactile Ultra', 'Légère et puissante, idéale pour le multimédia et la création', 489.99, 20, 'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0', 1),
('Montre Connectée Sport', 'Suivi GPS, fréquence cardiaque, étanche 5ATM', 149.50, 30, 'https://images.unsplash.com/photo-1523275335684-37898b6baf30', 1),

-- Vêtements (Category 2)
('Sweat à capuche Minimaliste', '100% coton bio, confort optimal', 49.99, 50, 'https://images.unsplash.com/photo-1556905055-8f358a7a47b2', 2),
('Jean Slim Stretch', 'Coupe ajustée, denim résistant et confortable', 69.90, 40, 'https://images.unsplash.com/photo-1542272604-787c3835535d', 2),
('Veste en Cuir Vintage', 'Cuir souple véritable, style intemporel', 199.00, 8, 'https://images.unsplash.com/photo-1551028719-00167b16eac5', 2),
('Baskets Sneakers Urbaines', 'Design épuré, semelle amortissante pour la ville', 89.99, 35, 'https://images.unsplash.com/photo-1542291026-7eec264c27ff', 2),

-- Maison & Déco (Category 3)
('Lampe de Bureau LED', 'Design moderne avec chargeur induction intégré', 39.99, 18, 'https://images.unsplash.com/photo-1534447677768-be436bb09401', 3),
('Plante d''Intérieur Monstera', 'Fournie avec son pot en céramique design, facile d''entretien', 34.50, 12, 'https://images.unsplash.com/photo-1614594975525-e45190c55d0b', 3),
('Ensemble de Tasses à Café', 'Céramique artisanale, lot de 4 pièces compatibles micro-ondes', 24.99, 25, 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd', 3),

-- Sports & Loisirs (Category 4)
('Tapis de Yoga Antidérapant', 'Épaisseur 6mm, éco-responsable et facile à transporter', 29.99, 45, 'https://images.unsplash.com/photo-1601925260368-ae2f83cf8b7f', 4),
('Gourde Isotherme Inox', 'Maintient au froid 24h et au chaud 12h, 750ml', 25.00, 60, 'https://images.unsplash.com/photo-1602143407151-7111542de6e8', 4),
('Haltères Ajustables (Paire)', 'De 2kg à 24kg par haltère, gain de place assuré', 249.99, 7, 'https://images.unsplash.com/photo-1584735935682-2f2b69dff9d2', 4),

-- Livres & Culture (Category 5)
('Guide du Développement Web Full-Stack', 'De la conception à la mise en production sous Docker', 45.00, 22, 'https://images.unsplash.com/photo-1532012197267-da84d127e765', 5),
('Roman de Science-Fiction - Odyssée', 'Un best-seller captivant sur l''exploration spatiale', 19.90, 30, 'https://images.unsplash.com/photo-1512820790803-83ca734da794', 5)
ON CONFLICT DO NOTHING;

-- 1. Activation de l'extension de chiffrement native de PostgreSQL
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 2. Insertion de l'administrateur avec hachage dynamique (bcrypt, coût 10)
INSERT INTO users (email, password_hash, first_name, last_name, role) 
VALUES (
    'admin@test.com', 
    crypt('admin123', gen_salt('bf', 10)), 
    'Brandon',
    'Admin',
    'admin'
)
ON CONFLICT (email) DO NOTHING;