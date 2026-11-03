# Excel → source → runtime: quy trình chung Avatar War

Excel là nguồn ý tưởng/thiết kế; repo lưu bản triển khai có phiên bản.
Một lần tạo demo tái sử dụng engine + scenario + asset, không tái tạo trận từ chat.

## Các thư mục và trách nhiệm

| Thành phần | Nơi lưu | Cách cập nhật |
|---|---|---|
| Thiết kế chuẩn | `data/excel/Thiết kế game.xlsx` | Cloud/người dùng sửa và lưu Excel đã tính lại |
| Bộ đồng bộ | `tools/design_sync/` | Đọc cấu trúc, so thay đổi, kiểm tra và xuất runtime |
| Snapshot đã áp dụng | `design/sync/snapshots/`, `accepted.json` | Có hash Excel và code, không phải chỉ ngày cập nhật |
| Scenario/build/AI | `design/scenarios/requested_9v9.template.json` | Chỉ chọn đội hình, node, cấp skill; không viết engine mới |
| Kết quả đang chờ | `design/sync/pending/` | Report + classes/rules/tables/scenarios, không commit file tạm |
| Logic gameplay dùng chung | `src/combat/` | Sửa handler khi mechanic/formula thay đổi; RefCounted, độc lập sprite |
| Cổng nạp dữ liệu | `src/design/runtime_catalog.gd` | Kiểm tra đúng Excel, bundle và phiên bản engine |
| Dữ liệu game đã xuất | `data/runtime/bundles/`, `active.json` | Bundle bất biến, pointer đổi sau khi xuất thành công |
| Presentation hiện tại | `src/ui/`, `assets/` | Vẽ sprite/animation và phát các event combat |
| Presentation 3D tương lai | Scene/model/rig riêng | Dùng cùng scenario/engine/event; adapter 3D chưa được xây trong PR này |

Không chuyển Python simulator thành engine Godot. Hai backend có receipt và kiểm thử riêng.
Không nhập các model/ảnh thử nghiệm local vào PR đồng bộ này.

## Lệnh dùng hằng ngày

```sh
python -m pip install -r tools/design_sync/requirements.txt
python -m tools.design_sync plan
python -m tools.design_sync sync --recalculated
python -m tools.design_sync check
```

`plan` chỉ so sánh và tạo candidate/report. `sync` chỉ xuất runtime khi tất cả thay đổi
được nhận diện là dữ liệu đã có ánh xạ. `--recalculated` là lời xác nhận của người chạy
rằng đã mở, tính lại và lưu workbook bằng Excel; công cụ KHÔNG tự tính công thức Excel.
Không dùng cờ này cho workbook chưa tính lại. Ô công thức thiếu cache sẽ bị chặn.
Chỉ sync từ workbook trong repo; có thể dùng `plan --workbook ...` để kiểm tra file ngoài.

Ví dụ quy trình thực tế:

1. Người dùng/cloud cập nhật workbook trong repo và ghi ý định thay đổi.
2. Local lấy commit mới, chạy `plan`; chỉ đọc những ô/sheet được báo đổi.
3. Chỉ số cơ bản tổng B9:B27, APR nhân vật C21, chi phí AP/MP/CD đã hỗ trợ:
   tính lại Excel, chạy sync; roster/build và code dùng lại.
4. Mô tả mechanic, node, status, target/area, formula, hiệu ứng skill hoặc dữ liệu
   không có ánh xạ: `blocked`. Agent sửa đúng handler/tài nguyên liên quan, không
   đổi engine toàn bộ, không thay skill bằng một skill có sẵn.
5. Chạy kiểm thử phần đổi và hồi quy cần thiết; lập implementation receipt cho
   chính xác workbook + change set + code + bằng chứng kiểm thử.
6. Xuất bundle, kiểm tra Godot, cập nhật nhật ký, push PR. Chỉ merge khi người dùng duyệt.
7. Lần tạo demo tiếp theo chạy `check`, nạp `active.json`, chọn scenario và asset.

