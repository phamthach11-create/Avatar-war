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

## 2026-10-29 — Đồ họa giai đoạn1: concept vòng1
- Đã tạo và hiển thị ba bảng định hướng A Stone Citadel / B Ashen Fortress / C Arcane Bastion bằng công cụ tạo ảnh tích hợp; gồm mẫu Napoleon và minh họa trận.
- PNG và prompt lưu local trong outputs/graphics-direction-v1, chưa upload binary lên GitHub. Chưa sửa gameplay hoặc asset Godot.
- Trạng thái: chờ người dùng chọn hướng; chưa hoàn thành giai đoạn1. Các ảnh chỉ dùng chọn style, không phải sprite hoặc screenshot đã triển khai. B có vài nhân vật thiếu/che; cần dựng lại đúng18slot ở bước tích hợp.
- Đã cập nhật bảng tiến độ trong graphics-roadmap.md. Tiếp theo: chốt hướng và tinh chỉnh, chưa sản xuất hàng loạt.

## 2026-10-29 — Napoleon anime/manga — bốn mẫu
- Người dùng nghiêng về map A thành đá sáng; nhân vật concept trước quá thực. Yêu cầu thử phong cách gaming anime/manga, nêu Genshin Impact làm tham chiếu, không pixel/chibi.
- Đã tạo và hiển thị bốn mẫu Napoleon toàn thân: 1 anime cel-shaded, 2 fantasy anime sắc nét, 3 manga tô màu, 4 anime painterly. Cùng trang phục sĩ quan/pháo và tư thế gần tương tự để so cách vẽ.
- PNG và đầy đủ prompt lưu local trong outputs/napoleon-style-v1 bằng công cụ tạo ảnh tích hợp; binary chưa upload repo. Không dùng tài sản nhân vật của game tham chiếu.
- Chưa chọn mẫu nhân vật; chờ người dùng duyệt số1–4 hoặc yêu cầu chỉnh. Chưa tạo asset animation hoặc sửa Godot.

## 2026-10-29 — Đã chốt Napoleon mẫu1 anime cel-shaded
- Người dùng chọn mẫu số1 trong bốn mẫu Napoleon. Dùng mẫu này làm tham chiếu phong cách nhân vật: anime cel-shaded, người trưởng thành, mảng màu sạch; không pixel/chibi/photorealistic.
- Kết hợp hướng map A thành đá sáng. Đã ghi quyết định vào graphics-roadmap.md.
- Concept được chọn lưu local: outputs/napoleon-style-v1/01-anime-cel.png, cùng prompts.md. Binary chưa upload GitHub; lựa chọn và kế hoạch đã ghi trên main.
- Tiếp theo: ghép concept theo đúng tỷ lệ sân để kiểm chứng tổng thể, rồi dựng cảnh mẫu Napoleon. Chưa có sprite/rig/animation mới và chưa thay asset Godot trong lần chốt này.

## 2026-10-29 — Đã mở scene ghép tĩnh Napoleon trên sân đá sáng
- Giai đoạn1: tạo RGBA Napoleon mẫu1 + môi trường sạch từ mapA bằng imagegen, ghép trong scene Godot riêng.
- 18vị trí / 4Napoleon mới / 14nhân vật cũ làm mốc tỷ lệ, main A5/B5. Có slider80–125%, chế độ chỉ Napoleon, xem gần và nút về trận test.
- Đã kiểm tra alpha, render ảnh thực trong Godot và chỉnh khoảng cách hàng/label sau kiểm tra. Test18slot/4Napoleon, solo, scale125%, closeup qua; đã mở preview trên máy.
- Scene/asset local: src/ui/art_direction_preview.gd/.tscn, assets/art_direction/v1/*.png, docs/design/art-stage-preview-v1.md. Screenshot và prompt local: outputs/napoleon-stage-preview-v1.
- Chưa thay combat hoặc thêm animation bắn. Chờ duyệt tỷ lệ/phối cảnh để sang cảnh mẫu Napoleon. Scene/PNG vẫn chưa upload binary/source lên repo; mục này chỉ báo trạng thái.

## Các lần tiếp theo
Thêm mục mới theo mẫu trong quy trình, cập nhật khoảng cách còn lại và liên kết pull request. Không biến kế hoạch thành kết quả đã hoàn thành.
