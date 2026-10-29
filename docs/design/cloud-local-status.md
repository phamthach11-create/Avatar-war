# Nhật ký bàn giao Cloud và Local

Đọc cùng [quy trình làm việc](cloud-local-workflow.md). Khi cập nhật trạng thái, kiểm tra commit, diff và pull request thực tế.

## 2026-10-29 — Local: thiết lập quy trình
- Trạng thái: đã hợp nhất vào main ngày 2026-10-29. [Pull request thiết lập quy trình Cloud–Local](https://github.com/phamthach11-create/Avatar-war/pull/1); merge commit 7c9938b561443c7b5bd235015e57e0751c4baaf8. Không cập nhật mã gameplay trong lần này.
- Nguồn: main tại dc81030fb999116aa50288ea2a388c16c7aa642a; workbook data/excel/Thiết kế game.xlsx, blob 36876091de28fd6b889e2e32c7f57c4f2f59f37c.
- Thay đổi: thêm quy trình và nhật ký bàn giao; đặt liên kết đọc từ README và AGENTS.
- Kiểm tra: đối chiếu workbook trên GitHub với snapshot demo trước; đây là tài liệu, không chạy kiểm thử gameplay cho thay đổi này.
- Trạng thái Godot: demo 9vs9 có map, sprite animation, skill và Stun đã chạy trên máy trong phiên trước, nhưng mã và asset của bản này CHƯA được đưa lên repo. Source Godot hiện có trên main vẫn là demo cũ.
- Khoảng cách đã phát hiện: bản thiết kế mới đổi cooldown sang cuối mỗi Global Turn cho cả hai đội từ Turn 1; Balanced Dummy đổi HP/MP, phân bổ SP, active/passive; Stun duration 3 và tối đa 1 Stun Count mỗi mục tiêu mỗi Global Turn. Demo local chưa áp dụng các thay đổi mới này.
- Python: repo có runner, dữ liệu và kiểm thử riêng trong simulation/. Không coi kết quả của Python là xác nhận Godot đã đồng bộ.
- Bước tiếp theo: sao lưu demo local, nhập mã/asset qua nhánh và pull request riêng, ghi rõ đây là snapshot lịch sử trước khi nâng gameplay theo workbook mới. Chưa thực hiện bước này.
- Xác nhận: GitHub trả kết quả hợp nhất thành công; quy trình, nhật ký và liên kết README/AGENTS đã có trên main. Người dùng yêu cầu cập nhật xác nhận này vào nhật ký sau khi hợp nhất.
- Lần kiểm tra tiếp theo: đọc nhật ký trên main và các pull request đang mở; đối chiếu diff từ mốc hợp nhất nêu trên.

## 2026-10-29 — Local: demo đội hình hỗn hợp 9vs9
- Trạng thái: đã triển khai và mở trong Godot trên máy; mã, asset và test của demo mới CHƯA được upload/hợp nhất vào GitHub. Mục này chỉ báo trạng thái, không phải bằng chứng mã đã đồng bộ.
- Nguồn: workbook blob 36876091de28fd6b889e2e32c7f57c4f2f59f37c tại commit thiết kế dc81030fb999116aa50288ea2a388c16c7aa642a.
- Đội hình đối xứng: front Joan tank / Leonidas tank / Bluetooth; middle Joan support / Leonidas Striker / Leonardo; rear Napoleon / Robin / Napoleon. Main bốc ngẫu nhiên một lần là Leonidas Striker, ô A5/B5. Cả hai đội dùng cùng build.
- Người dùng cho phép Local tự chọn build và chốt thứ tự đầu lượt: hồi sinh, passive auto-cast, AP, slots; cuối lượt: DOT, expiration, cooldown.
- Module local mới: src/combat/mixed_battle.gd, data/gameplay/mixed_9v9.json; mở rộng UI và shared sprite placeholder, tên/class tint, cannon overlay, projectile và heal popup. Giữ Dummy combat và fixture cũ.
- Đã ghép các skill được chọn của cả sáu class; hai Napoleon dùng Emperor/Imperial Decree, không chọn Grand Battery vì trigger chưa được thiết kế rõ. Không triển khai các nhánh không chọn, summon hoặc spirit revival.
- Kiểm tra: 6 trận seeded chia đều hai bên đi trước kết thúc ở Turn58–71, 6.896 checks qua; scene lifecycle và Restart qua; kiểm tra ảnh render và mở runtime không có script/runtime error. Có cảnh báo script không chặn chạy.
- Lưu ý nguồn: Soldier Accuracy B25=0 được giữ nguyên, không tự nâng lên 100%; Mona Lisa dùng cached SL5 heal4135 vì chuỗi công thức có 50%%.
- Bàn giao local chi tiết: docs/design/mixed-9v9-current.md. Cần nhập mã/asset/tests và cập nhật thiết kế đã chốt vào PR riêng trước khi máy khác có thể tái tạo demo chỉ từ repo. Python vẫn độc lập.

## Các lần tiếp theo
Thêm mục mới theo mẫu trong quy trình, cập nhật khoảng cách còn lại và liên kết pull request. Không biến kế hoạch thành kết quả đã hoàn thành.
