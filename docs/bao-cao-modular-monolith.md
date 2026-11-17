> **Lưu ý:** tài liệu này mô tả phiên bản đầu (module Analysis, Report lưu snapshot, 2 loại DB). Codebase hiện tại đã đổi sang Website + Report trên cùng MySQL; xem `README.md`.

# Báo cáo: Rails modular monolith trong `learn-rails-api`

Tài liệu này mô tả codebase demo đang làm gì, và bài học nào áp dụng được khi gộp nhiều ứng dụng Rails riêng thành một source monolith.

## Bối cảnh

Hiện có nhiều source Ruby on Rails tách riêng. Mục tiêu là gom chúng về một source duy nhất, nhưng vẫn giữ ranh giới module: mỗi miền nghiệp vụ có code, route, migration và database của nó. Repo này là một bản thu nhỏ của mô hình đó, với 3 module thay vì 8.

Đây là app để học. Chưa có cấu hình production, rate limit, hay refresh token.

## Kết luận ngắn

`learn-rails-api` là một process Rails 8.1, chế độ API-only. App gốc gần như rỗng. Toàn bộ nghiệp vụ nằm trong 3 Rails Engine, mỗi engine là một gem local:

| Module | Thư mục | Database | Việc nó sở hữu |
|---|---|---|---|
| System | `engines/system` | MySQL `system_dev` | User, đăng ký, đăng nhập, JWT |
| Analysis | `engines/analysis` | PostgreSQL `analysis_dev` | Event đo lường và thống kê theo user |
| Report | `engines/report` | PostgreSQL `report_dev` | Snapshot: bản sao đóng băng của thống kê |

Ba module chạy trong cùng một process, cùng một image Docker, cùng cổng 3000. Chúng không dùng chung một database và không JOIN xuyên database.

Chiều phụ thuộc một chiều:

```text
Report  -->  Analysis  -->  System
```

System không biết Analysis hay Report tồn tại.

## App gốc làm gì

Thư mục gốc không có `app/`. Host chỉ làm bốn việc:

1. Boot Rails API (`config/application.rb`, `config.api_only = true`).
2. Mount từng engine vào một prefix URL (`config/routes.rb`).
3. Khai báo 3 database và đường dẫn migration (`config/database.yml`).
4. Khai báo 3 gem local (`Gemfile`).

```ruby
mount System::Engine   => "/system"
mount Analysis::Engine => "/analysis"
mount Report::Engine   => "/report"
```

Route chi tiết không nằm ở app gốc. Mỗi engine có `config/routes.rb` riêng.

## Một engine được tổ chức thế nào

Ba engine cùng một khuôn:

```text
engines/<tên>/
├── <tên>.gemspec              # gem local, khai báo phụ thuộc
├── lib/<tên>.rb               # file Bundler load
├── lib/<tên>/engine.rb        # class Rails::Engine, isolate_namespace
├── config/routes.rb
├── app/controllers/<tên>/
├── app/models/<tên>/
├── app/services/              # chỉ Analysis có, là API công khai của module
└── db/migrate/
```

`isolate_namespace` làm ba việc cùng lúc:

- Class nằm trong namespace: `System::User`, `Analysis::Event`, `Report::Snapshot`.
- Tên bảng được prefix: `system_users`, `analysis_events`, `report_snapshots`.
- Route và controller của engine không đè lên nhau.

`Gemfile` của app gốc trỏ vào từng gem bằng `path`:

```ruby
gem "system",   path: "engines/system"
gem "analysis", path: "engines/analysis"
gem "report",   path: "engines/report"
```

Phụ thuộc giữa module khai báo trong gemspec, không khai báo bằng `require` tùy tiện:

- `analysis.gemspec` phụ thuộc `system`, vì controller Analysis include `System::Authentication`.
- `report.gemspec` phụ thuộc `system` và `analysis`, vì Report cần đăng nhập và cần số liệu thống kê.
- `system.gemspec` không phụ thuộc hai module kia. bcrypt và jwt chỉ nằm ở System.

## Ranh giới giữa các module

Module không được với vào model của nhau. Mỗi module có một cửa công khai.

