# Báo cáo: Authentication và Authorization trong `learn-rails-api`

Tài liệu này mô tả hiện trạng 3 module (System, Website, Report), phần phân quyền (authorization) vừa được thêm, và luồng xử lý của một request từ lúc đăng nhập đến lúc được hoặc bị từ chối.

## 1. Kết luận ngắn

- **Authentication** (bạn là ai) đã có từ trước: đăng ký, đăng nhập bằng email + mật khẩu (bcrypt), nhận **JWT** có hạn 24 giờ. Mọi endpoint mặc định đều yêu cầu token.
- **Authorization** (bạn được làm gì) trước đây gần như chưa có. Ai đăng nhập cũng xem được mọi website, và tạo được số liệu Report cho website của người khác.
- Phần mới thêm gồm **2 lớp phân quyền**:
  1. **Role toàn hệ thống** (`member` hoặc `admin`), lưu ở module System.
  2. **Role trên từng website** (`viewer`, `editor`, `owner`), lưu ở module Website.
- Quy tắc phân quyền được viết trong các **policy object**. Controller gọi `authorize!`, policy trả về `false` thì API trả `403`.
- Module Report không tự quản lý quyền trên website. Nó hỏi Website qua một "cửa" (`Website::SiteService`), nên ranh giới giữa các module vẫn được giữ.
- Có 21 test integration (11 test cũ và 10 test mới cho phân quyền). Tất cả đều pass.

## 2. Bối cảnh kiến trúc

App là một process Rails 8.1 API-only, chia thành 3 Rails Engine. Mỗi engine có database và MySQL server riêng:

| Module | Thư mục | Database (port) | Sở hữu |
|---|---|---|---|
| System | `engines/system` | `system_dev` (3307) | User, đăng ký, đăng nhập, JWT, role toàn hệ thống |
| Website | `engines/website` | `website_dev` (3308) | Website (domain, name), thành viên và role trên từng website |
| Report | `engines/report` | `report_dev` (3309) | Số liệu thống kê theo tháng của từng website |

Chiều phụ thuộc là một chiều:

```text
Report  ──►  Website  ──►  System
   └──────────────────────►  System
```

System không biết Website hay Report tồn tại. Module khác chỉ gọi vào một module qua "cửa" công khai của nó: concern hoặc service, không truy vấn thẳng bảng của module khác.

## 3. Chức năng hiện tại của từng module

### 3.1. System: người dùng, đăng nhập, quyền toàn hệ thống

| Endpoint | Ai được gọi | Chức năng |
|---|---|---|
| `POST /system/signup` | Ai cũng được | Đăng ký, luôn là `member`, trả token |
| `POST /system/login` | Ai cũng được | Đăng nhập, trả token |
| `GET /system/me` | Đã đăng nhập | Thông tin của mình (`id`, `email`, `role`) |
| `GET /system/users` | **admin** *(mới)* | Danh sách user |
| `PATCH /system/users/:id` | **admin**, không áp dụng cho chính mình *(mới)* | Đổi role của một user |

Các "cửa" System cung cấp cho module khác:
- `System::Authentication`: xác thực token, cung cấp `current_user`, trả `401`.
- `System::Authorization` *(mới)*: cung cấp `authorize!`, trả `403`.
- `System::Policy` *(mới)*: class gốc cho mọi policy.
- `System::UserService` *(mới)*: tra user theo email hoặc id.

Lệnh tạo admin đầu tiên *(mới)*: `bin/rails system:make_admin EMAIL=...`

### 3.2. Website: quản lý website và thành viên

| Endpoint | Ai được gọi | Chức năng |
|---|---|---|
| `GET /website/sites` | Đã đăng nhập | **Chỉ các website mình là thành viên** (admin thấy tất cả) *(đã đổi)* |
| `GET /website/sites/:id` | Thành viên của site | Xem một website |
| `POST /website/sites` | Đã đăng nhập | Tạo website, người tạo **tự động thành owner** *(đã đổi)* |
| `PATCH /website/sites/:id` | owner, editor, admin *(mới)* | Sửa website |
| `DELETE /website/sites/:id` | owner, admin *(mới)* | Xoá website |
| `GET /website/sites/:id/members` | Thành viên của site *(mới)* | Danh sách thành viên và role |
| `POST /website/sites/:id/members` | owner, admin *(mới)* | Thêm thành viên theo email |
| `PATCH /website/sites/:id/members/:user_id` | owner, admin *(mới)* | Đổi role của thành viên |
| `DELETE /website/sites/:id/members/:user_id` | owner, admin *(mới)* | Gỡ thành viên |

