# learn-rails-api

API Rails demo **Modular Monolith**: 1 app Rails, chia thành 3 module (Rails Engine), mỗi module một database riêng.

| Module | Thư mục | Database | Chức năng |
|---|---|---|---|
| System | `engines/system` | MySQL 8 (`system_*`) | Đăng ký, đăng nhập, JWT |
| Analysis | `engines/analysis` | PostgreSQL 16 (`analysis_*`) | Ghi event, thống kê |
| Report | `engines/report` | PostgreSQL 16 (`report_*`) | Lưu snapshot báo cáo từ số liệu Analysis |

```
Report ──> Analysis ──> System      (phụ thuộc một chiều)
```

- Analysis và Report dùng `System::Authentication` để bắt buộc đăng nhập.
- Report lấy số liệu qua `Analysis::SummaryService`, không JOIN sang DB của Analysis.
- Mỗi `ApplicationRecord` của module có `connects_to` trỏ tới DB riêng, khai báo trong `config/database.yml`.

## Chạy bằng Docker

Cần [Docker Desktop](https://www.docker.com/products/docker-desktop/). Không cần cài Ruby.

```powershell
docker compose up --build -d     # build image + chạy mysql, postgres, app
docker compose ps                # xem trạng thái
docker compose logs -f app       # xem log (Ctrl+C để thoát)
```

Khi khởi động, app tự chạy `db:prepare`: tạo DB nếu chưa có và migrate cả 3 DB.

| Service | Từ máy bạn | User / mật khẩu |
|---|---|---|
| API | http://localhost:3000 | |
| MySQL | localhost:3307 | root / password |
| PostgreSQL | localhost:5433 | postgres / password |

Lệnh hay dùng:

```powershell
docker compose exec app ruby bin/rails routes                            # xem toàn bộ route
docker compose exec app ruby bin/rails console                           # Rails console
docker compose exec -e RAILS_ENV=test app ruby bin/rails test            # chạy test
docker compose exec mysql mysql -uroot -ppassword -e "SHOW DATABASES"    # xem DB MySQL
docker compose exec postgres psql -U postgres -c "\l"                    # xem DB Postgres
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
| GET | `/analysis/events` | Có | Danh sách event (lọc: `?name=sale`) |
| POST | `/analysis/events` | Có | Tạo event `{ "event": { "name", "value" } }` |
| GET | `/analysis/summary` | Có | Thống kê theo `name`: count, total, average |
| GET | `/report/snapshots` | Có | Danh sách snapshot |
| POST | `/report/snapshots` | Có | Tạo snapshot `{ "snapshot": { "title" } }` từ summary hiện tại |
| GET | `/report/snapshots/:id` | Có | Xem một snapshot |
| DELETE | `/report/snapshots/:id` | Có | Xóa snapshot |

Mã lỗi: `400` thiếu tham số, `401` chưa đăng nhập hoặc token sai, `404` không tìm thấy (kể cả dữ liệu của người khác), `422` dữ liệu không hợp lệ.

## Test thử bằng PowerShell

```powershell
$base = "http://localhost:3000"

# 1. System: đăng ký, lấy token
$r = Invoke-RestMethod -Method Post "$base/system/signup" -ContentType application/json `
  -Body '{"user":{"email":"bob@example.com","password":"secret123"}}'
$h = @{ Authorization = "Bearer $($r.token)" }
Invoke-RestMethod "$base/system/me" -Headers $h

# 2. Analysis: ghi vài event rồi xem thống kê   (dữ liệu nằm ở PostgreSQL analysis_dev)
Invoke-RestMethod -Method Post "$base/analysis/events" -Headers $h -ContentType application/json -Body '{"event":{"name":"sale","value":100}}'
Invoke-RestMethod -Method Post "$base/analysis/events" -Headers $h -ContentType application/json -Body '{"event":{"name":"sale","value":300}}'
Invoke-RestMethod "$base/analysis/summary" -Headers $h | ConvertTo-Json

# 3. Report: chụp snapshot từ summary   (dữ liệu nằm ở PostgreSQL report_dev)
$s = Invoke-RestMethod -Method Post "$base/report/snapshots" -Headers $h -ContentType application/json `
  -Body '{"snapshot":{"title":"November report"}}'
$s | ConvertTo-Json -Depth 5
Invoke-RestMethod "$base/report/snapshots" -Headers $h | ConvertTo-Json -Depth 5
Invoke-RestMethod -Method Delete "$base/report/snapshots/$($s.id)" -Headers $h

# 4. Không gửi token -> 401
Invoke-RestMethod "$base/report/snapshots"
```

Bằng Postman: gọi `POST /system/signup` hoặc `/system/login`, copy `token`, rồi ở các request khác vào tab **Authorization**, chọn **Bearer Token** và dán token vào.

## Xem dữ liệu bằng DBeaver (hoặc tool tương tự)

- MySQL: host `localhost`, port `3307`, user `root`, password `password`, database `system_dev`, bảng `system_users`.
- PostgreSQL: host `localhost`, port `5433`, user `postgres`, password `password`. Database `analysis_dev` có bảng `analysis_events`, database `report_dev` có bảng `report_snapshots`.

## Thêm một module mới (ví dụ `billing`)

1. Tạo `engines/billing/` theo khuôn của `engines/analysis` (gemspec, `lib/billing/engine.rb` với `isolate_namespace Billing`, models, controllers, `config/routes.rb`, `db/migrate`).
2. Trong `Billing::ApplicationRecord`, thêm `connects_to database: { writing: :billing, reading: :billing }`.
3. Thêm `billing:` vào `config/database.yml` (cả `development` và `test`), kèm `migrations_paths: engines/billing/db/migrate`.
4. Thêm `gem "billing", path: "engines/billing"` vào `Gemfile`, và `mount Billing::Engine => "/billing"` vào `config/routes.rb`.
5. Chạy lại `docker compose up --build -d`.

> Chỉ dùng để học và demo: chưa có cấu hình production, rate limiting hay refresh token.
