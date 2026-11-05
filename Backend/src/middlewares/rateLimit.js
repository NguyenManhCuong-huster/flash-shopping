import rateLimit from 'express-rate-limit';
import { send } from '../common/errors.js';

const handler = (_req, res) => send(res, { code: '00024' });

const base = { standardHeaders: 'draft-7', legacyHeaders: false, handler };

/** Giới hạn chung theo IP. */
export const globalLimiter = rateLimit({ ...base, windowMs: 60_000, limit: 600 });

/** Chống dò mật khẩu / spam OTP cho các API không cần đăng nhập. */
export const authLimiter = rateLimit({ ...base, windowMs: 60_000, limit: 60 });

/** 20 tin nhắn AI mỗi phút mỗi người (Bảng 36). */
export const aiChatLimiter = rateLimit({
  ...base,
  windowMs: 60_000,
  limit: 20,
  keyGenerator: (req) => `u:${req.ctx?.userId ?? req.ip}`,
});
