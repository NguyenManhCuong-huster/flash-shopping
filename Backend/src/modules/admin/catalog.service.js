import { query } from '../../db/pool.js';
import { AppError, result } from '../../common/errors.js';
import { cleanString, ensure, isPresent } from '../../common/validate.js';
import { audit } from '../../common/audit.js';

/**
 * Danh mục thực phẩm (categories) và đơn vị đo (units) có cấu trúc giống nhau,
 * nên dùng chung một bộ thao tác, khác nhau ở tên bảng và mã phản hồi.
 */
function makeCatalog(table, codes) {
  const findByName = async (name) =>
    (await query(`SELECT id, name FROM ${table} WHERE lower(btrim(name)) = lower($1)`, [name])).rows[0];

  return {
    async list() {
      const { rows } = await query(`SELECT id, name FROM ${table} ORDER BY name`);
      return result(codes.listOk, { [table]: rows });
    },

    async create(ctx, rawName) {
      ensure(isPresent(rawName), codes.createMissing);
      const name = cleanString(rawName, { min: 1, max: 100 });
      ensure(name, codes.createMissing);
      try {
        const { rows } = await query(`INSERT INTO ${table} (name) VALUES ($1) RETURNING id, name`, [name]);
        await audit(null, ctx, `${table}.create`, table, rows[0].id, { name });
        return result(codes.createOk, rows[0]);
      } catch (err) {
        if (err.code === '23505') throw new AppError(codes.createExists);
        throw err;
      }
    },

    async rename(ctx, rawOld, rawNew) {
      ensure(isPresent(rawOld) && isPresent(rawNew), codes.editMissing);
      const oldName = cleanString(rawOld, { min: 1, max: 100 });
      const newName = cleanString(rawNew, { min: 1, max: 100 });
      ensure(oldName && newName, codes.editMissing);
      ensure(oldName !== newName, codes.editSame);
      const row = await findByName(oldName);
      ensure(row, codes.editNotFound);
      try {
        const { rows } = await query(`UPDATE ${table} SET name = $2 WHERE id = $1 RETURNING id, name`, [row.id, newName]);
        await audit(null, ctx, `${table}.rename`, table, row.id, { oldName: row.name, newName });
        return result(codes.editOk, rows[0]);
      } catch (err) {
        if (err.code === '23505') throw new AppError(codes.editExists);
        throw err;
      }
    },

    async remove(ctx, rawName) {
      ensure(isPresent(rawName), codes.deleteMissing);
      const row = await findByName(String(rawName).trim());
      ensure(row, codes.deleteNotFound);
      try {
        await query(`DELETE FROM ${table} WHERE id = $1`, [row.id]);
      } catch (err) {
        if (err.code === '23503') throw new AppError('00564'); // đang được foods tham chiếu
        throw err;
      }
      await audit(null, ctx, `${table}.delete`, table, row.id, { name: row.name });
      return result(codes.deleteOk);
    },
  };
}

export const CategoryService = makeCatalog('categories', {
  listOk: '00129',
  createMissing: '00131', createExists: '00132', createOk: '00135',
  editMissing: '00136', editSame: '00137', editNotFound: '00138', editExists: '00138x', editOk: '00141',
  deleteMissing: '00142', deleteNotFound: '00143', deleteOk: '00146',
});

export const UnitService = makeCatalog('units', {
  listOk: '00110',
  createMissing: '00112', createExists: '00113', createOk: '00116',
  editMissing: '00117', editSame: '00118', editNotFound: '00119', editExists: '00113', editOk: '00122',
  deleteMissing: '00123', deleteNotFound: '00125', deleteOk: '00128',
});
