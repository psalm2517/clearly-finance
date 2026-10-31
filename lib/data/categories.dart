/// The categories Clearly starts with. Names are plain text everywhere else
/// (budget targets, rules and entries all just store the name), so this list
/// is the single place the built-in names live: the merchant-code table, the
/// statement-text matcher and the Categorize picker all read from it.
///
/// The person's own categories are always allowed alongside these.
class Cat {
  const Cat._();

  // ---- spending ----
  static const food = 'Food & Dining';
  static const groceries = 'Groceries';
  static const housing = 'Housing';
  static const utilities = 'Utilities & Bills';
  static const auto = 'Transportation';
  static const financial = 'Financial Services';
  static const medical = 'Medical & Healthcare';
  static const personal = 'Personal, Family & Pets';
  static const entertainment = 'Entertainment';
  static const subscriptions = 'Subscriptions & Software';
  static const travel = 'Travel';
  static const education = 'Education';
  static const gifts = 'Gifts & Donations';
  static const taxes = 'Taxes & Government';
  static const transfers = 'Transfers';
  static const other = 'Other';

  // ---- income ----
  static const paycheck = 'Paycheck';
  static const interest = 'Interest & Dividends';
  static const refunds = 'Refunds & Reimbursements';
  static const otherIncome = 'Other Income';
}

/// What each built-in category is for, shown when choosing one.
const Map<String, String> categoryHints = {
  Cat.food: 'Restaurants, coffee, fast food, delivery',
  Cat.groceries: 'Supermarkets and food shopping',
  Cat.housing: 'Rent, mortgage, HOA, home repair and furnishing',
  Cat.utilities: 'Electric, water, natural gas, internet, phone',
  Cat.auto:
      'Gas stations and fuel, rideshare, transit, parking, tolls, repairs',
  Cat.financial:
      'Insurance, bank and ATM fees, interest, loan and car payments',
  Cat.medical: 'Doctor, dentist, vision, pharmacy, urgent care, vet',
  Cat.personal:
      'Shopping, clothing, salon, gym, personal care, childcare, kids, pet '
      'food and supplies',
  Cat.entertainment:
      'One-off fun: games (Steam), movies, events, tickets, betting',
  Cat.subscriptions:
      'Anything you pay for on repeat: streaming and music (Spotify, '
      'Netflix), cloud, hosting, AI tools, apps, VPN',
  Cat.travel: 'Flights, hotels, rentals, trips',
  Cat.education: 'Tuition, books, courses',
  Cat.gifts: 'Gifts and charity',
  Cat.taxes: 'Taxes, fines, government fees',
  Cat.paycheck: 'Wages and salary from an employer',
  Cat.interest: 'Interest on savings, dividends',
  Cat.refunds: 'Returns, refunds, cash back, money paid back to you',
  Cat.otherIncome: 'Anything else that came in: gifts, Zelle, side income',
  Cat.transfers:
      'Money moving between your own accounts and brokerage deposits. '
      'Not counted as income or spending',
};

/// Income categories, in the order they are offered.
const defaultIncomeCategories = <String>[
  Cat.paycheck,
  Cat.interest,
  Cat.refunds,
  Cat.otherIncome,
];

/// What the statement wording says an incoming amount is, when nothing more
/// specific (the person's own rules, a scheduled paycheck) already decided.
/// Null when the wording says nothing.
String? incomeCategoryFromText(String text) {
  final t = text.toLowerCase();
  if (RegExp(r'payroll|direct dep|salary|paychk|paycheck').hasMatch(t)) {
    return Cat.paycheck;
  }
  if (RegExp(r'dividend|interest (payment|paid|earned|credit)|'
          r'\binterest\b')
      .hasMatch(t)) {
    return Cat.interest;
  }
  if (RegExp(r'refund|reimburs|reversal|chargeback|cash ?back').hasMatch(t)) {
    return Cat.refunds;
  }
  if (RegExp(r'zelle|venmo|cash app|paypal|apple cash').hasMatch(t)) {
    return Cat.otherIncome;
  }
  return null;
}

/// Spending categories in the order they are offered.
const defaultSpendingCategories = <String>[
  Cat.food,
  Cat.groceries,
  Cat.housing,
  Cat.utilities,
  Cat.auto,
  Cat.financial,
  Cat.medical,
  Cat.personal,
  Cat.entertainment,
  Cat.subscriptions,
  Cat.travel,
  Cat.education,
  Cat.gifts,
  Cat.taxes,
  Cat.transfers,
  Cat.other,
];

/// Names earlier builds assigned automatically, and what they are now.
/// Applied once to bank entries only, so a category the person chose
/// themselves is never renamed.
const legacyCategoryNames = <String, String>{
  'Personal': Cat.personal,
  'Family & Pets': Cat.personal,
  'Dining': Cat.food,
  'Gas': Cat.auto,
  'Auto': Cat.auto,
  'Auto & Transport': Cat.auto,
  'Utilities': Cat.utilities,
  'Insurance': Cat.financial,
  'Cash': Cat.financial,
  'Payments': Cat.financial,
  'Health': Cat.medical,
  'Personal care': Cat.personal,
  'Fitness': Cat.personal,
  'Shopping': Cat.personal,
  'Home': Cat.housing,
  'Subscriptions': Cat.subscriptions,
  'Taxes & fees': Cat.taxes,
  'Peer payments': Cat.transfers,
};

/// Built-in categories alphabetically (with "Other" last), then the
/// person's own alphabetically. Used wherever a category is chosen so the
/// list is always in the same, findable order.
({List<String> builtIn, List<String> yours}) orderedCategories(
  Iterable<String> used, {
  bool income = false,
}) {
  if (income) {
    final yours = {
      for (final c in used)
        if (!defaultIncomeCategories.contains(c) &&
            !defaultSpendingCategories.contains(c) &&
            c != 'Split' &&
            c.trim().isNotEmpty)
          c,
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return (
      builtIn: [...defaultIncomeCategories]..sort(),
      yours: yours,
    );
  }
  final builtIn = [
    for (final c in defaultSpendingCategories)
      if (c != Cat.other) c,
  ]..sort();
  final yours = {
    for (final c in used)
      if (!defaultSpendingCategories.contains(c) &&
          c != 'Split' &&
          c.trim().isNotEmpty)
        c,
  }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return (builtIn: [...builtIn, Cat.other], yours: yours);
}
