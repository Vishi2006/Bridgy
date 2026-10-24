/// Parsed `upi://pay` checkout link, as sent by Blinkit, Rapido and Zepto.
class UpiIntent {
  const UpiIntent({
    required this.merchantVpa,
    required this.merchantName,
    required this.amountInr,
    this.note = '',
  });

  final String merchantVpa;
  final String merchantName;
  final double amountInr;
  final String note;

  /// Returns null when the link is not a usable `upi://pay` request.
  static UpiIntent? parse(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != 'upi') return null;
    if (uri.host.toLowerCase() != 'pay') return null;

    final vpa = (uri.queryParameters['pa'] ?? '').trim();
    final amount = double.tryParse(uri.queryParameters['am'] ?? '');
    if (vpa.isEmpty || amount == null || amount <= 0) return null;

    final name = (uri.queryParameters['pn'] ?? '').trim();
    return UpiIntent(
      merchantVpa: vpa,
      merchantName: name.isEmpty ? vpa : name,
      amountInr: amount,
      note: (uri.queryParameters['tn'] ?? '').trim(),
    );
  }
}
