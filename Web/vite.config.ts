import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Dev: /api/* -> backend (Docker) ở cổng 3001, bỏ tiền tố /api giống cấu hình Nginx khi chạy thật.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': { target: process.env.API_TARGET ?? 'http://localhost:3001', changeOrigin: true, rewrite: (p) => p.replace(/^\/api/, '') },
    },
  },
});
