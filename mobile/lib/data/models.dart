/// Data transfer models that mirror the MONOVA API (camelCase JSON, enums as strings).
/// Amounts are received as decimal numbers from the server and shown with two decimals. The server is the authority for every total.

double _d(Object? v) => v is num ? v.toDouble() : 0.0;
double? _dn(Object? v) => v is num ? v.toDouble() : null;
String _s(Object? v) => v as String? ?? '';
String? _sn(Object? v) => v as String?;
bool _b(Object? v) => v as bool? ?? false;
int _i(Object? v) => v is num ? v.toInt() : 0;
DateTime _dt(Object? v) => DateTime.parse(v as String);
DateTime? _dtn(Object? v) => v == null ? null : DateTime.parse(v as String);

class PagedResult<T> {
  const PagedResult({required this.items, required this.page, required this.totalCount, required this.totalPages});

  final List<T> items;
  final int page;
  final int totalCount;
  final int totalPages;

  static PagedResult<T> parse<T>(Object? json, T Function(Map<String, dynamic>) item) {
    final m = json as Map<String, dynamic>;
    return PagedResult<T>(
      items: (m['items'] as List<dynamic>).map((e) => item(e as Map<String, dynamic>)).toList(),
      page: _i(m['page']),
      totalCount: _i(m['totalCount']),
      totalPages: _i(m['totalPages']),
    );
  }
}

/// Result of asking the server to send a one-time code. devCode is only present on development servers.
class OtpChallengeResult {
  const OtpChallengeResult({required this.phoneNumber, required this.expiresAt, this.devCode});

  final String phoneNumber;
  final DateTime expiresAt;
  final String? devCode;

  factory OtpChallengeResult.fromJson(Map<String, dynamic> j) => OtpChallengeResult(
        phoneNumber: _s(j['phoneNumber']),
        expiresAt: _dt(j['expiresAtUtc']),
        devCode: _sn(j['devCode']),
      );
}

class UserProfile {
  const UserProfile({required this.id, required this.email, required this.phoneNumber, required this.displayName, required this.baseCurrency});

  final String id;
  final String? email;
  final String? phoneNumber;
  final String displayName;
  final String baseCurrency;

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: _s(j['id']),
        email: _sn(j['email']),
        phoneNumber: _sn(j['phoneNumber']),
        displayName: _s(j['displayName']),
        baseCurrency: _s(j['baseCurrency']),
      );
}

class AuthSession {
  const AuthSession({required this.accessToken, required this.refreshToken, required this.user});

  final String accessToken;
  final String refreshToken;
  final UserProfile user;

  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
        accessToken: _s(j['accessToken']),
        refreshToken: _s(j['refreshToken']),
        user: UserProfile.fromJson(j['user'] as Map<String, dynamic>),
      );
}

class AccountItem {
  const AccountItem({
    required this.id,
    required this.name,
    required this.bankName,
    required this.type,
    required this.openingBalance,
    required this.currentBalance,
    required this.isActive,
  });

  final String id;
  final String name;
  final String bankName;
  final String type;
  final double openingBalance;
  final double currentBalance;
  final bool isActive;

  bool get isBank => type == 'Bank' || type == 'Savings';

  factory AccountItem.fromJson(Map<String, dynamic> j) => AccountItem(
        id: _s(j['id']),
        name: _s(j['name']),
        bankName: _s(j['bankName']),
        type: _s(j['type']),
        openingBalance: _d(j['openingBalance']),
        currentBalance: _d(j['currentBalance']),
        isActive: _b(j['isActive']),
      );
}

class AccountMovement {
  const AccountMovement({required this.date, required this.kind, required this.title, required this.amount});

  final DateTime date;
  final String kind;
  final String title;
  final double amount;

  factory AccountMovement.fromJson(Map<String, dynamic> j) => AccountMovement(
        date: _dt(j['date']),
        kind: _s(j['kind']),
        title: _s(j['title']),
        amount: _d(j['amount']),
      );
}

