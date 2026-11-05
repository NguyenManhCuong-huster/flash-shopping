import { query, withTx } from '../../db/pool.js';
import { AppError, result } from '../../common/errors.js';
import { cleanString, ensure, isPresent } from '../../common/validate.js';
import { requireLeader, requireMember } from '../../common/permissions.js';
import { audit } from '../../common/audit.js';
import { toMemberDto } from '../user/user.mapper.js';

async function groupDetail(groupId) {
  const g = await query('SELECT id, name, created_at FROM groups WHERE id = $1', [groupId]);
  const m = await query(
    `SELECT u.id, u.name, u.username, u.image_url, gm.role, gm.joined_at
       FROM group_members gm JOIN users u ON u.id = gm.user_id
      WHERE gm.group_id = $1
      ORDER BY (gm.role = 'admin') DESC, gm.joined_at`,
    [groupId],
  );
  const group = g.rows[0];
  return { id: group.id, name: group.name, createdAt: group.created_at, members: m.rows.map(toMemberDto) };
}

const findUserByUsername = async (db, username) =>
  (await db.query('SELECT id, username FROM users WHERE username = $1', [username])).rows[0];

/** POST user/group/ - Tạo nhóm, người tạo là trưởng nhóm. */
export async function createGroup(ctx, body = {}) {
  ensure(!ctx.groupId, '00093');
  let name = `Gia đình ${ctx.name}`.slice(0, 100);
  if (isPresent(body.name)) {
    name = cleanString(body.name, { min: 1, max: 100 });
    ensure(name, '00508');
  }
  let groupId;
  try {
    groupId = await withTx(async (db) => {
      const g = await db.query('INSERT INTO groups (name) VALUES ($1) RETURNING id', [name]);
      await db.query(`INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'admin')`, [
        g.rows[0].id,
        ctx.userId,
      ]);
      await audit(db, ctx, 'group.create', 'group', g.rows[0].id, { name });
      return g.rows[0].id;
    });
  } catch (err) {
    if (err.code === '23505') throw new AppError('00093'); // đã vào nhóm khác cùng lúc
    throw err;
  }
  return result('00095', { group: await groupDetail(groupId) });
}

/** GET user/group/ - Xem nhóm và danh sách thành viên. */
export async function getGroup(ctx) {
  const groupId = requireMember(ctx, '00096');
  return result('00098', { group: await groupDetail(groupId), myRole: ctx.groupRole });
}

/** PUT user/group/ - Đổi tên nhóm (trưởng nhóm). */
export async function renameGroup(ctx, body = {}) {
  const groupId = requireLeader(ctx, '00096', '00104');
  const name = cleanString(body.name, { min: 1, max: 100 });
  ensure(name, '00508');
  await query('UPDATE groups SET name = $2 WHERE id = $1', [groupId, name]);
  await audit(null, ctx, 'group.rename', 'group', groupId, { name });
  return result('00098', { group: await groupDetail(groupId) });
}

/** POST user/group/add/ - Trưởng nhóm thêm thành viên qua username. */
export async function addMember(ctx, body = {}) {
  ensure(isPresent(body.username), '00100');
  const groupId = requireLeader(ctx, '00096', '00506');
  const username = String(body.username).trim();
  try {
    await withTx(async (db) => {
      const target = await findUserByUsername(db, username);
      ensure(target, '00099x');
      const exists = await db.query('SELECT 1 FROM group_members WHERE user_id = $1', [target.id]);
      ensure(!exists.rowCount, '00099');
      await db.query(`INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, 'member')`, [
        groupId,
        target.id,
      ]);
      await audit(db, ctx, 'group.add_member', 'user', target.id, { groupId, username });
    });
  } catch (err) {
    if (err.code === '23505') throw new AppError('00099');
    throw err;
  }
  return result('00102', { group: await groupDetail(groupId) });
}

/** DELETE user/group/ - Trưởng nhóm xóa thành viên. */
export async function removeMember(ctx, body = {}) {
  ensure(isPresent(body.username), '00107');
  const groupId = requireLeader(ctx, '00096', '00104');
  const username = String(body.username).trim();
  await withTx(async (db) => {
    const target = await findUserByUsername(db, username);
    ensure(target, '00099x');
    ensure(target.id !== ctx.userId, '00503');
    const del = await db.query('DELETE FROM group_members WHERE group_id = $1 AND user_id = $2', [groupId, target.id]);
    ensure(del.rowCount, '00103');
    await audit(db, ctx, 'group.remove_member', 'user', target.id, { groupId, username });
  });
  return result('00106', { group: await groupDetail(groupId) });
}

/** POST user/group/leave/ - Rời nhóm. Trưởng nhóm còn thành viên khác phải chuyển quyền trước. */
export async function leaveGroup(ctx) {
  const groupId = requireMember(ctx, '00096');
  await withTx(async (db) => {
    if (ctx.groupRole === 'admin') {
      const others = await db.query('SELECT count(*)::int AS n FROM group_members WHERE group_id = $1 AND user_id <> $2', [
        groupId,
        ctx.userId,
      ]);
      ensure(others.rows[0].n === 0, '00501');
      // Thành viên cuối cùng rời => giải tán nhóm và dữ liệu của nhóm
      await db.query('DELETE FROM groups WHERE id = $1', [groupId]);
      await audit(db, ctx, 'group.dissolve', 'group', groupId);
    } else {
      await db.query('DELETE FROM group_members WHERE group_id = $1 AND user_id = $2', [groupId, ctx.userId]);
      await audit(db, ctx, 'group.leave', 'group', groupId);
    }
  });
  return result('00500');
}

/** PUT user/group/leader/ - Chuyển quyền trưởng nhóm. */
export async function transferLeader(ctx, body = {}) {
  ensure(isPresent(body.username), '00100');
  const groupId = requireLeader(ctx, '00096', '00104');
  await withTx(async (db) => {
    const target = await findUserByUsername(db, String(body.username).trim());
    ensure(target, '00099x');
    ensure(target.id !== ctx.userId, '00563');
    const m = await db.query('SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2', [groupId, target.id]);
    ensure(m.rowCount, '00103');
    // Hạ quyền trước rồi mới nâng quyền để không vi phạm "một trưởng nhóm"
    await db.query(`UPDATE group_members SET role = 'member' WHERE user_id = $1`, [ctx.userId]);
    await db.query(`UPDATE group_members SET role = 'admin' WHERE user_id = $1`, [target.id]);
    await audit(db, ctx, 'group.transfer_leader', 'user', target.id, { groupId });
  });
  return result('00502', { group: await groupDetail(groupId) });
}