`plan`/`sync` trả exit2 khi bị chặn. Bundle đang active không bị ghi đè nếu đồng bộ lỗi.
Demo requested sẽ hiện DESIGN SYNC REQUIRED thay vì chạy im lặng với luật cũ.
Các scene baseline lịch sử còn giữ để kiểm thử snapshot cũ, không chứng minh đã sync.

## Khi thay đổi mechanic/formula

Không có bộ chuyển mô tả tiếng tự nhiên thành code tự động đáng tin cậy.
Agent nhận báo cáo diff, đối chiếu ý nghĩa, sửa handler, kiểm thử rồi mới đánh dấu áp dụng.
Công thức Excel chỉ được đọc như dữ liệu, không `eval` và không tự suy ra
cách scale mọi effect theo Skill Level. Formula/effect cache đổi cần review.

Sau phần triển khai, receipt JSON cho `accept --receipt path.json` phải chứa:

```json
{
  "source_sha256": "SHA256 workbook hiện tại",
  "reviewed_change_sha256": "SHA256 encoded(differences(accepted_snapshot, current_snapshot))",
  "engine_files": {"src/combat/handler.gd": "SHA256 từng file; lấy engine_hashes(root)"},
  "implementation_notes": "Luật đổi, handler, test và quyết định xử lý từng nhóm diff",
  "tests": [{"command": "lệnh thực tế đã chạy", "exit_code": 0,
             "log": "artifacts/test.log", "sha256": "SHA256 log sau khi chạy"}]
}
```

Receipt là checkpoint kỹ thuật có người/agent chịu trách nhiệm, không tự chứng minh
ý nghĩa mechanic đã đúng. Reviewer phải đối chiếu notes/diff/test. Không tạo receipt
chỉ để bỏ qua cổng đồng bộ. Evidence log để local/artifact CI, tránh push log cá nhân.
Sau `accept`, vẫn cần kiểm tra game rồi PR; không có cơ chế tự merge/publish.

## Tự động trên GitHub

Workflow `design-sync.yml` chạy unit test, plan và freshness check khi Excel,
runtime hoặc combat code đổi. Nó báo lỗi lệch phiên bản; không tự commit hay merge.
Excel thay đổi chưa triển khai → freshness đỏ là chủ ý. Mở artifact/report local để
agent cập nhật code, không chỉnh hash để làm xanh. Máy local vẫn cần lấy repo mới;
không có watcher ngầm kết nối một file OneDrive bất kỳ với GitHub.

## Trạng thái ban đầu và giới hạn

Accepted baseline giữ đúng snapshot demo cũ (workbook blob
`36876091de28fd6b889e2e32c7f57c4f2f59f37c`), không nhận vơ workbook mới đã áp dụng.
Base repo của PR: `c4648b7c6503cfabf46236e00890df4d5f001de4`, có cập nhật HP decay và area.
Lần chạy ban đầu thấy359 ô đổi,335 ô cần review. Chưa triển khai các luật mới đó trong
PR hạ tầng này; scene requested được chặn có thông báo khi dùng workbook mới.
CI freshness dự kiến chưa qua cho đến khi các thay đổi được triển khai/receipt hợp lệ.

Ánh xạ số v1 giới hạn ở6 class đã có và requested_9v9. Soldier Accuracy100/Evasion0,
Healer Leonardo SP+7 và các build/user corrections cũ vẫn được ghi rõ trong template.
Node catalog, bảng kỹ năng và công thức chung chưa được chuyển hết khỏi hardcode.
Các nhóm extraction classes/rules/tables phục vụ routing; xuất JSON chưa đồng nghĩa
engine đã có handler cho mọi dòng Excel. Bổ sung từng handler qua chính pipeline này.

Tests: `python -m unittest discover -s tests/design_sync -v`.