/// A repeating entry (rent, subscription, salary). The server creates the actual entries when they fall due.
class RecurringItem {
  const RecurringItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.title,
    required this.frequency,
    required this.nextRunOn,
    required this.isActive,
  });

  final String id;
  final String type;
  final double amount;
  final String title;
  final String frequency;
  final DateTime nextRunOn;
  final bool isActive;

  factory RecurringItem.fromJson(Map<String, dynamic> j) => RecurringItem(
        id: _s(j['id']),
        type: _s(j['type']),
        amount: _d(j['amount']),
        title: _s(j['title']),
        frequency: _s(j['frequency']),
        nextRunOn: _dt(j['nextRunOn']),
        isActive: _b(j['isActive']),
      );
}

class CategoryItem {
  const CategoryItem({required this.id, required this.name, required this.kind, required this.colorHex});

  final String id;
  final String name;
  final String kind;
  final String colorHex;

  factory CategoryItem.fromJson(Map<String, dynamic> j) => CategoryItem(
        id: _s(j['id']),
        name: _s(j['name']),
        kind: _s(j['kind']),
        colorHex: _s(j['colorHex']),
      );
}

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.occurredOn,
    required this.title,
    required this.note,
    required this.categoryName,
    required this.accountName,
    required this.creditCardName,
    required this.refundOfTransactionId,
    required this.refundedTotal,
    required this.accountId,
    required this.creditCardId,
    required this.categoryId,
  });

  final String id;
  final String type;
  final double amount;
  final DateTime occurredOn;
  final String title;
  final String? note;
  final String? categoryName;
  final String? accountName;
  final String? creditCardName;
  final String? refundOfTransactionId;
  final double refundedTotal;
  final String? accountId;
  final String? creditCardId;
  final String? categoryId;

  bool get isExpense => type == 'Expense';
  bool get isIncome => type == 'Income';
  bool get isRefund => type == 'Refund';

  factory TransactionItem.fromJson(Map<String, dynamic> j) => TransactionItem(
        id: _s(j['id']),
        type: _s(j['type']),
        amount: _d(j['amount']),
        occurredOn: _dt(j['occurredOn']),
        title: _s(j['title']),
        note: _sn(j['note']),
        categoryName: _sn(j['categoryName']),
        accountName: _sn(j['accountName']),
        creditCardName: _sn(j['creditCardName']),
        refundOfTransactionId: _sn(j['refundOfTransactionId']),
        refundedTotal: _d(j['refundedTotal']),
        accountId: _sn(j['accountId']),
        creditCardId: _sn(j['creditCardId']),
        categoryId: _sn(j['categoryId']),
      );
}

class CardItem {
  const CardItem({
    required this.id,
    required this.issuer,
    required this.name,
    required this.last4,
    required this.creditLimit,
    required this.statementDay,
    required this.dueDay,
    required this.isActive,
    required this.outstanding,
    required this.availableCredit,
    required this.utilizationPercent,
    required this.nextDueDate,
    required this.cycleSpend,
  });

  final String id;
  final String issuer;
  final String name;
  final String last4;
  final double creditLimit;
  final int statementDay;
  final int dueDay;
  final bool isActive;
  final double outstanding;
  final double availableCredit;
  final double utilizationPercent;
  final DateTime nextDueDate;
  final double cycleSpend;

  factory CardItem.fromJson(Map<String, dynamic> j) => CardItem(
        id: _s(j['id']),
        issuer: _s(j['issuer']),
        name: _s(j['name']),
        last4: _s(j['last4']),
        creditLimit: _d(j['creditLimit']),
        statementDay: _i(j['statementDay']),
        dueDay: _i(j['dueDay']),
        isActive: _b(j['isActive']),
        outstanding: _d(j['outstanding']),
        availableCredit: _d(j['availableCredit']),
        utilizationPercent: _d(j['utilizationPercent']),
        nextDueDate: _dt(j['nextDueDate']),
        cycleSpend: _d(j['cycleSpend']),
      );
}

class DebtItem {
  const DebtItem({
    required this.id,
    required this.counterparty,
    required this.principal,
    required this.annualRate,
    required this.borrowedOn,
    required this.dueOn,
    required this.accountId,
    required this.totalOutstanding,
    required this.isClosed,
  });

