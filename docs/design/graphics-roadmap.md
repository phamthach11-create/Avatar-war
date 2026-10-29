# Kế hoạch nâng cấp đồ họa chiến đấu 2D — đã chốt

Phiên bản: 1.0. Ngày chốt: 2026-10-29.
Người dùng đã duyệt kế hoạch sáu giai đoạn trong chat local và yêu cầu lưu lên GitHub trước khi triển khai từng phần.

## Mục tiêu và phạm vi
Nâng demo thành trận chiến 2D 9vs9 có hình ảnh đồng bộ, nhân vật tỷ lệ trưởng thành, chuyển động có lực, kỹ năng đẹp mắt và hoành tráng nhưng vẫn đọc được trận đấu 18 người. Fantasy Hàn Quốc, tỷ lệ người thật, không chibi.

MU Online, Lost Ark và Path of Exile là tham chiếu về không khí, ánh sáng và cảm giác ra đòn, không phải cam kết sao chép tài sản hoặc đạt chất lượng sản xuất tương đương chỉ bằng một lần tạo ảnh. Chất lượng cần được kiểm chứng qua cảnh mẫu chạy thật.

Đợt này tập trung environment, character design, animation, effect, audio và phản hồi hình ảnh. Giữ luật, chỉ số, build, phạm vi mục tiêu và mốc tác động theo thiết kế đã chốt. Lỗi combat phát hiện trong quá trình phải ghi riêng; không sửa luật để phục vụ hiệu ứng.

## Trạng thái hiện tại
- Kế hoạch: ĐÃ DUYỆT.
- Giai đoạn hiện tại: đã chốt tiếp tục2D, Napoleon mẫu1 ở tỷ lệ105% trên sân đá sáng A; mốc tiếp theo là Giai đoạn2 cảnh mẫu bắn pháo.
- Đã tạo ba ảnh concept local, chưa có phương án được duyệt, chưa tạo bộ asset chạy game và chưa hoàn thành cảnh mẫu Napoleon.
- Demo local có trận hỗn hợp 9vs9, hai Napoleon mỗi đội, main Leonidas A5/B5, Auto/Restart/Builds/Xuất log. Phần lớn mã, asset và kiểm thử bản này vẫn chưa được upload vào repo; nhật ký ghi rõ khoảng cách.
- Không coi README về demo cũ hoặc file kế hoạch này là bằng chứng repo đã có bản đồ họa mới.

## Điều kiện nền trước khi tích hợp đồ họa
Sao lưu và đồng bộ baseline demo local, mã, asset cần chạy, cấu hình và kiểm thử qua PR riêng; giữ bản combat đã kiểm tra để so sánh. Không kéo repo cũ đè lên ZIP/project local hiện tại. Việc phác thảo định hướng có thể bắt đầu trước; việc hợp nhất đồ họa phải dựa trên baseline tái tạo được.

## Giai đoạn 1 — Chốt định hướng hình ảnh
Đầu ra:
- Bảng định hướng phong cách: tỷ lệ người, trang phục, vật liệu, palette và chất lượng chi tiết.
- Góc nhìn, phối cảnh sân đấu, kích thước nhân vật tại kích thước chơi thực tế.
- Mẫu Napoleon và pháo; mẫu môi trường.
- Một ảnh tổng thể 9vs9 minh họa cách nhân vật, môi trường, UI và hiệu ứng phối hợp.

Cách làm: chuẩn bị ít phương án có khác biệt rõ, chọn một hướng và tinh chỉnh. Ảnh concept là tài liệu định hướng, chưa phải sprite animation hoặc asset dùng ngay trong game.
Điểm duyệt: người dùng chọn hướng nhìn và phong cách; đủ chỗ đọc 18 nhân vật. Chưa sản xuất hàng loạt asset trước mốc này.

## Giai đoạn 2 — Một cảnh mẫu Napoleon hoàn chỉnh
Dùng một Napoleon và một nhóm mục tiêu trên map mẫu để chứng minh chất lượng chạy thật:
- Idle, chuẩn bị bắn, khai hỏa, phản lực và thu động tác.
- Đạn bay, va chạm, vụ nổ, khói, tàn lửa và phản ứng mục tiêu.
- Một skill diện rộng theo đúng skill hiện có: vùng ảnh hưởng rõ, nhiều nhịp tác động phù hợp cơ chế.
- Ghép ánh sáng, bóng tiếp xúc, âm thanh và nhịp chiến đấu.

