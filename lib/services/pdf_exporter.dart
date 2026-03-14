import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/wfp_entry.dart';
import '../models/budget_activity.dart';
import '../utils/currency_formatter.dart';

/// Generates PDF summary reports — mirrors the Excel layout but formatted
/// for print/viewing. Uses the `pdf` Flutter package.
class PdfExporter {
  PdfExporter._();

  // ─── Shared styles ──────────────────────────────────────────────────────

  static final _headerBg  = PdfColor.fromHex('#2F3E46');
  static final _accentBg  = PdfColor.fromHex('#3A7CA5');
  static final _lightBg   = PdfColor.fromHex('#E8EEF2');
  static final _white      = PdfColors.white;
  static final _textDark   = PdfColor.fromHex('#1A1A1A');
  static final _textMuted  = PdfColor.fromHex('#666666');
  static final _green      = PdfColor.fromHex('#2D6A4F');
  static final _red        = PdfColor.fromHex('#B00020');

  // ─── Currency symbol → ASCII code map ───────────────────────────────────
  //
  // The pdf package uses Helvetica by default which only covers Latin-1.
  // Unicode currency symbols (₱ ¥ ₩ ₹ etc.) render as boxes.
  // Map each symbol to its plain-text ISO code so the PDF stays clean.

  static const _symbolToCode = <String, String>{
    '₱':  'PHP',
    '\$': 'USD',
    '€':  'EUR',
    '£':  'GBP',
    '¥':  'JPY',
    '₩':  'KRW',
    '₹':  'INR',
    '฿':  'THB',
    '₫':  'VND',
    '₴':  'UAH',
    '₺':  'TRY',
    '₦':  'NGN',
    '₲':  'PYG',
    '₡':  'CRC',
    '₸':  'KZT',
    '₼':  'AZN',
    '₾':  'GEL',
  };

  /// Formats [amount] for PDF output, replacing any Unicode currency symbol
  /// with its ASCII ISO code (e.g. ₱1,234.56 → PHP 1,234.56).
  static String _fmt(double amount) {
    final raw    = CurrencyFormatter.format(amount); // e.g. "₱1,234.56"
    final symbol = CurrencyFormatter.symbol;
    final code   = _symbolToCode[symbol];
    if (code != null) {
      // Replace the leading symbol with the ASCII code + space
      return raw.replaceFirst(symbol, '$code ');
    }
    // Symbol is already ASCII-safe (e.g. user typed "USD" themselves)
    return raw;
  }

  // ─── Single Report ──────────────────────────────────────────────────────

  static Future<String> exportSummaryReportPDF({
    required WFPEntry wfp,
    required List<BudgetActivity> activities,
    String operatingUnit = 'Department of Education',
  }) async {
    final doc = pw.Document(
      title:   'Summary Report - ${wfp.id}',
      author:  operatingUnit,
      subject: wfp.title,
    );

    final totalAR        = activities.fold<double>(0, (s, a) => s + a.total);
    final totalProjected = activities.fold<double>(0, (s, a) => s + a.projected);
    final totalDisbursed = activities.fold<double>(0, (s, a) => s + a.disbursed);
    final totalBalance   = activities.fold<double>(0, (s, a) => s + a.balance);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _pageHeader(ctx, wfp.id),
      footer: (ctx) => _pageFooter(ctx),
      build: (ctx) => [
        // ── Title ───────────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          color: _headerBg,
          child: pw.Center(
            child: pw.Text('SUMMARY REPORT',
              style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold,
                color: _white, letterSpacing: 2)),
          ),
        ),
        pw.SizedBox(height: 16),

