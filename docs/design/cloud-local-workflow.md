# Quy trình bàn giao Cloud và Local

## Nguồn chuẩn
GitHub là nguồn chuẩn. Thiết kế được chốt trên nhánh chính là cơ sở triển khai; nội dung chỉ nằm trong chat hoặc trên máy chưa phải trạng thái chung. Khi thiết kế chưa rõ hoặc mâu thuẫn nội bộ, hỏi người dùng trước khi triển khai. Không tự sửa thiết kế để hợp với code.

## Phân công
- Cloud: trao đổi và chốt thiết kế cùng người dùng, cập nhật workbook và ghi thay đổi. Có thể duy trì bộ mô phỏng Python theo yêu cầu.
- Local: lấy thiết kế đã chốt, triển khai và chạy Godot, quản lý asset và kiểm tra trải nghiệm trên máy.
- Godot và Python là hai implementation riêng; cập nhật một bên không chứng minh bên còn lại đã đồng bộ.

## Trước mỗi phiên
Đọc tài liệu này và [nhật ký bàn giao](cloud-local-status.md). Kiểm tra nhánh chính, các pull request đang mở và commit mới từ mốc phiên trước. Đối chiếu mã và workbook thực tế; nhật ký là chỉ mục, không thay thế diff. Không ghi đè thay đổi của bên khác hoặc kéo đè thư mục ZIP/local chưa sao lưu.

## Khi thay đổi
1. Ghi nhận commit nguồn và phiên bản workbook (commit/blob) dùng làm cơ sở.
2. Làm trên nhánh riêng. Tách cập nhật thiết kế, Python và Godot thành phạm vi dễ review.
3. Kiểm tra phần bị ảnh hưởng; ghi rõ kiểm tra nào đã chạy, kết quả và giới hạn.
4. Cập nhật nhật ký trong cùng pull request: thay đổi gì, file/module liên quan, thiết kế nào đã áp dụng, phần nào còn thiếu, bước tiếp theo.
5. Tạo pull request có mô tả cụ thể. Theo chỉ thị người dùng ngày 2026-11-01, agent tự hợp nhất sau khi rà soát diff và hoàn thành các kiểm tra phù hợp đối với thay đổi đã được người dùng yêu cầu rõ; không hỏi lại chỉ để merge. Không bỏ qua kiểm tra bắt buộc hoặc branch protection. Nếu kiểm tra thất bại, có xung đột, phạm vi chưa được cho phép hoặc còn quyết định thiết kế chưa rõ thì xử lý hoặc hỏi đúng điểm còn thiếu trước khi merge. Chỉ thay đổi đã hợp nhất mới được coi là trạng thái triển khai trên nhánh chính.

## Cách cloud nhận biết việc local đã làm
Mỗi pull request của local phải cập nhật nhật ký. Cloud đọc nhật ký trên nhánh chính cho phần đã hợp nhất, đồng thời xem pull request mở cho phần đang đề xuất. Nhãn “đã chạy trên máy” không đồng nghĩa “đã push” hoặc “đã hợp nhất”. Hai chat không tự chia sẻ lịch sử hay tự nhận thông báo từ GitHub.

## Mẫu mục bàn giao
- Ngày và bên thực hiện:
- Trạng thái: chỉ local / đã push, chờ review / đã hợp nhất.
- Commit nguồn và workbook:
- Thay đổi và file/module:
- Kiểm tra, kết quả, giới hạn:
- Chênh lệch thiết kế còn lại:
- Pull request hoặc commit triển khai:
- Bước tiếp theo:

Không lưu bí mật, đường dẫn máy cá nhân hoặc log không cần thiết trong repo. Asset, cấu hình và mã cần cho việc chạy phải được commit; loại cache và file tạm.

## Chuyển máy
Lấy repo và phiên bản đã hợp nhất, đọc nhật ký, cài phiên bản Godot được ghi nhận rồi chạy kiểm tra. Cấu hình đường dẫn công cụ riêng cho máy mới. Các thay đổi chưa push không thể phục hồi chỉ từ GitHub.
