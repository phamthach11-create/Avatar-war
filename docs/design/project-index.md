# Avatar War — chỉ mục công việc
Cập nhật 2026-11-01. Đọc phần liên quan và kiểm tra revision/file trước khi dùng; đây là chỉ mục, không thay luật hoặc kiểm thử.

## Nguồn và trạng thái
- Thiết kế chuẩn: main, `data/excel/Thiết kế game.xlsx`, cùng đính chính trực tiếp mới hơn của người dùng. Snapshot trận local gần nhất: blob `36876091de28fd6b889e2e32c7f57c4f2f59f37c`.
- Godot, Python và asset là các implementation/tài nguyên riêng. Không tự đồng bộ từ Excel hoặc từ chat khác.
- Nhánh `demo/godot-requested-9v9-2026-11-01` bổ sung code, scene, cấu hình, test và asset Godot; chờ review, chưa merge. Main chưa nhận implementation này.
- Xem `docs/design/godot-9v9-checkout.md` để chạy và kiểm tra từ checkout sạch.

## Chọn đúng phần
| Yêu cầu | Điểm vào |
|---|---|
| Chạy/đổi cấu hình trận Godot | Kiểm tra project và capability đang có; xem checkpoint combat bên dưới |
| Mô phỏng Python/thống kê | `simulation/README.md`, `simulation/AGENTS.md`, runner/importer/scenario tương ứng |
| Thay luật hoặc bàn giao | `docs/design/cloud-local-workflow.md`, các mục liên quan trong `cloud-local-status.md` |
| Đồ họa/nhân vật/animation | `docs/design/graphics-roadmap.md`, checkpoint 3D bên dưới; giữ combat |
| Quy trình tiết kiệm ngữ cảnh | `.agents/skills/avatar-war-workflow/SKILL.md` |

## Checkpoint combat Godot (PR, chưa merge)
Bản test gần nhất có hai đội cùng build, main Leonidas slot5; đội hình Bluetooth / Jean / Leonidas / Napoleon1 / main Leonidas / Leonardo1 / Napoleon2 / Leonardo2 / Robin.
Các điểm vào được ghi nhận ở bản local: `src/ui/requested_9v9.tscn`, `data/gameplay/requested_9v9.json`, `src/combat/requested_battle.gd` (mở rộng mixed battle), `docs/design/requested-9v9-2026-10-31.md`. Những file này có trong nhánh demo; CHƯA hợp nhất vào main.
Giới hạn được chốt: tối đa một Automaton mỗi loại/đội; không chiếm slot, không bị chọn, mất khi chủ chết. Chỉ Attack kế thừa theo skill; MHR/Accuracy nền100%, CHC/PEN/CDB nền0, node Automaton áp dụng. Grand Battery auto-cast đầu lượt đồng minh. Leonardo2 ưu tiên Mona Lisa khi đồng minh≤65%HP (AI policy); Robin ưu tiên normal.
Local báo cáo1742 checks cho scenario,8196 checks regression mixed và1150 checks log qua; không phải kết quả CI trên GitHub.
Chưa có bộ node catalog Godot tổng quát: chỉ các build/handler đã kiểm tra được xác nhận. Build hoặc kit mới cần kiểm tra gap trước, không chỉ sửa tên trong JSON.

## Checkpoint đồ họa
Người dùng đã chọn hướng3D và concept Bluetooth ngực trần/râu vàng/trang phục đỏ–navy. Các bản model/texture/rig Hunyuan và retarget tự làm chỉ ở local; chất lượng animation chưa được duyệt.
Nguồn người dùng mới chọn là Tripo với rig Mixamo. Đã hướng dẫn xuất FBX kèm texture; chưa xác minh file đã được nhận hoặc tích hợp. Không tiếp tục pipeline bị loại nếu không có yêu cầu mới.
Các đường dẫn máy và phần mềm cài đặt giữ ở cấu hình/chỉ mục local, không đưa vào bản dùng chung này.

## Cập nhật sau mỗi thay đổi
Ghi ngắn: nguồn thiết kế → file/scene → thay đổi → kiểm tra → hạn chế → bước tiếp. Giữ trạng thái local / push / merge chính xác. Thay chỉ mục khi điểm vào/capability đổi; lịch sử chi tiết để trong nhật ký, không chép toàn bộ vào đây.
