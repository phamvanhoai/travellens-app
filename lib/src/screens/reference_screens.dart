import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../design/app_colors.dart';
import '../design/app_text_styles.dart';

class AiAssistantScreen extends StatelessWidget {
  const AiAssistantScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('AI Assistant'), actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.history_rounded))]),
    body: Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(18), children: [
        const _BotMessage('Xin chào Huy! 👋\nTôi có thể gợi ý cho chuyến đi của bạn hôm nay?'),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerRight, child: Container(
          constraints: const BoxConstraints(maxWidth: 250),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(14)),
          child: Text('Gợi ý cho tôi tour Bali 5 ngày 4 đêm có giá tốt', style: AppTextStyles.bodySmall.copyWith(color: Colors.white)),
        )),
        const SizedBox(height: 14),
        const _BotMessage('Dưới đây là một số tour Bali phù hợp được khách hàng yêu thích:'),
        const SizedBox(height: 10),
        _TourResult(onTap: () => context.push('/tours')),
      ])),
      SafeArea(top: false, child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderLight))),
        child: TextField(decoration: InputDecoration(
          hintText: 'Nhập tin nhắn...',
          suffixIcon: IconButton(onPressed: () {}, icon: const Icon(Icons.send_rounded, color: AppColors.brand)),
        )),
      )),
    ]),
  );
}

class TravelMapScreen extends StatelessWidget {
  const TravelMapScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bản đồ du lịch')),
    body: Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _MapPainter(), child: const ColoredBox(color: Color(0xFFE8F5F2)))),
      Positioned(left: 16, right: 16, top: 14, child: Column(children: [
        Container(height: 46, padding: const EdgeInsets.symmetric(horizontal: 13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 14)]), child: Row(children: [
          const Icon(Icons.search_rounded, color: AppColors.subtle), const SizedBox(width: 9), Expanded(child: Text('Tìm địa điểm...', style: AppTextStyles.bodySmall)), const Icon(Icons.tune_rounded, size: 19),
        ])),
        const SizedBox(height: 10),
        SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: const [
          _MapChip('Tất cả', true), _MapChip('View360', false), _MapChip('Ăn uống', false), _MapChip('Khách sạn', false),
        ])),
      ])),
      const Positioned(left: 70, top: 230, child: Icon(Icons.location_on, size: 36, color: Colors.green)),
      const Positioned(right: 65, top: 290, child: Icon(Icons.location_on, size: 36, color: AppColors.brand)),
      const Positioned(left: 150, top: 410, child: Icon(Icons.location_on, size: 36, color: Colors.orange)),
      Positioned(left: 16, right: 16, bottom: 18, child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 16)]),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: 'https://images.unsplash.com/photo-1533669955142-6a73332af4db?auto=format&fit=crop&w=400&q=85', width: 78, height: 68, fit: BoxFit.cover)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tanah Lot Temple', style: AppTextStyles.label), Text('Bali, Indonesia', style: AppTextStyles.caption), const Row(children: [Icon(Icons.star, size: 13, color: AppColors.gold), Text(' 4.7 (218)', style: TextStyle(fontSize: 10))])])),
          TextButton(onPressed: () {}, child: const Text('Xem chi tiết')),
        ]),
      )),
    ]),
  );
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.bookingId});
  final String bookingId;
  @override State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('Thanh toán')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      _Box(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Thông tin thanh toán', style: AppTextStyles.label), const SizedBox(height: 12),
        const _Row('Tổng thanh toán', '2.400.000đ'),
        _Row('Mã booking', widget.bookingId.isEmpty ? 'BK250720001' : widget.bookingId),
        const _Row('Ngày khởi hành', '20/07/2025'),
      ])),
      const SizedBox(height: 22), Text('Phương thức thanh toán', style: AppTextStyles.label), const SizedBox(height: 10),
      for (var i = 0; i < 4; i++) Padding(padding: const EdgeInsets.only(bottom: 9), child: _Box(child: Row(children: [
        Radio<int>(value: i, groupValue: selected, onChanged: (v) => setState(() => selected = v!)),
        Expanded(child: Text(const ['Thẻ tín dụng / Ghi nợ', 'Ví điện tử', 'Chuyển khoản ngân hàng', 'Thanh toán tại cửa hàng'][i], style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink))),
        Icon(const [Icons.credit_card, Icons.wallet, Icons.account_balance, Icons.store][i], color: i == selected ? AppColors.brand : AppColors.subtle),
      ]))),
      const SizedBox(height: 8), _Box(child: const _Row('Tổng thanh toán', '2.400.000đ', strong: true)), const SizedBox(height: 14),
      FilledButton(onPressed: () => _success(context), child: const Text('Thanh toán ngay')),
      const SizedBox(height: 10), Text('Bằng việc nhấn “Thanh toán ngay”, bạn đồng ý với chính sách đặt tour và điều khoản hủy tour.', textAlign: TextAlign.center, style: AppTextStyles.caption),
    ]),
  );

  void _success(BuildContext context) => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [
    const CircleAvatar(radius: 38, backgroundColor: AppColors.success, child: Icon(Icons.check_rounded, size: 48, color: Colors.white)),
    const SizedBox(height: 18), Text('Thanh toán thành công!', style: AppTextStyles.h4.copyWith(color: AppColors.success)),
    const SizedBox(height: 8), Text('Cảm ơn bạn đã đặt tour cùng TravelLens.', textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
    const SizedBox(height: 20), FilledButton(onPressed: () { Navigator.pop(dialogContext); context.go('/bookings'); }, child: const Text('Xem chi tiết booking')),
  ])));
}