  final String id;
  final String counterparty;
  final double principal;
  final double annualRate;
  final DateTime borrowedOn;
  final DateTime? dueOn;
  final String accountId;
  final double totalOutstanding;
  final bool isClosed;

  factory DebtItem.fromJson(Map<String, dynamic> j) => DebtItem(
        id: _s(j['id']),
        counterparty: _s(j['counterparty']),
        principal: _d(j['principal']),
        annualRate: _d(j['annualInterestRatePercent']),
        borrowedOn: _dt(j['borrowedOn']),
        dueOn: _dtn(j['dueOn']),
        accountId: _s(j['accountId']),
        totalOutstanding: _d(j['totalOutstanding']),
        isClosed: _b(j['isClosed']),
      );
}

class ReceivableItem {
  const ReceivableItem({
    required this.id,
    required this.counterparty,
    required this.principal,
    required this.lentOn,
    required this.expectedOn,
    required this.accountId,
    required this.remaining,
    required this.isClosed,
  });

  final String id;
  final String counterparty;
  final double principal;
  final DateTime lentOn;
  final DateTime? expectedOn;
  final String accountId;
  final double remaining;
  final bool isClosed;

  factory ReceivableItem.fromJson(Map<String, dynamic> j) => ReceivableItem(
        id: _s(j['id']),
        counterparty: _s(j['counterparty']),
        principal: _d(j['principal']),
        lentOn: _dt(j['lentOn']),
        expectedOn: _dtn(j['expectedOn']),
        accountId: _s(j['accountId']),
        remaining: _d(j['remaining']),
        isClosed: _b(j['isClosed']),
      );
}

class InstallmentItem {
  const InstallmentItem({
    required this.number,
    required this.dueOn,
    required this.amount,
    required this.principalComponent,
    required this.interestComponent,
    required this.isPaid,
    required this.paidOn,
  });

  final int number;
  final DateTime dueOn;
  final double amount;
  final double principalComponent;
  final double interestComponent;
  final bool isPaid;
  final DateTime? paidOn;

  factory InstallmentItem.fromJson(Map<String, dynamic> j) => InstallmentItem(
        number: _i(j['number']),
        dueOn: _dt(j['dueOn']),
        amount: _d(j['amount']),
        principalComponent: _d(j['principalComponent']),
        interestComponent: _d(j['interestComponent']),
        isPaid: _b(j['isPaid']),
        paidOn: _dtn(j['paidOn']),
      );
}

class LoanItem {
  const LoanItem({
    required this.id,
    required this.name,
    required this.lender,
    required this.principal,
    required this.annualRate,
    required this.termMonths,
    required this.emiAmount,
    required this.accountId,
    required this.outstanding,
    required this.paidInstallments,
    required this.nextDueOn,
    required this.nextAmount,
    required this.totalInterest,
    required this.isClosed,
    required this.schedule,
  });

  final String id;
  final String name;
  final String lender;
  final double principal;
  final double annualRate;
  final int termMonths;
  final double emiAmount;
  final String accountId;
  final double outstanding;
  final int paidInstallments;
  final DateTime? nextDueOn;
  final double? nextAmount;
  final double totalInterest;
  final bool isClosed;
  final List<InstallmentItem> schedule;

