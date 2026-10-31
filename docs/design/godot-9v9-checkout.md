# Godot 9vs9 — checkout và kiểm tra

Nhánh đề xuất: `demo/godot-requested-9v9-2026-11-01`, chưa merge.
Godot **4.7.2 Standard**, GL Compatibility; không cần plugin/Python cho runtime.

```sh
git clone --branch demo/godot-requested-9v9-2026-11-01 https://github.com/phamthach11-create/Avatar-war.git
cd Avatar-war
godot --headless --editor --import
godot --path .
```

Hoặc Import `project.godot` trong Project Manager và F5. Scene mặc định
`src/ui/requested_9v9.tscn`. Nhấn Auto để chạy, Build để xem cả9 nhân vật,
Export log để lưu snapshot của trận. Hai đội cùng build, main Leonidas slot5.

## Kiểm tra

Sau import, chạy từng lệnh (UI cần cửa sổ thật để kiểm tra bố cục):

```sh
godot --headless --path . --script res://tests/simulation/test_requested_battle.gd
godot --headless --path . --script res://tests/simulation/test_mixed_battle.gd
godot --headless --path . --script res://tests/simulation/test_battle_log.gd
godot --path . --script res://tests/simulation/test_requested_ui.gd
godot --path . --script res://tests/simulation/test_build_dialog.gd
```

Test UI và log ghi vào `artifacts/` đã ignore; test scenario
sinh `tests/requested-match.json` đã ignore. `.godot/` tự tạo khi import,
không commit. Giữ `.uid` và `.import` là metadata nguồn; không chứa đường dẫn máy.
Bản local ban đầu được giữ nguyên, chỉ bản đóng gói sửa đường dẫn test cho portable.

## Phạm vi và nguồn

Snapshot thiết kế được cấu hình ghi lại: workbook blob
`36876091de28fd6b889e2e32c7f57c4f2f59f37c`, source commit
`a2afe350854e6bfb31933d2ae93c02b67cd261ab`; không nhập lại workbook trong lần đóng gói.
Các đính chính summon/AI của người dùng ghi trong requested-9v9-2026-10-31.md.
Python simulation không đổi. Chỉ build/handler đã kiểm tra được hỗ trợ;
không có node catalog Godot tổng quát. Sprite/map hiện tại là placeholder2D.

Asset PNG (nhân vật/map/preview) được tạo trong các phiên làm dự án;
âm thanh WAV tổng hợp. Preview Napoleon lịch sử đi kèm phụ thuộc để scene
không bị thiếu asset, chưa phải đồ họa được duyệt cho bản3D. Không kèm model
Tripo, công cụ cài đặt, source Blender, log trận cá nhân hay ảnh test tạm.