class _BotMessage extends StatelessWidget {
  const _BotMessage(this.text); final String text;
  @override Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const CircleAvatar(radius: 16, backgroundColor: Color(0xFFE0E7FF), child: Icon(Icons.auto_awesome, size: 17, color: AppColors.brand)), const SizedBox(width: 8),
    Flexible(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF4F6FA), borderRadius: BorderRadius.circular(14)), child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink)))),
  ]);
}

class _TourResult extends StatelessWidget {
  const _TourResult({required this.onTap}); final VoidCallback onTap;
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)), child: Row(children: [
    ClipRRect(borderRadius: BorderRadius.circular(9), child: CachedNetworkImage(imageUrl: 'https://images.unsplash.com/photo-1533669955142-6a73332af4db?auto=format&fit=crop&w=500&q=85', width: 78, height: 68, fit: BoxFit.cover)), const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Bali Discovery 5N4Đ', style: AppTextStyles.label), const SizedBox(height: 5), Text('8.990.000đ', style: AppTextStyles.label), const Row(children: [Icon(Icons.star, size: 12, color: AppColors.gold), Text(' 4.8 (326)', style: TextStyle(fontSize: 9))])])),
  ])));
}

class _MapChip extends StatelessWidget {
  const _MapChip(this.text, this.selected); final String text; final bool selected;
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center, decoration: BoxDecoration(color: selected ? AppColors.brandDark : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: selected ? AppColors.brandDark : AppColors.border)), child: Text(text, style: AppTextStyles.caption.copyWith(color: selected ? Colors.white : AppColors.ink)));
}

class _Box extends StatelessWidget {
  const _Box({required this.child}); final Widget child;
  @override Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)), child: child);
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.strong = false}); final String label, value; final bool strong;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: strong ? AppTextStyles.label : AppTextStyles.bodySmall)), Text(value, style: strong ? AppTextStyles.h4.copyWith(fontSize: 15) : AppTextStyles.label.copyWith(fontSize: 11))]));
}

class _MapPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..strokeWidth = 5..style = PaintingStyle.stroke;
    canvas.drawPath(Path()..moveTo(0, size.height * .3)..cubicTo(size.width * .3, size.height * .15, size.width * .55, size.height * .65, size.width, size.height * .5), paint);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