  factory LoanItem.fromJson(Map<String, dynamic> j) => LoanItem(
        id: _s(j['id']),
        name: _s(j['name']),
        lender: _s(j['lender']),
        principal: _d(j['principal']),
        annualRate: _d(j['annualInterestRatePercent']),
        termMonths: _i(j['termMonths']),
        emiAmount: _d(j['emiAmount']),
        accountId: _s(j['accountId']),
        outstanding: _d(j['outstanding']),
        paidInstallments: _i(j['paidInstallments']),
        nextDueOn: _dtn(j['nextDueOn']),
        nextAmount: _dn(j['nextAmount']),
        totalInterest: _d(j['totalInterest']),
        isClosed: _s(j['status']) == 'Closed',
        schedule: (j['schedule'] as List<dynamic>? ?? const [])
            .map((e) => InstallmentItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class BudgetLine {
  const BudgetLine({required this.categoryId, required this.name, required this.budget, required this.spent, required this.percentUsed, required this.status});

  final String? categoryId;
  final String name;
  final double budget;
  final double spent;
  final double percentUsed;
  final String status;

  factory BudgetLine.fromJson(Map<String, dynamic> j) => BudgetLine(
        categoryId: _sn(j['categoryId']),
        name: _s(j['name']),
        budget: _d(j['budget']),
        spent: _d(j['spent']),
        percentUsed: _d(j['percentUsed']),
        status: _s(j['status']),
      );
}

class BudgetSummary {
  const BudgetSummary({
    required this.year,
    required this.month,
    required this.overallBudget,
    required this.overallSpent,
    required this.overallPercentUsed,
    required this.overallStatus,
    required this.lines,
    required this.warnings,
  });

  final int year;
  final int month;
  final double overallBudget;
  final double overallSpent;
  final double overallPercentUsed;
  final String overallStatus;
  final List<BudgetLine> lines;
  final List<String> warnings;

  factory BudgetSummary.fromJson(Map<String, dynamic> j) => BudgetSummary(
        year: _i(j['year']),
        month: _i(j['month']),
        overallBudget: _d(j['overallBudget']),
        overallSpent: _d(j['overallSpent']),
        overallPercentUsed: _d(j['overallPercentUsed']),
        overallStatus: _s(j['overallStatus']),
        lines: (j['lines'] as List<dynamic>? ?? const []).map((e) => BudgetLine.fromJson(e as Map<String, dynamic>)).toList(),
        warnings: (j['warnings'] as List<dynamic>? ?? const []).map((e) => e as String).toList(),
      );
}

class GoalItem {
  const GoalItem({
    required this.id,
    required this.name,
    required this.target,
    required this.targetDate,
    required this.saved,
    required this.remaining,
    required this.percentComplete,
    required this.monthlyNeeded,
  });

  final String id;
  final String name;
  final double target;
  final DateTime? targetDate;
  final double saved;
  final double remaining;
  final double percentComplete;
  final double? monthlyNeeded;

  factory GoalItem.fromJson(Map<String, dynamic> j) => GoalItem(
        id: _s(j['id']),
        name: _s(j['name']),
        target: _d(j['targetAmount']),
        targetDate: _dtn(j['targetDate']),
        saved: _d(j['saved']),
        remaining: _d(j['remaining']),
        percentComplete: _d(j['percentComplete']),
        monthlyNeeded: _dn(j['monthlyNeeded']),
      );
}

class GroupSummary {
  const GroupSummary({required this.id, required this.name, required this.emoji, required this.memberCount, required this.yourNet});

  final String id;
  final String name;
  final String? emoji;
  final int memberCount;
  final double yourNet;

  factory GroupSummary.fromJson(Map<String, dynamic> j) => GroupSummary(
        id: _s(j['id']),
        name: _s(j['name']),
        emoji: _sn(j['emoji']),
        memberCount: _i(j['memberCount']),
        yourNet: _d(j['yourNet']),
      );
}

class GroupMemberItem {
  const GroupMemberItem({required this.id, required this.name, required this.isSelf});

  final String id;
  final String name;
  final bool isSelf;

  factory GroupMemberItem.fromJson(Map<String, dynamic> j) => GroupMemberItem(
        id: _s(j['id'] ?? j['memberId']),
        name: _s(j['displayName'] ?? j['name']),
        isSelf: _b(j['isSelf']),
      );
}

class GroupDetail {
  const GroupDetail({required this.id, required this.name, required this.emoji, required this.members});

  final String id;
  final String name;
  final String? emoji;
  final List<GroupMemberItem> members;

  factory GroupDetail.fromJson(Map<String, dynamic> j) => GroupDetail(
        id: _s(j['id']),
        name: _s(j['name']),
        emoji: _sn(j['emoji']),
        members: (j['members'] as List<dynamic>? ?? const [])
            .map((e) => GroupMemberItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class GroupExpenseItem {
  const GroupExpenseItem({required this.id, required this.description, required this.amount, required this.occurredOn, required this.yourShare, required this.categoryName, required this.payerNames});

  final String id;
  final String description;
  final double amount;
  final DateTime occurredOn;
  final double yourShare;
  final String? categoryName;
  final List<String> payerNames;

  factory GroupExpenseItem.fromJson(Map<String, dynamic> j) => GroupExpenseItem(
        id: _s(j['id']),
        description: _s(j['description']),
        amount: _d(j['amount']),
        occurredOn: _dt(j['occurredOn']),
        yourShare: _d(j['yourShare']),
        categoryName: _sn(j['categoryName']),
        payerNames: (j['payers'] as List<dynamic>? ?? const []).map((p) => _s((p as Map)['memberName'])).toList(),
      );
}

class SuggestedPayment {
  const SuggestedPayment({required this.fromMemberId, required this.fromName, required this.toMemberId, required this.toName, required this.amount});

  final String fromMemberId;
  final String fromName;
  final String toMemberId;
  final String toName;
  final double amount;

  factory SuggestedPayment.fromJson(Map<String, dynamic> j) => SuggestedPayment(
        fromMemberId: _s(j['fromMemberId']),
        fromName: _s(j['fromName']),
        toMemberId: _s(j['toMemberId']),
        toName: _s(j['toName']),
        amount: _d(j['amount']),
      );
}

class GroupBalances {
  const GroupBalances({required this.members, required this.suggestions, required this.youAreOwed, required this.youOwe, required this.yourNet});

  final List<GroupMemberItem> members;
  final List<SuggestedPayment> suggestions;
  final double youAreOwed;
  final double youOwe;
  final double yourNet;

  factory GroupBalances.fromJson(Map<String, dynamic> j) => GroupBalances(
        members: (j['members'] as List<dynamic>? ?? const []).map((e) => GroupMemberItem.fromJson(e as Map<String, dynamic>)).toList(),
        suggestions: (j['suggestions'] as List<dynamic>? ?? const []).map((e) => SuggestedPayment.fromJson(e as Map<String, dynamic>)).toList(),
        youAreOwed: _d(j['youAreOwed']),
        youOwe: _d(j['youOwe']),
        yourNet: _d(j['yourNet']),
      );
}

class UpcomingItem {
  const UpcomingItem({required this.kind, required this.title, required this.amount, required this.dueOn, required this.isIncoming});

  final String kind;
  final String title;
  final double amount;
  final DateTime dueOn;
  final bool isIncoming;

  factory UpcomingItem.fromJson(Map<String, dynamic> j) => UpcomingItem(
        kind: _s(j['kind']),
        title: _s(j['title']),
        amount: _d(j['amount']),
        dueOn: _dt(j['dueOn']),
        isIncoming: _b(j['isIncoming']),
      );
}

class RecentItem {
  const RecentItem({required this.title, required this.type, required this.amount, required this.date, required this.categoryName});

  final String title;
  final String type;
  final double amount;
  final DateTime date;
  final String? categoryName;

  factory RecentItem.fromJson(Map<String, dynamic> j) => RecentItem(
        title: _s(j['title']),
        type: _s(j['type']),
        amount: _d(j['amount']),
        date: _dt(j['date']),
        categoryName: _sn(j['categoryName']),
      );
}

class MonthPoint {
  const MonthPoint({required this.year, required this.month, required this.expenses, required this.income});

  final int year;
  final int month;
  final double expenses;
  final double income;

  factory MonthPoint.fromJson(Map<String, dynamic> j) => MonthPoint(
        year: _i(j['year']),
        month: _i(j['month']),
        expenses: _d(j['expenses']),
        income: _d(j['income']),
      );
}

class CategoryTotal {
  const CategoryTotal({required this.name, required this.amount, required this.percent});

  final String name;
  final double amount;
  final double percent;

  factory CategoryTotal.fromJson(Map<String, dynamic> j) => CategoryTotal(
        name: _s(j['name']),
        amount: _d(j['amount']),
        percent: _d(j['percent']),
      );
}

class Dashboard {
  const Dashboard({
    required this.bankBalance,
    required this.cashBalance,
    required this.totalLiquid,
    required this.monthIncome,
    required this.monthExpenses,
    required this.monthNet,
    required this.cardOutstanding,
    required this.cardLimit,
    required this.cardAvailable,
    required this.debtsOutstanding,
    required this.loansOutstanding,
    required this.receivablesOutstanding,
    required this.groupOwedToYou,
    required this.groupYouOwe,
    required this.netWorth,
    required this.upcoming,
    required this.recent,
    required this.trend,
    required this.categories,
    required this.budget,
    required this.savingsSaved,
  });

  final double bankBalance;
  final double cashBalance;
  final double totalLiquid;
  final double monthIncome;
  final double monthExpenses;
  final double monthNet;
  final double cardOutstanding;
  final double cardLimit;
  final double cardAvailable;
  final double debtsOutstanding;
  final double loansOutstanding;
  final double receivablesOutstanding;
  final double groupOwedToYou;
  final double groupYouOwe;
  final double netWorth;
  final List<UpcomingItem> upcoming;
  final List<RecentItem> recent;
  final List<MonthPoint> trend;
  final List<CategoryTotal> categories;
  final BudgetSummary budget;
  final double savingsSaved;

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        bankBalance: _d(j['bankBalance']),
        cashBalance: _d(j['cashBalance']),
        totalLiquid: _d(j['totalLiquid']),
        monthIncome: _d(j['monthIncome']),
        monthExpenses: _d(j['monthExpenses']),
        monthNet: _d(j['monthNet']),
        cardOutstanding: _d(j['cardOutstanding']),
        cardLimit: _d(j['cardLimit']),
        cardAvailable: _d(j['cardAvailable']),
        debtsOutstanding: _d(j['debtsOutstanding']),
        loansOutstanding: _d(j['loansOutstanding']),
        receivablesOutstanding: _d(j['receivablesOutstanding']),
        groupOwedToYou: _d(j['groupOwedToYou']),
        groupYouOwe: _d(j['groupYouOwe']),
        netWorth: _d(j['netWorth']),
        upcoming: (j['upcoming'] as List<dynamic>? ?? const []).map((e) => UpcomingItem.fromJson(e as Map<String, dynamic>)).toList(),
        recent: (j['recentTransactions'] as List<dynamic>? ?? const []).map((e) => RecentItem.fromJson(e as Map<String, dynamic>)).toList(),
        trend: (j['spendingTrend'] as List<dynamic>? ?? const []).map((e) => MonthPoint.fromJson(e as Map<String, dynamic>)).toList(),
        categories: (j['categorySpending'] as List<dynamic>? ?? const []).map((e) => CategoryTotal.fromJson(e as Map<String, dynamic>)).toList(),
        budget: BudgetSummary.fromJson(j['budget'] as Map<String, dynamic>),
        savingsSaved: _d(j['savingsSaved']),
      );
}

class NetWorthPoint {
  const NetWorthPoint({required this.asOf, required this.netWorth});

  final DateTime asOf;
  final double netWorth;

  factory NetWorthPoint.fromJson(Map<String, dynamic> j) => NetWorthPoint(asOf: _dt(j['asOf']), netWorth: _d(j['netWorth']));
}

class MonthlyReport {
  const MonthlyReport({required this.income, required this.expenses, required this.net, required this.savingsRate, required this.categories, required this.groupShare, required this.interest});

  final double income;
  final double expenses;
  final double net;
  final double savingsRate;
  final List<CategoryTotal> categories;
  final double groupShare;
  final double interest;

  factory MonthlyReport.fromJson(Map<String, dynamic> j) => MonthlyReport(
        income: _d(j['income']),
        expenses: _d(j['expenses']),
        net: _d(j['net']),
        savingsRate: _d(j['savingsRatePercent']),
        categories: (j['categories'] as List<dynamic>? ?? const []).map((e) => CategoryTotal.fromJson(e as Map<String, dynamic>)).toList(),
        groupShare: _d(j['groupShareExpenses']),
        interest: _d(j['interestExpenses']),
      );
}
