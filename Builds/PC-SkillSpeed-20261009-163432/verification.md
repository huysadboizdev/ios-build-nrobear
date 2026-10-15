# Sửa client skill khi tăng tốc — 09/10/2026

Đã triển khai trên project `C:/Users/Admin/Downloads/PRJ_2Tab_550K`, cả Game1/Game2. Server được review, chưa sửa source server hoặc thay `SRC/20.jar` trong tác vụ này.

## Thay đổi

- Gồng tự nổ, quả cầu kênh khí, Makankosappo dùng deadline theo thời gian monotonic, lấy duration đầy đủ từ server; bỏ hủy theo 500 lượt update/giới hạn chung 3 giây. Bay lên không reset deadline.
- Biến khỉ khởi tạo mốc riêng và chờ kết quả server, có watchdog thời gian thực để tránh kẹt.
- Hiệu ứng gồng tối đa một batch mỗi 100 ms; hiệu ứng đánh trúng/hoạt ảnh có sẵn tiếp tục update.
- Chụp skill/mục tiêu khi bắt đầu; khóa đường đổi/dùng skill chồng lên cast; kiểm tra target còn trong map và còn sống trước khi gửi.
- Gói prepare lặp không kéo dài deadline; gói sai skill bị bỏ qua. Chuẩn bị/release không gửi trùng, không trừ MP hai lần.
- Hồi chiêu -94 chấp nhận cả giá trị bằng cooldown đầy đủ, loại giá trị âm/vượt giới hạn.
- Hủy cast dọn đúng projectile/animation do cast tạo ra, ngăn callback đánh muộn; giữ khóa chết/đóng băng/trói. Mục tiêu chết giữa animation giải phóng ngay trạng thái cast.
- Map load/disconnect/death dọn cast. Thay đổi hiện có của workspace mở khóa lúc hồi sinh được đồng bộ vào build cuối.

Production files: hai `Char.cs`, hai `Controller.cs`, hai `GameScr.cs`, `SkillCastTiming.cs`. Test/build runner: `Assets/Editor/HighSpeedSkillRegression.cs`, `HighSpeedSkillBuild.cs`.

## Kiểm chứng

Kiểm thử trên mã cũ trong Unity đã tái hiện Game1 tự nổ bị hủy sau 250 lượt update trước 2000 ms và Game2 biến khỉ thoát chờ ngay. Log: `.analysis/client-skill-speed-20261009/baseline.log`.

Review phát hiện bốn lỗi trong bản sửa trung gian. Đã viết regression và xác nhận lỗi trước sửa: hiệu ứng cũ không tiến; callback đánh sau hủy; dọn cast mở khóa chết; target chết sau deadline gây kẹt. Log RED: `effect-regression-red.log`, `review-regression-red.log`.

Bộ Unity integration cuối chạy chính `Char`, `Controller`, `Service` với fake clock và session thu packet. 42 tổ hợp tự nổ/QCKK/Makankosappo × 7 mức tốc độ × 2 tab (x1/x2/x5/x10/x20/x50/x100), cộng khỉ/gói cải trang, biên cooldown, prepare trễ/lặp, MP, cleanup, target chết, hiệu ứng cũ, callback muộn. `HIGH_SPEED_SKILL_REGRESSION_PASS checks=169582`; số này gồm assertion mỗi update, không phải 169582 kịch bản riêng. Log `regression.log`; build runner chạy lại cùng regression trước build.

Build đầu thành công, 0 errors, 66 warnings. Build cuối đồng bộ thêm source hồi sinh; kết quả và đường dẫn artifact ghi trong `.analysis/client-skill-speed-20261009/build-final.log`, `build-output-path.txt` và `build-result.txt` trong thư mục build. Bản backup nguồn trước sửa và hash nằm ở `source-backup/`, `source-before.json`; build có manifest SHA-256 riêng.

## Review lịch sử

[Báo cáo server](client-skill-server-review-20261009.md) đối chiếu hai commit `708cb8979`/`d70b13e23` và diff hiện tại. Các nhánh chuẩn bị player có từ baseline; async tự nổ boss/pet là diff chưa commit, có nguy cơ task lặp và đọc skill/zone thay đổi. BIEN_KHI server đọc skill đang chọn khi hoàn tất; QCKK/laser chưa kiểm tra thời gian gồng trên server. Đây là các phát hiện server riêng, chưa tự động sửa hoặc triển khai JAR.

[Review client](client-skill-client-review-20261009.md) lưu bốn phát hiện của bản trung gian; cả bốn đã sửa và qua regression trên hai tab. Reviewer cuối không chạy tiếp được; người triển khai kiểm tra mã và dùng kết quả Unity để xác nhận các sửa đó. Client không có Git; server chỉ có hai commit tác giả Huydev. Không có bằng chứng để quy từng dòng sửa cho Claude.

## Giới hạn

Chưa đăng nhập gameplay trên server thật, chưa đo FPS/GC bằng Unity Profiler hoặc nghiệm thu nhiều người cùng gồng. Test xác nhận thời gian/trạng thái/packet của client với môi trường kiểm soát; không cam kết mượt tuyệt đối x100 trên mọi cấu hình. TCP hiện không có cast token, nên gói prepare trễ cùng skill từ cast cũ chưa thể phân biệt hoàn toàn. Các nhánh lỗi server nêu trong report vẫn cần đợt sửa riêng nếu gặp ngoài client này.

Chạy bản mới bằng cách giải nén trọn ZIP, giữ exe cùng thư mục `_Data`, `UnityPlayer.dll` và `MonoBleedingEdge`. Dùng source backup để rollback code; các build cũ được giữ nguyên.