"Cửa" cho module khác: `Website::SiteService` (tra site, và *mới thêm* `can_write_reports?`), `Website::ReportJoin` (các mảnh SQL để JOIN qua bảng FEDERATED).

### 3.3. Report: số liệu thống kê

| Endpoint | Ai được gọi | Chức năng |
|---|---|---|
| `GET /report/details` | Đã đăng nhập | Số liệu thô **do mình tạo** |
| `POST /report/details` | **owner, editor của site, admin** *(mới)* | Thêm số liệu một tháng cho một site |
| `GET /report/reports/via_join` | Đã đăng nhập | Report cuối, ghép tên miền bằng SQL JOIN qua bảng FEDERATED |
| `GET /report/reports/via_service` | Đã đăng nhập | Report cuối, ghép tên miền bằng `Website::SiteService` |

## 4. Những gì đã implement thêm

### 4.1. Thiết kế: 2 lớp role

| | Role toàn hệ thống | Role trên website |
|---|---|---|
| Lưu ở | `users.role` (DB system) | `site_members.role` (DB website) |
| Giá trị | `member`, `admin` | `viewer`, `editor`, `owner` |
| Một user có | 1 role | Nhiều role, mỗi website 1 role |
| Ai cấp | Admin, hoặc rake task | Owner của website |
| Mặc định | Signup thì ra `member` | Tạo website thì thành `owner` |

Lý do tách 2 lớp: một user có thể là owner của website A, editor của website B, và không có quyền gì ở website C. Một cột role duy nhất không diễn tả được điều này. Role trên website được đặt trong module Website vì website là dữ liệu của Website, như vậy System không phải biết gì về Website.

Bảng quyền:

| Hành động | viewer | editor | owner | admin |
|---|:-:|:-:|:-:|:-:|
| Thấy website, xem thành viên | ✅ | ✅ | ✅ | ✅ |
| Sửa website | ❌ | ✅ | ✅ | ✅ |
| Thêm số liệu Report cho website | ❌ | ✅ | ✅ | ✅ |
| Xoá website, quản lý thành viên | ❌ | ❌ | ✅ | ✅ |
| Xem danh sách user, đổi role toàn hệ thống | ❌ | ❌ | ❌ | ✅ |

### 4.2. Các file thay đổi

**System**
- `db/migrate/20261119000001_add_role_to_users.rb`: thêm cột `role` (integer, mặc định 0 là member).
- `app/models/system/user.rb`: `enum :role, { member: 0, admin: 1 }, validate: true`.
- `app/controllers/concerns/system/authorization.rb` *(mới)*: `authorize!` và `rescue_from NotAuthorized`, trả 403.
- `app/policies/system/policy.rb` *(mới)*: class gốc, mặc định từ chối, có helper `admin?`.
- `app/policies/system/user_policy.rb` *(mới)*: luật cho các endpoint quản lý user.
- `app/services/system/user_service.rb` *(mới)*: `id_by_email`, `emails_for`.
- `app/controllers/system/users_controller.rb`, `config/routes.rb`: thêm `index` và `update`.
- `lib/tasks/system.rake` *(mới)*: `system:make_admin`.

**Website**
- `db/migrate/20261119000001_create_website_site_members.rb` *(mới)*: bảng `site_members(site_id, user_id, role)`, unique theo `(site_id, user_id)`. Cột `site_id` có foreign key thật vì cùng DB. Cột `user_id` không có foreign key vì `users` nằm ở DB khác.
- `app/models/website/site_member.rb` *(mới)*: enum role, chặn đổi role hoặc gỡ **owner cuối cùng**.
- `app/models/website/site.rb`: `has_many :members`, scope `accessible_by(user)`, method `role_of(user)`.
- `app/policies/website/site_policy.rb` *(mới)*: `show?`, `update?`, `destroy?`, `manage_members?`, `write_reports?`.
- `app/controllers/website/sites_controller.rb`: lọc theo quyền, người tạo thành owner, thêm `update` và `destroy`.
- `app/controllers/website/members_controller.rb` *(mới)*: CRUD thành viên.
- `app/services/website/site_service.rb`: thêm `can_write_reports?(user, site_id)`.

**Report**
- `app/policies/report/detail_policy.rb` *(mới)*: `create?` hỏi Website qua `SiteService`.
- `app/controllers/report/details_controller.rb`: gọi `authorize!` trước khi lưu.

**Khác**
- `test/integration/authorization_test.rb` *(mới)*: 10 test. Các helper chung được chuyển sang `test/test_helper.rb`.
- `db/seeds.rb`: thêm user `viewer@example.com`, `admin@example.com`, và dữ liệu thành viên.
- `README.md`: bảng endpoint có thêm cột quyền, thêm mã lỗi 403, thêm mục Phân quyền.

