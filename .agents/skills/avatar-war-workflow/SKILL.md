---
name: avatar-war-workflow
description: Quản lý công việc Avatar War trên cloud/local theo phạm vi, phiên bản thiết kế và khả năng engine hiện có. Dùng khi tiếp tục dự án, tạo trận test, đổi build hoặc bàn giao; không dùng cho câu hỏi game chung không cần dữ liệu dự án.
---

# Avatar War — làm việc theo phạm vi

Giảm việc khám phá lại dự án; không đánh đổi tính đúng để đạt một hạn mức token tùy ý. Tuân thủ các chỉ dẫn dự án đang áp dụng.

## Bắt đầu gọn

- Xác định yêu cầu thuộc: chạy bản có sẵn, đổi cấu hình, thêm mechanic, đồ họa hay bàn giao. Không mặc định “demo mới” là viết engine mới.
- Đọc phần tương ứng trong [chỉ mục](references/project-map.md), rồi kiểm tra file/phiên bản thực tế. Chỉ mục là snapshot điều hướng, không thay thế thiết kế hoặc bằng chứng kiểm tra.
- GitHub main là thiết kế chuẩn, cùng các đính chính trực tiếp mới hơn của người dùng. So commit/blob trước; chỉ đọc sheet, mục luật và diff liên quan. Hỏi khi mâu thuẫn ảnh hưởng kết quả. Không tải toàn bộ nhật ký hoặc workbook thành văn bản vào hội thoại.
- Tách nguồn thiết kế, Godot đã triển khai và Python đã triển khai. Không coi cập nhật một bên là đồng bộ tất cả.

## Chọn đường triển khai

- **Chạy:** mở đúng project/scene đã xác minh, không import lại thiết kế nếu không có thay đổi.
- **Đổi cấu hình:** dùng schema/importer và engine đang có. Kiểm tra node, prerequisite, SP, cấp skill, main và slot; chỉ sửa cấu hình khi engine thực sự hỗ trợ. Không coi field/skill xuất hiện trong JSON là đã có handler.
- **Thiếu mechanic:** xác định khoảng thiếu trước, hỏi đúng thông số chưa được thiết kế, rồi mở rộng handler dùng chung và kiểm tra hành vi. Không im lặng thay bằng skill khác hoặc tạo một engine riêng cho mỗi trận.
- **Đồ họa:** giữ combat; đọc asset/concept và scene cần sửa, không mở lại bộ mô phỏng hoặc lịch sử thiết kế không liên quan.

## Kiểm tra và kết thúc

- Dùng bộ kiểm tra liên quan, giữ seed/nguồn/AI policy. Sau khi qua, chỉ mở rộng kiểm tra khi có thay đổi shared code hoặc rủi ro chưa giải quyết. Test có thể chạy nhiều phép kiểm tra trên máy; chỉ đưa tóm tắt và lỗi cần sửa vào ngữ cảnh.
- Khi lỗi, đọc signature/thông báo cụ thể trước khi sửa; không lặp lại thao tác không đổi đầu vào. Không tiếp tục sửa đoán khi thiếu quyết định thiết kế.
- Ghi checkpoint ngắn: nguồn, file/scene, thay đổi, kiểm tra, hạn chế, bước tiếp. Cập nhật chỉ mục khi đường dẫn hoặc khả năng engine đổi; không sao chép lịch sử chat vào đó.
- Ghi rõ local / đã push / đã merge bằng bằng chứng. Chỉ thực hiện GitHub mutation trong phạm vi được phép; tuân thủ workflow repo. Không nói code/asset đã đồng bộ khi chỉ có tài liệu trên GitHub.
- Chat mới đọc skill và checkpoint liên quan; không cần sao chép toàn bộ chat cũ. Không tạo chat mới hoặc chuyển việc sang chat khác nếu người dùng chưa yêu cầu.