import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// Фон «тетрадный лист в клетку» с красной линией полей.
class NotebookPaper extends StatelessWidget {
  const NotebookPaper({super.key, required this.child, this.cell = 22, this.showMargin = true});

  final Widget child;
  final double cell;
  final bool showMargin;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(cell: cell, showMargin: showMargin),
      child: child,
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.cell, required this.showMargin});
  final double cell;
  final bool showMargin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Pen.paper);
    final grid = Paint()
      ..color = Pen.grid
      ..strokeWidth = 0.7;
    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (showMargin && size.width > 360) {
      final margin = Paint()
        ..color = Pen.margin
        ..strokeWidth = 1.4;
      final x = cell * 0.5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), margin);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.cell != cell || old.showMargin != showMargin;
}

/// Заголовок, «написанный ручкой».
class PenTitle extends StatelessWidget {
  const PenTitle(this.text, {super.key, this.color = Pen.blue, this.size = 20});
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: Fonts.hand,
        fontFamilyFallback: Fonts.fallback,
        color: color,
        // Caveat визуально мельче — увеличиваем кегль.
        fontSize: size * 1.35,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    ),
  );
}

/// Жёлтый стикер-уведомление.
class Sticker extends StatelessWidget {
  const Sticker({super.key, required this.child, this.onTap, this.color = Pen.sticker});
  final Widget child;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.012,
      child: Material(
        color: color,
        elevation: 3,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
  }
}

/// Счётчик монет-пуговиц.
class ButtonsBadge extends StatelessWidget {
  const ButtonsBadge({super.key, required this.count, this.gold = false});
  final int count;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: gold ? const Color(0xFFFFF3C4) : const Color(0xFFE8EEF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold ? Pen.gold : Pen.grid),
      ),
      child: Text(
        '${gold ? '🟡' : '🔘'} $count',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: gold ? const Color(0xFF8A6500) : Pen.blue,
        ),
      ),
    );
  }
}

/// Ограничивает ширину контента на широких экранах (web).
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.maxWidth = 720});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Pen.red : Pen.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
