import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import multer from 'multer';
import { env } from '../config/env.js';
import { AppError } from '../common/errors.js';

const EXT = { 'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp' };

/**
 * Nhận một file ảnh ở trường `image` (multipart/form-data), lưu vào UPLOAD_DIR/<folder>.
 * Ảnh là tùy chọn; request không phải multipart vẫn đi tiếp bình thường.
 */
export function imageUpload(folder, errorCode = '00158') {
  const dir = path.join(env.uploadDir, folder);
  fs.mkdirSync(dir, { recursive: true });
  const uploader = multer({
    storage: multer.diskStorage({
      destination: dir,
      filename: (_req, file, cb) => cb(null, `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${EXT[file.mimetype]}`),
    }),
    limits: { fileSize: env.maxUploadBytes, files: 1 },
    fileFilter: (_req, file, cb) => {
      if (EXT[file.mimetype]) cb(null, true);
      else cb(new AppError(errorCode));
    },
  }).single('image');

  return (req, res, next) =>
    uploader(req, res, (err) => {
      if (!err) return next();
      next(err instanceof AppError ? err : new AppError(errorCode));
    });
}

/** Đường dẫn public của file đã upload (ứng dụng ghép với BASE_URL). */
export const publicUrl = (folder, file) => (file ? `/uploads/${folder}/${file.filename}` : null);

export function removeUploaded(file) {
  if (file?.path) fs.promises.unlink(file.path).catch(() => {});
}

/** Xóa file cũ khi thay ảnh (chỉ trong thư mục uploads). */
export function removeByUrl(url) {
  if (typeof url !== 'string' || !url.startsWith('/uploads/')) return;
  const p = path.join(env.uploadDir, url.slice('/uploads/'.length));
  if (!p.startsWith(env.uploadDir)) return;
  fs.promises.unlink(p).catch(() => {});
}