**Cửa của System** là concern `System::Authentication`. Analysis và Report chỉ viết:

```ruby
include System::Authentication
```

Concern đọc header `Authorization: Bearer <token>`, giải JWT, set `current_user`. Hai module kia không cần biết thuật toán JWT hay bảng `system_users`.

**Cửa của Analysis** là `Analysis::SummaryService.for_user(user_id)`. Report gọi method này. Report không query `Analysis::Event` và không biết event nằm ở PostgreSQL.

Khi tạo snapshot, Report lấy mảng thống kê rồi lưu một bản copy vào cột `jsonb` của chính nó. Event tạo sau đó không sửa snapshot cũ. Đó là cách chuyển dữ liệu qua ranh giới database: copy tại thời điểm cần, không JOIN.

`user_id` trên event và snapshot là một số thường, không có foreign key. User nằm ở MySQL, event và snapshot nằm ở PostgreSQL, nên database không thể ràng buộc khóa ngoại.

## Schema đang chạy

Đã kiểm tra trên Docker lúc app đang chạy. `db:prepare` đã tạo cả database development và test.

### MySQL, cổng host 3307

Database: `system_dev`, `system_test`.

Bảng nghiệp vụ `system_users`:

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| id | bigint, auto increment | primary key |
| email | varchar(255) | not null, unique |
| password_digest | varchar(255) | not null, bcrypt hash, không bao giờ trả ra API |
| created_at, updated_at | datetime(6) | not null |

### PostgreSQL, cổng host 5433, một server hai database

Database `analysis_dev` và `analysis_test`. Bảng `analysis_events`:

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| id | bigint | primary key |
| user_id | bigint | not null, không có foreign key |
| name | varchar | not null |
| value | integer | not null, default 0 |
| created_at, updated_at | timestamp(6) | not null |

Index: `(user_id, name)`.

Database `report_dev` và `report_test`. Bảng `report_snapshots`:

| Cột | Kiểu | Ràng buộc |
|---|---|---|
| id | bigint | primary key |
| user_id | bigint | not null, không có foreign key |
| title | varchar | not null |
| data | jsonb | not null, default `[]`, bản copy của summary |
| created_at, updated_at | timestamp(6) | not null |

Index: `(user_id)`.

Model chọn database bằng `connects_to` trên `ApplicationRecord` của chính module đó. `migrations_paths` trong `database.yml` chỉ migration của engine vào đúng database. Vì vậy `rails db:prepare` migrate cả ba, không trộn bảng.

## Luồng một request

Ví dụ tạo snapshot:

1. Client gửi `POST /report/snapshots` kèm Bearer token và `{ "snapshot": { "title": "..." } }`.
2. App gốc thấy prefix `/report` và chuyển vào `Report::Engine`.
3. `Report::SnapshotsController` chạy `authenticate_user!` từ System. JWT được giải bằng `secret_key_base`. `user_id` trong payload được dùng để tìm `System::User` trên MySQL.
4. Token sai, hết hạn, hoặc không có user thì trả 401.
5. Controller gọi `Analysis::SummaryService.for_user(current_user.id)`. Service query `analysis_events` trên PostgreSQL, group theo `name`, trả count, total, average.
6. Controller ghi một dòng `report_snapshots` trên database `report_dev`, cột `data` là bản copy JSON của summary.
7. Response 201 trả snapshot vừa lưu.

Các request khác cùng kiểu. Mọi query danh sách đều có `where(user_id: current_user.id)`. Snapshot hoặc event của người khác trả 404, vì bản ghi không nằm trong scope của user hiện tại.

Mã lỗi thống nhất: 400 thiếu tham số, 401 chưa đăng nhập, 404 không thấy trong scope của user, 422 validation.

## Endpoint

| Method | Đường dẫn | Token |
|---|---|---|
| POST | `/system/signup` | không |
| POST | `/system/login` | không |
| GET | `/system/me` | có |
| GET | `/analysis/events` | có, lọc được bằng `?name=` |
| POST | `/analysis/events` | có |
| GET | `/analysis/summary` | có |
| GET | `/report/snapshots` | có |
| POST | `/report/snapshots` | có |
| GET | `/report/snapshots/:id` | có |
| DELETE | `/report/snapshots/:id` | có |
| GET | `/up` | không, health check của Rails |

