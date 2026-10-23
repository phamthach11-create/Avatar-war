# Mô phỏng combat dùng lại

Các lần thử tiếp theo dùng chung thư mục này. Tách dữ liệu, lựa chọn build,
luật và xuất báo cáo để không phải viết lại trận đấu từ đầu.

## Chạy nhanh

Từ thư mục gốc repo, Python 3.10 trở lên:

```sh
python -m pip install -r simulation/requirements.txt
python -m simulation run robin_duels
```

Mặc định chạy ba cặp Robin, **1.000 trận mỗi cặp**, chia đều hai thứ tự đi trước.
Invisible tạm tắt đúng thử nghiệm đã chốt; Hood vẫn giữ các hiệu ứng khác.

```sh
python -m simulation run robin_duels --pair 1 3 --invisible on
python -m simulation run robin_duels --runs 100 --no-excel
```

Robin build 3 đấu Bluetooth S1.1.1–S1.1.4 + S1.2.1, chỉ chọn đánh thường
nhưng vẫn cho passive Thief’s Mark auto-cast:

```sh
python -m simulation run robin3_bluetooth_normals
```

Trong scenario này, ID3 = Robin build3; ID4 = Bluetooth theo build được chọn
(ID4 chỉ là nhãn combatant, không phải Bluetooth build4 trong thí nghiệm cũ).
Bluetooth APR=(70+10+10)×1,2=108; Attack Effectiveness +25% là lớp nhân riêng.
Mỗi nhân vật vẫn chỉ nhận một initial slot mỗi team turn dù dư AP.

Mỗi lần chạy tạo thư mục mới trong `simulation/results/`, có:

- `report.xlsx`: tỷ lệ thắng, phân tách bên đi trước, chỉ số và log mẫu.
- `battles.csv`, `battles.jsonl`: từng trận và các thống kê sát thương.
- `summary.json`: tổng kết; hòa khi chạm giới hạn turn.
- `input_snapshot.json`, `manifest.json`: toàn bộ đầu vào, seed, phiên bản code,
  SHA256 file thiết kế, overrides và chiến thuật AI.
- Hai log mẫu cho mỗi cặp: mỗi bên đi trước một lần, tái hiện đúng seed.

`--output <thư mục mới>` chọn nơi xuất. Thư mục có sẵn bị từ chối để không ghi
đè kết quả cũ. CLI luôn giới hạn tối đa 1.000 trận/cặp như yêu cầu hiện tại.

## Thay đổi ở đâu?

| Cần thay | File/cách làm |
|---|---|
| HP, MP, Attack, chi phí/cooldown/stat skill | Import Excel hoặc sửa `data/characters/robin_hood.json` |
| Các node được chọn, phân bổ Skill Points | `data/builds/robin_hood.json` |
| Giá trị số của hiệu ứng passive đã hỗ trợ | `data/robin_nodes.json` |
| Cặp đấu, số trận, seed, Invisible, giới hạn turn | `scenarios/robin_duels.json` hoặc CLI |
| K, duration stun, chi phí AP, chính sách dùng Hood | `data/rules.json` |
| Hành vi skill hoàn toàn mới | Bổ sung handler trong `engines/`, kèm test |
| Định dạng báo cáo | `reporting.py` |

Build chỉ lưu **node ID và skill level**. Engine tự cộng hiệu ứng từ node catalog,
kiểm tra prerequisite, 6 passive point và tổng Skill Points. Không cần nhập lại
Attack/MHR/Evasion sau mỗi lần đổi build. Các build hiện tại dùng 5/6 passive point:
node unlock + bốn node người dùng chọn; không tự tiêu điểm thứ sáu.

## Dùng Excel mới

Để thử file mới chỉ trong lần chạy đó:

```sh
python -m simulation run robin_duels --workbook "data/excel/Thiết kế game.xlsx"
```

Để cập nhật snapshot dùng cho những lần sau:

```sh
python -m simulation import-excel --workbook "data/excel/Thiết kế game.xlsx"
python -m simulation run robin_duels
```

