class FaqItem {
  final String question;
  final String answer;
  const FaqItem({required this.question, required this.answer});
}

const List<FaqItem> kFaq = [
  FaqItem(
    question: 'Làm sao để đặt xe ghép?',
    answer:
        'Trên màn hình chọn xe, bấm "Xe ghép thông minh". WeGo sẽ tự tìm '
        'hành khách khác cùng tuyến để bạn chia sẻ chuyến — tiết kiệm tới '
        '38% so với xe riêng.',
  ),
  FaqItem(
    question: 'Cách thanh toán bằng MoMo?',
    answer:
        'Khi hoàn tất chuyến, ở màn hình "Hoá đơn", chọn phương thức MoMo. '
        'App sẽ chuyển sang MoMo để xác nhận giao dịch. Phí giao dịch 0đ.',
  ),
  FaqItem(
    question: 'Huỷ chuyến có mất phí không?',
    answer:
        'Huỷ trong vòng 2 phút sau khi đặt: miễn phí. Sau đó tính phí 10.000đ '
        'nếu tài xế đã trên đường tới đón.',
  ),
  FaqItem(
    question: 'Tài xế đến muộn, tôi làm gì?',
    answer:
        'Bạn có thể gọi trực tiếp tài xế qua nút điện thoại trong màn hình '
        'chuyến đi, hoặc huỷ miễn phí nếu chờ quá 10 phút.',
  ),
  FaqItem(
    question: 'Mất đồ trên xe, liên hệ ai?',
    answer:
        'Vào tab "Hoạt động" → chọn chuyến → "Báo cáo vấn đề" → "Mất đồ". '
        'WeGo sẽ liên hệ tài xế thay bạn trong vòng 30 phút.',
  ),
  FaqItem(
    question: 'Cách tích điểm thành viên?',
    answer:
        'Mỗi chuyến hoàn tất sẽ cộng 1 điểm. Đạt 50 điểm → hạng Bạc (giảm '
        '5%). 200 điểm → hạng Vàng (giảm 10%). 500 điểm → hạng Bạch Kim.',
  ),
];
