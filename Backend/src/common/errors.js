import { messageOf, statusOf } from './codes.js';

/** Lỗi nghiệp vụ mang mã phản hồi của hệ thống. Service ném, controller/AI Guard bắt. */
export class AppError extends Error {
  constructor(code, data = undefined) {
    super(messageOf(code));
    this.code = code;
    this.status = statusOf(code);
    this.data = data;
  }
}

/** Kết quả thành công của Service: mã phản hồi + dữ liệu. */
export const result = (code, data = null) => ({ code, data });

export function send(res, { code, data }) {
  return res.status(statusOf(code)).json({ code, message: messageOf(code), data: data ?? null });
}

/** Bọc service thành handler Express: service trả {code, data}. */
export const handle = (fn) => async (req, res) => send(res, await fn(req, res));
