const express = require('express');
const PDFDocument = require('pdfkit');

const app = express();
app.use(express.json());

app.post('/generate-invoice', (req, res) => {
  const { order, user, items } = req.body;

  const doc = new PDFDocument({ margin: 50 });
  const buffers = [];

  doc.on('data', chunk => buffers.push(chunk));
  doc.on('end', () => {
    const pdfBuffer = Buffer.concat(buffers);
    res.setHeader('Content-Type', 'application/pdf');
    res.send(pdfBuffer);
  });
  doc.on('error', err => {
    console.error(err);
    res.status(500).json({ error: 'Erreur génération PDF' });
  });

  // --- En-tête de la facture ---
  doc.fontSize(20).text('FACTURE OFFICIELLE', { align: 'right' });
  doc.fontSize(10).text(`Facture N° : FAC-${order.id}`, { align: 'right' });
  doc.text(`Date : ${new Date(order.created_at).toLocaleDateString()}`, { align: 'right' });
  doc.moveDown();

  // --- Infos Entreprise / Client ---
  doc.fontSize(12).fillColor('#333333').text('E-Commerce Multi-Services', 50, 50);
  doc.fontSize(10).text('12 Rue de la République');
  doc.text('75001 Paris, France');
  doc.text('contact@ecommerce-docker.com');
  
  doc.moveDown(2);
  doc.fontSize(12).text(`Facturé à :`, 50, 150);
  doc.fontSize(10).text(`${user.first_name || 'Client'} ${user.last_name || ''}`);
  doc.text(`Email : ${user.email}`);
  doc.text(`Adresse de livraison : ${order.shipping_address}`);

  doc.moveDown(3);

  // --- Tableau des articles ---
  const tableTop = 240;
  doc.fontSize(10).fillColor('#000000');
  doc.text('Produit', 50, tableTop, { width: 250 });
  doc.text('Quantité', 310, tableTop, { width: 60, align: 'center' });
  doc.text('Prix Unitaire', 380, tableTop, { width: 80, align: 'right' });
  doc.text('Total', 470, tableTop, { width: 80, align: 'right' });

  doc.moveTo(50, tableTop + 15).lineTo(550, tableTop + 15).stroke();

  let position = tableTop + 25;
  items.forEach(item => {
    doc.text(item.name, 50, position, { width: 250 });
    doc.text(item.quantity.toString(), 310, position, { width: 60, align: 'center' });
    doc.text(`${item.price} €`, 380, position, { width: 80, align: 'right' });
    doc.text(`${item.subtotal} €`, 470, position, { width: 80, align: 'right' });
    position += 20;
  });

  doc.moveTo(50, position + 5).lineTo(550, position + 5).stroke();

  // --- Total ---
  doc.moveDown(2);
  doc.fontSize(12).text(`Montant Total : ${order.total_amount} €`, { align: 'right' });

  // --- Pied de page ---
  doc.fontSize(8).fillColor('#777777').text(
    'Document généré automatiquement par la plateforme E-Commerce Docker - Merci pour votre achat !', 
    50, 750, { align: 'center', width: 500 }
  );

  doc.end();
});

const PORT = 4000;
app.listen(PORT, () => {
  console.log(`Micro-service PDF démarré sur le port ${PORT}`);
});