## 5. Luồng Authentication

```text
① Đăng nhập
Client ── POST /system/login {email, password}
  └─ SessionsController#create  (không cần token)
       ├─ User.find_by(email)              email được chuẩn hoá (strip + downcase)
       ├─ user.authenticate(password)      bcrypt so với password_digest
       │     sai → 401 "Invalid email or password" (cùng một câu cho sai email và sai mật khẩu)
       └─ JsonWebToken.encode(user.id)     payload {user_id, exp: +24h}, ký HS256 bằng secret_key_base
Client ◄── { token, user: {id, email, role} }

② Gọi API được bảo vệ
Client ── GET /website/sites   Header: Authorization: Bearer <token>
  └─ before_action :authenticate_user!   (System::Authentication, có ở mọi controller)
       ├─ tách token khỏi header
       ├─ JsonWebToken.decode → sai chữ ký hoặc hết hạn thì nil
       ├─ User.find_by(id: payload["user_id"])
       └─ không có user → 401 "Unauthorized" (dừng ở đây)
     có current_user → chạy tiếp sang bước phân quyền
```

Điểm thiết kế:
- JWT là stateless: server không lưu session, chỉ kiểm tra chữ ký. Payload chỉ được base64, không bí mật.
- **Role không nằm trong token.** Mỗi request đều load user từ DB, nên khi đổi role thì quyền mới có hiệu lực ngay, không phải chờ token hết hạn. Đã có test kiểm chứng điều này.

## 6. Luồng Authorization

Sau khi có `current_user`, request đi qua 3 lớp kiểm tra theo thứ tự:

```text
Request (đã có current_user)
  │
  ▼ 1. SCOPE: có được biết tài nguyên này tồn tại không?
  │     Site.accessible_by(current_user).find(id)
  │       admin  → mọi site
  │       member → các site có dòng trong site_members
  │     không thấy → 404 (không lộ việc site của người khác có tồn tại)
  │
  ▼ 2. POLICY: có được làm hành động này không?
  │     authorize!(SitePolicy.new(current_user, site), :update?)
  │       update? = admin? || role.in?(["owner", "editor"])
  │                 ▲          ▲
  │                 │          role trên site này (site_members)
  │                 role toàn hệ thống (users.role)
  │     false → raise NotAuthorized → rescue_from → 403 "Forbidden"
  │
  ▼ 3. VALIDATION: dữ liệu gửi lên có hợp lệ không?
  │     sai → 422
  ▼
 200 / 201 / 204
```

Ý nghĩa các mã lỗi:

| Mã | Ý nghĩa |
|---|---|
| 401 | Không biết bạn là ai: thiếu token, token sai, hoặc hết hạn |
| 403 | Biết bạn là ai, nhưng bạn không có quyền làm việc này |
| 404 | Tài nguyên bị giấu khỏi bạn, hoặc không tồn tại |
| 422 | Có quyền, nhưng dữ liệu không hợp lệ |

Phân quyền xuyên module (Report hỏi Website):

```text
POST /report/details {site_id: 1, ...}
  └─ Report::DetailsController#create
       ├─ detail.valid?   → 422 nếu sai định dạng hoặc site không tồn tại
       └─ authorize!(Report::DetailPolicy, :create?)
            └─ Website::SiteService.can_write_reports?(user, 1)     ← "cửa" của Website
                 └─ Website::SitePolicy#write_reports?              ← luật nằm ở Website
            false → 403
```

Report không đọc bảng `site_members` và không biết có những role nào. Muốn đổi luật thì chỉ cần sửa `SitePolicy`.

## 7. Các tình huống minh hoạ

Dữ liệu mẫu (`bin/rails db:seed`, mật khẩu đều là `secret123`):
- `demo@example.com`: member, **owner** của 4 website
- `viewer@example.com`: member, **viewer** của `shop.example.com`
- `admin@example.com`: **admin**

