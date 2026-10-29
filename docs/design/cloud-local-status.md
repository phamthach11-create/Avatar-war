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

## 2026-10-29 — Local: sửa cửa sổ Build và Accuracy Leonidas
- Người dùng chốt Accuracy100%, Evasion0% cho Leonidas. Demo local đã áp dụng cho cả hai build và cả hai đội; đây là sửa thiết kế được chốt sau workbook, thay cho B25=0. Workbook chưa được sửa trong lần này.
- Build dialog đã chuyển sang nội dung cuộn giới hạn theo viewport, kiểm tra hiển thị đủ mục9. Log phân biệt MISS với sát thương0.
- Kiểm tra sau sửa Accuracy: 8.196 checks qua; đánh thường gây HP damage ở cả bốn Leonidas; 6 trận seeded kết thúc Turn72–79.
- Mã/asset demo vẫn chỉ local, chưa upload qua PR; nhật ký trên main thông báo thay đổi cho Cloud. Cần phản ánh Accuracy100/Evasion0 vào lần sửa workbook tiếp theo.

## 2026-10-29 — Local: tùy chọn xuất log trận test
- Đã thêm nút Xuất log vào demo local: chọn nơi lưu và JSON hoặc TXT; dùng được giữa trận sau khi hết playback hoặc sau kết quả trận.
- Log có nguồn thiết kế, user corrections, build, seed/first team, Skills mode, engine/config hashes, từng lượt/hành động/impact, HP/MP/AP, cooldown, status, Stun và trạng thái đầu/cuối. JSON dùng delta unit snapshots để giảm lặp; có hướng dẫn tái dựng state. TXT đọc trực tiếp.
- Chặn xuất lúc animation chưa xong; mở hộp lưu dừng Auto; Restart đổi match ID và hủy hộp lưu cũ. Không tự ghi log nếu người dùng chưa chọn xuất.
- Module local: src/combat/battle_log.gd, src/ui/main.gd, tests/simulation/test_battle_log.gd, docs/design/log-export.md.
- Kiểm tra trên project chính: 1.150 checks qua; JSON/TXT trận60 lượt, 1.114 impacts; khôi phục đúng state cuối từ JSON, xuất trận0lượt/đang chạy/đã xong, stale/busy guard, Auto pause. Đã kiểm tra ảnh toolbar và hộp lưu.
- Trạng thái đồng bộ: mã demo/asset/test vẫn ở local, CHƯA upload qua PR. Nhật ký này chỉ thông báo tiến độ; không chứng minh GitHub đã có tính năng chạy được.

## 2026-10-29 — Kế hoạch nâng cấp đồ họa đã được người dùng chốt
- Quyết định: người dùng duyệt lộ trình sáu giai đoạn và yêu cầu lưu trên GitHub làm chuẩn cho các phiên tiếp theo.
- Tài liệu chính: [graphics-roadmap.md](graphics-roadmap.md); README và AGENTS có liên kết/điểm đọc.
- Phạm vi: fantasy Hàn Quốc, tỷ lệ trưởng thành, không chibi, chiến đấu2D 9vs9 đẹp và dễ đọc. Giữ cơ chế/build đã chốt.
- Thứ tự: định hướng → cảnh mẫu Napoleon → environment → sáu nhân vật/animation → hiệu ứng skill → polish/tối ưu.
- Trạng thái: mới chốt kế hoạch; chưa tạo hoặc duyệt bộ asset mới. Giai đoạn tiếp theo là1. Baseline demo local vẫn cần nhập mã/asset/tests qua PR trước tích hợp.
- Kiểm tra: đối chiếu nội dung với kế hoạch người dùng đã duyệt, kiểm tra đường dẫn tài liệu và giữ các mục lịch sử. Không thay gameplay hoặc workbook; không cần chạy kiểm thử game cho thay đổi tài liệu.
- Nhánh tài liệu đã chốt được hợp nhất vào main theo yêu cầu lưu kế hoạch đã duyệt; đối chiếu lịch sử PR/commit của tài liệu để xác nhận trạng thái thực tế.

## Các lần tiếp theo
Thêm mục mới theo mẫu trong quy trình, cập nhật khoảng cách còn lại và liên kết pull request. Không biến kế hoạch thành kết quả đã hoàn thành.
