const { S3Client, PutObjectCommand, GetObjectCommand, HeadBucketCommand } = require('@aws-sdk/client-s3');
require('dotenv').config();

const region = process.env.AWS_REGION || 'us-east-1';
let endpoint = process.env.AWS_ENDPOINT_URL || 'http://localhost:4566';

// Si l'application s'exécute dans un conteneur Docker et que l'endpoint cible localhost,
// rediriger vers host.docker.internal pour joindre LocalStack sur l'hôte.
if (require('fs').existsSync('/.dockerenv') && endpoint.includes('localhost')) {
  endpoint = endpoint.replace('localhost', 'host.docker.internal');
}

const bucketName = process.env.S3_BUCKET_NAME || 'ecom-localstack-storage';

// Client S3 configuré pour LocalStack avec forcePathStyle
const s3Client = new S3Client({
  region,
  endpoint,
  forcePathStyle: true,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test',
  },
});

/**
 * Téléverse une facture PDF vers le bucket S3 LocalStack
 * @param {number|string} orderId - L'ID de la commande
 * @param {Buffer} pdfBuffer - Le buffer du PDF généré
 * @returns {Promise<{bucket: string, key: string, location: string}>}
 */
async function uploadInvoice(orderId, pdfBuffer) {
  const key = `invoices/facture-${orderId}.pdf`;
  const command = new PutObjectCommand({
    Bucket: bucketName,
    Key: key,
    Body: pdfBuffer,
    ContentType: 'application/pdf',
    Metadata: {
      orderId: String(orderId),
      uploadedAt: new Date().toISOString(),
    },
  });

  try {
    await s3Client.send(command);
    const fileUrl = `${endpoint}/${bucketName}/${key}`;
    console.log(`[S3 SUCCESS] Facture téléversée avec succès dans S3 : s3://${bucketName}/${key}`);
    return { bucket: bucketName, key, url: fileUrl };
  } catch (error) {
    console.error(`[S3 ERROR] Échec de l'upload de la facture #${orderId} vers S3:`, error.message);
    throw error;
  }
}

/**
 * Récupère le stream d'une facture PDF depuis S3
 * @param {number|string} orderId
 * @returns {Promise<{stream: ReadableStream, contentType: string}>}
 */
async function getInvoiceStream(orderId) {
  const key = `invoices/facture-${orderId}.pdf`;
  const command = new GetObjectCommand({
    Bucket: bucketName,
    Key: key,
  });

  try {
    const response = await s3Client.send(command);
    return {
      stream: response.Body,
      contentType: response.ContentType || 'application/pdf',
    };
  } catch (error) {
    console.error(`[S3 ERROR] Impossible de récupérer la facture #${orderId} depuis S3:`, error.message);
    throw error;
  }
}

/**
 * Vérifie l'état de santé du bucket S3
 */
async function checkBucketHealth() {
  try {
    await s3Client.send(new HeadBucketCommand({ Bucket: bucketName }));
    return true;
  } catch (err) {
    console.warn(`[S3 WARN] Bucket ${bucketName} non accessible ou non encore prêt:`, err.message);
    return false;
  }
}

module.exports = {
  s3Client,
  bucketName,
  uploadInvoice,
  getInvoiceStream,
  checkBucketHealth,
};

