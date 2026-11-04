# Rà soát workbook Nightingale / Morgan — 2026-11-04

## Phạm vi và bằng chứng

- Nhánh: `design/workbook-20261103`; main đối chiếu `334ea46fc2a2e13960018a7cd0a9720152c15f26` (đã fetch kiểm tra lại).
- File upload: SHA-256 `af238b367bef1f2bab757bef14d3b5b7c3d7e7ba7c76b09d19d7c6a26862611f`.
- Bản đã chỉnh text: SHA-256 `0930269b70fbf8bc1935c4276f64e9ed63c51519c4b819021409f7d2a3862e2f`.
- Đây là rà soát và chỉnh text thiết kế theo trả lời của người dùng, chưa phải triển khai engine hoặc chứng nhận runtime.
- Pipeline có 735 changed cells,724 yêu cầu review. Đây là số ô, không phải 724 lỗi hay724 mechanic.

## Phân loại toàn bộ735 ô

| Nhóm | Số ô | Kết luận |
|---|---:|---|
| Caster class mới |482|Hai khối nhân vật Nightingale/Morgan, stat, skill, spec, công thức và CP. Cần định danh riêng từng nhân vật; chưa có handler.|
| Item |135|Phần lớn do thêm dòng và dịch vị trí. So theo item+stat chỉ Caster weapon thay đổi nội dung số.|
| Phạm vi SUMIFS |96|1003→1004 sau khi thêm dòng Item; sáu class cũ vẫn giữ nguyên tổng stat trong ngưỡng số thực.|
| Cache số thực |8|Chỉ lệch làm tròn rất nhỏ; so bằng rel_tol1e-9/abs_tol1e-8. Không phải thay đổi thiết kế.|
| Thay đổi riêng còn lại |14|Stun, aura Soldier, scaling Connection, giá trị Vitruvian và text/cột hiển thị; liệt kê dưới đây.|

## Chỉnh13 ô text; không đổi số hoặc công thức

- Nightingale: dùng Healing Hands thay Nurse Care; Light of Hope thay Continue Battle; Back to Duty thay Adrenaline. Đây là ánh xạ theo ba skill mặc định/spec1/spec2 trong cuộc trao đổi.
- Morgan: I73 sửa DOT SATK thành SATK vì Fae Starfall gây damage tức thời; D79 sửa tên Avalon’s Veil; F82 sửa Curse thành Malediction.
- G81 ghi rõ Firestorm kế thừa thay đổi AP/cooldown và nâng cấp Starfall; SATK Effectiveness chuyển sang DOT SATK Effectiveness, theo trả lời người dùng.
- Status F23: Stun vô hiệu passive skills, auto-cast và continuous skill effects; giữ intrinsic stat bonuses từ specialization points. Không tự xóa status đã cast trước đó hoặc despawn summon chỉ vì chủ bị Stun.
- Không tự đổi các chỉ số hoặc lựa chọn build/SP.

## Thay đổi ngữ nghĩa và tác động code

| Nguồn | Thay đổi / kết luận | Tác động hiện tại |
|---|---|---|
| Item F16:I18 | Caster weapon: Attack 1348.3685→780.6718; MP 10000→25000; thêm HA 10 điểm%; tổng CP vẫn16050 |Các class cũ không dùng Caster weapon. CP chuyển từAttack sangMP/HA, không tăng ngân sách.|
| Soldier H43 | Fortify 7%→12%, Rage 5%→4% |`requested_battle.gd::_sum` vẫn dùng0.07/0.05; ảnh hưởng roster requested9v9.|
| Soldier B41:C43 | Heraclid và Spartan King, thêm mô tả |Text/metadata, không thay tác dụng chỉ số.|
| Destroyer J36:K37 | SL 5 Fortify 27.5%→18.6667%; Resistance 13%→8.6667% |Connection chưa có handler trong combat hiện tại. Roster requested9v9 không mở Connection; không được tuyên bố đã kiểm chứng skill này.|
| Piercer L34 | Vitruvian SATK equivalent 33080→16540 |C34 vẫn 10004 MP; cần đồng bộ lại định giá nếu giữ equivalent mới.|
| Piercer K35 | Hiển thị Negative Status Removal Count(Upgrade)=1 |Mô tả chỉ nâng cấp; không tự cho cleanse khi chưa mở node. Build requested hiện tại Vitruvian level0.|
| Piercer G45, Warrior F50 | Viết rõ prerequisite/start combat cooldown |Đổi lời văn, không thêm effect mới.|
| status F23 | Stun nay khóa passive skills |`_ready_skill` chưa chặn stun; `_sum` aura chưa kiểm tra stun; block Phalanx kiểm tra level nhưng không kiểm tra stun. Cần một cổng passive-skill chung; không xóa stat nội tại từ spec.|