## Docker được dựng thế nào

Một image cho cả ba module. File là `Dockerfile`.

1. Base image `ruby:3.4-slim`, khớp `.ruby-version` 3.4.
2. Cài compiler và client library của MySQL (`default-libmysqlclient-dev`) cùng PostgreSQL (`libpq-dev`), vì gem `mysql2` và `pg` biên dịch native extension.
3. Copy `Gemfile`, `Gemfile.lock` và cả thư mục `engines/` trước khi `bundle install`. Bước này bắt buộc: ba gem là path gem, Bundler đọc `engines/*/gemspec` ngay lúc cài.
4. `bundle install` cài Rails 8.1.4.1 và phần còn lại. Lần build vừa chạy cài 74 gem.
5. Copy toàn bộ source. Tách bước này để sửa code Ruby không buộc cài lại gem nếu Gemfile không đổi.
6. Lúc container start, lệnh là `rails db:prepare` rồi `rails server -b 0.0.0.0 -p 3000`. `db:prepare` tạo database nếu chưa có và chạy migration của cả ba connection.

`docker-compose.yml` có ba service:

- `mysql:8.0`, publish `3307:3306`, volume `mysqldata`.
- `postgres:16`, publish `5433:5432`, volume `pgdata`. Một server PostgreSQL giữ hai database analysis và report.
- `app`, build từ Dockerfile, publish `3000:3000`. App chỉ start sau khi cả hai database healthy.

Trong mạng Docker, app nối tới hostname `mysql` và `postgres`. Từ máy host, DBeaver nối `localhost:3307` và `localhost:5433`.

Lệnh đã dùng: `docker compose up --build -d`. Image kết quả có tên `learn-rails-api-app`. Ba container sau build: `learn-rails-api-mysql-1`, `learn-rails-api-postgres-1`, `learn-rails-api-app-1`.

## Áp dụng khi gộp nhiều source Rails

Mẫu này cho thấy một monolith vẫn có thể giữ biên giới của nhiều app cũ.

Việc nên giữ:

- Mỗi app cũ thành một engine trong `engines/<tên>`.
- App gốc chỉ mount route, khai báo database, và liệt kê gem. Không nhét nghiệp vụ vào `app/` của host.
- `isolate_namespace` để class và tên bảng không đụng nhau khi gộp.
- Phụ thuộc một chiều, ghi trong gemspec. Module nền (auth, user) không được phụ thuộc module nghiệp vụ.
- Mỗi module công bố một cửa nhỏ: concern, service, hoặc một public class. Module khác không gọi model nội bộ.
- Database có thể giữ riêng trong giai đoạn đầu, bằng `connects_to` và `migrations_paths`. Không bắt buộc gộp schema ngay ngày đầu.
- Khóa xuyên database để là id thường. Dữ liệu cần "đóng băng" thì copy sang module đích, như cột `data` của snapshot.

Việc demo này chưa trả lời, và sẽ là phần việc thật khi gộp 8 source:

- Thứ tự di chuyển: nên đưa identity/auth vào trước, vì mọi module khác phụ thuộc nó.
- Code dùng chung thật sự (tiền, thời gian, lỗi HTTP) đặt ở đâu, để không biến một engine thành chỗ chứa mọi thứ.
- Job nền, mailer, file upload, và callback hiện đang gọi chéo app.
- Dữ liệu cũ: có migrate sang database mới hay giữ connection cũ.
- Một số module có thể cần deploy tách sau này. Engine giữ cửa công khai sẽ làm bước đó dễ hơn là model gọi lẫn nhau.
- Quyền sở hữu: mỗi engine một nhóm người review, thay vì một `app/models` chung.

## Cách tự kiểm tra

```powershell
docker compose up --build -d
docker compose exec -e RAILS_ENV=test app ruby bin/rails test
```

Test trong `test/integration/api_flow_test.rb` đi hết signup, event, summary, snapshot, và kiểm tra user này không đọc được dữ liệu của user kia. Test dùng database `*_test`, không đụng dữ liệu `*_dev`.
