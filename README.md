# Avatar War

Game chiến thuật theo lượt với đội hình 3×3, gồm một main và tám avatar.

## Mô phỏng thiết kế bằng Python

Bộ mô phỏng dùng lại nằm trong [simulation/](simulation/README.md): dữ liệu nhân vật,
node passive, build và cấu hình trận tách khỏi code. Chạy ba cặp Robin 1vs1:

```sh
python -m pip install -r simulation/requirements.txt
python -m simulation run robin_duels
```

Mặc định 1.000 trận/cặp, chia đều bên đi trước; xuất Excel và log có seed.
Đọc hướng dẫn trong thư mục này trước các lần mô phỏng tiếp theo. Mã Bluetooth 9vs9
cũ được giữ riêng với snapshot lịch sử; engine Godot chưa đồng bộ tự động với Python.

## Demo Godot 9vs9

Mở `project.godot` bằng Godot **4.7.2 Standard**, import asset rồi nhấn **F5**.
Scene mặc định: `src/ui/requested_9v9.tscn`; hai đội cùng build, Leonidas main slot5.
Có Auto, Next turn, Restart, Build và Export log; cấu hình ở
`data/gameplay/requested_9v9.json`. Không cần Python, Blender hoặc plugin để chơi demo.

Xem [hướng dẫn checkout và kiểm tra](docs/design/godot-9v9-checkout.md) và
[build, nguồn thiết kế, giới hạn](docs/design/requested-9v9-2026-10-31.md).
Các scene Dummy/mixed và preview đồ họa cũ vẫn giữ để hồi quy; đây là bản combat2D,
chưa tích hợp model Tripo hay trận3D.

## AI và tài nguyên đồ họa

Godot không mặc định có AI tạo hình ảnh hoặc mô hình. Có thể tạo tài nguyên ở
công cụ bên ngoài rồi nhập vào Godot; không cần plugin để chạy demo này.

- Hình ảnh 2D: đặt tài nguyên trong `assets/art/`, sau đó dùng trong scene.
- Mô hình 3D từ Tripo: ưu tiên định dạng GLB/glTF được Godot hỗ trợ. Cần kiểm tra
  mô hình, rig và animation thực tế trước khi tích hợp. Bản demo hiện là 2D;
  muốn dùng model 3D cần thêm scene 3D, còn module luật combat có thể tái sử dụng.
- Âm thanh: đặt trong `assets/audio/` và gắn vào sự kiện giao diện/animation.

Hướng dẫn chi tiết: [Godot và tài nguyên AI](docs/design/godot-quickstart.md).

## Kiểm tra tự động

Trong thư mục repository, với `godot` có trong PATH:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/simulation/test_dummy_duel.gd
godot --headless --path . --script res://tests/simulation/test_main_scene.gd
```

Trong môi trường cloud hạn chế ghi ngoài workspace, đặt `XDG_DATA_HOME`,
`XDG_CONFIG_HOME` và `XDG_CACHE_HOME` vào các thư mục có thể ghi trong `/tmp`
trước khi chạy Godot. Không cần thay đổi thiết lập này trên Windows thông thường.

Kiểm tra đã thực hiện: luật combat và scene trong chế độ headless. Chưa kiểm tra
hiển thị bằng cửa sổ đồ họa trên Windows hoặc phát hành bản web/desktop.

## Cấu trúc repository

```text
Avatar-war/
├── project.godot         # Dự án Godot; Import file này rồi nhấn F5
├── README.md
├── docs/
│   ├── design/          # Ý tưởng, vai trò nhân vật, kế hoạch phát triển
│   ├── rules/           # Luật combat, lượt, AP, chọn mục tiêu và hiệu ứng
│   └── balance/         # Công thức, Balanced Dummy, CP và kết quả phân tích
├── data/
│   ├── excel/           # File thiết kế Excel gốc
│   └── gameplay/        # Dữ liệu nhân vật, skill và item cho game trong tương lai
├── src/
│   ├── combat/          # Luồng trận đấu, action slot, AP, damage và trigger
│   ├── characters/      # Trạng thái nhân vật và tính stat
│   ├── skills/          # Hành vi và xử lý kỹ năng
│   ├── items/           # Trang bị và các đóng góp stat
│   ├── ai/              # Quyết định hành động của đối thủ hoặc bot
│   └── ui/              # Giao diện và trình bày trận đấu
├── assets/
│   ├── art/             # Hình ảnh, sprite, model và animation
│   └── audio/           # Nhạc và hiệu ứng âm thanh
├── tests/
│   ├── unit/            # Kiểm tra từng công thức và quy tắc
│   └── simulation/      # Kịch bản và kiểm tra mô phỏng combat
├── tools/               # Công cụ chuyển đổi dữ liệu và hỗ trợ thiết kế
└── config/              # Cấu hình không chứa bí mật
```

## Tài liệu thiết kế hiện tại

File gốc nằm tại `data/excel/Thiết kế game.xlsx`. Mã demo nằm trong `src/combat/`
và `src/ui/`; các thư mục dự phòng khác vẫn dùng `.gitkeep`.

Khi thêm nội dung, tài liệu diễn giải đặt trong `docs/`, dữ liệu game đọc được
đặt trong `data/gameplay/`, còn hành vi và thuật toán đặt trong `src/`.

Engine hiện tại là Godot, ngôn ngữ GDScript. Git không lưu thư mục trống nên các
thư mục dự phòng dùng `.gitkeep`; có thể bỏ file này khi có nội dung thật.

## Làm việc giữa Cloud và Local

Đọc [quy trình bàn giao](docs/design/cloud-local-workflow.md) và [nhật ký trạng thái](docs/design/cloud-local-status.md) trước khi tiếp tục. GitHub là nguồn chuẩn; kiểm tra cả pull request đang mở để biết thay đổi chưa hợp nhất.

## Kế hoạch đồ họa đã chốt

Theo [lộ trình nâng cấp đồ họa 2D](docs/design/graphics-roadmap.md), đã được người dùng duyệt ngày 29/10/2026. Thứ tự: định hướng → cảnh mẫu Napoleon → môi trường → sáu nhân vật/animation → hiệu ứng skill → polish/tối ưu. Tiến độ và điều kiện nghiệm thu nằm trong tài liệu; kế hoạch được duyệt không có nghĩa asset mới đã hoàn thành.


## Tiếp tục dự án với ngữ cảnh gọn

Bắt đầu từ [chỉ mục dự án](docs/design/project-index.md) và [skill Avatar War](.agents/skills/avatar-war-workflow/SKILL.md). Chọn đúng backend và phạm vi trước khi đọc tài liệu chi tiết. Skill trong repo là bản dùng chung; đường dẫn máy và cách cài cá nhân giữ ở local. Xem chỉ mục để phân biệt code đã commit với các bản demo còn chỉ trên máy.
