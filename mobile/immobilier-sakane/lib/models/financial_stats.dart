class FinancialStats {
  final StatsSummary summary;
  final OccupancyStats occupancy;
  final List<PeriodRevenue> revenueByPeriod;
  final List<FinancialTransactionItem> transactions;
  final ClientStats clients;
  final List<PropertyComparative> comparative;
  final List<StatAlert> alerts;

  /// Les opérations de caisse de la période. Nul avec un serveur qui ne
  /// les renvoie pas encore : la section est alors masquée.
  final CaisseStats? caisse;

  FinancialStats({
    required this.summary,
    required this.occupancy,
    required this.revenueByPeriod,
    required this.transactions,
    required this.clients,
    required this.comparative,
    required this.alerts,
    this.caisse,
  });

  factory FinancialStats.fromJson(Map<String, dynamic> json) {
    return FinancialStats(
      summary: StatsSummary.fromJson(json['summary'] ?? {}),
      occupancy: OccupancyStats.fromJson(json['occupancy'] ?? {}),
      revenueByPeriod: (json['revenueByPeriod'] as List? ?? [])
          .map((e) => PeriodRevenue.fromJson(e))
          .toList(),
      transactions: (json['transactions'] as List? ?? [])
          .map((e) => FinancialTransactionItem.fromJson(e))
          .toList(),
      clients: ClientStats.fromJson(json['clients'] ?? {}),
      comparative: (json['comparative'] as List? ?? [])
          .map((e) => PropertyComparative.fromJson(e))
          .toList(),
      alerts: (json['alerts'] as List? ?? [])
          .map((e) => StatAlert.fromJson(e))
          .toList(),
      caisse: json['caisse'] is Map
          ? CaisseStats.fromJson(Map<String, dynamic>.from(json['caisse']))
          : null,
    );
  }
}

class StatsSummary {
  final double totalIncome;
  final double totalExpenses;
  final double totalExpenseReversals;
  final double totalRefunds;
  final double totalCancellations;
  final double netProfit;

  /// TVA des factures appliquees, deja comprise dans [totalIncome].
  final double totalTva;

  /// Revenus des reservations Airbnb, deja compris dans [totalIncome].
  final double totalAirbnb;

  StatsSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalExpenseReversals,
    required this.totalRefunds,
    required this.totalCancellations,
    required this.netProfit,
    this.totalTva = 0,
    this.totalAirbnb = 0,
  });

  static double _nombre(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().trim().replaceAll(' ', '').replaceAll(',', '.') ?? '') ?? 0;
  }

  factory StatsSummary.fromJson(Map<String, dynamic> json) => StatsSummary(
        totalIncome: (json['totalIncome'] ?? 0).toDouble(),
        totalExpenses: (json['totalExpenses'] ?? 0).toDouble(),
        totalExpenseReversals: (json['totalExpenseReversals'] ?? 0).toDouble(),
        totalRefunds: (json['totalRefunds'] ?? 0).toDouble(),
        totalCancellations: (json['totalCancellations'] ?? 0).toDouble(),
        netProfit: (json['netProfit'] ?? 0).toDouble(),
        totalTva: _nombre(json['totalTva']),
        totalAirbnb: _nombre(json['totalAirbnb']),
      );
}

class OccupancyStats {
  final int totalDays;
  final int reservedDays;
  final int nonReservedDays;
  final double rate;
  final List<PropertyOccupancy> byProperty;

  OccupancyStats({
    required this.totalDays,
    required this.reservedDays,
    required this.nonReservedDays,
    required this.rate,
    required this.byProperty,
  });

  factory OccupancyStats.fromJson(Map<String, dynamic> json) => OccupancyStats(
        totalDays: (json['totalDays'] ?? 0).toInt(),
        reservedDays: (json['reservedDays'] ?? 0).toInt(),
        nonReservedDays: (json['nonReservedDays'] ?? 0).toInt(),
        rate: (json['rate'] ?? 0.0).toDouble(),
        byProperty: (json['byProperty'] as List? ?? [])
            .map((e) => PropertyOccupancy.fromJson(e))
            .toList(),
      );
}