### Vitruvian Man: giá trị mana cần sửa riêng

Dùng đúng tham chiếu mana 200 own turns, cả hai thứ tự, reference active 8270/CD3, normal equivalent 4147.2; skill AP 100 / CD 6 / duration 6 / value 16540:
- Mỗi thứ tự: 67 normals  + 67 reference actives  + 66 casts.
- Tổng equivalent 1,923,592.4; reference mean 1,239,658.6.
- Mana=4106×1,923,592.4/1,239,658.6=**6371.3270689**, đề xuất**6371.33MP**.
- File vẫn giữ 10004 MP vì người dùng chưa yêu cầu đổi lại số này trong bước rà soát.

## Khả năng hỗ trợ Caster

- Bộ importer `build_scenario` đang lấy sheet bằng `unit.type + ' class'`, stat ởB9:B27. Caster có Nightingale tại B9:B27 và Morgan tại B50:B68: chỉ thêm type Caster sẽ khiến cả hai đọc stat Nightingale. Cần character ID và block/range riêng.
- `requested_battle.gd::_apply_build`, `_act` và `_cast_impl` chưa có hai kit Caster. Có dữ liệu JSON trong pending không đồng nghĩa đã triển khai.
- Nightingale cần handler heal Full Row, heal+clear Stun/all Stun Count, heal+Haste (duration 8); skill-level scaling và nodes đúng từng nhân vật.
- Morgan cần Starfall directSATK, Firestorm DOT, Malediction DOT/Silence/Intimidated, Veil target-filter cho bốn class được liệt kê và MP Stat Effectiveness. Cấm chọn làmprimary không phải miễn damage phụ.
- Trong `mixed_battle.gd::_damage`, danh sách ranged hiện chỉ Ranger/Piercer/Devastator; khi thêm Caster phải cập nhật tương tác block/counterattack, không để Caster bị xem là melee.
- Mana Effectiveness: Terminology định nghĩa MP stat pipeline cho Max MP. Nên dùng tên rõ MP Stat Effectiveness; không tự diễn giải thành giảm mana cost.
- Spec mới hầu hết chưa có node ID bằng chữ. Cần mapping có thể kiểm tra với nhánh trong sheet; không tự chọn build/SP để chứng nhận2nhân vật.
- Cột K là giá trị SL5; max level10/6 không có nghĩa K phải là giá trị max. Các công thức SL5 hiện khớp. Mana pricing trong hội thoại cũng dùng equivalent SL5.

## Trạng thái kiểm tra và giới hạn

- ZIP integrity hợp lệ; đọc được 14 sheet. Có 1.011 ô công thức với cache, không thiếu cache hoặc chứa Excel error tại ô công thức.
- Chỉnh XML của 13 ô text; giữ nguyên byte của mọi ZIP part ngoài hai worksheet được sửa, giữ nguyên mọi ô ngoài danh sách chỉnh và toàn bộ formula/cache pairs.
- Không mở Excel để tính lại; cache tồn tại không chứng minh công thức đã được tính lại. Không dùng `--recalculated` hoặc tạo receipt giả.
- `python -m unittest discover -s tests/design_sync -v`: 12 tests qua. Đây là kiểm thử pipeline, không phải kiểm thử Caster/Stun mới trong Godot.
- `python -m tools.design_sync plan`: BLOCKED, 735 changes / 724 review. Pipeline dựa trên snapshot đã triển khai, không đọc quyết định review trong Markdown.
- Không thay code, accepted.json, implementation receipt hoặc runtime bundle. Chưa chạy hoặc tuyên bố Godot đã áp dụng thiết kế này.
- Phần không đổi so với main: Combat Mechanics vẫn cấm refresh status cùng nguồn. Điều này khác đính chính trước đây trong chat cho phép refresh duration; engine và workbook hiện cùng hành vi no-refresh. Không tự đưa sửa đổi này vào đợt review.

## Thứ tự triển khai tiếp

1. Cập nhật Stun/passive gate và aura 12%/4%; kiểm thử auto-cast, aura, Phalanx và việc giữ stat nội tại. Phân biệt status đã cast với passive đang hoạt động.
2. Rà soát mana Vitruvian và level scaling trước khi xuất dữ liệu.
3. Thêm character key/range và handler Caster vào engine có sẵn; kiểm thử target/AOE, DOT, cleanse, Haste, Veil, kế thừa Firestorm, MP và cấp skill.
4. Chọn scenario/build/SP cụ thể khi người dùng yêu cầu test Caster; không dùng roster 9v9 cũ để nhận vơ đã test Caster.
5. Sau khi có bằng chứng kiểm thử đúng scope mới lập receipt, xuất bundle, check và merge. Không chỉ cập nhật hash để làm freshness xanh.
