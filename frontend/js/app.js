const API_URL = 'http://localhost:3000/api';
let products = [];
let cart = [];
let isRegisterMode = false;
let authToken = localStorage.getItem('jwt_token');
let userEmail = localStorage.getItem('user_email');

document.addEventListener('DOMContentLoaded', () => {
    loadProducts();
    updateAuthUI();
});

// 1. Charger les produits
async function loadProducts() {
    const grid = document.getElementById('product-grid');
    try {
        const response = await fetch(`${API_URL}/products`);
        if (!response.ok) throw new Error('Erreur réseau');
        products = await response.json();
        
        grid.innerHTML = '';
        products.forEach(product => {
            const card = `
                <div class="bg-white rounded-xl shadow-md overflow-hidden hover:shadow-lg transition flex flex-col">
                    <img src="${product.image_url}" alt="${product.name}" class="h-48 w-full object-cover">
                    <div class="p-5 flex flex-col flex-grow">
                        <h4 class="font-bold text-lg text-gray-800 mb-1">${product.name}</h4>
                        <p class="text-gray-500 text-sm flex-grow mb-4">${product.description || ''}</p>
                        <div class="flex justify-between items-center mt-auto">
                            <span class="text-xl font-extrabold text-indigo-600">${product.price} €</span>
                            <button onclick="addToCart(${product.id})" class="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-indigo-700 transition">Ajouter</button>
                        </div>
                    </div>
                </div>
            `;
            grid.insertAdjacentHTML('beforeend', card);
        });
    } catch (error) {
        console.error(error);
        grid.innerHTML = '<p class="col-span-full text-center text-red-500">Impossible de charger les produits. Vérifiez que le backend tourne.</p>';
    }
}

// 2. Gestion du Panier
function addToCart(productId) {
    const product = products.find(p => p.id === productId);
    if (!product) return;

    const existing = cart.find(item => item.product_id === productId);
    if (existing) {
        existing.quantity += 1;
    } else {
        cart.push({ product_id: product.id, name: product.name, price: product.price, quantity: 1 });
    }
    updateCartCount();
}

function updateCartCount() {
    const totalItems = cart.reduce((sum, item) => sum + item.quantity, 0);
    document.getElementById('cart-count').innerText = totalItems;
}

function toggleCartModal() {
    const modal = document.getElementById('cart-modal');
    modal.classList.toggle('hidden');
    if (!modal.classList.contains('hidden')) {
        renderCartItems();
    }
}

function renderCartItems() {
    const container = document.getElementById('cart-items');
    const totalEl = document.getElementById('cart-total');
    
    if (cart.length === 0) {
        container.innerHTML = '<p class="text-gray-500 text-center py-8">Votre panier est vide.</p>';
        totalEl.innerText = '0.00 €';
        return;
    }

    container.innerHTML = '';
    let total = 0;

    cart.forEach(item => {
        total += item.price * item.quantity;
        container.insertAdjacentHTML('beforeend', `
            <div class="flex justify-between items-center border-b pb-3">
                <div>
                    <h4 class="font-bold text-gray-800">${item.name}</h4>
                    <p class="text-sm text-gray-500">${item.price} € x ${item.quantity}</p>
                </div>
                <span class="font-bold text-indigo-600">${(item.price * item.quantity).toFixed(2)} €</span>
            </div>
        `);
    });
    totalEl.innerText = `${total.toFixed(2)} €`;
}

// 3. Passage de commande (Checkout)
async function checkout() {
    if (!authToken) {
        alert('Veuillez vous connecter pour passer une commande.');
        toggleCartModal();
        openAuthModal();
        return;
    }

    if (cart.length === 0) {
        alert('Votre panier est vide.');
        return;
    }

    const shipping_address = document.getElementById('shipping-address').value;
    if (!shipping_address) {
        alert('Veuillez renseigner une adresse de livraison.');
        return;
    }

    const payload = {
        items: cart.map(item => ({ product_id: item.product_id, quantity: item.quantity })),
        shipping_address
    };

    try {
        const response = await fetch(`${API_URL}/orders`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${authToken}`
            },
            body: JSON.stringify(payload)
        });

        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Erreur lors de la commande');

        alert(`Commande #${data.order.id} passée avec succès ! Un e-mail de confirmation a été déclenché.`);
        cart = [];
        updateCartCount();
        toggleCartModal();
    } catch (err) {
        alert('Erreur : ' + err.message);
    }
}

// 4. Authentification & UI Client
function openAuthModal() {
    document.getElementById('auth-modal').classList.toggle('hidden');
}

function toggleAuthMode() {
    isRegisterMode = !isRegisterMode;
    document.getElementById('name-fields').classList.toggle('hidden');
    document.getElementById('auth-title').innerText = isRegisterMode ? 'Inscription Client' : 'Connexion Client';
    document.getElementById('auth-submit-btn').innerText = isRegisterMode ? "S'inscrire" : 'Se connecter';
    document.getElementById('auth-switch-text').innerText = isRegisterMode ? 'Déjà un compte ? Se connecter' : "Pas encore de compte ? S'inscrire";
}

async function handleAuth(event) {
    event.preventDefault();
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    const errorDiv = document.getElementById('auth-error');
    errorDiv.classList.add('hidden');

    const endpoint = isRegisterMode ? '/auth/register' : '/auth/login';
    const payload = { email, password };

    if (isRegisterMode) {
        payload.first_name = document.getElementById('first_name').value;
        payload.last_name = document.getElementById('last_name').value;
    }

    try {
        const response = await fetch(`${API_URL}${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        const data = await response.json();
        if (!response.ok) throw new Error(data.error || 'Erreur d’authentification');

        if (isRegisterMode) {
            alert('Compte créé avec succès ! Vous pouvez maintenant vous connecter.');
            toggleAuthMode();
        } else {
            authToken = data.token;
            localStorage.setItem('jwt_token', authToken);
            localStorage.setItem('user_email', email);
            // Stocke le prénom renvoyé par l'API (ou l'email par défaut si absent)
            localStorage.setItem('user_name', data.first_name || email);
            
            openAuthModal();
            updateAuthUI();
            alert('Connexion réussie !');
        }
    } catch (err) {
        errorDiv.innerText = err.message;
        errorDiv.classList.remove('hidden');
    }
}

function updateAuthUI() {
    const container = document.getElementById('auth-container');
    const userName = localStorage.getItem('user_name') || localStorage.getItem('user_email');
    
    if (authToken) {
        container.innerHTML = `
            <div class="flex items-center space-x-3">
                <span class="text-sm font-medium text-gray-700 hidden md:inline">👤 ${userName}</span>
                <button onclick="logout()" class="text-sm text-red-600 hover:underline">Déconnexion</button>
            </div>
        `;
    } else {
        container.innerHTML = `<button onclick="openAuthModal()" class="text-sm font-medium text-indigo-600 hover:text-indigo-800">Connexion / Inscription</button>`;
    }
}

function logout() {
    localStorage.removeItem('jwt_token');
    localStorage.removeItem('user_email');
    authToken = null;
    updateAuthUI();
    alert('Déconnecté.');
}