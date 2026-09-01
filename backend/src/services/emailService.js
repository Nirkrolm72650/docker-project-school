const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail', // Fonctionne aussi avec Outlook (smtp.office365.com)
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

const sendEmail = async (to, subject, text) => {
  if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
    console.log(`[SIMULATION EMAIL] 📧 Destinataire: ${to} | Sujet: ${subject} | Message: ${text}`);
    return true;
  }

  try {
    await transporter.sendMail({
      from: `"E-Commerce Shop" <${process.env.EMAIL_USER}>`,
      to,
      subject,
      text,
    });
    console.log(`Email envoyé avec succès à ${to}`);
  } catch (error) {
    console.error("Erreur lors de l'envoi de l'email :", error);
  }
};

// 1. E-mail de bienvenue lors de la création du compte
const sendWelcomeEmail = async (userEmail) => {
  const subject = "Bienvenue sur notre boutique !";
  const text = "Bonjour,\n\nVotre compte a bien été créé avec succès. Bienvenue sur notre plateforme e-commerce !\n\nÀ très vite !";
  await sendEmail(userEmail, subject, text);
};

// 2. E-mail de confirmation lors d'une commande passée
const sendOrderConfirmationEmail = async (userEmail, orderId, totalAmount) => {
  const subject = `Confirmation de votre commande #${orderId}`;
  const text = `Bonjour,\n\nMerci pour votre achat ! Votre commande #${orderId} d'un montant total de ${totalAmount} € a bien été enregistrée.\n\nNous préparons votre colis avec soin.`;
  await sendEmail(userEmail, subject, text);
};

// 3. E-mail lors du changement de statut de la commande
const sendOrderStatusEmail = async (userEmail, orderId, newStatus) => {
  const subject = `Mise à jour de votre commande #${orderId}`;
  const text = `Bonjour,\n\nLe statut de votre commande #${orderId} a été mis à jour : "${newStatus}".\n\nMerci pour votre confiance !`;
  await sendEmail(userEmail, subject, text);
};

module.exports = {
  sendEmail,
  sendWelcomeEmail,
  sendOrderConfirmationEmail,
  sendOrderStatusEmail,
};