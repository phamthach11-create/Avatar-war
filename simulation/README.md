# Mô phỏng combat dùng lại

## Đội hình hỗn hợp có Automaton — 2026-10-31

`python -m simulation.mixed_run --output simulation/results/my_mixed_test`

Dùng workbook hiện tại và scenario `mixed_mirror_automata.json`, chạy đúng một trận seed42, hai đội giống nhau, main slot5. Tái sử dụng vòng lặp TeamBattle; bổ sung handler sáu kit đã chọn, cùng nguồn status không stack/refresh, máy đánh ở đầu allied team turn và Mona khi có đồng minh dưới50%HP. Đổi build/skill level/seed trong scenario; không viết script mới. Đây là Python, chưa cập nhật Godot. Xem `docs/design/mixed-roster-automata-test.md` để biết SP, chiến thuật, phạm vi và kiểm thử.


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

Đấu **9 Robin build3 vs 9 Bluetooth cùng build trên**, cho dùng skill:

```sh
python -m simulation run robin3_bluetooth_9v9
```

Main ở ô8 (giữa hàng sau); Front là đầu từng cột, Any được nhắm main được che chắn.
Robin dùng Golden5 + Mark5; Bluetooth dùng Frozen5 + Deadly5. Node S1.1.2 bỏ điều
kiện HP của Deadly. AI ưu tiên kết liễu main; nếu chưa thể, dùng Frozen vào hàng
hợp lệ chưa có Frozen để khống chế; còn lại so normal attack với direct skill theo
sát thương kỳ vọng. Không chọn swap hoặc Defend để chuyển slot. Đây là chiến thuật
đã ghi rõ, chưa phải tìm nước đi tối ưu toàn trận.

Mark chọn kẻ địch còn sống gây nhiều **HP damage thực tế** nhất; hòa thì ưu tiên main,
rồi HP thấp, rồi ngẫu nhiên. Mỗi dấu chỉ khuếch đại sát thương của chính người đặt,
không cộng chồng amplification của chín Robin. Mark áp trước damage của chính nó;
auto-cast vẫn hoạt động khi Frozen. Main chết dừng toàn bộ hit/DOT/cast còn lại.
DOT tick cuối global turn gồm lượt áp dụng; tồn tại sau khi người đặt chết.
Các cột HP trong log trận đội là HP main; MP/AP là tổng toàn đội.

Thử nghiệm **bỏ hoàn toàn main, đánh đến khi cả chín đối thủ chết**:

```sh
python -m simulation run robin3_bluetooth_9v9_elimination
```

Scenario này giữ nguyên build và luật Front/Any nhưng không ưu tiên vị trí main.
Đòn chủ động chọn mục tiêu hợp lệ có HP hiện tại thấp nhất; hòa thì ngẫu nhiên.
Ưu tiên đòn trực tiếp dự kiến kết liễu mục tiêu, rồi Frozen không chồng hiệu ứng,
rồi sát thương trực tiếp kỳ vọng cao hơn. Mark vẫn chọn đối thủ gây nhiều sát
thương nhất; hòa thì HP thấp nhất, rồi ngẫu nhiên. HP/MP/AP trong log đều là tổng
toàn đội. Đây là điều kiện thắng riêng của thí nghiệm, không sửa luật game gốc.

Thử SATK Thief’s Mark còn 1/4, cùng đội hình và seed:

```sh
python -m simulation run robin3_bluetooth_9v9_mark_quarter
```

Trong scenario, `combatants.3.character_overrides.mark_satk = 1200` thay SATK
SL5 từ 4800 thành 1200; node Effectiveness +20% vẫn áp dụng, amplification vẫn
24%. Các thử nghiệm chỉ đổi số có thể dùng `character_overrides` cho tên chỉ số
trong bảng nhân vật, `mark_satk` hoặc `frozen_dot`, không cần viết lại engine hay
sao chép toàn bộ dữ liệu nhân vật. Snapshot Excel gốc được giữ nguyên.

Đổi cùng thử nghiệm SATK còn 1/4 sang 1vs1, vẫn dùng đầy đủ skill:

```sh
python -m simulation run robin3_bluetooth_1v1_mark_quarter
```

Engine đội cũng nhận `team_size: 1`, `main_position: 0`: chỉ một nhân vật mỗi
bên, tối đa một initial action slot mỗi lượt đủ điều kiện, không có mục tiêu phụ.
Các handler skill, chiến thuật và báo cáo dùng chung với 9vs9.

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
| Điều kiện thắng 9vs9 | `victory_condition`: `main` hoặc `elimination` trong scenario đội |
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
cùng dùng lại vòng lặp combat và báo cáo. `team_battle` mở rộng Fighter và công thức
đó cho đúng hai đội hình 9vs9 nói trên, với target/slot/DOT kế thừa luật của bộ
Bluetooth cũ. Backend đội hiện hỗ trợ Golden, Mark, Frozen, Deadly và các passive
của hai build đã chọn; các kit khác cần thêm handler và test. Không lấy số liệu của một skill mới rồi giả vờ nó có hành vi
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
