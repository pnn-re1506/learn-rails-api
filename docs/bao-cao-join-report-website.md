# Báo cáo: ghép dữ liệu Report và Website giữa hai database

## 1. Yêu cầu của mentor

Codebase là Rails modular monolith (mỗi module là một Rails Engine, mỗi module một database). Yêu cầu:

1. Cả 3 database đều là MySQL, cùng một server.
2. Đổi module `analysis` thành `website`: database lưu thông tin website (domain, name).
3. Module `report`: database lưu thông tin chi tiết của website để tạo report.
4. Nghiên cứu: khi gọi API của Report, có cách nào **join** hai database report và website để Report trả ra **một report cuối cùng** không, và so sánh với cách gọi qua method của module.

## 2. Kết luận

**Có.** Vì hai database nằm trên cùng một MySQL server, một connection có thể đọc bảng của database khác bằng cú pháp `` `ten_db`.`ten_bang` ``. Report join thẳng vào bảng của Website trong **một câu SQL**.

Tôi implement **cả hai cách** thành hai endpoint trả cùng một JSON, để so sánh trực tiếp:

| Endpoint | Cách ghép |
|---|---|
| `GET /report/reports/via_join` | Cách 1: SQL `LEFT JOIN` xuyên database |
| `GET /report/reports/via_service` | Cách 2: gọi `Website::SiteService`, ghép bằng Ruby |

## 3. Kiến trúc đã implement

```
Report ──> Website ──> System        (phụ thuộc một chiều)
 report_dev   website_dev   system_dev      (3 database, 1 MySQL server, user root)
```

- `config/database.yml`: 3 database MySQL, mỗi database có `migrations_paths` riêng.
- Mỗi module có `ApplicationRecord` riêng với `connects_to`, nên model của module chỉ nối vào database của nó.
- Website: model `Site` (`domain`, `name`).
- Report: model `Detail` (`user_id`, `site_id`, `period`, `visits`, `page_views`, `bounce_rate`). `site_id` trỏ sang Website nhưng **không có foreign key** vì khác database.

## 4. Cách 1: JOIN xuyên database (`via_join`)

Report cần tên domain nhưng không được biết tên database và tên bảng của Website. Vì vậy phần "biết tên bảng" nằm trong module sở hữu bảng đó:

- `Website::ReportJoin` (trong module Website) tạo các mảnh SQL: tên bảng có tiền tố database (lấy từ cấu hình, nên dev là `website_dev`, test là `website_test`), câu `LEFT JOIN`, và các cột cần lấy.
- `Report::Detail` có scope `with_site`, `for_domain`, `order_by_domain` chỉ gọi `ReportJoin` để lấy các mảnh này.

Câu SQL thực tế (lấy từ log):

```sql
SELECT report_details.*, `website_dev`.`website_sites`.domain AS site_domain, ...
FROM report_details
LEFT JOIN `website_dev`.`website_sites` ON `website_dev`.`website_sites`.id = report_details.site_id
WHERE report_details.user_id = 1 AND `website_dev`.`website_sites`.domain LIKE '%blog%'
ORDER BY report_details.visits DESC, report_details.id ASC
```

Điều kiện để chạy: cùng MySQL server, user có quyền đọc cả hai database. Dùng `LEFT JOIN` để dòng report vẫn hiện (với `site: null`) khi site đã bị xóa.

## 5. Cách 2: gọi qua method của module (`via_service`)

1. Lọc `Detail` theo user (nếu có `?domain=`, lấy trước danh sách `site_id` từ `Website::SiteService.ids_by_domain`).
2. `Website::SiteService.find_many(ids)` lấy thông tin site bằng một query `WHERE id IN (...)`.
3. Ghép bằng Ruby. Sắp xếp theo domain cũng làm bằng Ruby.

## 6. So sánh

| | JOIN xuyên DB | Gọi service |
|---|---|---|
| Số query | 1 | 2 (hoặc 3 khi lọc theo domain) |
| Lọc / sắp xếp theo cột website | Trong SQL | Phải làm bằng Ruby hoặc lấy id trước |
| Hiệu năng với dữ liệu lớn | Tốt | Tốn bộ nhớ, nhiều lượt hơn |
| Ranh giới module | Bị nới (Report dùng bảng của Website), được hạn chế bằng `ReportJoin` | Giữ nguyên, Report chỉ gọi method |
| Website đổi schema | Có thể làm vỡ Report | Không ảnh hưởng nếu giữ method |
| Tách Website sang server khác | Mất khả năng join | Không phải sửa Report |
| Quyền MySQL | User cần quyền trên cả hai database | Mỗi module chỉ cần database của nó |

## 7. Những điểm đáng lưu ý khi làm thực tế

- **Không có foreign key xuyên database:** `Detail` tự kiểm tra `site_id` qua `Website::SiteService.exists?`. Site bị xóa vẫn có thể để lại dòng "mồ côi", cả hai endpoint đều trả `site: null` cho dòng đó.
- **Test:** test của endpoint join không chạy trong transaction, vì mỗi connection giữ dữ liệu chưa commit riêng nên connection của Report không thấy site vừa tạo của connection Website. `ApiFlowTest` tắt `use_transactional_tests` và tự xóa dữ liệu.
- **Kết quả kiểm chứng:** 11 test pass; hai endpoint trả cùng `count`, `total_visits` và danh sách dòng với dữ liệu mẫu.

## 8. Đề xuất

- Mặc định dùng **gọi service**, vì giữ được ranh giới module và dễ tách sau này.
- Dùng **JOIN xuyên database** cho các report nặng cần lọc, sắp xếp, tổng hợp theo cột của website, và đặt phần SQL trong module sở hữu bảng (`Website::ReportJoin`).
- Với dự án gộp 8 source: nếu các database cũ đã cùng một MySQL server, JOIN xuyên database là cách chuyển đổi nhanh nhất, nhưng phải ghi nhận là ràng buộc "cùng server" và là một dạng nợ kỹ thuật.

## 9. File liên quan

- `engines/website/app/queries/website/report_join.rb`, `engines/website/app/services/website/site_service.rb`
- `engines/report/app/models/report/detail.rb`, `engines/report/app/controllers/report/reports_controller.rb`
- `config/database.yml`, `db/seeds.rb`, `test/integration/api_flow_test.rb`
