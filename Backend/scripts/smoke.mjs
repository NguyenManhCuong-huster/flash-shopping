/**
 * Kiểm thử end-to-end các nghiệp vụ chính + phân quyền + cách ly dữ liệu nhóm.
 * Chạy khi stack đang chạy:  node scripts/smoke.mjs
 *   API_URL (mặc định http://localhost:3001), MAILPIT_URL (mặc định http://localhost:8025)
 */
const BASE = process.env.API_URL || 'http://localhost:3001';
const MAIL = process.env.MAILPIT_URL || 'http://localhost:8025';
const ADMIN = { email: process.env.ADMIN_EMAIL || 'admin@dicho.local', password: process.env.ADMIN_PASSWORD || 'Admin@123' };

let passed = 0;
let failed = 0;
const sfx = Date.now().toString(36).slice(-5);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function call(method, path, { token, body, headers = {} } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const j = await res.json().catch(() => null);
  return { status: res.status, code: j?.code, data: j?.data, message: j?.message };
}

function expect(name, r, code, check) {
  const ok = r.code === code && (!check || check(r.data));
  if (ok) {
    passed += 1;
    console.log(`  ✓ ${name} [${code}]`);
  } else {
    failed += 1;
    console.log(`  ✗ ${name}: cần ${code}, nhận ${r.code} (${r.status}) ${r.message ?? ''} ${JSON.stringify(r.data)?.slice(0, 400) ?? ''}`);
  }
  return r;
}
const section = (t) => console.log(`\n== ${t}`);

async function otpFor(email) {
  for (let i = 0; i < 20; i++) {
    const res = await fetch(`${MAIL}/api/v1/search?query=${encodeURIComponent(`to:"${email}"`)}`);
    const j = await res.json();
    const m = j.messages?.[0];
    const code = m?.Subject?.match(/(\d{6})/)?.[1];
    if (code) return code;
    await sleep(300);
  }
  throw new Error(`Không thấy email OTP cho ${email}`);
}

async function newUser(label) {
  const email = `${label}.${sfx}@test.local`;
  const reg = await call('POST', '/user', { body: { email, password: 'secret123', name: `Người ${label}`, language: 'vi', timezone: 'Asia/Ho_Chi_Minh' } });
  const code = await otpFor(email);
  await call('POST', '/user/verify-email', { body: { code, token: reg.data.confirmToken } });
  const login = await call('POST', '/user/login', { body: { email, password: 'secret123' } });
  const username = `${label}${sfx}`.slice(0, 14);
  await call('PUT', '/user', { token: login.data.accessToken, body: { username } });
  return { email, username, token: login.data.accessToken, refresh: login.data.refreshToken };
}

