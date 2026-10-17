# Bắt đầu với Godot

## Mở dự án lần đầu

Dùng **Godot 4.6.3 Standard**; không cần .NET. Trong Project Manager chọn
**Import**, tìm `project.godot` ở gốc repository và mở editor. Nhấn **F5** để chạy.
Lần đầu Godot tự tạo `.godot/` và nhập tài nguyên; thư mục này không đưa vào Git.

Scene chính là `src/ui/main.tscn`. Giao diện được dựng bằng GDScript trong
`main.gd`; cây node con xuất hiện khi chạy, không được lưu sẵn trong scene.
Trong editor có thể xem cây node đang chạy bằng tab **Remote** khi game mở.

## Chơi thử

1. Bấm **Next turn**: A hồi 100 AP, nhận một suất và đánh B mất 1.000 HP.
2. Bấm tiếp: B hồi AP và phản công.
3. Bấm **Auto** để tự chạy đến kết thúc; bấm lại để dừng.
4. Bấm **Restart** để làm lại. Chọn **Team B** ở ô initiative để thử bên kia đi trước.

Nhật ký mô tả AP trước hồi, lượng hồi, chi phí và AP sau hành động. Trận mặc định
kết thúc ở lượt toàn trận 39. Đây là 20 lượt tấn công riêng của bên thắng;
bên còn lại chỉ kịp đánh 19 lần.

Chỉ tiêu này kiểm tra công thức và thứ tự lượt; không chứng minh rằng lợi thế
đi trước hoặc bảng CP đã cân bằng trong một trận đội hình đầy đủ.

## Tổ chức mã

- `src/combat/dummy_duel.gd`: trạng thái trận, AP, cấp suất, sát thương và kết thúc.
- `src/ui/main.gd`: thanh HP/AP, nút, timer, nhật ký và kết nối với module combat.
- `src/ui/dummy_view.gd`: hình nhân vật tạm và animation tấn công/nhận sát thương.
- `data/gameplay/balanced_dummy.json`: cấu hình kịch bản; là dữ liệu có cấu trúc,
  không phải code. Cần đồng bộ thủ công khi thiết kế Excel thay đổi.
- `tests/simulation/`: bài kiểm tra combat và tương tác scene.

Để thử AP Recovery khác, có thể đổi `base_ap_recovery` trong JSON rồi khởi động
lại. Các dòng mô tả benchmark trong UI vẫn nói về bộ thông số chuẩn, không phải
kết quả dự báo cho mọi bộ stat. Những stat phần trăm khác chưa được mô phỏng.

## Dùng AI tạo tài nguyên

Không cần AI plugin để dựng hoặc chạy dự án. AI có thể hỗ trợ theo hai hướng:

1. Viết hoặc sửa GDScript và scene trong repository, rồi kiểm tra bằng Godot.
2. Tạo ảnh, mô hình hoặc âm thanh ở công cụ bên ngoài rồi nhập tài nguyên vào dự án.

Nếu dùng Tripo, xuất một model thử ở định dạng GLB/glTF và kiểm tra cấu trúc,
vật liệu, số polygon, rig và animation trong Godot. Không mặc định rằng model
AI sinh ra đã có chuyển động chiến đấu dùng được ngay.

Demo hiện là 2D. Dùng model 3D cần một lớp scene 3D với camera, ánh sáng và node
nhân vật; module combat không cần phụ thuộc vào các node đó. Các định dạng, giá
dịch vụ và quyền sử dụng của công cụ AI cần kiểm tra theo tài nguyên/gói thực tế.

## Trạng thái kiểm chứng

Đã kiểm tra bằng **Godot 4.6.3 headless**:

- Hai đội lần lượt đi trước đều khớp kết quả Excel.
- Thiếu AP thì bỏ lượt, AP tích lũy và chỉ đội đến lượt được hồi.
- 200 AP Recovery không tự tạo thêm suất cho một nhân vật.
- Hết HP thì dừng ngay; không chạy thêm hành động sau khi trận kết thúc.
- Scene mở được, nút tiến lượt/reset hoạt động, tự chạy hoạt động và dừng khi kết thúc.

Chưa có kiểm chứng bằng cửa sổ đồ họa trên máy Windows của người dùng.
Chưa xuất bản build web hoặc desktop.