class PropertyOccupancy {
  final int id;
  final String title;
  final int totalDays;
  final int reservedDays;
  final int nonReservedDays;
  final double rate;

  PropertyOccupancy({
    required this.id,
    required this.title,
    required this.totalDays,
    required this.reservedDays,
    required this.nonReservedDays,
    required this.rate,
  });

  factory PropertyOccupancy.fromJson(Map<String, dynamic> json) =>
      PropertyOccupancy(
        id: json['id'],
        title: json['title'] ?? '',
        totalDays: (json['totalDays'] ?? 0).toInt(),
        reservedDays: (json['reservedDays'] ?? 0).toInt(),
        nonReservedDays: (json['nonReservedDays'] ?? 0).toInt(),
        rate: (json['rate'] ?? 0.0).toDouble(),
      );
}

class PeriodRevenue {
  final String period;
  final double income;
  final double expenses;
  final double refunds;

  PeriodRevenue({
    required this.period,
    required this.income,
    required this.expenses,
    required this.refunds,
  });

  factory PeriodRevenue.fromJson(Map<String, dynamic> json) => PeriodRevenue(
        period: json['period'] ?? '',
        income: (json['income'] ?? 0).toDouble(),
        expenses: (json['expenses'] ?? 0).toDouble(),
        refunds: (json['refunds'] ?? 0).toDouble(),
      );
}

class FinancialTransactionItem {
  final String date;
  final String type;
  final double amount;
  final String description;

  /// Qui a saisi l'écriture, quand on le sait.
  final String? par;

  FinancialTransactionItem({
    required this.date,
    required this.type,
    required this.amount,
    required this.description,
    this.par,
  });

  factory FinancialTransactionItem.fromJson(Map<String, dynamic> json) =>
      FinancialTransactionItem(
        date: json['date'] ?? '',
        type: json['type'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
        description: json['description'] ?? '',
        par: json['par'],
      );
}

class ClientStats {
  final int total;
  final int newClients;
  final int returning;

  ClientStats({
    required this.total,
    required this.newClients,
    required this.returning,
  });

  factory ClientStats.fromJson(Map<String, dynamic> json) => ClientStats(
        total: (json['total'] ?? 0).toInt(),
        newClients: (json['new'] ?? 0).toInt(),
        returning: (json['returning'] ?? 0).toInt(),
      );
}

class PropertyComparative {
  final int id;
  final String title;
  final int reservedDays;
  final int nonReservedDays;
  final double revenue;
  final double expenses;
  final double refunds;
  final double cancellations;
  final double profit;

  PropertyComparative({
    required this.id,
    required this.title,
    required this.reservedDays,
    required this.nonReservedDays,
    required this.revenue,
    required this.expenses,
    required this.refunds,
    required this.cancellations,
    required this.profit,
  });

  factory PropertyComparative.fromJson(Map<String, dynamic> json) =>
      PropertyComparative(
        id: json['id'],
        title: json['title'] ?? '',
        reservedDays: (json['reservedDays'] ?? 0).toInt(),
        nonReservedDays: (json['nonReservedDays'] ?? 0).toInt(),
        revenue: (json['revenue'] ?? 0).toDouble(),
        expenses: (json['expenses'] ?? 0).toDouble(),
        refunds: (json['refunds'] ?? 0).toDouble(),
        cancellations: (json['cancellations'] ?? 0).toDouble(),
        profit: (json['profit'] ?? 0).toDouble(),
      );
}

class StatAlert {
  final String type;
  final String priority;
  final String color;
  final String message;

  StatAlert({
    required this.type,
    required this.priority,
    required this.color,
    required this.message,
  });