Chuỗi nhìn thấy: chuẩn bị → thi triển → tác động → tan dần. Hiệu ứng không tự tạo damage mới; lấy đúng mốc và mục tiêu từ combat.
Điểm duyệt: xem trong Godot ở tốc độ thường, đánh giá cảm giác có lực, độ rõ và chi phí hiển thị. Lấy cảnh mẫu đã duyệt làm chuẩn trước khi nhân rộng.

## Giai đoạn 3 — Xây lại môi trường
Mặt đất rõ, đủ thoáng; tiền cảnh/hậu cảnh tách lớp; chuyển động môi trường nhẹ; bóng chân, ánh sáng, sương bụi; dấu cháy/va chạm phù hợp.
Điểm duyệt: phối cảnh và điểm tiếp đất đúng; nhân vật, vùng skill và thanh HP nổi bật trên nền; trang trí không che ô đội hình.

## Giai đoạn 4 — Sáu nhân vật và animation
Sáu thiết kế riêng: Joan, Harald Bluetooth, Leonardo, Robin Hood, Leonidas, Napoleon. Dễ nhận biết qua hình dáng, vũ khí, tư thế và màu; bản sao dùng chung tài nguyên, thêm dấu phân biệt nhỏ.
Bộ cơ bản: idle, di chuyển, đánh thường, thi triển, trúng đòn, gục. Động tác quan trọng có lấy đà, chạm và thu đòn.
Hướng kỹ thuật đề xuất: kết hợp rig 2D cho chuyển động thường và khung hình riêng cho động tác đặc trưng. Chỉ chốt cách làm sau thử nghiệm ở cảnh mẫu; ảnh nhiều tư thế không tự động tạo thành animation mượt.
Chuẩn hóa tên file, kích thước, pivot, điểm chân, socket vũ khí/phát đạn, animation clip và mốc hiệu ứng trong dữ liệu; tránh tọa độ/tư thế ghi cứng trong UI.
Điểm duyệt: nhận ra sáu class trên sân; hai chiều đối diện hoạt động đúng, chuyển động có trọng lượng và không trượt chân.

## Giai đoạn 5 — Hiệu ứng từng bộ kỹ năng
| Nhân vật | Bản sắc |
| --- | --- |
| Joan | Ánh sáng thánh, kiếm sáng, khiên và hồi máu |
| Bluetooth | Băng, rìu nặng, mặt đất đóng băng |
| Leonardo | Cơ khí, hình học và hỗ trợ |
| Robin Hood | Mũi tên nhanh, đường bay rõ và dấu mục tiêu |
| Leonidas | Khiên, giáo, động tác mạnh và hiệu ứng chiến trận |
| Napoleon | Pháo, đạn đạo, khói lửa và oanh tạc diện rộng |

Mỗi skill có cảnh báo/chuẩn bị phù hợp, thi triển, tác động và fade-out; hiệu ứng liên tục có cách tắt khi hết duration, chết hoặc Restart. Heal, miss, block, buff, DOT và sát thương trực tiếp phải dễ phân biệt.
Điểm duyệt: đúng người, đúng vùng, đúng thời điểm combat, không che main hoặc thanh HP. Mỗi kit được kiểm tra trước khi ghép toàn bộ.

## Giai đoạn 6 — Cảm giác chiến đấu và tối ưu
Âm thanh riêng theo vũ khí; rung màn hình có giới hạn; nhịp dừng ngắn ở đòn mạnh; số sát thương và biểu tượng rõ. Các lựa chọn giảm hiệu ứng và tắt rung/âm thanh phù hợp.
Kiểm tra 18 nhân vật, hai Napoleon mỗi bên và nhiều DOT cùng lúc; giới hạn particle, khói, nguồn sáng và pooling theo đo đạc trên máy người dùng. Chốt mục tiêu hiệu năng sau khi đo baseline, không cam kết FPS khi chưa đo.
Điểm duyệt: trận 9vs9 ổn định; không sót/chồng hiệu ứng khi Auto, đổi tốc độ, tắt Auto hoặc Restart; xuất log vẫn dùng được; luật combat không bị nhịp hình ảnh làm thay đổi.

