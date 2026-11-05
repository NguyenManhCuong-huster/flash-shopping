import pg from 'pg';
import { env } from '../config/env.js';

// BIGINT -> number (id không vượt 2^53), NUMERIC -> number, DATE -> chuỗi 'YYYY-MM-DD'
pg.types.setTypeParser(20, (v) => Number.parseInt(v, 10));
pg.types.setTypeParser(1700, (v) => Number.parseFloat(v));
pg.types.setTypeParser(1082, (v) => v);

export const pool = new pg.Pool({ connectionString: env.databaseUrl, max: 20 });

pool.on('error', (err) => {
  console.error('[db] idle client error', err);
});

export const query = (text, params) => pool.query(text, params);

/**
 * Chạy hàm trong một giao dịch CSDL. Lỗi bất kỳ => ROLLBACK toàn bộ (NFR09).
 */
export async function withTx(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}