  factory StatAlert.fromJson(Map<String, dynamic> json) => StatAlert(
        type: json['type'] ?? '',
        priority: json['priority'] ?? 'medium',
        color: json['color'] ?? 'orange',
        message: json['message'] ?? '',
      );
}


// ── Les opérations de caisse ─────────────────────────────────────────

double _nombreCaisse(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int? _entierCaisse(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

String? _texteCaisse(dynamic v) {
  final t = v?.toString();
  return t == null || t.trim().isEmpty ? null : t;
}

List<Map<String, dynamic>> _listeCaisse(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

/// Ce qui est entré et sorti des caisses sur la période.
class CaisseStats {
  final double entrees;
  final double sorties;
  final double net;
  final List<CaisseMotifStat> parMotif;

  /// Du plus récent au plus ancien, 500 au plus.
  final List<CaisseOperation> mouvements;

  const CaisseStats({
    this.entrees = 0,
    this.sorties = 0,
    this.net = 0,
    this.parMotif = const [],
    this.mouvements = const [],
  });

  bool get estVide => mouvements.isEmpty && parMotif.isEmpty &&
      entrees.abs() < 0.005 && sorties.abs() < 0.005;

  factory CaisseStats.fromJson(Map<String, dynamic> json) => CaisseStats(
        entrees: _nombreCaisse(json['entrees']),
        sorties: _nombreCaisse(json['sorties']),
        net: _nombreCaisse(json['net']),
        parMotif:
            _listeCaisse(json['parMotif']).map(CaisseMotifStat.fromJson).toList(),
        mouvements:
            _listeCaisse(json['mouvements']).map(CaisseOperation.fromJson).toList(),
      );
}

class CaisseMotifStat {
  final String motif;
  final String libelle;
  final String sens;
  final int nombre;
  final double total;

  const CaisseMotifStat({
    required this.motif,
    required this.libelle,
    required this.sens,
    this.nombre = 0,
    this.total = 0,
  });

  bool get estEntree => sens != 'sortie';

  factory CaisseMotifStat.fromJson(Map<String, dynamic> json) =>
      CaisseMotifStat(
        motif: json['motif']?.toString() ?? '',
        libelle: _texteCaisse(json['libelle']) ??
            _texteCaisse(json['motif']) ??
            '—',
        sens: json['sens']?.toString() ?? 'entree',
        nombre: _entierCaisse(json['nombre']) ?? 0,
        total: _nombreCaisse(json['total']),
      );
}

class CaisseOperation {
  final int id;
  final DateTime? date;

  /// Le nom de la caisse.
  final String caisse;

  /// agent | agence | banque | airbnb
  final String caisseType;
  final String sens;
  final double montant;
  final String motif;
  final String libelle;
  final String? commentaire;
  final int? bookingId;
  final String? par;

  const CaisseOperation({
    required this.id,
    this.date,
    required this.caisse,
    this.caisseType = 'agent',
    required this.sens,
    required this.montant,
    this.motif = '',
    this.libelle = '',
    this.commentaire,
    this.bookingId,
    this.par,
  });

  bool get estEntree => sens != 'sortie';

  factory CaisseOperation.fromJson(Map<String, dynamic> json) =>
      CaisseOperation(
        id: _entierCaisse(json['id']) ?? 0,
        date: DateTime.tryParse(json['date']?.toString() ?? '')?.toLocal(),
        caisse: _texteCaisse(json['caisse']) ?? '—',
        caisseType: json['caisseType']?.toString() ?? 'agent',
        sens: json['sens']?.toString() ?? 'entree',
        montant: _nombreCaisse(json['montant']),
        motif: json['motif']?.toString() ?? '',
        libelle: json['libelle']?.toString() ?? '',
        commentaire: _texteCaisse(json['commentaire']),
        bookingId: _entierCaisse(json['bookingId']),
        par: _texteCaisse(json['par']),
      );
}
