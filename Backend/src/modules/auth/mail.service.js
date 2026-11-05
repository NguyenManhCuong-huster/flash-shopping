import nodemailer from 'nodemailer';
import { env } from '../../config/env.js';

let transporter = null;

function getTransporter() {
  if (!env.smtp.host) return null;
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: env.smtp.host,
      port: env.smtp.port,
      secure: env.smtp.secure,
      auth: env.smtp.user ? { user: env.smtp.user, pass: env.smtp.pass } : undefined,
    });
  }
  return transporter;
}

/** Gửi mã OTP xác minh email. Không cấu hình SMTP thì in ra log (môi trường dev). */
export async function sendVerificationEmail(to, name, code) {
  const t = getTransporter();
  const minutes = env.verificationCodeTtlMinutes;
  if (!t) {
    console.log(`[mail] (SMTP chưa cấu hình) OTP cho ${to}: ${code}`);
    return;
  }
  await t.sendMail({
    from: env.smtp.from,
    to,
    subject: `Mã xác minh Đi chợ tiện lợi: ${code}`,
    text: `Xin chào ${name},\n\nMã xác minh của bạn là: ${code}\nMã có hiệu lực trong ${minutes} phút.\n\nĐi chợ tiện lợi`,
    html: `<p>Xin chào <b>${escapeHtml(name)}</b>,</p>
           <p>Mã xác minh của bạn là:</p>
           <p style="font-size:28px;font-weight:bold;letter-spacing:6px">${code}</p>
           <p>Mã có hiệu lực trong ${minutes} phút.</p><p>Đi chợ tiện lợi</p>`,
  });
}

const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
