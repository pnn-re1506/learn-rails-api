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
docker compose exec app ruby bin/rails db:seed                          # nạp dữ liệu mẫu (login demo@example.com / secret123)
docker compose up --build -d                                             # sau khi sửa code
docker compose down                                                      # tắt (giữ dữ liệu)
docker compose down -v                                                   # tắt và xóa dữ liệu
```

## Endpoints

| Method | Đường dẫn | Token | Mô tả |
|---|---|---|---|
| POST | `/system/signup` | Không | Đăng ký, trả token |
| POST | `/system/login` | Không | Đăng nhập, trả token |
| GET | `/system/me` | Có | Thông tin user hiện tại |
| GET | `/website/sites` | Có | Danh sách website |
| GET | `/website/sites/:id` | Có | Xem một website |
| POST | `/website/sites` | Có | Tạo website `{ "site": { "domain", "name" } }` |
| GET | `/report/details` | Có | Số liệu thô của Report (chưa có domain/name) |
| POST | `/report/details` | Có | Tạo `{ "detail": { "site_id", "period": "2026-10", "visits", "page_views", "bounce_rate" } }` |
| GET | `/report/reports/via_join` | Có | Report cuối, ghép bằng SQL JOIN xuyên DB |
| GET | `/report/reports/via_service` | Có | Report cuối, ghép bằng `Website::SiteService` |

Hai endpoint report nhận cùng tham số: `?domain=blog` (lọc theo domain), `?sort=domain` (mặc định sắp theo visits giảm dần).

Mã lỗi: `400` thiếu tham số, `401` chưa đăng nhập hoặc token sai, `404` không tìm thấy (kể cả dữ liệu của người khác), `422` dữ liệu không hợp lệ.

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