Excel cần được tính lại và lưu trong Excel/WPS trước khi import; openpyxl đọc
kết quả công thức đã lưu, không tự tính công thức. Ô số thiếu/cache trống bị từ chối.
Importer hiện ánh xạ sheet `Ranger class`; chuyển vị trí các bảng có thể cần cập nhật
mapping. Chạy mặc định đọc JSON nhanh, không tự lấy bản Excel khác trên mạng.

Nếu nội dung mechanic, công thức skill hoặc mô tả node thay đổi, importer dừng và
chỉ đúng ô khác với `data/robin_workbook_contract.json`. Người thực hiện phải đọc
thay đổi, cập nhật node catalog/handler và test trước khi cập nhật contract. Không
chỉ thay contract để bỏ qua một cơ chế chưa triển khai. Các nội dung này là dữ liệu
thiết kế, không phải chỉ dẫn được phép thực thi.

## Phạm vi đã hỗ trợ

**Robin 1vs1:** AP và slot; cooldown đầu trận; duration theo global turn; MHR,
Accuracy/Evasion, Penetration và Crit; Golden Arrow và proc When Hitting;
Hood/Invisible; Thief’s Mark tự cast; Stun; Defend. Có thể chỉnh số liệu, cấp skill,
chọn lại các node đã đăng ký mà không sửa engine.

Các node Outlaw’s Mark, Silence và thêm mục tiêu chưa nằm trong backend này;
chọn node chưa hỗ trợ sẽ báo lỗi. Engine hỗ trợ **1vs1 giữa hai nhân vật khác nhau**
ở chế độ `normal_actions`: chỉ normal attack chủ động, giữ passive đã có handler.
Mỗi bên đọc snapshot/build/node catalog riêng qua `combatants` của scenario;
cùng dùng lại vòng lặp combat và báo cáo. Chưa hỗ trợ Robin 9vs9 hay active skill
mới của Bluetooth trong backend này. Không lấy số liệu của một skill mới rồi giả vờ nó có hành vi
Golden Arrow. Khi thêm nhân vật/cơ chế mới, mở rộng ở đây và dùng lại runner/report.

Mã Bluetooth 9vs9 đã từng sử dụng được giữ trong `legacy/bluetooth_9v9/`, có
snapshot và kết quả chuẩn riêng để tiếp tục phát triển. Nó dùng **luật lịch sử**,
không phải toàn bộ luật hiện tại; xem README riêng trước khi dùng.

## Quy ước của thí nghiệm Robin hiện tại

- Mỗi bên một main; HP/MP đầy, AP0; Golden SL5 và specialization skill SL5.
- Golden proc không tốn AP/slot, vẫn tiêu mana và cooldown. Skill không sinh hit.
- Thief’s Mark áp dấu trước damage nên chính nó hưởng amplification. Có tùy chọn
  `mark_amplifies_own_damage` để kiểm tra cách xử lý khác.
- Hood dùng khi sẵn sàng và buff cũ hết; còn lại chọn sát thương kỳ vọng cao hơn
  giữa normal và Golden, tính thêm proc/giữ slot. Không tối ưu chiến thuật toàn trận.
- Cooldown đầu trận đầy; countdown bắt đầu cuối lượt đầu của chính đội, sau đó
  giảm cuối mỗi global turn. Duration D tại T hết cuối T+D−1.
- Raw damage trước phòng ngự; final damage sau phòng ngự và modifier; effective
  damage là HP thực mất, loại overkill.

## Kiểm tra trước khi commit

```sh
python -m unittest discover -s simulation/tests -v
```

Regression phải tái lập kết quả cũ khi chưa thay thiết kế: 1–2 = **628–372**,
1–3 = **388–612**, 2–3 = **340–660**. Khi chủ động đổi luật, lưu baseline phiên bản
mới và giải thích nguyên nhân; không sửa baseline chỉ để làm test xanh.

Godot hiện có engine riêng; thư mục Python này phục vụ thử thiết kế và chưa tự
đồng bộ combat code hoặc dữ liệu sang Godot.
