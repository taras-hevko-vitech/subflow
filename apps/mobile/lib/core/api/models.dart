// Plain models decoded from the API (contract lives in the backend OpenAPI; kept hand-written
// for the skeleton, will be generated from /openapi.json when the surface stabilizes).

class BackfillProgress {
  BackfillProgress({required this.totalWindows, required this.completedWindows, required this.done});

  factory BackfillProgress.fromJson(Map<String, dynamic> j) => BackfillProgress(
        totalWindows: (j['totalWindows'] as num).toInt(),
        completedWindows: (j['completedWindows'] as num).toInt(),
        done: j['done'] as bool,
      );

  final int totalWindows;
  final int completedWindows;
  final bool done;

  double get fraction => totalWindows == 0 ? 0 : completedWindows / totalWindows;
}

class Connection {
  Connection({required this.id, required this.provider, required this.status, required this.backfill});

  factory Connection.fromJson(Map<String, dynamic> j) => Connection(
        id: j['id'] as String,
        provider: j['provider'] as String,
        status: j['status'] as String,
        backfill: BackfillProgress.fromJson(j['backfill'] as Map<String, dynamic>),
      );

  final String id;
  final String provider;
  final String status; // active | revoked | error
  final BackfillProgress backfill;

  bool get isActive => status == 'active';
}

class BankAccountView {
  BankAccountView({
    required this.id,
    required this.type,
    required this.currencyCode,
    required this.maskedPan,
    required this.isTracked,
  });

  factory BankAccountView.fromJson(Map<String, dynamic> j) => BankAccountView(
        id: j['id'] as String,
        type: j['type'] as String?,
        currencyCode: (j['currencyCode'] as num).toInt(),
        maskedPan: j['maskedPan'] as String?,
        isTracked: j['isTracked'] as bool,
      );

  final String id;
  final String? type;
  final int currencyCode;
  final String? maskedPan;
  bool isTracked;

  bool get isFop => type == 'fop';
}

class ConnectResult {
  ConnectResult({required this.connectionId, required this.accounts});

  factory ConnectResult.fromJson(Map<String, dynamic> j) => ConnectResult(
        connectionId: j['connectionId'] as String,
        accounts: (j['accounts'] as List<dynamic>).map((a) => BankAccountView.fromJson(a as Map<String, dynamic>)).toList(),
      );

  final String connectionId;
  final List<BankAccountView> accounts;
}

class MerchantView {
  MerchantView({required this.displayName, this.logoUrl, this.cancelUrl, this.cancelInstructions, required this.isSeed});

  factory MerchantView.fromJson(Map<String, dynamic> j) => MerchantView(
        displayName: j['displayName'] as String,
        logoUrl: j['logoUrl'] as String?,
        cancelUrl: j['cancelUrl'] as String?,
        cancelInstructions: j['cancelInstructions'] as String?,
        isSeed: j['isSeed'] as bool,
      );

  final String displayName;
  final String? logoUrl;
  final String? cancelUrl;
  final String? cancelInstructions;
  final bool isSeed;
}

class SubscriptionView {
  SubscriptionView({
    required this.id,
    required this.merchant,
    required this.cadence,
    required this.amountMinor,
    required this.currencyCode,
    required this.monthlyEqMinor,
    required this.confidence,
    required this.status,
    required this.nextChargeAt,
  });

  factory SubscriptionView.fromJson(Map<String, dynamic> j) => SubscriptionView(
        id: j['id'] as String,
        merchant: MerchantView.fromJson(j['merchant'] as Map<String, dynamic>),
        cadence: j['cadence'] as String,
        amountMinor: (j['amountMinor'] as num).toInt(),
        currencyCode: (j['currencyCode'] as num).toInt(),
        monthlyEqMinor: (j['monthlyEqMinor'] as num).toInt(),
        confidence: (j['confidence'] as num).toDouble(),
        status: j['status'] as String,
        nextChargeAt: j['nextChargeAt'] == null ? null : DateTime.tryParse(j['nextChargeAt'] as String),
      );

  final String id;
  final MerchantView merchant;
  final String cadence; // weekly | monthly | yearly
  final int amountMinor;
  final int currencyCode;
  final int monthlyEqMinor;
  final double confidence;
  final String status; // detected | confirmed | container
  final DateTime? nextChargeAt;

  bool get isContainer => status == 'container';
  bool get needsConfirm => confidence < 0.8 && status == 'detected';
}

class SubscriptionsSummary {
  SubscriptionsSummary({required this.totalMonthlyMinor, required this.totalYearlyMinor, required this.currencyCode, required this.items});

  factory SubscriptionsSummary.fromJson(Map<String, dynamic> j) => SubscriptionsSummary(
        totalMonthlyMinor: (j['totalMonthlyMinor'] as num).toInt(),
        totalYearlyMinor: (j['totalYearlyMinor'] as num).toInt(),
        currencyCode: (j['currencyCode'] as num).toInt(),
        items: (j['subscriptions'] as List<dynamic>).map((s) => SubscriptionView.fromJson(s as Map<String, dynamic>)).toList(),
      );

  final int totalMonthlyMinor;
  final int totalYearlyMinor;
  final int currencyCode;
  final List<SubscriptionView> items;
}

/// Minor units → "₴1 234" style. currencyCode 980 = UAH.
String formatMoney(int minor, {int currencyCode = 980}) {
  final major = (minor / 100).round();
  final s = major.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  final symbol = currencyCode == 980 ? '₴' : '';
  return '$symbol$buf';
}
