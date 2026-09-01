const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail', // Fonctionne aussi avec Outlook (smtp.office365.com)
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

const sendEmail = async (to, subject, text) => {
  if (!process.env.EMAIL_USER || process.env.EMAIL_USER === !process.env.EMAIL_PASS) {
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

module.exports = { sendEmail };