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

## Demo Godot đầu tiên

Repository hiện có bản demo **2D hai Balanced Dummy**, kiểm tra cùng kịch bản
đánh thường trong sheet `Combat demo`. Phiên bản đã kiểm tra: **Godot 4.6.3 Standard**,
dùng GDScript, không cần bản .NET hay plugin.

Để mở trên Windows:

1. Tải Godot Standard từ https://godotengine.org/download/windows/ và giải nén.
2. Tải repository về máy. Trong Godot Project Manager, chọn **Import**, chọn
   file `project.godot` ở thư mục gốc repository rồi chọn **Import & Edit**.
3. Nhấn **F5** để chạy toàn bộ dự án.

Nếu chỉ chơi bản xuất chạy riêng hoặc bản web trong tương lai, người chơi không
cần Godot editor. Repository hiện có source project, chưa có bản export đóng gói.

Điều khiển:

- **Next turn:** thực hiện một lượt đội.
- **Auto: OFF / ON:** bật hoặc tắt tự chạy.
- **Restart:** khôi phục toàn bộ trận và dừng tự chạy.
- **Initiative tie winner:** chọn A/B cho trường hợp hòa AP; thay lựa chọn sẽ bắt đầu lại.

Hai bên có HP 20.000, ATK 2.000, DEF 1.000, APR 100, K 1.000 và SE 100%.
AP đầu trận là 0. Hồi AP trước khi cấp suất; mỗi đội chỉ có một nhân vật nên
chỉ nhận tối đa một suất, kể cả khi giới hạn lượt là 2/4/5. Tấn công luôn trúng,
không crit hoặc multi-hit. Mỗi hit gây 1.000 sát thương. Bên đi trước thắng ở
lượt toàn trận 39, sau 20 hit, còn 1.000 HP.

Demo này chưa triển khai phòng thủ, skill, đổi chỗ, chuyển suất, trigger hoặc
đội hình 3×3. Hai hình nhân vật được vẽ bằng code, chưa cần tài nguyên bên ngoài.

Luật nằm trong `src/combat/dummy_duel.gd`, dữ liệu trong
`data/gameplay/balanced_dummy.json`, scene chính trong `src/ui/main.tscn`.
Dữ liệu JSON là bản chụp kịch bản thiết kế; thay Excel chưa tự cập nhật JSON.

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
