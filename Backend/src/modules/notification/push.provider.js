import fs from 'node:fs/promises';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env.js';

/**
 * Dịch vụ Push (tác nhân "Dịch vụ Email và Push").
 * send() trả về { status: 'ok' | 'invalid' | 'retry' | 'failed', error? }
 *  - invalid: token thiết bị hết hiệu lực => vô hiệu hóa token (UC06 - 4a)
 *  - retry:   lỗi tạm thời => thử lại có giới hạn (UC06 - 4b)
 */

const logProvider = {
  name: 'log',
  async send(token, msg) {
    console.log(`[push:log] -> ${token.slice(0, 12)}… | ${msg.title} | ${msg.body}`);
    return { status: 'ok' };
  },
};

let cachedToken = { value: null, exp: 0 };

async function googleAccessToken() {
  if (cachedToken.value && Date.now() < cachedToken.exp - 60_000) return cachedToken.value;
  const sa = JSON.parse(await fs.readFile(env.fcmServiceAccountFile, 'utf8'));
  const now = Math.floor(Date.now() / 1000);
  const assertion = jwt.sign(
    {
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    },
    sa.private_key,
    { algorithm: 'RS256' },
  );
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) throw new Error(`OAuth ${res.status}: ${await res.text()}`);
  const j = await res.json();
  cachedToken = { value: j.access_token, exp: Date.now() + j.expires_in * 1000 };
  return cachedToken.value;
}

const fcmProvider = {
  name: 'fcm',
  async send(token, { title, body, data = {} }) {
    try {
      const accessToken = await googleAccessToken();
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${env.fcmProjectId}/messages:send`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body },
            data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
            android: { priority: 'high', notification: { channel_id: 'expiry_reminders' } },
          },
        }),
        signal: AbortSignal.timeout(10_000),
      });
      if (res.ok) return { status: 'ok' };
      const text = await res.text();
      if (res.status === 404 || /UNREGISTERED|registration-token-not-registered/i.test(text)) {
        return { status: 'invalid', error: text.slice(0, 500) };
      }
      if (res.status === 429 || res.status >= 500) return { status: 'retry', error: text.slice(0, 500) };
      return { status: 'failed', error: text.slice(0, 500) };
    } catch (err) {
      return { status: 'retry', error: err.message };
    }
  },
};

export function getPushProvider() {
  return env.fcmProjectId && env.fcmServiceAccountFile ? fcmProvider : logProvider;
}
