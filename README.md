<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/logo/clearly-mark.svg">
  <img src="docs/logo/clearly-mark-light.svg" alt="Clearly" height="96">
</picture>

# Clearly

### __Knowing your financial health shouldn't cost you $15 a month.__

[seeclearly.app](https://seeclearly.app)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Android-lightgrey.svg)](#building)
[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Version](https://img.shields.io/badge/version-0.7.1-informational.svg)](https://github.com/Psalm2517/clearly-finance/releases)
[![Downloads](https://img.shields.io/github/downloads/Psalm2517/clearly-finance/total.svg?v=2)](https://github.com/Psalm2517/clearly-finance/releases)

### [⬇ Download for Linux](https://github.com/Psalm2517/clearly-finance/releases/latest/download/Clearly-x86_64.AppImage)

One file. Make it executable (right-click, Properties, Permissions), then double-click it.

Free, open-source personal finance for the desktop. Your data stays on your
computer.

![Clearly dashboard](docs/screenshots/dashboard-0.7.png)

</div>

## Why Clearly

- **Free.** No subscription, no account.
- **Flexible.** Type things in manually, or connect your banks through
  SimpleFIN ($1.50/month, paid to them).
- **Accurate.** Transfers between your own accounts and card payments aren't
  counted as spending or income.
- **Local.** Your data never leaves your device.

## Features

**Dashboard.** Net worth and what it is made of, how this month's spending
compares with last month's, and a short list of anything worth your
attention: a projected shortfall, high card use, a category running hot.

**Accounts.** Every account, card and loan in one overview, with tabs for
cash, cards, loans and goals. Loans show payoff progress and a "what if" for
extra payments. Goals track a savings or payoff target.

![Accounts](docs/screenshots/accounts-0.7.png)

![Goals](docs/screenshots/goals-0.7.png)

**Transactions.** A searchable register across every month, with filters,
tags and split transactions.

**Cash Flow.** Where the month's money came from and where it went, spending
by category, and a projected balance that warns you before it goes negative.

![Cash Flow](docs/screenshots/cash-flow-0.7.png)

**Budget.** Targets for each category, with bills and paychecks counted in
the plan, so every dollar is counted once.

![Budget](docs/screenshots/budget-0.7.png)

**Recurring.** Upcoming bills, paychecks, transfers and repeating
transactions. Clearly also finds subscriptions and regular deposits in your
history and offers to track them.

**Households.** Multiple profiles, each with its own data and an optional
PIN. An admin can switch into any of them.

## Clearly Sync

Create a **Synced** profile and connect your banks through
[SimpleFIN](https://www.simplefin.org/), a read-only feed. Accounts and
transactions come from the bank, they update daily, and nothing is typed in
by hand. A **Manual** profile never connects to anything.

## Your data

Everything is stored in `~/.local/share/app.seeclearly.Clearly/clearly.sqlite`.
Back up and restore from Settings. Backups are plain JSON, so keep them
somewhere you trust.

## Theme

Light and dark, with the [Catppuccin](https://catppuccin.com) flavors (Mocha
by default) and a choice of accent color.

## Building

See [BUILD.md](BUILD.md).

## Architecture

    lib/
      data/         Drift schema, repository, bank sync, backup
      screens/      One file per screen
      widgets/      Shared UI pieces
      theme/        Catppuccin flavors and ThemeData
      util/         Money formatting, payoff maths, PIN hashing

All database access goes through one repository, and money is stored as
integer cents. Schema changes are versioned migrations with tests that
upgrade a real database of each older shape.

## Coming next

- Flathub submission
- An Investments tab
- Android build, and eventually Windows and macOS builds

## AI disclosure

This project was built with AI assistance, directed by me.

## License

MIT. See [LICENSE](./LICENSE).