## Cách triển khai từng phần cùng người dùng
1. Nêu rõ đang ở giai đoạn nào, đầu ra cần duyệt và việc sẽ làm.
2. Local chuẩn bị concept/asset/tích hợp và trình diễn; người dùng đánh giá bằng hình ảnh hoặc cửa sổ Godot. Người dùng không phải tự học vẽ hay tự tạo asset để tiếp tục.
3. Sau khi đầu ra được duyệt, ghi phiên bản và quyết định rồi chuyển sang phần tiếp theo. Không hỏi lại lựa chọn đã được chốt, chỉ hỏi điểm ảnh hưởng đáng kể chưa có câu trả lời.
4. Mỗi PR cập nhật bảng tiến độ bên dưới, nhật ký cloud-local và liên kết ảnh/video/commit đã kiểm chứng. Giữ riêng concept, source chỉnh sửa, texture xuất dùng trong game và cấu hình.
5. Thay đổi hướng nghệ thuật hoặc thứ tự giai đoạn phải được người dùng chốt và ghi vào chính tài liệu này. Không tự thay thế kế hoạch bằng nội dung chỉ nằm trong chat.

## Bảng theo dõi
| Giai đoạn | Trạng thái | Bằng chứng / việc tiếp theo |
| --- | --- | --- |
| Baseline | Cần đồng bộ | Nhập demo local qua PR riêng trước tích hợp |
| 1. Định hướng | Đã chốt hướng và tỷ lệ Napoleon | 2D, anime cel-shaded mẫu1, mapA thành đá sáng, Napoleon105%; cảnh mẫu chuyển động ở giai đoạn2 |
| 2. Cảnh mẫu Napoleon | V1 đang mở, chờ duyệt | Commander poses, cannon recoil, projectile/impact, Barrage/DOT VFX; chưa tích hợp combat |
| 3. Environment | Chưa thực hiện | Theo chuẩn cảnh mẫu |
| 4. Nhân vật / animation | Chưa thực hiện | Nhân rộng sau khi cảnh mẫu đạt |
| 5. Hiệu ứng skill | Chưa thực hiện | Kiểm tra lần lượt từng kit |
| 6. Polish / tối ưu | Chưa thực hiện | Đo trận đủ 18 nhân vật |

Bước tiếp theo: hướng dẫn và chuẩn bị Giai đoạn 1; chưa tự tạo hàng loạt asset, chưa chỉnh gameplay.

## Lịch sử
- 2026-10-29: người dùng duyệt kế hoạch sáu giai đoạn và yêu cầu lưu GitHub để Cloud/Local theo cùng lộ trình. Bản1.0 ghi nhận quyết định này.

### Concept vòng1 — 2026-10-29
Ba phương án đã được tạo bằng công cụ tạo ảnh tích hợp và hiển thị cho người dùng. A: thành đá sáng/ánh chiều ấm; B: pháo đài tối/lửa pháo tương phản; C: fantasy sáng trắng-xanh-vàng. Bố cục và số nhân vật trong ảnh chỉ minh họa; B có nhân vật thiếu/che, chưa đạt đội hình gameplay18slot. Không dùng ảnh concept như sprite hoặc screenshot triển khai. Bộ PNG và prompts.md được lưu local tại outputs/graphics-direction-v1; chưa upload binary lên repo. Bước tiếp: chọn hướng, sửa bố cục và duyệt trước khi sản xuất.

### Nhân vật anime/manga — vòng2, 2026-10-29
Người dùng nghiêng về environment A (thành đá sáng), nhưng nhận xét nhân vật vòng1 quá thực. Hướng mới cho nhân vật: anime/manga, người trưởng thành, thiết kế toàn thân hoàn chỉnh; không pixel/chibi. Genshin Impact là một tham chiếu người dùng nêu cho kiểu game anime đẹp, không phải yêu cầu sao chép nhân vật hay tài sản.

Đang chuẩn bị bốn mẫu Napoleon cùng trang phục/tư thế/nền đơn giản để so sánh cách vẽ: (1) anime cel-shaded, (2) fantasy anime sắc nét, (3) manga tô màu, (4) anime painterly. Chưa chọn mẫu nhân vật. Giữ environment thành đá sáng làm định hướng; chưa đưa concept vào Godot và chưa chuyển sang cảnh mẫu animation.

### Quyết định đã chốt — Napoleon mẫu1, 2026-10-29
Người dùng chọn rõ mẫu số1 (Anime Cel-Shaded) trong vòng thử bốn mẫu toàn thân. Đây là tham chiếu phong cách nhân vật: nét anime rõ, mảng sáng/tối sạch, màu gọn, vóc dáng trưởng thành; không pixel/chibi và không quay lại chất liệu mặt photorealistic. Dùng Napoleon gốc của dự án, không sao chép thiết kế nhân vật của game tham chiếu.

