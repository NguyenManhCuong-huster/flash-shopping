/**
 * Tạo dữ liệu mẫu cho demo: 2 người dùng cùng một gia đình, thực phẩm, tủ lạnh, danh sách đi chợ,
 * công thức, kế hoạch bữa ăn và lịch sử mua/dùng (cho thống kê). Đi qua API thật nên dữ liệu
 * đúng nghiệp vụ. Chạy lại an toàn: bỏ qua nếu tài khoản demo đã tồn tại.
 *
 *   node scripts/seed-demo.mjs
 */
import pg from 'pg';

const API = process.env.API_URL || 'http://localhost:3001';
const DB = process.env.DATABASE_URL || 'postgres://dicho:dicho@localhost:5433/dicho';
const PASSWORD = 'Demo@123';
const USERS = [
  { email: 'demo@dicho.local', name: 'Nguyễn Văn Minh', username: 'minh' },
  { email: 'lan@dicho.local', name: 'Trần Thị Lan', username: 'lan_tran' },
];

async function call(method, path, body, token, headers = {}) {
  const res = await fetch(API + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const j = await res.json().catch(() => ({}));
  if (!res.ok && res.status !== 409) throw new Error(`${method} ${path} -> ${j.code} ${j.message}`);
  return j.data;
}

const day = (n) => {
  const d = new Date(Date.now() + n * 86400_000);
  return d.toISOString().slice(0, 10);
};

const db = new pg.Client({ connectionString: DB });
await db.connect();

const exists = await db.query('SELECT 1 FROM users WHERE lower(email) = $1', [USERS[0].email]);
if (exists.rowCount) {
  console.log('Dữ liệu demo đã có sẵn.');
  await db.end();
  process.exit(0);
}

// ---------- Tài khoản ----------
const tokens = [];
for (const u of USERS) {
  await call('POST', '/user', { email: u.email, password: PASSWORD, name: u.name, language: 'vi', timezone: 'Asia/Ho_Chi_Minh' });
  await db.query('UPDATE users SET email_verified_at = now() WHERE lower(email) = $1', [u.email]);
  const login = await call('POST', '/user/login', { email: u.email, password: PASSWORD });
  await call('PUT', '/user', { username: u.username }, login.accessToken);
  tokens.push(login.accessToken);
}
const [minh, lan] = tokens;

// ---------- Nhóm ----------
await call('POST', '/user/group', { name: 'Gia đình nhà Minh' }, minh);
await call('POST', '/user/group/add', { username: 'lan_tran' }, minh);

// ---------- Thực phẩm ----------
const foods = [
  ['Thịt bò', 'Thịt', 'kg'], ['Thịt lợn', 'Thịt', 'kg'], ['Ức gà', 'Thịt', 'kg'], ['Cá hồi', 'Cá & hải sản', 'kg'], ['Tôm', 'Cá & hải sản', 'kg'],
  ['Trứng gà', 'Trứng & sữa', 'quả'], ['Sữa tươi', 'Trứng & sữa', 'lít'], ['Cà chua', 'Rau củ', 'kg'], ['Cà rốt', 'Rau củ', 'củ'],
  ['Hành lá', 'Rau củ', 'bó'], ['Rau muống', 'Rau củ', 'bó'], ['Khoai tây', 'Rau củ', 'kg'], ['Hành tây', 'Rau củ', 'củ'],
  ['Táo', 'Trái cây', 'kg'], ['Chuối', 'Trái cây', 'quả'], ['Nước mắm', 'Gia vị', 'chai'], ['Gạo', 'Đồ khô', 'kg'], ['Đậu phụ', 'Khác', 'cái'],
];
for (const [name, cat, unit] of foods) await call('POST', '/food', { name, foodCategoryName: cat, unitName: unit }, minh);

// ---------- Tủ lạnh (vài món sắp hết hạn / đã hết hạn để có thông báo) ----------
const fridge = [
  ['Thịt bò', 0.8, '2', 'freezer'], ['Ức gà', 0.5, '1', 'cool'], ['Cá hồi', 0.4, '4', 'freezer'], ['Trứng gà', 10, '12', 'cool'],
  ['Sữa tươi', 1, '3', 'cool'], ['Cà rốt', 4, '7', 'cool'], ['Khoai tây', 1.5, '14', 'other'], ['Hành tây', 3, '20', 'other'],
  ['Táo', 1, '6', 'cool'], ['Nước mắm', 1, '180', 'other'], ['Gạo', 5, '120', 'other'], ['Đậu phụ', 2, '1', 'cool'],
];
for (const [foodName, quantity, useWithin, location] of fridge) {
  await call('POST', '/fridge', { foodName, quantity, useWithin, location }, lan);
}
await call('POST', '/fridge', { foodName: 'Chuối', quantity: 4, useWithin: '1' }, lan);
await db.query(`UPDATE fridge_items fi SET use_within = now() - interval '1 day'
                  FROM foods f WHERE f.id = fi.food_id AND f.name = 'Chuối'`);

// ---------- Công thức ----------
const recipes = [
  { foodName: 'Thịt bò', name: 'Bò hầm cà rốt', description: 'Món hầm mềm, đậm vị cho bữa tối cả nhà',
    steps: ['Thịt bò cắt miếng vuông, ướp nước mắm, hành tây 20 phút', 'Phi thơm hành, xào săn thịt bò', 'Thêm cà chua, nước, hầm lửa nhỏ 60 phút', 'Cho cà rốt, khoai tây vào hầm thêm 20 phút', 'Rắc hành lá, nêm vừa ăn'],
    ingredients: [['Cà rốt', 2], ['Khoai tây', 0.5], ['Cà chua', 0.3], ['Hành lá', 1]] },
  { foodName: 'Trứng gà', name: 'Trứng chiên cà chua', description: 'Món nhanh 10 phút',
    steps: ['Đánh tan 3 quả trứng với chút nước mắm', 'Xào cà chua cho mềm', 'Đổ trứng vào, đảo nhẹ đến khi chín'],
    ingredients: [['Trứng gà', 3], ['Cà chua', 0.2], ['Hành lá', 1]] },
  { foodName: 'Cá hồi', name: 'Cá hồi áp chảo', description: 'Giàu omega-3, ăn kèm khoai tây',
    steps: ['Ướp cá với muối tiêu 10 phút', 'Áp chảo mặt da 4 phút, lật mặt 2 phút', 'Khoai tây luộc, dằm cùng bơ'],
    ingredients: [['Khoai tây', 0.3]] },
  { foodName: 'Rau muống', name: 'Rau muống xào tỏi', description: 'Món rau quen thuộc',
    steps: ['Nhặt rau, rửa sạch, để ráo', 'Phi tỏi thơm, xào rau lửa lớn', 'Nêm nước mắm vừa ăn'],
    ingredients: [['Nước mắm', null]] },
  { foodName: 'Đậu phụ', name: 'Đậu phụ sốt cà chua', description: 'Món chay đơn giản',
    steps: ['Cắt đậu miếng vừa, rán vàng', 'Xào cà chua thành sốt, nêm nước mắm', 'Cho đậu vào rim 5 phút, rắc hành lá'],
    ingredients: [['Cà chua', 0.3], ['Hành lá', 1]] },
];
const recipeIds = {};
for (const r of recipes) {
  const d = await call('POST', '/recipe', {
    foodName: r.foodName, name: r.name, description: r.description,
    htmlContent: r.steps.map((s) => `<p>${s}</p>`).join(''),
    ingredients: r.ingredients.map(([foodName, quantity]) => ({ foodName, quantity })),
  }, r.foodName === 'Trứng gà' ? lan : minh);
  recipeIds[r.name] = d.recipe.id;
}

// ---------- Kế hoạch bữa ăn tuần này ----------
const plans = [
  [0, 'tối', { recipeId: recipeIds['Bò hầm cà rốt'] }], [0, 'sáng', { recipeId: recipeIds['Trứng chiên cà chua'] }],
  [1, 'trưa', { recipeId: recipeIds['Đậu phụ sốt cà chua'] }], [1, 'tối', { recipeId: recipeIds['Cá hồi áp chảo'] }],
  [2, 'tối', { recipeId: recipeIds['Rau muống xào tỏi'] }], [3, 'trưa', { foodName: 'Ức gà' }], [-2, 'tối', { foodName: 'Thịt lợn' }],
  [-5, 'tối', { foodName: 'Thịt lợn' }],
];
for (const [offset, name, ref] of plans) await call('POST', '/meal', { ...ref, timestamp: day(offset), name }, minh);

// ---------- Danh sách đi chợ ----------
// 1) Đã đi chợ xong (Lan xác nhận mua -> vào tủ lạnh, có lịch sử mua)
const done = await call('POST', '/shopping', { name: 'Đi chợ cuối tuần', date: day(-3), assignToUsername: 'lan_tran', note: 'Chợ Hôm' }, minh);
const doneTasks = await call('POST', '/shopping/task', {
  sessionId: done.sessionId,
  tasks: [{ foodName: 'Thịt lợn', quantity: 1 }, { foodName: 'Tôm', quantity: 0.5 }, { foodName: 'Rau muống', quantity: 2 }, { foodName: 'Chuối', quantity: 6 }],
}, minh);
await call('POST', '/shopping/purchase', {
  sessionId: done.sessionId,
  items: doneTasks.created.map((t) => ({ taskId: t.taskId, useWithin: t.foodName === 'Rau muống' ? '2' : '5', location: t.foodName === 'Tôm' ? 'freezer' : 'cool' })),
}, lan, { 'Idempotency-Key': `seed-${Date.now()}` });

// 2) Đang mở, giao cho Lan, đã mua một phần
const open = await call('POST', '/shopping', { name: 'Đi chợ hôm nay', date: day(0), assignToUsername: 'lan_tran', note: 'Mua thêm nguyên liệu bò hầm' }, minh);
const openTasks = await call('POST', '/shopping/task', {
  sessionId: open.sessionId,
  tasks: [{ foodName: 'Cà chua', quantity: 0.5 }, { foodName: 'Hành lá', quantity: 2 }, { foodName: 'Sữa tươi', quantity: 2 }, { foodName: 'Táo', quantity: 1 }],
}, minh);
await call('POST', '/shopping/purchase', {
  sessionId: open.sessionId,
  items: [{ taskId: openTasks.created.find((t) => t.foodName === 'Táo').taskId, boughtQuantity: 1.2, useWithin: '7', location: 'cool' }],
}, lan, { 'Idempotency-Key': `seed-${Date.now()}-2` });

// 3) Ngày mai, chưa giao
const next = await call('POST', '/shopping', { name: 'Siêu thị ngày mai', date: day(1) }, minh);
await call('POST', '/shopping/task', { sessionId: next.sessionId, tasks: [{ foodName: 'Gạo', quantity: 5 }, { foodName: 'Nước mắm', quantity: 1 }] }, minh);

// ---------- Tiêu thụ / bỏ đi (cho thống kê) ----------
const items = (await call('GET', '/fridge?limit=50', undefined, lan)).items;
const byName = Object.fromEntries(items.map((i) => [i.food.name, i]));
const consume = async (name, quantity, type = 'consume') => {
  const it = byName[name];
  if (it) await call('POST', '/fridge/consume', { itemId: it.id, quantity, type }, lan);
};
await consume('Thịt lợn', 0.6);
await consume('Rau muống', 1);
await consume('Trứng gà', 4);
await consume('Gạo', 1);
await consume('Tôm', 0.1, 'discard');

// Lùi thời gian một phần lịch sử để biểu đồ thống kê có nhiều ngày
await db.query(`UPDATE stock_events SET occurred_at = occurred_at - (random() * interval '10 days')
                 WHERE group_id = (SELECT group_id FROM group_members gm JOIN users u ON u.id = gm.user_id WHERE u.email = $1)`, [USERS[0].email]);

// Gợi ý chủ động cho trưởng nhóm
await call('POST', '/ai/suggestion/refresh', undefined, minh);

await db.end();
console.log('Đã tạo dữ liệu demo.');
for (const u of USERS) console.log(`  ${u.email} / ${PASSWORD}  (@${u.username})`);