| # | Ai | Request | Kết quả | Lý do |
|---|---|---|---|---|
| 1 | Không có token | `GET /website/sites` | **401** | Authentication thất bại |
| 2 | viewer | `GET /website/sites` | 200, chỉ có shop | Scope theo `site_members` |
| 3 | viewer | `GET /website/sites/<blog>` | **404** | Không phải thành viên của blog, nên site bị giấu |
| 4 | viewer | `PATCH /website/sites/<shop>` | **403** | Thấy được site nhưng viewer không có `update?` |
| 5 | demo (owner) | `PATCH /website/sites/<shop>/members/<viewer>` `{"role":"editor"}` | 200 | Owner có `manage_members?` |
| 6 | viewer (giờ đã là editor) | `PATCH /website/sites/<shop>` | 200 | Role trên site đổi, role System giữ nguyên |
| 7 | viewer | `POST /report/details` cho shop khi còn là viewer | **403** | `write_reports?` cần owner hoặc editor |
| 8 | demo | `DELETE` chính mình khỏi shop khi là owner duy nhất | **422** | Website phải giữ ít nhất 1 owner |
| 9 | Ai đó | `POST /system/signup` có `"role":"admin"` | 201, role là `member` | `role` không nằm trong strong params, nên không bị mass assignment |
| 10 | demo | `GET /system/users` | **403** | Chỉ admin được xem |
| 11 | admin | `GET /system/users`, xem hoặc sửa mọi website | 200 | `admin?` vượt qua mọi kiểm tra |
| 12 | admin | `PATCH /system/users/<chính mình>` `{"role":"member"}` | **403** | Admin không tự hạ quyền mình, tránh hệ thống mất admin |

## 8. Kiểm thử

```bash
docker compose exec -e RAILS_ENV=test app ruby bin/rails test
# 21 runs, 155 assertions, 0 failures, 0 errors, 0 skips
```

`test/integration/authorization_test.rb` kiểm tra:
- Signup luôn ra member, kể cả khi client gửi kèm role.
- Chỉ admin được quản lý user. Admin không được đổi role của chính mình.
- Role đổi xong có hiệu lực ngay, dùng lại token cũ vẫn được.
- User chỉ thấy website của mình. Website của người khác trả 404.
- Admin thấy và quản lý được mọi website.
- Quyền của viewer, editor và owner trên một website.
- Thêm thành viên: email không tồn tại, role sai, hoặc trùng thành viên đều bị từ chối.
- Website luôn còn ít nhất 1 owner.
- Chỉ owner, editor và admin được thêm số liệu Report.

## 9. Quyết định thiết kế và lý do

| Quyết định | Lý do |
|---|---|
| Tự viết policy (khoảng 30 dòng) thay vì dùng Pundit hay CanCanCan | Dự án để học, cần hiểu rõ cơ chế. Pattern giống hệt Pundit nên chuyển sang Pundit sau này rất dễ |
| Role trên website đặt ở module Website | Ai sở hữu dữ liệu thì sở hữu luôn quyền trên dữ liệu đó. Giữ được phụ thuộc một chiều |
| Report hỏi quyền qua `SiteService` | Không phá ranh giới module, và luật chỉ nằm ở một chỗ |
| Website của người khác trả 404 thay vì 403 | Không để lộ việc tài nguyên đó có tồn tại |
| Không đưa role vào JWT | Quyền mới có hiệu lực ngay khi role thay đổi |
| `enum ... validate: true` | Role sai thì trả 422, không bị exception 500 |
| Không có foreign key `site_members.user_id → users` | Hai bảng nằm ở 2 MySQL server khác nhau |
| Chặn xoá hoặc hạ cấp owner cuối cùng | Tránh website không còn ai quản lý |

## 10. Hạn chế và hướng tiếp theo

1. **Luật đọc và luật ghi của Report chưa khớp.** Quyền **ghi** dựa vào role trên website, còn quyền **đọc** vẫn dựa vào người tạo (`user_id`). Hệ quả:
   - Viewer của một website không xem được số liệu của website đó.
   - Hai editor cùng website không thấy số liệu của nhau.
   - Người đã bị gỡ khỏi website vẫn xem được các dòng họ tạo trước đó.
   - Admin không xem được Report của người khác.

   Hướng sửa: đổi scope đọc thành `Detail.where(site_id: Website::SiteService.accessible_ids(user))`, và chỉ giữ `user_id` để biết ai đã nhập dữ liệu. Việc này cần thống nhất với mentor về nghiệp vụ.
2. **Lộ thông tin nhỏ ở `POST /report/details`.** Site không tồn tại trả 422, còn site của người khác trả 403, nên người dùng đoán được một `site_id` có tồn tại hay không.
3. **Không thu hồi được JWT.** Chưa có logout, và token sống đủ 24 giờ. Cần denylist hoặc refresh token.
4. **Chưa có rate limit cho login.** Rails 8 có sẵn `rate_limit`.
5. **Dữ liệu cũ:** các website tạo trước khi có `site_members` không có owner, nên chỉ admin thấy được. Cần gán owner bằng tay, hoặc viết một data migration.
6. **Mỗi lần kiểm tra quyền tốn thêm query** (`role_of`). Hiện tại không đáng kể. Nếu cần, có thể cache role trong một request.
