const pool = require('./db');

setInterval(async () => {
    console.log("[WORKER] Vérification des nouvelles commandes...");
    try {
        // 1. Récupérer une commande en attente
        const res = await pool.query("SELECT * FROM orders WHERE status = 'pending' LIMIT 1");
        
        if (res.rows.length > 0) {
            const order = res.rows[0];
            console.log(`[WORKER SUCCESS] Traitement de la commande #${order.id} - Envoi de l'e-mail de confirmation simulé.`);
            
            // 2. Mettre à jour le statut pour qu'elle ne soit plus traitée en boucle
            await pool.query("UPDATE orders SET status = 'processed' WHERE id = $1", [order.id]);
            
            console.log(`[WORKER] Commande #${order.id} marquée comme traitée.`);
        }
    } catch (err) {
        console.error("[WORKER ERROR]", err.message);
    }
}, 5000);