        // ── Header block ─────────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _lightBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _headerRow('Operating Unit:', operatingUnit),
                  pw.SizedBox(height: 5),
                  _headerRow('Program:', wfp.title),
                  pw.SizedBox(height: 5),
                  _headerRow('Approval:', wfp.approvalStatus),
                  if (wfp.approvedDate != null) ...[
                    pw.SizedBox(height: 5),
                    _headerRow('Approved On:', wfp.approvedDate!),
                  ],
                ],
              )),
              pw.SizedBox(width: 20),
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _headerRow('Fund Type:', wfp.fundType),
                  pw.SizedBox(height: 5),
                  _headerRow('Title:', wfp.title),
                  pw.SizedBox(height: 5),
                  _headerRow('Indicator:', wfp.indicator),
                  if (wfp.dueDate != null) ...[
                    pw.SizedBox(height: 5),
                    _headerRow('Due Date:', wfp.dueDate!),
                  ],
                ],
              )),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // ── Financial summary ─────────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(children: [
            _summaryRow('Total AR Amount:',
                _fmt(totalAR)),
            _summaryRow('Total AR Amount (Projected/Obligated):',
                _fmt(totalProjected)),
            _summaryRow('Total AR Disbursed:',
                _fmt(totalDisbursed)),
            _summaryRow('Total AR Balance:',
                _fmt(totalBalance),
              valueColor: totalBalance >= 0 ? _green : _red),
          ]),
        ),
        pw.SizedBox(height: 16),

        // ── Activities section ────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: _accentBg,
          child: pw.Text('BUDGET ACTIVITIES',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold,
              color: _white, letterSpacing: 1)),
        ),
        pw.SizedBox(height: 8),

        if (activities.isEmpty)
          pw.Text('No activities linked to this WFP entry.',
            style: pw.TextStyle(fontSize: 10, color: _textMuted))
        else
          _activitiesTable(
              activities, totalAR, totalProjected, totalDisbursed, totalBalance),
      ],
    ));

    return _savePDF(doc, 'SummaryReport_${wfp.id}');
  }

  // ─── Grouped Report ──────────────────────────────────────────────────────

  static Future<String> exportGroupedReportPDF({
    required List<WFPEntry> wfps,
    required Map<String, List<BudgetActivity>> activitiesMap,
    required String groupLabel,
    String operatingUnit = 'Department of Education',
  }) async {
    final displayLabel = groupLabel.replaceAll('_', ' ');

    final doc = pw.Document(
      title:  'Grouped Report - $displayLabel',
      author: operatingUnit,
    );

    double grandAR = 0, grandProjected = 0, grandDisbursed = 0, grandBalance = 0;
    for (final wfp in wfps) {
      final acts = activitiesMap[wfp.id] ?? [];
      grandAR        += acts.fold(0, (s, a) => s + a.total);
      grandProjected += acts.fold(0, (s, a) => s + a.projected);
      grandDisbursed += acts.fold(0, (s, a) => s + a.disbursed);
      grandBalance   += acts.fold(0, (s, a) => s + a.balance);
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _pageHeader(ctx, 'Grouped: $displayLabel'),
      footer: (ctx) => _pageFooter(ctx),
      build: (ctx) => [
        // Title
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 10),
          color: _headerBg,
          child: pw.Center(child: pw.Text(
            'GROUPED SUMMARY REPORT - $displayLabel',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold,
              color: _white, letterSpacing: 1.5))),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          '$operatingUnit  |  ${wfps.length} WFP entr${wfps.length == 1 ? 'y' : 'ies'}',
          style: pw.TextStyle(fontSize: 10, color: _textMuted)),
        pw.SizedBox(height: 16),

        // Grand totals summary
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          color: _lightBg,
          child: pw.Column(children: [
            _summaryRow('Grand Total AR:',   _fmt(grandAR)),
            _summaryRow('Grand Projected:',  _fmt(grandProjected)),
            _summaryRow('Grand Disbursed:',  _fmt(grandDisbursed)),
            _summaryRow('Grand Balance:',    _fmt(grandBalance),
              valueColor: grandBalance >= 0 ? _green : _red),
          ]),
        ),
        pw.SizedBox(height: 20),

        // Each WFP section — wrapped in pw.Column so MultiPage treats the
        // entire block as one unit and never splits it mid-section.
        ...wfps.map((wfp) {
          final acts           = activitiesMap[wfp.id] ?? [];
          final totalAR        = acts.fold<double>(0, (s, a) => s + a.total);
          final totalProjected = acts.fold<double>(0, (s, a) => s + a.projected);
          final totalDisbursed = acts.fold<double>(0, (s, a) => s + a.disbursed);
          final totalBalance   = acts.fold<double>(0, (s, a) => s + a.balance);

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                color: _accentBg,
                child: pw.Text(
                  '${wfp.id}  -  ${wfp.title}  [${wfp.fundType} ${wfp.year}]',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
                    color: _white)),
              ),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _headerRow('Operating Unit:', operatingUnit),
                    pw.SizedBox(height: 4),
                    _headerRow('Approval:', wfp.approvalStatus),
                  ],
                )),
                pw.SizedBox(width: 16),
                pw.Expanded(child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _headerRow('Fund Type:', wfp.fundType),
                    pw.SizedBox(height: 4),
                    _headerRow('Amount:', _fmt(wfp.amount)),
                  ],
                )),
              ]),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                pw.Expanded(child: _miniSummaryChip(
                    'Total AR', _fmt(totalAR))),
                pw.SizedBox(width: 6),
                pw.Expanded(child: _miniSummaryChip(
                    'Disbursed', _fmt(totalDisbursed))),
                pw.SizedBox(width: 6),
                pw.Expanded(child: _miniSummaryChip(
                    'Balance', _fmt(totalBalance),
                  valueColor: totalBalance >= 0 ? _green : _red)),
              ]),
              pw.SizedBox(height: 8),
              if (acts.isNotEmpty)
                _activitiesTable(
                    acts, totalAR, totalProjected, totalDisbursed, totalBalance),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 12),
            ],
          );
        }),
      ],
    ));

    return _savePDF(doc, 'GroupedReport_$groupLabel');
  }

  // ─── Shared PDF widgets ──────────────────────────────────────────────────

  static pw.Widget _pageHeader(pw.Context ctx, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400))),
      child: pw.Row(children: [
        pw.Text('PIMS DepED',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
            color: _headerBg)),
        pw.Spacer(),
        pw.Text(subtitle,
          style: pw.TextStyle(fontSize: 9, color: _textMuted)),
      ]),
    );
  }

  static pw.Widget _pageFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400))),
      child: pw.Row(children: [
        pw.Text('Generated by PIMS DepED',
          style: pw.TextStyle(fontSize: 8, color: _textMuted)),
        pw.Spacer(),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: _textMuted)),
      ]),
    );
  }

  static pw.Widget _headerRow(String label, String value) {
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(width: 90,
        child: pw.Text(label, style: pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textMuted))),
      pw.Expanded(child: pw.Text(value,
        style: pw.TextStyle(fontSize: 9, color: _textDark))),
    ]);
  }

  static pw.Widget _summaryRow(String label, String value,
      {PdfColor? valueColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(label, style: pw.TextStyle(
          fontSize: 10, fontWeight: pw.FontWeight.bold, color: _textDark))),
        pw.Text(value, style: pw.TextStyle(
          fontSize: 10, fontWeight: pw.FontWeight.bold,
          color: valueColor ?? _headerBg)),
      ]),
    );
  }

  static pw.Widget _miniSummaryChip(String label, String value,
      {PdfColor? valueColor}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: pw.BoxDecoration(
        color: _lightBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _textMuted)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(
            fontSize: 9, fontWeight: pw.FontWeight.bold,
            color: valueColor ?? _headerBg)),
        ]),
    );
  }

  static pw.Widget _activitiesTable(
    List<BudgetActivity> activities,
    double totalAR, double totalProjected, double totalDisbursed,
    double totalBalance,
  ) {
    const colWidths = [2.0, 3.0, 1.8, 1.8, 1.8, 1.8, 1.5];
    final headers = [
      'Activity ID', 'Name', 'Total AR', 'Projected',
      'Disbursed', 'Balance', 'Status',
    ];

    return pw.Table(
      columnWidths: {
        for (int i = 0; i < colWidths.length; i++)
          i: pw.FlexColumnWidth(colWidths[i]),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _headerBg),
          children: headers.map((h) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(h, style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold, color: _white)),
          )).toList(),
        ),
        // Data rows
        ...activities.asMap().entries.map((entry) {
          final i  = entry.key;
          final a  = entry.value;
          final bg = i.isEven ? PdfColors.white : PdfColors.grey100;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              a.id, a.name,
              _fmt(a.total),
              _fmt(a.projected),
              _fmt(a.disbursed),
              _fmt(a.balance),
              a.status,
            ].map((v) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Text(v,
                style: pw.TextStyle(fontSize: 8, color: _textDark)),
            )).toList(),
          );
        }),
        // Totals row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _lightBg),
          children: [
            'TOTAL', '',
            _fmt(totalAR),
            _fmt(totalProjected),
            _fmt(totalDisbursed),
            _fmt(totalBalance),
            '',
          ].map((v) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: pw.Text(v, style: pw.TextStyle(
              fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textDark)),
          )).toList(),
        ),
      ],
    );
  }

  // ─── Save helper ──────────────────────────────────────────────────────────

  static Future<String> _savePDF(pw.Document doc, String baseName) async {
    final dir      = await getApplicationDocumentsDirectory();
    final safeName = baseName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final filePath = p.join(dir.path, '$safeName.pdf');
    final file     = File(filePath);
    await file.writeAsBytes(await doc.save());
    return filePath;
  }
}