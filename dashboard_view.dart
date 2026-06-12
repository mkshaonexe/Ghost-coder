import 'package:flutter/material.dart';
import '../../../domain/models.dart';
import '../../core/app_theme.dart';
import '../bank_view_model.dart';
import '../add_money/add_money_view.dart';

class DashboardView extends StatelessWidget {
  final BankViewModel viewModel;
  final VoidCallback onAddMoneyPressed;

  const DashboardView({
    super.key,
    required this.viewModel,
    required this.onAddMoneyPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color.fromARGB(223, 235, 240, 240),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  _buildBalanceCard(context),
                  const SizedBox(height: 32),
                  _buildYourCardsHeader(context),
                  const SizedBox(height: 16),
                  _buildCardsList(context),
                  const SizedBox(height: 32),
                  _buildTransactionsHeader(context),
                  const SizedBox(height: 16),
                  _buildTransactionsList(context),
                  const SizedBox(
                    height: 100,
                  ), // Space for bottom navigation bar
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good morning, Terry',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Welcome to Neobank',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        // Notification bell icon with green circle badge
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight, width: 1.5),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.charcoal,
                size: 24,
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.neonLime,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
    final formattedBalance =
        '\$${viewModel.balance.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your balance',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: Icon(
                  viewModel.isBalanceVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                onPressed: viewModel.toggleBalanceVisibility,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            viewModel.isBalanceVisible ? formattedBalance : '\$ ••••••',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onAddMoneyPressed,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.charcoal,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  'Add money',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourCardsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Your cards',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, size: 16, color: AppColors.charcoal),
          label: Text(
            'New card',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildCardsList(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: viewModel.cards.length,
        itemBuilder: (context, index) {
          final card = viewModel.cards[index];
          return Padding(
            padding: EdgeInsets.only(right: 16, left: index == 0 ? 0 : 0),
            child: _buildCardWidget(context, card),
          );
        },
      ),
    );
  }

  Widget _buildCardWidget(BuildContext context, CardModel card) {
    final isNeon = card.backgroundColor.value == const Color(0xFFC9F158).value;
    final isDark = card.backgroundColor.value == const Color(0xFF202020).value;
    final textColor = isNeon ? AppColors.charcoal : AppColors.white;

    return Container(
      width: 280,
      height: 180,
      decoration: BoxDecoration(
        color: card.backgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: AppColors.charcoal.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          // Background repeated text pattern for Lime Green card
          if (isNeon)
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Center(
                  child: Transform.rotate(
                    angle: -0.15,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: List.generate(12, (index) {
                        return Text(
                          card.textPattern,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.charcoal,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          // Background lines pattern for Dark card
          if (isDark)
            Positioned.fill(child: CustomPaint(painter: CardLinesPainter())),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'N.',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (card.brand == 'Mastercard')
                      _buildMastercardLogo()
                    else if (card.brand == 'Visa')
                      Text(
                        'VISA',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Icon(Icons.account_balance_rounded, color: textColor),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.cardType,
                      style: TextStyle(
                        color: textColor.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '•••• ${card.cardNumber}',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(width: 8), // Minimal gap
                          if (isNeon)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.remove_red_eye_outlined,
                                    size: 14,
                                    color: AppColors.charcoal,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Details',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: AppColors.charcoal,
                                          fontSize: 11,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMastercardLogo() {
    return SizedBox(
      width: 30,
      height: 20,
      child: Stack(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFFEB001B),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            left: 10,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFF79E1B).withOpacity(0.85),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Transactions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            'See all',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: viewModel.transactions.length,
      itemBuilder: (context, index) {
        final tx = viewModel.transactions[index];
        final isNegative = tx.amount < 0;
        final amountText =
            '${isNegative ? '-' : '+'}\$${tx.amount.abs().toStringAsFixed(2)}';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(tx.icon, color: AppColors.charcoal, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.merchant,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx.date,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (tx.cashback != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neonLime.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tx.cashback!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF7CA018),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Custom Painter to draw modern stripe lines on Credit Card
class CardLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withOpacity(0.04)
      ..strokeWidth = 24
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (double i = -50; i < size.width + 50; i += 45) {
      path.moveTo(i, -20);
      path.lineTo(i + 80, size.height + 20);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