Tham chiếu local: outputs/napoleon-style-v1/01-anime-cel.png và prompts.md. Mẫu được duyệt là concept, chưa phải sprite tách nền, rig hay animation. Environment tiếp tục theo hướng A thành đá sáng mà người dùng đã ưu tiên.

Bước tiếp: phối Napoleon theo hướng đã chọn vào sân đá sáng ở kích thước chơi thực tế, kiểm tra silhouette, màu và phối cảnh; sau đó tiến tới cảnh mẫu Napoleon chạy thật theo Giai đoạn2. Chưa mặc định người dùng đã duyệt thiết kế chi tiết của năm nhân vật còn lại hoặc cam kết chất lượng animation chưa được thực hiện. Không hỏi lại việc chọn phong cách số1.

### Scene kiểm chứng tổng thể v1 — 2026-10-29
Đã tạo hai asset nháp bằng imagegen từ tham chiếu đã chọn: Napoleon+cannon RGBA trong suốt, sân thành đá sáng sạch. Đã kiểm tra alpha thật, ghép và render trong Godot tại1280x820. Scene local riêng src/ui/art_direction_preview.tscn có18vị trí,4Napoleon mới,14nhân vật cũ để so tỷ lệ; hai đội đối xứng, main A5/B5. Có slider80–125%, chỉ xem Napoleon, xem gần và trở lại combat.

Sau ảnh kiểm tra đầu, đã giãn hàng170px và chỉnh kích thước/label để giảm chồng nhau; base Napoleon150px, nhân vật tạm126px. Đã kiểm tra 18slot/4Napoleon, chế độsolo4, scale125%, closeup và mở scene trên máy. Đây là kiểm chứng ảnh tĩnh ở giai đoạn1, không phải cảnh animation giai đoạn2. Combat/main scene không bị thay; chưa đồng bộ scene và PNG lên repo. Ảnh chụp, PNG và prompt nằm local outputs/napoleon-stage-preview-v1. Chờ người dùng duyệt tổng thể trước khi làm cảnh bắn pháo.

### Chốt 2D và tỷ lệ105% — 2026-10-29
Sau trao đổi về khả năng3D, người dùng quyết định tiếp tục kế hoạch2D và chốt Napoleon105% trong scene xem thử. Không chuyển dự án sang3D. Đã đặt mặc định preview105% (Napoleon157.5px từ base150px tại1280x820); đây là kích thước group người+pháo, không phải tăng chỉ số gameplay. Chọn này áp dụng đồng nhất cả bốn Napoleon và được giữ làm mốc khi dựng cảnh mẫu. Kích thước của năm thiết kế nhân vật khác chưa được suy ra là đã duyệt.

Tiếp theo: Giai đoạn2 — chuẩn bị động tác lấy đà/khai hỏa/phản lực và đạn/va chạm/khói trong cảnh mẫu Napoleon; chưa coi các animation này đã được tạo. Giữ mốc impact của combat hiện có và không nhân rộng asset trước khi cảnh mẫu được duyệt.

## 2026-10-29 — Cảnh mẫu bắn pháo Napoleon v1
- Đã tạo và mở scene local riêng src/ui/napoleon_firing_preview.tscn: bốn key pose ra lệnh, bộ phận pháo độc lập để recoil, đạn bay, nổ8frame, khói/tàn lửa, hurt pose, rung có tắt và hai âm thanh tổng hợp.
- Giữ anime mẫu1 và chiều cao157.5px tương ứng105%. Bốn pose được đo vùng/anchor riêng vì atlas không chia cell chính xác; tránh cắt bàn tay và lệch chân.
- Normal minh họa1hit vùngCross; Barrage minh họa3salvo, ápSunder/DOT không có directdamage rồi6tickDOT tua nhanh. Không sửa tài nguyên hoặc luật combat; đây là sceneVFX chưa tích hợp trận9vs9.
- Test timeline normal1fire/arrival, barrage3fire, DOT6tick và reset qua; đã render fire/impact và mở scene sau import trên project chính. Nút pause/speed/sound/shake/zoom/back có trong scene.
- Đang chờ người dùng duyệt bản đầu. Chưa phải rig/animation/VFX hoàn thiện. Source/PNG/WAV local ở assets/art_direction/firing_v1 và outputs/napoleon-firing-v1; binary chưa upload GitHub.
