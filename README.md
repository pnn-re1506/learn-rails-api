# learn-rails-api

API Rails demo **Modular Monolith**: 1 app Rails, chia thành 3 module (Rails Engine), mỗi module một database riêng, mỗi database một MySQL server riêng.

| Module | Thư mục | Database | Chức năng |
|---|---|---|---|
| System | `engines/system` | MySQL `system_*` (port 3307) | Đăng ký, đăng nhập, JWT |
| Website | `engines/website` | MySQL `website_*` (port 3308) | Thông tin website: `domain`, `name` |
| Report | `engines/report` | MySQL `report_*` (port 3309) | Số liệu chi tiết theo website và tháng, ghép với Website thành report cuối |

```
Report ──> Website ──> System      (phụ thuộc một chiều)
```

- 3 database nằm trên **3 MySQL server khác nhau** (3 port). Tên bảng không có prefix module: `users`, `sites`, `details`.
- Website và Report dùng `System::Authentication` để bắt buộc đăng nhập.
- Report ghép dữ liệu Website theo **hai cách** để so sánh (cùng kết quả JSON):
  - `via_join`: 1 câu SQL `LEFT JOIN` trên DB của Report. Report không nối thẳng sang server Website được, nên DB Report có bảng **FEDERATED** `sites` (không chứa dữ liệu, mỗi query được MySQL chuyển sang bảng `sites` ở server Website). Xem migration `CreateFederatedSites` và `Website::ReportJoin`.
  - `via_service`: gọi `Website::SiteService` rồi ghép bằng Ruby.
- Mỗi `ApplicationRecord` của module có `connects_to` trỏ tới DB riêng, khai báo trong `config/database.yml`.

## Base controller và Swagger

- `System::BaseController` (`engines/system/app/controllers/system/base_controller.rb`) là lớp cha của mọi `ApplicationController`. Nó gồm: đăng nhập (401), phân quyền (403), `System::ApiResponder` (lỗi 404/400/422) và `System::CrudActions` (index/show/create/update/destroy).
- Controller mới chỉ cần khai báo `model_class` và `record_params`; route quyết định action nào được mở. Muốn tùy biến thì override hook (`scope`, `collection`, `find_record`, `build_record`, `authorize_record!`, `serialize`) hoặc override cả action. Ví dụ: `Website::SitesController`, `Report::DetailsController`.
- Swagger UI: http://localhost:3000/api-docs (đọc file `config/openapi.yml`). Đăng nhập `POST /system/login`, bấm **Authorize**, dán token. Khi thêm hoặc sửa endpoint, nhớ cập nhật `config/openapi.yml`.

## Chạy bằng Docker

