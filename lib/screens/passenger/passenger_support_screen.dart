import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/wg_button.dart';
import '../../core/widgets/wg_list_tile.dart';
import '../../core/widgets/wg_toast.dart';
import '../../data/mock_faq.dart';

class PassengerSupportScreen extends StatelessWidget {
  const PassengerSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(title: const Text('Hỗ trợ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary500, AppColors.primary700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.card,
              boxShadow: AppShadows.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.support_agent,
                  color: Colors.white,
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bạn cần hỗ trợ?',
                  style: AppTypography.h1.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Đội ngũ WeGo sẵn sàng 24/7 — trả lời trong vài phút.',
                  style: AppTypography.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                WgButton.secondary(
                  label: 'Chat với CSKH',
                  leadingIcon: Icons.chat_bubble_outline,
                  onPressed: () =>
                      WgToast.info(context, 'Chat sẽ có ở phiên bản sau'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Text(
              'CÂU HỎI THƯỜNG GẶP',
              style: AppTypography.micro.copyWith(
                color: AppColors.ink500,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppRadius.card,
              boxShadow: AppShadows.sm,
            ),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: AppColors.ink100,
                splashColor: Colors.transparent,
              ),
              child: ExpansionPanelList.radio(
                elevation: 0,
                expandedHeaderPadding: EdgeInsets.zero,
                children: kFaq.asMap().entries.map((e) {
                  return ExpansionPanelRadio(
                    value: e.key,
                    backgroundColor: AppColors.white,
                    headerBuilder: (ctx, isOpen) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Text(
                        e.value.question,
                        style: AppTypography.body.copyWith(
                          color: AppColors.ink900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    body: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          e.value.answer,
                          style: AppTypography.body.copyWith(
                            color: AppColors.ink700,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Text(
              'LIÊN HỆ',
              style: AppTypography.micro.copyWith(
                color: AppColors.ink500,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: AppRadius.card,
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              children: [
                WgListTile(
                  icon: Icons.phone_outlined,
                  title: 'Hotline 24/7',
                  value: '1900 1234',
                  onTap: () =>
                      WgToast.info(context, 'Đang gọi 1900 1234...'),
                ),
                const Divider(height: 1, color: AppColors.ink100, indent: 70),
                WgListTile(
                  icon: Icons.email_outlined,
                  title: 'Email hỗ trợ',
                  value: 'support@wego.vn',
                  onTap: () => WgToast.info(
                    context,
                    'Đã sao chép support@wego.vn',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
