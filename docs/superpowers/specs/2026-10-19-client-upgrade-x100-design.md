# Client nâng cấp x100 — Thiết kế

## Mục tiêu

Thêm thao tác đập/nâng cấp x100 vào giao diện ghép đồ trên client. Client gửi từng lượt nâng cấp, dừng ngay khi server báo thành công, đồng thời phản ánh đúng yêu cầu đá bảo vệ của cấp đang đập.

## Phạm vi

- Áp dụng đồng nhất cho hai client logic `Game1` và `Game2` trong `Assets/Scripts/Assembly-CSharp`.
- Chỉ thay đổi source client; không sửa server, không đóng gói hoặc build APK/EXE/JAR.
- Không thay đổi hành vi nâng cấp một lượt hiện tại.

## Thiết kế

Giao diện ghép đồ trong `Game1/Panel.cs` và `Game2/Panel.cs` hiện gửi hành động ghép qua `Service.combine(1, vItemCombine)`. Controller nhận phản hồi giao thức `-81`; với nhánh nâng cấp thường (`typeCombine == 0`), `b32 == 2` ánh xạ đến thông báo thành công, còn `b32 == 3` ánh xạ đến thất bại. Tên biến `combineSuccess` đang mã hóa ngược (`0` là nhánh thành công, `1` là nhánh thất bại), vì vậy luồng x100 phải dựa vào phản hồi/hiệu ứng thực tế, không diễn giải tên biến theo nghĩa đen. Thêm nút x100 ở giao diện này và quản lý một phiên nâng cấp tuần tự ở client: gửi một yêu cầu, chờ phản hồi tương ứng rồi mới gửi lượt sau. Mỗi phiên giới hạn tối đa 100 lượt.

Khi nhận phản hồi thành công (`b32 == 2` ở nâng cấp thường), kết thúc phiên ngay, không gửi thêm yêu cầu, giữ nguyên hiệu ứng và thông báo kết quả hiện tại. Với thất bại (`b32 == 3`), chỉ gửi lượt sau sau khi hiệu ứng hiện tại hoàn tất (`isDoneCombine`), nếu vẫn còn lượt và trạng thái client còn hợp lệ. Phản hồi yêu cầu mới, đóng giao diện, mất kết nối hoặc lỗi gửi đều phải kết thúc/hủy phiên và xóa cờ chờ phản hồi để không gửi lặp.

Nút x100 hiển thị ở giao diện nâng cấp tương tự nút hiện tại. Nếu thông tin công thức/cấp đang chọn có yêu cầu đá bảo vệ, chỉ cho bắt đầu khi túi có tối thiểu 100 viên; một phiên có thể tiêu hao tối đa 100 viên bảo vệ, tương ứng một viên mỗi yêu cầu. Nếu cấp đó không có yêu cầu đá bảo vệ, x100 vẫn chạy bình thường và không áp dụng điều kiện này. Server tiếp tục là nguồn quyết định cuối cùng về nguyên liệu và kết quả từng lượt.

## Ranh giới thành phần

- `Game1/Panel.cs`, `Game2/Panel.cs`: nút x100, trạng thái phiên, xác thực vật phẩm đầu vào và khởi động/hủy phiên.
- `Game1/Controller.cs`, `Game2/Controller.cs`: chuyển phản hồi `-81` thành kết quả cho phiên x100; không làm đổi hiệu ứng hiện có.
- `Game1/Service.cs`, `Game2/Service.cs`: giữ nguyên cấu trúc gói combine hiện tại; dùng gửi từng lượt.

## Tiêu chí chấp nhận

1. Nút x100 gọi tối đa 100 lần nâng cấp, không gửi chồng khi đang chờ phản hồi.
2. Phản hồi thành công đầu tiên dừng phiên ngay và không phát sinh yêu cầu lượt tiếp.
3. Thất bại tiếp tục lượt sau cho đến khi đạt thành công, đủ 100 lượt, hoặc gặp điều kiện dừng/lỗi.
4. Nếu công thức có đá bảo vệ, thiếu 100 viên thì không bắt đầu x100; đủ thì số yêu cầu được giới hạn tối đa 100. Cấp không yêu cầu đá bảo vệ vẫn có thể chạy.
5. Nút một lượt, thông báo và hiệu ứng ghép hiện có vẫn hoạt động.
6. Hai bản `Game1` và `Game2` có hành vi tương đương.

## Kiểm chứng dự kiến

Kiểm tra tĩnh các đường đi thành công, thất bại, hủy, mất kết nối và kiểm tra số yêu cầu tối đa; kiểm tra cả hai namespace và diff để xác nhận thay đổi chỉ nằm ở source client. Không chạy build hoặc đóng gói client trong tác vụ này.