Cần [Docker Desktop](https://www.docker.com/products/docker-desktop/). Không cần cài Ruby.

```powershell
docker compose up --build -d     # build image + chạy 3 mysql + app
docker compose ps                # xem trạng thái
docker compose logs -f app       # xem log (Ctrl+C để thoát)
```

Khi khởi động, app tự chạy `db:prepare`: tạo DB nếu chưa có và migrate cả 3 DB (migration của Report tạo bảng FEDERATED nên bảng `sites` của Website phải có trước; `db:prepare` migrate theo thứ tự `system`, `website`, `report` nên đã đúng). Không có file `db/*_schema.rb`: DB luôn được dựng từ migration, vì bảng FEDERATED trỏ tới một MySQL SERVER theo từng môi trường.

| Service | Từ máy bạn | User / mật khẩu |
|---|---|---|
| API | http://localhost:3000 | |
| MySQL system | localhost:3307 | root / password |
| MySQL website | localhost:3308 | root / password |
| MySQL report | localhost:3309 | root / password |

Lệnh hay dùng:

```powershell
docker compose exec app ruby bin/rails routes                            # xem toàn bộ route
docker compose exec app ruby bin/rails console                           # Rails console
docker compose exec -e RAILS_ENV=test app ruby bin/rails test            # chạy test
docker compose exec mysql-report mysql -uroot -ppassword -e "SHOW DATABASES"   # xem DB MySQL (mysql-system / mysql-website / mysql-report)
docker compose exec app ruby bin/rails system:make_admin EMAIL=a@b.com # cấp quyền admin cho một user
docker compose exec app ruby bin/rails db:seed                          # nạp dữ liệu mẫu (xem mục Phân quyền)
docker compose up --build -d                                             # sau khi sửa code
docker compose down                                                      # tắt (giữ dữ liệu)
docker compose down -v                                                   # tắt và xóa dữ liệu
```

## Demo tách service theo nhóm route

`compose.split.yml` dùng chung một image Rails cho `app-system`, `app-website` và `app-report`. Nginx chuyển `/system`, `/website` và `/report` tới service tương ứng. Dùng PowerShell 7, Docker Compose v2.24.4 trở lên và một project riêng để demo trên bộ dữ liệu riêng. Demo mở HTTP tại `http://127.0.0.1:8080`.

```powershell
if (-not (Test-Path tmp/split.env)) {
  New-Item -ItemType Directory -Path tmp -Force | Out-Null
  $signingKey = [Convert]::ToHexString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(64))
  Set-Content tmp/split.env "SECRET_KEY_BASE=$signingKey" -Encoding ascii
}

$split = @('--env-file', 'tmp/split.env', '-p', 'learn-rails-api-split', '-f', 'docker-compose.yml', '-f', 'compose.split.yml')
docker build -t learn-rails-api:v1 .
docker compose @split up -d --wait --wait-timeout 120
docker compose @split exec app-system ruby bin/rails db:seed
docker compose @split ps -a
```

Tác vụ `migrate` chờ các MySQL service healthy, chạy `db:prepare` rồi thoát với mã `0`. Ba web service chờ kết quả này khi dựng stack và dùng cùng khóa JWT từ `tmp/split.env`. Có thể sử dụng các request ở mục **Test thử bằng PowerShell** với `$base = "http://127.0.0.1:8080"` sau khi seed bằng lệnh trên.

Để thử cô lập lỗi, chạy `docker compose @split stop app-report`. Gọi `/report/reports/via_service` sẽ lỗi tại proxy. Với JWT còn hạn, `/system/me` và `/website/sites` vẫn chạy. Dùng `docker compose @split up -d --no-deps --wait app-report` để bật lại Report mà không chạy tác vụ migration.

Khi có code mới chỉ ảnh hưởng Report, build và cập nhật service đó. Ví dụ sau áp dụng cho `v2` dùng cùng schema với `v1`.

```powershell
docker build -t learn-rails-api:v2 .
$env:REPORT_IMAGE = 'learn-rails-api:v2'
docker compose @split up -d --no-deps --wait app-report

# Rollback riêng Report
$env:REPORT_IMAGE = 'learn-rails-api:v1'
docker compose @split up -d --no-deps --wait app-report
```

Nếu release có migration, chạy `MIGRATE_IMAGE` tương ứng trước khi cập nhật web. Kiểm tra code cũ và mới đều chạy được trên schema sau migration trong thời gian rollout và rollback.

```powershell
$env:MIGRATE_IMAGE = 'learn-rails-api:v2'
docker compose @split run --rm --no-deps migrate
```

`docker compose @split down` dừng môi trường demo và giữ các volume DB.

## Endpoints

| Method | Đường dẫn | Quyền | Mô tả |
|---|---|---|---|
| POST | `/system/signup` | Không cần token | Đăng ký (luôn là `member`), trả token |
| POST | `/system/login` | Không cần token | Đăng nhập, trả token |
| GET | `/system/me` | Đăng nhập | Thông tin user hiện tại (`id`, `email`, `role`) |
| GET | `/system/users` | admin | Danh sách user |
| PATCH | `/system/users/:id` | admin (không đổi được role của chính mình) | Đổi role `{ "user": { "role": "admin" } }` |
| GET | `/website/sites` | Đăng nhập | Các site mình là thành viên (admin: tất cả) |
| GET | `/website/sites/:id` | Thành viên site | Xem một website |
| POST | `/website/sites` | Đăng nhập | Tạo website `{ "site": { "domain", "name" } }`, người tạo thành `owner` |
| PATCH | `/website/sites/:id` | owner, editor, admin | Sửa website |
| DELETE | `/website/sites/:id` | owner, admin | Xóa website |
| GET | `/website/sites/:id/members` | Thành viên site | Danh sách thành viên và role |
| POST | `/website/sites/:id/members` | owner, admin | Thêm `{ "member": { "email", "role": "viewer\|editor\|owner" } }` |
| PATCH | `/website/sites/:id/members/:user_id` | owner, admin | Đổi role `{ "member": { "role" } }` |
| DELETE | `/website/sites/:id/members/:user_id` | owner, admin | Xóa thành viên (không xóa được owner cuối cùng) |
| GET | `/report/details` | Đăng nhập | Số liệu thô CỦA MÌNH (chưa có domain/name) |
| POST | `/report/details` | owner, editor của site, admin | Tạo `{ "detail": { "site_id", "period": "2026-10", "visits", "page_views", "bounce_rate" } }` |
| GET | `/report/reports/via_join` | Đăng nhập | Report cuối, ghép bằng SQL JOIN xuyên DB |
| GET | `/report/reports/via_service` | Đăng nhập | Report cuối, ghép bằng `Website::SiteService` |

Hai endpoint report nhận cùng tham số: `?domain=blog` (lọc theo domain), `?sort=domain` (mặc định sắp theo visits giảm dần).

Mã lỗi: `400` thiếu tham số, `401` chưa đăng nhập hoặc token sai, `403` đã đăng nhập nhưng không đủ quyền, `404` không tìm thấy (kể cả site/dữ liệu của người khác: giấu luôn sự tồn tại), `422` dữ liệu không hợp lệ.

## Phân quyền (authorization)

Hai lớp:

1. **Role toàn hệ thống** (module System, cột `users.role`): `member` (mặc định) hoặc `admin` (làm được mọi thứ). Đăng ký luôn ra `member`. Admin đầu tiên tạo bằng `bin/rails system:make_admin EMAIL=...`.
2. **Role trên từng site** (module Website, bảng `site_members`): `viewer` (xem), `editor` (+ sửa site, thêm số liệu report), `owner` (+ xóa site, quản lý thành viên). Mỗi site luôn còn ít nhất 1 owner.

Quy tắc nằm trong các policy: `System::UserPolicy`, `Website::SitePolicy`, `Report::DetailPolicy` (kế thừa `System::Policy`). Controller gọi `authorize!(policy, :action?)` (concern `System::Authorization`), sai thì trả `403`.

User mẫu sau `db:seed` (mật khẩu đều là `secret123`): `demo@example.com` (owner 4 site), `viewer@example.com` (viewer của shop.example.com), `admin@example.com` (admin).

## Test thử bằng PowerShell

```powershell
$base = "http://localhost:3000"
docker compose exec app ruby bin/rails db:seed      # dữ liệu mẫu, chạy 1 lần

# 1. Đăng nhập user mẫu, lấy token
$r = Invoke-RestMethod -Method Post "$base/system/login" -ContentType application/json `
  -Body '{"user":{"email":"demo@example.com","password":"secret123"}}'
$h = @{ Authorization = "Bearer $($r.token)" }

# 2. Website (DB website_dev) và số liệu thô của Report (DB report_dev)
Invoke-RestMethod "$base/website/sites" -Headers $h | ConvertTo-Json
Invoke-RestMethod "$base/report/details" -Headers $h | ConvertTo-Json

# 3. Report cuối: cùng kết quả, hai cách ghép
Invoke-RestMethod "$base/report/reports/via_join"    -Headers $h | ConvertTo-Json -Depth 6
Invoke-RestMethod "$base/report/reports/via_service" -Headers $h | ConvertTo-Json -Depth 6
Invoke-RestMethod "$base/report/reports/via_join?domain=blog&sort=domain" -Headers $h | ConvertTo-Json -Depth 6

# 4. Không gửi token -> 401
Invoke-RestMethod "$base/report/reports/via_join"
```

Bằng Postman: gọi `POST /system/signup` hoặc `/system/login`, copy `token`, rồi ở các request khác vào tab **Authorization**, chọn **Bearer Token** và dán token vào.

## Xem dữ liệu bằng DBeaver (hoặc tool tương tự)

MySQL: host `localhost`, user `root`, password `password`. Ba server: `system_dev` (bảng `users`) ở port `3307`, `website_dev` (bảng `sites`) ở port `3308`, `report_dev` (bảng `details` và `sites` FEDERATED) ở port `3309`. Kết nối vào port `3309`, thử join tay:

```sql
SELECT d.period, d.visits, s.domain, s.name
FROM report_dev.details d
LEFT JOIN report_dev.sites s ON s.id = d.site_id;   -- sites là bảng FEDERATED, dữ liệu thật ở port 3308
```

## Thêm một module mới (ví dụ `billing`)

1. Tạo `engines/billing/` theo khuôn của `engines/website` (gemspec, `lib/billing/engine.rb` với `isolate_namespace Billing`, models, controllers, `config/routes.rb`, `db/migrate`).
2. Trong `Billing::ApplicationRecord`, thêm `connects_to database: { writing: :billing, reading: :billing }`.
3. Thêm `billing:` vào `config/database.yml` (cả `development` và `test`), kèm `migrations_paths: engines/billing/db/migrate`.
4. Thêm `gem "billing", path: "engines/billing"` vào `Gemfile`, và `mount Billing::Engine => "/billing"` vào `config/routes.rb`.
5. Chạy lại `docker compose up --build -d`.

> Chỉ dùng để học và demo: chưa có cấu hình production, rate limiting hay refresh token.
