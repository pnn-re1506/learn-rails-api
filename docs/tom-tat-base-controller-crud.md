# Tóm tắt: Base controller CRUD, filter và Swagger

## 1. Yêu cầu của mentor

Tạo base controller API trong Rails và một module chung. Controller mới kế thừa là có sẵn CRUD, và vẫn tùy biến được khi cần. Sau đó mentor yêu cầu thêm filter cho các API danh sách.

## 2. Đã làm

Tất cả nằm trong engine `System`, vì Website và Report vốn đã dùng System làm "front door" (Authentication, Authorization).

| File | Vai trò |
|---|---|
| `engines/system/app/controllers/concerns/system/api_responder.rb` | Xử lý lỗi dùng chung: 404, 400, `render_validation_errors` (422) |
| `engines/system/app/controllers/concerns/system/crud_actions.rb` | 5 action CRUD + các hook tùy biến + filter/search/sort cho `index` |
| `engines/system/app/controllers/system/base_controller.rb` | Include Authentication, Authorization, ApiResponder, CrudActions |

Cả 3 `ApplicationController` (System, Website, Report) kế thừa `System::BaseController`, nên không còn lặp `rescue_from` ở từng engine.

Controller mới chỉ cần:

```ruby
class ProductsController < ApplicationController
  private
  def model_class   = Product
  def record_params = params.expect(product: %i[name price])
end
```

Route quyết định action nào được mở (`only: [...]`).

## 3. Các hook

| Hook | Mặc định | Dùng để |
|---|---|---|
| `model_class` | báo lỗi (bắt buộc) | model quản lý |
| `record_params` | báo lỗi (bắt buộc) | strong params cho create/update |
| `scope` | `model_class.all` | giới hạn dữ liệu được phép thấy (quyền), mọi action đều dựa vào đây |
| `collection` | `scope.order(:id)` | danh sách cho `index`, đổi thứ tự mặc định |
| `find_record` | `scope.find(params[:id])` | tìm một record |
| `build_record` | `scope.new(record_params)` | cách tạo record, ví dụ gắn thêm owner |
| `authorize_record!(action, record)` | cho phép tất cả | kiểm tra quyền, sai thì 403 |
| `serialize(record)` | trả record nguyên | định dạng JSON (ẩn/thêm field) |

Lưu ý: `authorize_record!` mặc định không chặn gì, quên ghi đè thì không kiểm tra quyền.

## 4. Controller con ghi đè hook thế nào

- **`Website::SitesController`** (54 xuống 33 dòng): `scope = Site.accessible_by(current_user)`, `collection` theo `domain`, `build_record` tạo thêm owner membership, `authorize_record!` dùng `SitePolicy` (bỏ qua `:create`), `search_fields = domain, name`.
- **`Report::DetailsController`** (35 xuống 27 dòng): `scope = Detail.where(user_id: current_user.id)`, `collection` theo `period, id`, `authorize_record!` dùng `DetailPolicy`, `filter_fields = site_id, period`, `sortable_fields` gồm visits, page_views, bounce_rate...
- **Giữ nguyên** (không phải CRUD thuần): `MembersController`, `ReportsController`, `UsersController`, `SessionsController`.

## 5. Filter cho `index`

`scope` là giới hạn **do server quyết định** (bảo mật). Filter là lựa chọn **do client quyết định** theo từng request, áp lên tập đã giới hạn bởi `scope`.

```
collection → filter_records → search_records → sort_records → serialize
```

| Hook | Query param | Ý nghĩa |
|---|---|---|
| `filter_fields` | `?site_id=1&period=2026-10` | lọc đúng giá trị |
| `search_fields` | `?q=shop` | tìm "chứa" trên bất kỳ field nào |
| `sortable_fields` | `?sort=visits&direction=desc` | sắp xếp (`asc` mặc định) |

Field không có trong danh sách bị bỏ qua, nên client không lọc hay sắp xếp theo cột không được phép (ví dụ `sort=password_digest`). Không khai báo gì thì `index` hoạt động y như trước.

`index` và `show`: `index` lấy nhiều record qua `collection` (có filter), `show` lấy một record qua `find_record` (không có filter, không thấy thì 404).

## 6. Swagger

- Swagger UI: `http://localhost:3000/api-docs`, đọc file `config/openapi.yml`.
- Không dùng gem. Giao diện tải từ CDN (cần internet). Khi thêm hoặc sửa endpoint phải cập nhật `openapi.yml` thủ công.
- Cách dùng: `POST /system/login` lấy token, bấm **Authorize**, dán token (không thêm chữ `Bearer`).
- Tài khoản seed (`db:seed`, mật khẩu `secret123`): `admin@example.com` (admin), `demo@example.com`, `viewer@example.com`.
- Admin thấy mọi site, nhưng `GET /report/details` của admin rỗng nếu admin chưa có dòng số liệu riêng, vì Details luôn lọc theo `user_id` của người đăng nhập.

## 7. Test

Chạy trong container: `docker compose exec -e RAILS_ENV=test app ruby bin/rails test` (sau khi sửa code phải `docker compose up --build -d`). Hiện có **30 test, 0 lỗi**.

- `test/integration/docs_test.rb`: Swagger khớp với route thật (thiếu hoặc thừa route đều báo lỗi).
- `test/integration/list_filter_test.rb`: filter, search, sort và không lộ dữ liệu của user khác.

## 8. Docker

Không cần đổi `Dockerfile` hay compose, vì không thêm gem. Chỉ cần build lại image khi sửa code. Với `compose.split.yml`, nginx chỉ chuyển `/system`, `/website`, `/report`, nên `/api-docs` chỉ xem được ở chế độ monolith (cổng 3000).

## 9. Câu hỏi còn mở với mentor

- Base đặt trong engine `System` có ổn không?
- Có cần thêm phân trang không (cần đổi định dạng JSON hoặc dùng header)?
- Có cần macro giới hạn action (ví dụ `crud only: %i[index create]`) không? Hiện mọi controller con đều có sẵn 5 action, route chặn bên ngoài.
- Admin có nên xem được số liệu Report của mọi user không? (Hiện không.)

## 10. Tin nhắn báo mentor (ngắn)

> "Em đã tạo base controller dùng chung (CRUD + xử lý lỗi), controller con chỉ khai báo model và field được phép. Em đã refactor Website và Report, thêm filter/tìm kiếm/sắp xếp cho API danh sách, thêm Swagger và test, test đều qua. Anh/chị xem giúp em hướng làm đã ổn chưa ạ?"
