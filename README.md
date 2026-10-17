# Avatar War

Game chiến thuật theo lượt với đội hình 3×3, gồm một main và tám avatar.

## Cấu trúc repository

```text
Avatar-war/
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

File gốc nằm tại `data/excel/Thiết kế game.xlsx`. Các thư mục còn lại mới là
khung tổ chức, chưa có nội dung thiết kế hoặc mã game được triển khai.

Khi thêm nội dung, tài liệu diễn giải đặt trong `docs/`, dữ liệu game đọc được
đặt trong `data/gameplay/`, còn hành vi và thuật toán đặt trong `src/`.

Chưa chọn ngôn ngữ lập trình hoặc game engine. Cấu trúc sẽ được điều chỉnh khi
chốt công nghệ. Git không lưu thư mục trống nên các thư mục dự phòng dùng file
`.gitkeep`; có thể bỏ file này khi thư mục đã có nội dung thật.
