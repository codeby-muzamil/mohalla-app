import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Zakat Calculator: 2.5% on cash, gold, silver and trade goods above
/// the Nisab. Nisab = 52.5 tola silver OR 7.5 tola gold (whichever the
/// user follows — the app shows both). Amounts are entered in PKR.
/// This is a calculator, not a fatwa — the note says to confirm with
/// a local scholar for complex cases.
class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});

  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  final _cash = TextEditingController();
  final _gold = TextEditingController();
  final _silver = TextEditingController();
  final _trade = TextEditingController();
  final _debts = TextEditingController();
  final _goldRateCtrl = TextEditingController();
  final _silverRateCtrl = TextEditingController();
  double _goldRate = 0; // PKR per tola
  double _silverRate = 0; // PKR per tola
  double? _zakat;
  String? _message;

  @override
  void dispose() {
    _cash.dispose();
    _gold.dispose();
    _silver.dispose();
    _trade.dispose();
    _debts.dispose();
    _goldRateCtrl.dispose();
    _silverRateCtrl.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text) ?? 0;

  void _calculate() {
    final cash = _num(_cash);
    final goldTola = _num(_gold);
    final silverTola = _num(_silver);
    final trade = _num(_trade);
    final debts = _num(_debts);
    final goldValue = goldTola * _goldRate;
    final silverValue = silverTola * _silverRate;
    final total = cash + goldValue + silverValue + trade - debts;
    // Nisab in PKR: silver nisab (52.5 tola) is the lower threshold
    // used by most scholars for cash.
    final nisabSilver = 52.5 * _silverRate;
    final nisabGold = 7.5 * _goldRate;
    setState(() {
      if (_silverRate <= 0 || _goldRate <= 0) {
        _message =
            'First enter today\'s gold/silver rate (PKR per tola).';
        _zakat = null;
        return;
      }
      if (total < nisabSilver) {
        _message =
            'Total wealth is Rs ${total.toStringAsFixed(0)} — below the silver nisab '
            '(Rs ${nisabSilver.toStringAsFixed(0)}), so Zakat is not due. '
            '(Gold nisab: Rs ${nisabGold.toStringAsFixed(0)}.)';
        _zakat = 0;
        return;
      }
      _zakat = total * 0.025;
      _message =
          'Total wealth: Rs ${total.toStringAsFixed(0)} (above the nisab of Rs ${nisabSilver.toStringAsFixed(0)}). '
          'Zakat is 2.5%.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppTheme.mutedDark : AppTheme.mutedLight;
    final gold = isDark ? AppTheme.goldDark : AppTheme.gold;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 92),
      children: [
        const SectionTitle(
          title: 'Zakat Calculator',
          subtitle:
              '2.5% — on wealth held for a year. For difficult cases, ask a mufti.',
        ),
        // Grouped into cards with section headers: the old single
        // column of 7 bare fields with long labels looked unaligned,
        // and long labels clipped at 1.3x elder text. Labels are now
        // short; the unit lives in helperText below the field.
        _FieldGroup(
          title: 'Cash and trade',
          icon: Icons.account_balance_wallet,
          children: [
            _moneyField(_cash, 'Cash', helper: 'In PKR'),
            _moneyField(_trade, 'Trade goods', helper: 'Value — in PKR'),
            _moneyField(_debts, 'Debts / owed', helper: 'In PKR — deducted from the total'),
          ],
        ),
        const SizedBox(height: 12),
        _FieldGroup(
          title: 'Gold and silver',
          icon: Icons.diamond,
          children: [
            _moneyField(_gold, 'Gold', helper: 'In tola'),
            _moneyField(_silver, 'Silver', helper: 'In tola'),
          ],
        ),
        const SizedBox(height: 12),
        _FieldGroup(
          title: "Today's rates",
          icon: Icons.trending_up,
          children: [
            _moneyField(
              _goldRateCtrl,
              'Gold rate',
              helper: 'PKR per tola',
              onChanged: (v) => _goldRate = double.tryParse(v) ?? 0,
            ),
            _moneyField(
              _silverRateCtrl,
              'Silver rate',
              helper: 'PKR per tola',
              onChanged: (v) => _silverRate = double.tryParse(v) ?? 0,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Enter today's market rate (from the bullion market / news).",
          style: TextStyle(fontSize: 12, color: muted),
        ),
        const SizedBox(height: 12),
        GoldButton(
          label: 'Calculate Zakat',
          onPressed: _calculate,
          icon: Icons.calculate,
        ),
        const SizedBox(height: 16),
        if (_message != null)
          Card(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: gold.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.calculate,
                          color: accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Result',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_message!),
                  if (_zakat != null && _zakat! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Zakat: Rs ${_zakat!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: gold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SampleNote(
          text:
              'Nisab: 52.5 tola silver or 7.5 tola gold. This calculator '
              'is for guidance only — not a fatwa.',
        ),
      ],
    );
  }

  Widget _moneyField(
    TextEditingController c,
    String label, {
    String? helper,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
        ),
      ),
    );
  }
}

/// A labelled card grouping related Zakat inputs.
class _FieldGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FieldGroup({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppTheme.goldDark : AppTheme.emerald;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