async function main() {
  console.log(`API ${BASE} | hậu tố ${sfx}`);

  section('UC01 Xác thực');
  const emailA = `lead.${sfx}@test.local`;
  expect('Đăng ký email sai', await call('POST', '/user', { body: { email: 'abc', password: 'secret123', name: 'Abcd' } }), '00026');
  expect('Đăng ký mật khẩu ngắn', await call('POST', '/user', { body: { email: emailA, password: '123', name: 'Abcd' } }), '00027');
  const regA = expect('Đăng ký', await call('POST', '/user', { body: { email: emailA, password: 'secret123', name: 'Trưởng nhóm A' } }), '00035');
  expect('Đăng ký trùng email', await call('POST', '/user', { body: { email: emailA.toUpperCase(), password: 'secret123', name: 'Abcd' } }), '00032');
  expect('Đăng nhập khi chưa xác minh', await call('POST', '/user/login', { body: { email: emailA, password: 'secret123' } }), '00044');
  expect('Xác minh sai mã', await call('POST', '/user/verify-email', { body: { code: '000000', token: regA.data.confirmToken } }), '00054');
  const otp = await otpFor(emailA);
  expect('Xác minh đúng mã (OTP lấy từ Mailpit)', await call('POST', '/user/verify-email', { body: { code: otp, token: regA.data.confirmToken } }), '00058');
  expect('Đăng nhập sai mật khẩu', await call('POST', '/user/login', { body: { email: emailA, password: 'wrongpass' } }), '00045');
  const loginA = expect('Đăng nhập', await call('POST', '/user/login', { body: { email: emailA, password: 'secret123' } }), '00047');
  const A = { token: loginA.data.accessToken, refresh: loginA.data.refreshToken, username: `lead${sfx}` };
  expect('Đặt username', await call('PUT', '/user', { token: A.token, body: { username: A.username } }), '00086');
  expect('Không có token', await call('GET', '/user'), '00006');
  expect('Token giả', await call('GET', '/user', { token: 'abc.def.ghi' }), '00012');
  const ref = expect('Làm mới token', await call('POST', '/user/refresh-token', { body: { refreshToken: A.refresh } }), '00065');
  expect('Dùng lại refresh token cũ (phát hiện tái sử dụng)', await call('POST', '/user/refresh-token', { body: { refreshToken: A.refresh } }), '00061');
  expect('Access token cũ bị thu hồi theo phiên', await call('GET', '/user', { token: A.token }), '00012');
  const relogin = await call('POST', '/user/login', { body: { email: emailA, password: 'secret123' } });
  A.token = relogin.data.accessToken;
  expect('Đổi mật khẩu sai mật khẩu cũ', await call('POST', '/user/change-password', { token: A.token, body: { oldPassword: 'nopenope', newPassword: 'secret456' } }), '00072');
  void ref;

  const B = await newUser('mem');
  const C = await newUser('out');

  section('UC02 Nhóm gia đình');
  expect('B xem nhóm khi chưa có nhóm', await call('GET', '/user/group', { token: B.token }), '00096');
  expect('A tạo nhóm', await call('POST', '/user/group', { token: A.token, body: { name: 'Nhà A' } }), '00095');
  expect('A tạo nhóm lần 2', await call('POST', '/user/group', { token: A.token }), '00093');
  expect('A thêm B', await call('POST', '/user/group/add', { token: A.token, body: { username: B.username } }), '00102');
  expect('A thêm lại B', await call('POST', '/user/group/add', { token: A.token, body: { username: B.username } }), '00099');
  expect('A thêm user không tồn tại', await call('POST', '/user/group/add', { token: A.token, body: { username: 'khongtontai' } }), '00099x');
  expect('B (thành viên) thêm C', await call('POST', '/user/group/add', { token: B.token, body: { username: C.username } }), '00506');
  expect('B xóa thành viên', await call('DELETE', '/user/group', { token: B.token, body: { username: A.username } }), '00104');
  expect('B xem nhóm', await call('GET', '/user/group', { token: B.token }), '00098', (d) => d.group.members.length === 2 && d.myRole === 'member');
  expect('C tạo nhóm riêng', await call('POST', '/user/group', { token: C.token }), '00095');
  expect('A rời nhóm khi còn thành viên', await call('POST', '/user/group/leave', { token: A.token }), '00501');

  section('UC11 Quản trị');
  const adm = await call('POST', '/user/login', { body: ADMIN });
  const AD = adm.data.accessToken;
  expect('Thành viên gọi API admin', await call('GET', '/admin/category', { token: A.token }), '00017');
  expect('Admin tạo category', await call('POST', '/admin/category', { token: AD, body: { name: `Test ${sfx}` } }), '00135');
  expect('Admin tạo category trùng', await call('POST', '/admin/category', { token: AD, body: { name: `test ${sfx}` } }), '00132');
  expect('Admin đổi tên category', await call('PUT', '/admin/category', { token: AD, body: { oldName: `Test ${sfx}`, newName: `Test2 ${sfx}` } }), '00141');
  expect('Admin xóa category', await call('DELETE', '/admin/category', { token: AD, body: { name: `Test2 ${sfx}` } }), '00146');
  expect('Admin xem log', await call('GET', '/admin/logs?limit=5', { token: AD }), '00109', (d) => d.logs.length > 0);

  section('Thực phẩm');
  const foods = [['Thịt bò', 'Thịt', 'kg'], ['Cà rốt', 'Rau củ', 'củ'], ['Cà chua', 'Rau củ', 'kg'], ['Hành lá', 'Rau củ', 'bó']];
  for (const [name, cat, unit] of foods) {
    expect(`A tạo ${name}`, await call('POST', '/food', { token: A.token, body: { name, foodCategoryName: cat, unitName: unit } }), '00160');
  }
  expect('Tạo trùng tên (không phân biệt hoa thường)', await call('POST', '/food', { token: A.token, body: { name: 'thịt bò', foodCategoryName: 'Thịt', unitName: 'kg' } }), '00151');
  expect('Danh mục không tồn tại', await call('POST', '/food', { token: A.token, body: { name: 'X', foodCategoryName: 'Không có', unitName: 'kg' } }), '00155');
  expect('B (thành viên) tạo thực phẩm', await call('POST', '/food', { token: B.token, body: { name: 'Trứng gà', foodCategoryName: 'Trứng & sữa', unitName: 'quả' } }), '00160');
  expect('B sửa thực phẩm (chỉ trưởng nhóm)', await call('PUT', '/food', { token: B.token, body: { name: 'Trứng gà', newName: 'Trứng' } }), '00167x');
  expect('Danh sách thực phẩm nhóm A', await call('GET', '/food', { token: B.token }), '00188', (d) => d.total === 5);
  expect('C không thấy thực phẩm nhóm A', await call('GET', '/food', { token: C.token }), '00188', (d) => d.total === 0);
  expect('Admin xóa đơn vị đang được dùng', await call('DELETE', '/admin/unit', { token: AD, body: { unitName: 'kg' } }), '00564');
  expect('C tạo "Thịt bò" trong nhóm riêng', await call('POST', '/food', { token: C.token, body: { name: 'Thịt bò', foodCategoryName: 'Thịt', unitName: 'kg' } }), '00160');

  section('UC05 Tủ lạnh & tiêu thụ');
  const fi = expect('B thêm thịt bò', await call('POST', '/fridge', { token: B.token, body: { foodName: 'Thịt bò', quantity: 1, useWithin: '5', location: 'freezer' } }), '00202');
  const itemId = fi.data.item.id;
  expect('Thêm trùng thực phẩm', await call('POST', '/fridge', { token: B.token, body: { foodName: 'Thịt bò', quantity: 1, useWithin: '5' } }), '00199');
  expect('Hạn dùng sai định dạng', await call('POST', '/fridge', { token: B.token, body: { foodName: 'Cà rốt', quantity: 1, useWithin: '2026-13-45' } }), '00191');
  expect('C xem thịt bò (nhóm C chưa có mục)', await call('GET', `/fridge/${encodeURIComponent('Thịt bò')}`, { token: C.token }), '00234');
  expect('C tiêu thụ mục của nhóm A (cách ly)', await call('POST', '/fridge/consume', { token: C.token, body: { itemId, quantity: 0.1 } }), '00213');
  expect('C xem mục theo id của nhóm A', await call('GET', `/fridge/item/${itemId}`, { token: C.token }), '00234');
  expect('Tiêu thụ 0.3', await call('POST', '/fridge/consume', { token: B.token, body: { itemId, quantity: 0.3, version: 1 } }), '00520', (d) => d.remaining === 0.7);
  expect('Version cũ => yêu cầu tải lại', await call('POST', '/fridge/consume', { token: A.token, body: { itemId, quantity: 0.1, version: 1 } }), '00523');
  expect('Tiêu thụ vượt tồn', await call('POST', '/fridge/consume', { token: A.token, body: { itemId, quantity: 5 } }), '00522');
  expect('Lượng âm', await call('POST', '/fridge/consume', { token: A.token, body: { itemId, quantity: -1 } }), '00521');
  expect('Hủy bỏ 0.2', await call('POST', '/fridge/consume', { token: A.token, body: { itemId, quantity: 0.2, type: 'discard' } }), '00520', (d) => d.remaining === 0.5);
  expect('Cập nhật số lượng', await call('PUT', '/fridge', { token: A.token, body: { itemId, newQuantity: 0.6, newNote: 'Hộp xanh' } }), '00216', (d) => d.item.quantity === 0.6);

  section('UC03 Danh sách mua sắm');
  const today = new Date().toISOString().slice(0, 10);
  expect('B tạo danh sách (không phải trưởng nhóm)', await call('POST', '/shopping', { token: B.token, body: { name: 'Đi chợ', date: today } }), '00243');
  expect('Giao cho người nhóm khác', await call('POST', '/shopping', { token: A.token, body: { name: 'Đi chợ', date: today, assignToUsername: C.username } }), '00246');
  expect('Ngày sai', await call('POST', '/shopping', { token: A.token, body: { name: 'Đi chợ', date: '2026-02-30' } }), '00242');
  const sl = expect('A tạo danh sách giao cho B', await call('POST', '/shopping', { token: A.token, body: { name: 'Đi chợ sáng', date: today, assignToUsername: B.username } }), '00249');
  const listId = sl.data.listId;
  const tk = expect(
    'Thêm mục: 1 hợp lệ, 1 không tồn tại, 1 trùng',
    await call('POST', '/shopping/task', {
      token: A.token,
      body: { listId, tasks: [{ foodName: 'Cà rốt', quantity: 3 }, { foodName: 'Không tồn tại', quantity: 1 }, { foodName: 'cà rốt', quantity: 1 }, { foodName: 'Cà chua', quantity: 0.5 }] },
    }),
    '00507',
    (d) => d.created.length === 2 && d.failed.length === 2 && d.failed.some((f) => f.code === '00285x'),
  );
  const carrotTask = tk.data.created.find((t) => t.foodName === 'Cà rốt').taskId;
  const tomatoTask = tk.data.created.find((t) => t.foodName === 'Cà chua').taskId;
  expect('B thêm mục (không phải trưởng nhóm)', await call('POST', '/shopping/task', { token: B.token, body: { listId, tasks: [{ foodName: 'Hành lá', quantity: 1 }] } }), '00281');
  expect('C xem danh sách nhóm A', await call('GET', `/shopping/${listId}`, { token: C.token }), '00260');
  expect('C không thấy list nhóm A', await call('GET', '/shopping/task', { token: C.token }), '00292', (d) => d.total === 0);
  expect('B xem danh sách được giao', await call('GET', '/shopping/task?assignedToMe=true', { token: B.token }), '00292', (d) => d.total === 1);

  section('UC04 Xác nhận mua (giao dịch + khóa chống lặp)');
  const key = `k-${sfx}-0001`;
  const purchaseBody = { listId, items: [{ taskId: carrotTask, boughtQuantity: 2.5, useWithin: '7', location: 'cool' }] };
  expect('Thiếu Idempotency-Key', await call('POST', '/shopping/purchase', { token: B.token, body: purchaseBody }), '00511');
  expect('C xác nhận list nhóm A', await call('POST', '/shopping/purchase', { token: C.token, body: purchaseBody, headers: { 'Idempotency-Key': `c-${key}` } }), '00283');
  expect('B xác nhận mua cà rốt', await call('POST', '/shopping/purchase', { token: B.token, body: purchaseBody, headers: { 'Idempotency-Key': key } }), '00510', (d) => d.replayed === false && d.results[0].fridge.quantity === 2.5);
  expect('Gửi lại cùng khóa => trả kết quả cũ', await call('POST', '/shopping/purchase', { token: B.token, body: purchaseBody, headers: { 'Idempotency-Key': key } }), '00510', (d) => d.replayed === true);
  expect('Cùng khóa, nội dung khác', await call('POST', '/shopping/purchase', { token: B.token, body: { ...purchaseBody, items: [{ ...purchaseBody.items[0], boughtQuantity: 9 }] }, headers: { 'Idempotency-Key': key } }), '00512');
  expect('Khóa mới, nhiệm vụ đã mua', await call('POST', '/shopping/purchase', { token: B.token, body: purchaseBody, headers: { 'Idempotency-Key': `${key}-x` } }), '00514');
  expect('Tồn cà rốt chỉ cộng 1 lần', await call('GET', `/fridge/${encodeURIComponent('Cà rốt')}`, { token: B.token }), '00237', (d) => d.item.quantity === 2.5);
  // Hai yêu cầu song song cùng khóa: chỉ một lần cộng tồn
  const key2 = `k-${sfx}-0002`;
  const body2 = { listId, items: [{ taskId: tomatoTask, useWithin: '2', location: 'cool' }] };
  const [p1, p2] = await Promise.all([
    call('POST', '/shopping/purchase', { token: A.token, body: body2, headers: { 'Idempotency-Key': key2 } }),
    call('POST', '/shopping/purchase', { token: A.token, body: body2, headers: { 'Idempotency-Key': key2 } }),
  ]);
  expect('Song song cùng khóa (yêu cầu 1)', p1, '00510');
  expect('Song song cùng khóa (yêu cầu 2)', p2, '00510', () => [p1, p2].filter((p) => p.data?.replayed).length === 1);
  expect('Tồn cà chua = 0.5 (không nhân đôi)', await call('GET', `/fridge/${encodeURIComponent('Cà chua')}`, { token: A.token }), '00237', (d) => d.item.quantity === 0.5);

  section('UC07/UC09 Công thức & gợi ý');
  const rc = expect(
    'B tạo công thức (HTML được làm sạch)',
    await call('POST', '/recipe', {
      token: B.token,
      body: {
        foodName: 'Thịt bò', name: 'Bò hầm cà rốt', description: 'Món hầm cho cả nhà',
        htmlContent: '<p>Hầm bò 2 giờ</p><script>alert(1)</script>',
        ingredients: [{ foodName: 'Cà rốt', quantity: 2 }, { foodName: 'Cà chua', quantity: 1 }, { foodName: 'Hành lá', quantity: 1 }],
      },
    }),
    '00357',
    (d) => !d.recipe.htmlContent.includes('script') && d.recipe.ingredients.length === 3,
  );
  const recipeId = rc.data.recipe.id;
  expect('C sửa công thức nhóm A', await call('PUT', '/recipe', { token: C.token, body: { recipeId, newName: 'Hack' } }), '00365');
  expect('A (trưởng nhóm) sửa công thức của B', await call('PUT', '/recipe', { token: A.token, body: { recipeId, newDescription: 'Món hầm mềm' } }), '00370');
  expect('Gợi ý món từ tủ lạnh', await call('GET', '/recipe/suggest', { token: B.token }), '00530', (d) => {
    const s = d.suggestions[0];
    return s && !s.canCook && s.missing.some((m) => m.food.name === 'Hành lá') && s.missing.some((m) => m.food.name === 'Cà chua' && m.missingQuantity === 0.5);
  });
  expect('Tìm công thức theo nguyên liệu', await call('GET', `/recipe?foodId=${fi.data.item.food.id}`, { token: B.token }), '00378', (d) => d.total === 1);

  section('UC08 Kế hoạch bữa ăn');
  const tomorrow = new Date(Date.now() + 86400_000).toISOString().slice(0, 10);
  expect('B lập kế hoạch (không phải trưởng nhóm)', await call('POST', '/meal', { token: B.token, body: { foodName: 'Thịt bò', timestamp: tomorrow, name: 'tối' } }), '00319');
  expect('Bữa không hợp lệ', await call('POST', '/meal', { token: A.token, body: { foodName: 'Thịt bò', timestamp: tomorrow, name: 'khuya' } }), '00316');
  const mp = expect('A lập bữa tối ngày mai theo công thức', await call('POST', '/meal', { token: A.token, body: { recipeId, timestamp: tomorrow, name: 'tối' } }), '00322', (d) => d.plan.date === tomorrow);
  expect('B xem lịch ngày mai', await call('GET', `/meal?date=${tomorrow}`, { token: B.token }), '00348', (d) => d.plans.length === 1);
  expect('Kiểm tra nguyên liệu', await call('GET', `/meal/ingredients?planId=${mp.data.plan.id}`, { token: B.token }), '00535', (d) => d.missing.length === 2);
  const tasksBefore = (await call('GET', `/shopping/${listId}`, { token: A.token })).data.list.tasks.length;
  expect('Thêm nguyên liệu thiếu vào danh sách', await call('POST', '/meal/missing-to-shopping', { token: A.token, body: { planId: mp.data.plan.id, listId } }), '00536', (d) => d.list.tasks.length === tasksBefore + 1);

  section('UC10 Thống kê');
  expect('Báo cáo', await call('GET', '/stats', { token: B.token }), '00540', (d) => d.totals.purchase === 2 && d.totals.consume === 1 && d.totals.discard === 1);
  expect('Lịch sử biến động', await call('GET', '/stats/events?type=purchase', { token: B.token }), '00525', (d) => d.total === 2);
  expect('Khoảng thời gian sai', await call('GET', '/stats?from=2026-05-01&to=2026-01-01', { token: B.token }), '00541');

  section('UC06 Nhắc hạn sử dụng');
  expect('Thêm trứng hết hạn sau 1 ngày', await call('POST', '/fridge', { token: B.token, body: { foodName: 'Trứng gà', quantity: 10, useWithin: '1' } }), '00202');
  await sleep(3500);
  const n1 = expect('B nhận thông báo sắp hết hạn', await call('GET', '/notification', { token: B.token }), '00550', (d) => d.notifications.some((x) => x.type === 'food_expiring' && x.data.foodName === 'Trứng gà'));
  expect('A cũng nhận (mọi thành viên)', await call('GET', '/notification', { token: A.token }), '00550', (d) => d.unreadCount >= 1);
  expect('C không nhận thông báo nhóm A', await call('GET', '/notification', { token: C.token }), '00550', (d) => d.total === 0);
  expect('Đánh dấu đã đọc', await call('PUT', '/notification/read', { token: B.token, body: { all: true } }), '00551');
  expect('Hết chưa đọc', await call('GET', '/notification', { token: B.token }), '00550', (d) => d.unreadCount === 0 && d.total === n1.data.total);

  section('AI Agent (không cần LLM: cài đặt, gợi ý chủ động, xác nhận hành động)');
  expect('Cài đặt AI', await call('GET', '/ai/settings', { token: A.token }), '00428');
  expect('autoExecuteLevel sai', await call('PUT', '/ai/settings', { token: A.token, body: { autoExecuteLevel: 'all' } }), '00429');
  const chat = await call('POST', '/ai/chat', { token: A.token, body: { message: 'Tủ lạnh còn gì?' } });
  if (chat.code === '00410') expect('Chat (đã cấu hình AI_API_KEY)', chat, '00410');
  else expect('Chat khi chưa cấu hình LLM', chat, '00413');
  expect('Danh sách công cụ AI', await call('GET', '/ai/tools', { token: B.token }), '00427', (d) => d.tools.length >= 30 && d.tools.find((t) => t.name === 'create_shopping_list').allowedForMe === false);
  const sg = expect('Chạy Suggestion Worker', await call('POST', '/ai/suggestion/refresh', { token: A.token }), '00431', (d) => d.suggestions.length >= 2);
  expect('B (thành viên) không thấy gợi ý cần quyền trưởng nhóm', await call('GET', '/ai/suggestion', { token: B.token }), '00431', (d) => d.suggestions.length === 0);
  const shopSug = sg.data.suggestions.find((s) => s.type === 'shopping_from_plan');
  const acc = expect('Chấp nhận gợi ý đi chợ', await call('POST', '/ai/suggestion/accept', { token: A.token, body: { suggestionId: shopSug.id } }), '00434', (d) => d.pendingActions.length === 2 && d.pendingActions[1].dependsOn === d.pendingActions[0].actionId);
  const [parent, child] = acc.data.pendingActions;
  expect('C xác nhận hành động của A', await call('POST', '/ai/action/confirm', { token: C.token, body: { actionIds: [parent.actionId] } }), '00419');
  expect('Sửa tham số sai schema', await call('POST', '/ai/action/confirm', { token: A.token, body: { actionIds: [parent.actionId], editedArguments: { [parent.actionId]: { hack: 1 } } } }), '00422');
  expect('Xác nhận cả hai (cha trước, con dùng $action ref)', await call('POST', '/ai/action/confirm', { token: A.token, body: { actionIds: [child.actionId, parent.actionId] } }), '00423', (d) => d.results.length === 2 && d.results.every((r) => r.status === 'executed'));
  expect('Xác nhận lại => không chạy lần 2', await call('POST', '/ai/action/confirm', { token: A.token, body: { actionIds: [parent.actionId] } }), '00424', (d) => d.results[0].resultCode === '00420');
  const expSug = sg.data.suggestions.find((s) => s.type === 'expiring_food');
  const acc2 = expect('Chấp nhận gợi ý đồ sắp hết hạn', await call('POST', '/ai/suggestion/accept', { token: A.token, body: { suggestionId: expSug.id } }), '00434');
  expect('Từ chối hành động', await call('POST', '/ai/action/reject', { token: A.token, body: { actionIds: [acc2.data.pendingActions[0].actionId], reason: 'Đã có món khác' } }), '00425');
  expect('Nhật ký AI (admin)', await call('GET', '/admin/ai/logs', { token: AD }), '00436', (d) => d.total >= 3);
  expect('Audit log ghi nguồn AI', await call('GET', '/admin/logs?source=ai', { token: AD }), '00109', (d) => d.logs.some((l) => l.aiActionId));

  section('Quản trị người dùng & khóa tài khoản');
  const users = await call('GET', `/admin/users?q=${encodeURIComponent(C.email)}`, { token: AD });
  const cId = users.data.users[0].id;
  expect('Admin khóa C', await call('PUT', '/admin/users', { token: AD, body: { userId: cId, isActive: false } }), '00561');
  expect('Token của C mất hiệu lực', await call('GET', '/user', { token: C.token }), '00012');
  expect('C đăng nhập khi bị khóa', await call('POST', '/user/login', { body: { email: C.email, password: 'secret123' } }), '00043');
  expect('Admin mở khóa C', await call('PUT', '/admin/users', { token: AD, body: { userId: cId, isActive: true } }), '00561');

  section('Rời nhóm / xóa tài khoản');
  expect('B rời nhóm (danh sách được giao tự bỏ giao)', await call('POST', '/user/group/leave', { token: B.token }), '00500');
  expect('Danh sách không còn người được giao', await call('GET', `/shopping/${listId}`, { token: A.token }), '00570', (d) => d.list.assignedTo === null);
  expect('B không còn thấy dữ liệu nhóm', await call('GET', '/fridge', { token: B.token }), '00225');
  const C2 = await call('POST', '/user/login', { body: { email: C.email, password: 'secret123' } });
  expect('C xóa tài khoản (nhóm của C bị giải tán)', await call('DELETE', '/user', { token: C2.data.accessToken }), '00092');
  expect('A (một mình) rời nhóm => giải tán nhóm', await call('POST', '/user/group/leave', { token: A.token }), '00500');
  expect('A không còn nhóm', await call('GET', '/user/group', { token: A.token }), '00096');

  console.log(`\nKết quả: ${passed} đạt, ${failed} lỗi`);
  process.exit(failed ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
