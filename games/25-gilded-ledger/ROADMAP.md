# 25 — Gilded Ledger Roadmap

> Run a merchant house in a Renaissance republic, where double-entry bookkeeping is the board and credit is the sharpest weapon.

Read [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 in full before starting. This roadmap only adds what is specific to Gilded Ledger.

## 0. Metadata

| Field | Value |
| --- | --- |
| Game number and slug | 25 · `gilded-ledger` |
| Code prefix | `GLD` (packages `GLDCore`, `GLDContent`, `GLDAI`, `GLDRender`, `GLDAudio`, `GLDPlatform`, `GLDMeta`) |
| Bundle ID | `GEIST_BUNDLE_ID` build setting, set by the maintainer (`_CONVENTIONS.md` §2) |
| Subgenre | Economic strategy (credit, markets, and politics) |
| Difficulty tier | Deep |
| Scope | Small team |
| Session length | 45–90 min (16 quarters over 4 years) |
| Renderer | SwiftUI for the ledger board and most surfaces; SpriteKit for the harbor/city scene and coin animations (`SpriteView` embedded); `SKShader` for marbled paper |
| Players | Solo vs 2–3 AI rival houses; local hot-seat for 2–4 humans |
| Conventions | [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) v2.0 (read first) |

## 1. Summary and Design Pillars

**Hook:** Run a merchant house in a Renaissance republic, where double-entry bookkeeping is the board and credit is the sharpest weapon.

**Summary:** The player heads a merchant house in a fictional maritime republic over four years. Each quarter, the house sends its four factors to act: buy and sell goods in three markets, take shares in sea voyages, draw and accept bills of exchange between cities, lend and borrow, lobby the council, gather intelligence, commission art for prestige, and buy up rivals' debts. The **ledger is the board**: every action is a movement of value between accounts (Cash, Goods, Voyages, Bills Receivable, Bills Payable, Loans, Prestige Works, and Capital), shown as a living double-entry book that always balances. Danger lives in timing: bills fall due on fixed quarters, voyages return late or never, and a rival who quietly buys your notes can present them all at once and break your liquidity at the annual audit. The house with the greatest capital plus prestige after four years wins.

**Pillars:**

1. **The books tell the story.** Every action appears as a journal entry the player can read; the ledger is not a report but the play surface.
2. **Liquidity kills, not losses.** Most eliminations come from cash timing (bills due), not from bad trades. Sims must show that profitable but illiquid houses fail.
3. **Information is an asset.** Intelligence about next quarter's events and rivals' exposures is worth paying for, and the market rewards it.
4. **Credit as a weapon, with risk.** Buying a rival's notes to squeeze them ties up your own cash and can backfire.
5. **Elegant density.** Deep systems, but every screen fits on an iPad without scrolling for the core decisions.

**Aesthetic spec:**

| Element | Spec |
| --- | --- |
| Palette | Marbled paper base `#EDE3CF` with marbling in `#3E5C76` and `#9C6B3F`; iron-gall ink `#2A2420`; red ink for debits shown in the period style `#8E2B22`; gold leaf `#C9A227`; wax seal crimson `#9E1B32`; lagoon green `#3C6E66` |
| Shapes | Ledger pages with ruled columns, marginal flourishes, wax seals for bills, coin stacks as small rendered sprites; the harbor scene as an engraved view |
| Typography | A humanist italic for headings (default New York Italic), tabular numerals in SF Mono for amounts; period-style roman numerals optional in settings |
| Motion | Coins slide between accounts; ink lines draw themselves when entries post; seals stamp; ships come and go in the harbor scene |
| Music | Harpsichord and recorder consort; harbor bustle ambience; a tense continuo under audits |
| SFX | Quill scratches, coin clinks (pitch by amount), seal stamps, bells for quarter turns |
| Haptics | Tick per coin stack moved; firm press on seal stamping; heavy for a default |

**Inspirations:** Through the Ages' economic engine, Twilight Struggle's tension, and the history of Renaissance merchant banking and double-entry bookkeeping (treated as fiction).

## 2. Tech Stack Decision

Per [`_CONVENTIONS.md`](../_shared/_CONVENTIONS.md) §2, with these game-specific choices:

- **UI:** SwiftUI is the primary surface (ledger, accounts, bills, council, and markets); SpriteKit only for the harbor scene and coin transfer animations (embedded `SpriteView`). This differs from the default 2D renderer choice because the board is tabular (ADR-0003).
- **Accounting core:** Core posts every state change as a balanced journal entry (debits equal credits, enforced by the type system: `JournalEntry` initializer rejects unbalanced lines).
- **Money:** Core stores integer **denari** as `Int` (12 denari = 1 soldo, 20 soldi = 1 lira); the UI displays decimal lire by default or period L/s/d as an option.
- **Turns:** quarters; within a quarter, factor placements are sequential across houses (worker placement order by initiative).

ADRs to create in P0:

- ADR-0003 SwiftUI-first board with embedded SpriteKit.
- ADR-0004 Journal-entry-only state mutation for money and assets.
- ADR-0005 Integer denari currency.
- ADR-0006 Hidden information model for rivals' ledgers.

## 3. Repository Structure (Game-Specific Additions)

```
Packages/
├── GLDCore/Sources/GLDCore/
│   ├── Foundation/   SeededRNG.swift, Fixed.swift, Denari.swift
│   ├── Ledger/       Account.swift, JournalEntry.swift, Ledger.swift, TrialBalance.swift, Audit.swift
│   ├── Markets/      Good.swift, Market.swift (three cities), PriceCycle.swift, Shock.swift
│   ├── Credit/       Bill.swift (bill of exchange), Loan.swift, ExchangeRate.swift, CreditRating.swift, NoteMarket.swift
│   ├── Voyages/      Voyage.swift, Share.swift, SeaLoan.swift (insurance), Outcome.swift
│   ├── Politics/     Council.swift (9 seats), Seat.swift, Policy.swift, Vote.swift, Lobby.swift
│   ├── Intel/        EventDeck.swift, Intelligence.swift, Rumor.swift
│   ├── Houses/       House.swift, Factor.swift, Trait.swift, Prestige.swift, Commission.swift
│   ├── Turn/         Quarter.swift, Initiative.swift, ActionSpaces.swift, Settlement.swift
│   └── Engine/       GameState.swift, Action.swift, Event.swift, Reducer.swift, Observation.swift
├── GLDContent/       GoodDef.swift, CityDef.swift, EventDef.swift, PolicyDef.swift, HouseTraitDef.swift, CommissionDef.swift, ScenarioDef.swift, Loader.swift
├── GLDAI/            RivalHouse.swift, Planner.swift, LiquidityForecaster.swift, SqueezeDetector.swift, Evaluator.swift, Personality.swift
├── GLDRender/        LedgerBoardView.swift, AccountColumn.swift, JournalView.swift, BillCard.swift, CouncilView.swift, HarborScene.swift, CoinTransfer.swift
├── GLDAudio/         Consort.swift, Harbor.swift
├── GLDPlatform/      PencilSignature.swift, GameCenterService.swift, CloudSaveService.swift
└── GLDMeta/          Progression.swift, Scenarios.swift, Chronicle.swift, Stats.swift
Resources/Content/    goods.json, cities.json, events.json, policies.json, house_traits.json, commissions.json, scenarios/*.json, balance.json
```

## 4. Core Rules Specification

Copy this section verbatim to `docs/RULES.md` in S0.5. Amounts are in denari (d); 12 d = 1 soldo (s), 20 s = 1 lira (L).

### 4.1 Setup

- **R-1 Houses.** 3–4 houses (player plus rivals). Each starts with Capital 2,000 L posted as Cash 1,500 L and Goods 500 L (scenario-defined), 4 factors, credit rating B (scale A, B, C, D), and one house trait (R-40).
- **R-2 Cities.** Three markets: the Republic (home), the Northern Fair, and the Levant Port. Each trades 6 goods (wool, alum, grain, silk, pepper, glass) at its own prices.
- **R-3 Calendar.** 16 quarters (Q1 year 1 … Q4 year 4). Audits at the end of every Q4 (R-28).
- **R-4 Accounts.** Every house has the accounts: `cash`, `goods:<city>:<good>`, `voyages`, `bills_receivable`, `bills_payable`, `loans_receivable`, `loans_payable`, `prestige_works`, `capital`, and `profit_and_loss` (closed into capital at audit), plus two contra accounts for bill discounts: `discount_on_bills_payable` (asset-side contra, interest not yet expensed) and `discount_on_bills_receivable` (liability-side contra, interest not yet earned).

### 4.2 The Ledger

- **R-5 Journal entries.** Every change to any account happens through a journal entry: a dated set of lines, each `(account, debit or credit, amount)`, with Σ debits = Σ credits. An unbalanced entry is unrepresentable (constructor throws `RuleError.unbalanced`).
- **R-6 Valuation.** Goods are carried at cost (FIFO lots). Voyages at amount invested. Bills and loans at face value. Prestige works at commission cost (they cannot be sold).
- **R-7 Net worth.** `netWorth = assets − liabilities` = capital + P&L (accounting identity; checked each quarter).

### 4.3 Quarter Structure

- **R-8 Phases.** (1) **News:** reveal this quarter's public event (R-24); (2) **Initiative:** order houses by lowest net worth first (catch-up), ties by credit rating then seat; (3) **Factors:** in initiative order, each house places one factor on an action space; repeat until all factors are placed (4 rounds); (4) **Settlement:** resolve voyages returning, bills and loans due (R-16), interest, and market moves; (5) **Council:** votes on pending policies (R-21); (6) **Audit** (Q4 only).
- **R-9 Action spaces.** Each space has a capacity per quarter (number of factors that may use it): `market:<city>` (2 per city: buy and/or sell up to 3 goods), `voyage_office` (2: take shares in an open voyage), `exchange` (3: draw or accept bills, R-12), `bank` (2: borrow or lend, R-15), `note_market` (2: buy or sell other houses' bills, R-18), `council` (2: lobby, R-22), `intelligence` (1: draw a private look at the next 2 event cards or one rival's exposure summary, R-25), `workshop` (1: commission a prestige work, R-27), and `counting_house` (unlimited: reduce one upcoming obligation by settling early with a 2% discount).

### 4.4 Markets

- **R-10 Prices.** Each city keeps per good a price and a stock. Price = `base × cycle(quarter) × (target / max(stock, 1))^elasticity × shockFactor`, integer denari.
- **R-11 Trading.** Buying moves value `cash → goods` (entry: debit goods, credit cash) and raises price per unit (marginal quotes); selling posts `cash` debit, `goods` credit at cost, and the difference to `profit_and_loss`. Goods sold must be in that city (goods are city-located; moving goods between cities requires a voyage or overland carriage at the market action: 5% of value, one quarter in transit).

### 4.5 Bills of Exchange and Credit

- **R-12 Drawing a bill.** A house may **draw** a bill: receive cash now in city A from the exchange (a taker), promising to pay face value in city B at quarter `q + 1` or `q + 2`. The exchange rate spread between cities (from `cities.json` and events) sets the implicit interest (typically 6–12% per quarter-pair). Entry at drawing: debit `cash` (proceeds), debit `discount_on_bills_payable` (face − proceeds), credit `bills_payable` (face). At maturity, the discount is moved to `profit_and_loss` as interest expense.
- **R-13 Accepting a bill.** A house may **accept** (buy) a bill offered by the exchange or drawn by a rival: pay cash now, receive face later. Entry: debit `bills_receivable` (face), credit `cash` (price paid), credit `discount_on_bills_receivable` (face − price). At maturity, the discount is moved to `profit_and_loss` as interest income.
- **R-14 Exchange arbitrage.** Bills can profit from rate differences between cities (the *cambium*). Rates move with events (R-24).
- **R-15 Loans.** At the bank, borrow up to `creditLimit(rating)` (A: 1,500 L, B: 1,000 L, C: 500 L, D: 0) at quarterly interest by rating (A 3%, B 5%, C 8%); repay any quarter. Lending to the bank earns 2% per quarter (liquid, withdrawable at the bank space).
- **R-16 Maturity.** In Settlement, every bill or loan due this quarter is presented by its holder. The debtor pays from cash. If cash is insufficient, the debtor may immediately sell goods at the home market at 80% of the current price, call its own loans receivable (with a 10% penalty), or sell bills receivable on the note market at 85% of face. If still short, the debtor **defaults** on that obligation (R-19).
- **R-17 Credit rating.** Ratings move at audit by a formula of liquidity ratio (cash + 0.8 × goods + receivables due within 2 quarters) / (payables due within 2 quarters), defaults, and council favor: ≥ 2.0 → up one step, ≤ 1.0 → down one step, any default → down two steps.
- **R-18 Note market.** Bills drawn by houses are **transferable**. At the note market a house may buy a rival's outstanding bill from its current holder (the exchange or another house) at a price set by the debtor's rating (A 98%, B 94%, C 88%, D 70% of face). The debtor is **not** informed who holds its notes unless it uses intelligence. A holder may present a bill only at maturity (no calling early), but the holder may **refuse renewal**: debtors routinely roll bills by drawing new ones at maturity, and a holder of ≥ 50% of a house's notes due in a quarter can block that house from drawing new bills on the exchange that quarter (the *squeeze*).
- **R-19 Default.** A defaulted obligation remains owed with a 20% penalty added; the debtor's rating drops (R-17); the creditor may seize goods of equal value in the debtor's home warehouse. Two defaults in one year, or any default at audit, trigger **bankruptcy** proceedings (R-29).

### 4.6 Voyages

- **R-20 Voyages.** Each quarter 1–3 voyages open (from the event deck): destination, duration (2–4 quarters), total shares (10), share price, and a risk band (`calm`, `fair`, `perilous`) with known probabilities (90/75/55% success). On return, a successful voyage pays `share × multiplier` (1.4–2.5× by band) as goods in the home city (valued at the current price) or cash (player's choice at return). Failure pays 0. **Sea loans** (insurance) can be bought at 10/20/35% of share value to recover 80% on failure.

### 4.7 Politics

- **R-21 Council.** 9 seats; each seat is aligned to a house or neutral. Policies (from `policies.json`) come up for vote each quarter (one per quarter): e.g., `tariff_on_levant_pepper`, `war_with_the_north` (Northern Fair closed for 2 quarters, wool prices spike), `debasement` (cash values −5%, debts lighter), `usury_inquiry` (bill spreads capped; exchange rates compress), `public_works` (prestige works +20%).
- **R-22 Lobbying.** A factor at the council spends 50–200 L to sway one neutral seat (chance 40% + 10% per 50 L above 50, capped 85%) or to hold one of the house's own seats against sway. Seats realign at each audit toward the houses with the highest prestige (one neutral seat per audit).
- **R-23 Votes.** Each aligned seat votes as its house chooses (AI rivals per policy utility); neutral seats vote by a policy's public appeal plus prestige pull. Majority (5) passes.

### 4.8 Events and Intelligence

- **R-24 Event deck.** A shuffled deck of 40 cards (seeded per game) mixes market shocks (`harvest_failure`, `silk_glut`, `plague_in_the_north`), sea events (`pirates`, `storm_season`: voyage risk worse), political events, and exchange events (`fair_postponed`: bills to the Northern Fair delayed one quarter). One card is revealed each quarter in News.
- **R-25 Intelligence.** The intelligence action shows privately either the next 2 event cards (in order) or one rival's **exposure summary** (total bills payable by due quarter, cash band, and who holds ≥ 25% of its notes).
- **R-26 Observation.** Each house sees its own full ledger, all market prices, the council, open voyages, all public bill offers, every house's credit rating and published audit statement (once per year), and only what intelligence reveals beyond that.

### 4.9 Prestige, Audit, and Victory

- **R-27 Commissions.** At the workshop, a house commissions a work (fresco, altarpiece, palazzo wing, library) for a cost and receives prestige points (from `commissions.json`) when completed (1–3 quarters later). Entry: debit prestige_works, credit cash.
- **R-28 Audit.** At each Q4 end: close P&L into capital; publish a summary statement (assets, liabilities, rating); recompute ratings (R-17); seat realignment (R-22). The ledger's trial balance must balance (it always does by R-5; the audit is a public reckoning of liquidity and solvency).
- **R-29 Bankruptcy.** A house in bankruptcy proceedings must pay all due obligations by the next quarter's Settlement or be eliminated: its assets are liquidated (goods sold at 70%, receivables sold at 70%), creditors paid pro rata, and its remaining notes written off (creditors book losses).
- **R-30 Victory.** After Q4 of year 4, score = net worth (in lire) + prestige × `prestigeValue` (default 40 L per point) + 200 L per council seat aligned. Highest score wins. A house that eliminates all rivals wins immediately.

### 4.10 Houses and Edge Cases

- **R-40 House traits.** E.g., `old_money` (+1 rating step at start), `seafarers` (voyage shares −10% price), `wool_guild` (wool trades at 2% better prices), `exchangers` (bill spreads −1 point), `patrons` (commissions +1 prestige).
- **R-41** A house cannot buy its own notes on the note market (it repays them via the counting house).
- **R-42** If two settlements on the same quarter would each exhaust cash, obligations are paid in order of due date (drawn earlier first), then by face value descending.
- **R-43** A voyage returning during war with its destination's region fails automatically unless insured.
- **R-44** Hot-seat: each human's ledger is private during their factor placement (hand-over screen).

### 4.11 Invariants

- **INV-1** For every journal entry, Σ debits = Σ credits; for every house, the trial balance sums to zero at all times.
- **INV-2** For every bill, exactly one holder and one debtor exist; the holder's receivable equals the debtor's payable (cross-ledger consistency).
- **INV-3** Cash never negative after Settlement (defaults are posted instead).
- **INV-4** Net worth identity (R-7) holds every quarter.
- **INV-5** Observation for a house never reveals another house's private data beyond R-26 (diff test).
- **INV-6** Replays deterministic across platforms.

## 5. Data Schemas and Content Tables

### 5.1 Core State

```swift
public struct GameState: Codable, Equatable, Hashable, Sendable {
    public var quarter: Int; public var phase: Phase; public var rng: SeededRNG
    public var houses: [HouseID: House]                 // each with Ledger, factors, rating, trait, prestige
    public var markets: [CityID: Market]; public var exchangeRates: [CityPair: Int]
    public var bills: [BillID: Bill]; public var loans: [LoanID: Loan]; public var voyages: [VoyageID: Voyage]
    public var council: Council; public var pendingPolicy: PolicyID?
    public var deck: [EventID]; public var revealed: [EventID]; public var spaces: [SpaceID: [FactorID]]
    public var initiative: [HouseID]
}
public struct JournalEntry: Codable, Equatable, Hashable, Sendable {
    public let id: EntryID; public let quarter: Int; public let memoKey: String
    public let lines: [Line]          // Line { account: AccountID, side: Side(debit/credit), amount: Denari }
    public init(id: EntryID, quarter: Int, memoKey: String, lines: [Line]) throws(RuleError)   // throws if unbalanced
}
public struct Bill: Codable, Equatable, Hashable, Sendable {
    public var id: BillID; public var debtor: HouseID?; public var holder: HolderID   // exchange or house
    public var face: Denari; public var payCity: CityID; public var dueQuarter: Int; public var renewed: Int
}
public enum Action: Codable, Equatable, Sendable {
    case placeFactor(FactorID, SpaceID, SpaceAction)    // e.g., .market(trades), .drawBill(...), .buyNote(BillID), .lobby(seat, amount)
    case vote(PolicyID, Bool), settleChoice(SettlementChoice), endPlacement
}
public enum Event: Codable, Equatable, Sendable {
    case posted(HouseID, JournalEntry), priceMoved(CityID, GoodID, Int), billDrawn(BillID), noteSold(BillID, to: HolderID)
    case voyageReturned(VoyageID, success: Bool), presented(BillID), defaulted(HouseID, BillID), squeezed(HouseID, by: HouseID)
    case policyResolved(PolicyID, passed: Bool), seatChanged(Int, to: HouseID?), audit(HouseID, Statement)
    case bankrupt(HouseID), eliminated(HouseID), gameEnded(Result)
}
```

### 5.2 Content Tables

**`goods.json`** — 6 goods with base prices per city, cycles, and elasticity.

```json
{ "id": "alum", "base": { "republic": 2400, "northern_fair": 3000, "levant": 1800 },
  "cycle": [100, 105, 95, 100], "elasticity": 0.3, "volatility": 0.05 }
```

**`cities.json`** — 3 cities with exchange spreads.

```json
{ "id": "northern_fair", "fairQuarters": [1, 3], "rateToRepublic": 1080, "spreadBasisPoints": 800 }
```

**`events.json`** — G3: 40 cards; G5: 60 (deck built from a scenario subset). **`policies.json`** — G3: 12; G5: 20. **`house_traits.json`** — G3: 6; G5: 10. **`commissions.json`** — G3: 12. **`scenarios/*.json`** — G5: 5 (Standard, The Alum Monopoly, Year of the Plague, The War of the Fair, Credit Crunch).

```json
{ "id": "credit_crunch", "houses": 4, "startCash": 1200, "startGoods": 800, "deckBias": { "exchange": 2 },
  "ratingStart": "C", "specialRules": ["usury_inquiry_in_force"] }
```

## 6. Balancing Parameters

| Name | Default | Range | File |
| --- | --- | --- | --- |
| `quarters` | 16 | 12–20 | balance.json |
| `factors.perHouse` | 4 | 3–5 | balance.json |
| `credit.limit` A/B/C | 1500/1000/500 L | ±50% | balance.json |
| `credit.interest` A/B/C | 3/5/8% | ±2 points | balance.json |
| `note.price` A/B/C/D | 98/94/88/70% | ±5 | balance.json |
| `squeeze.threshold` | 50% of notes due | 40–66% | balance.json |
| `default.penalty` | 20% | 10–30% | balance.json |
| `voyage.success` calm/fair/perilous | 90/75/55% | ±10 | balance.json |
| `prestige.value` | 40 L | 25–60 | balance.json |
| `lobby.base` | 40% | 30–50% | balance.json |

**Target metrics (sims, ≥ 2,000 games per configuration):**

| Metric | Target |
| --- | --- |
| Win rate per seat (equal AI, 4 houses) | 22–28% each |
| Bankruptcies per game | 0.3–0.8 |
| Bankruptcies caused by liquidity (house had positive net worth) | ≥ 70% (pillar 2) |
| Successful squeezes per game | 0.3–1.0; squeezer's win rate when squeezing 40–60% (risky, pillar 4) |
| Intelligence action usage by the strong AI | 40–70% of quarters |
| Prestige share of winning score | 20–40% |
| Strong AI vs medium AI | 65–80% |

## 7. AI Approach

The game is stochastic with hidden information and a large action space; AI uses forecasting plus sampled lookahead rather than full tree search.

| Tier | Algorithm | Budget (iPad A16, p95) per factor placement |
| --- | --- | --- |
| `clerk` (easy) | Rule-based: buy low/sell high by price vs base, take calm voyages, avoid bills, never squeeze | 50 ms |
| `factor` (medium) | Generates 30 candidate actions per placement; evaluates each with `LiquidityForecaster` (deterministic cash projection 4 quarters ahead under expected events) and an expected-value model for trades and voyages; uses squeeze only when `SqueezeDetector` predicts ≥ 70% success | 400 ms |
| `magnate` (hard) | Candidate generation as medium (50 candidates) plus 16 sampled futures (determinized event deck and rival behaviors via medium policy) for 2 quarters; chooses by mean score minus a risk penalty on default probability | 1,500 ms |

**LiquidityForecaster:** projects cash by quarter: obligations due, expected voyage returns (probability-weighted and a pessimistic case), market liquidation values at 80%, and rollover availability (blocked if a squeeze is possible); reports minimum cash and the first quarter of shortfall. The same component powers the player's **Forecast** panel (identical numbers; INV test).

**SqueezeDetector:** for a target house, estimates its obligations due in the next 2 quarters (from public bills on the note market and intelligence), its liquid assets band, and the cost to acquire 50% of its notes due that quarter.

**Personalities:** `conservative` (risk penalty ×2), `speculator` (perilous voyages, exchange arbitrage), `politician` (council and prestige), `predator` (squeezes).

**Determinism:** per-house AI RNG `SplitMix64(seed ^ houseID ^ quarter)`; sampled futures use forked RNGs; AI receives only its house's `Observation` (INV-5).

## 8. Phases, Tasks, and Gates

### P0 Setup

Standard tasks S0.1–S0.7.

- **GLD-P0.1 Denari money type and display formatting** (L/s/d and decimal lire), outside Core for formatting.
- **GLD-P0.2 JournalEntry type** with the balancing constructor and a trial balance helper. Acceptance: property test with 10,000 random entries.

```
GATE G0 — Setup
Checks:
  [ ] Standard G0 checks; RULES.md contains R-1…R-30, R-40…R-44, INV-1…INV-6
Sign-off: GLM-SELF
```

### P1 Rules Engine Prototype

Standard tasks S1.1–S1.4.

- **GLD-P1.1 Ledger, accounts, valuation, and net worth (R-4–R-7).**
- **GLD-P1.2 Quarter flow, initiative, and action spaces (R-8, R-9).**
- **GLD-P1.3 Markets and trading with FIFO lots (R-10, R-11).**
- **GLD-P1.4 Bills, exchange rates, loans, maturity, and defaults (R-12–R-17, R-19, R-42).** Acceptance: INV-2 cross-ledger consistency property test.
- **GLD-P1.5 Note market and squeeze (R-18, R-41).**
- **GLD-P1.6 Voyages and sea loans (R-20, R-43).**
- **GLD-P1.7 Council, lobbying, votes, and policies (R-21–R-23).**
- **GLD-P1.8 Events, intelligence, Observation (R-24–R-26).** Acceptance: INV-5 diff test.
- **GLD-P1.9 Commissions, audit, bankruptcy, victory (R-27–R-30).**
- **GLD-P1.10 Sim CLI** `Tools/sim --houses 4 --ai clerk --games 2000`.

```
GATE G1 — Rules Engine
Checks:
  [ ] All rule IDs tagged; INV-1…INV-6 over 1,000 seeds
  [ ] GLDCore coverage ≥ 90%
  [ ] `make sim N=1000`: 0 crashes; identical hashes across runs and platforms; trial balances zero at every quarter in every game
Sign-off: GLM-SELF
```

### P2 Core Loop Vertical Slice

Standard tasks S2.1–S2.5. Slice scope: 3 houses (player + 2 clerk AIs), 2 cities (Republic and Northern Fair), 4 goods, bills, loans, voyages, 20 events, no council.

- **GLD-P2.1 Ledger board (SwiftUI).** Account columns as ledger pages with balances; the journal on the right writing entries as actions post; drag coins from one account to another to begin the matching action (e.g., drag Cash to Voyages opens the voyage share picker), and every action is also available as a button.
- **GLD-P2.2 Factor placement.** Action spaces as a row of desks; drag a factor token to a desk; a sheet opens with that space's choices; confirm with a wax seal (select-then-confirm).
- **GLD-P2.3 Bills view.** Your bills payable and receivable as sealed cards in a timeline by due quarter.
- **GLD-P2.4 Forecast panel.** Cash projection 4 quarters ahead with the shortfall warning (shared with the AI forecaster).
- **GLD-P2.5 Harbor scene** (placeholder) showing ships leaving and returning.
- **GLD-P2.6 Audit and results screens.**

```
GATE G2 — Vertical Slice
Checks:
  [ ] XCUITest plays 16 quarters vs 2 clerk AIs to results on iPad and Mac
  [ ] Every Event.posted is visible in the journal view (UI data test)
  [ ] Forecast panel equals LiquidityForecaster output (test)
  [ ] Save and resume mid-quarter to identical hash; docs/media/slice.mp4 recorded
Sign-off: GLM-SELF
```

### P3 Content and Systems

- **GLD-P3.1** Third city, all 6 goods, note market and squeezes, council and 20 policies.
- **GLD-P3.2** 60 events, 10 house traits, 12 commissions, 5 scenarios.
- **GLD-P3.3** Tutorial: "The First Quarter" (trade and a bill), "The Fair" (exchange arbitrage), "The Audit" (liquidity), "The Squeeze" (a rival squeezes you; survive it).
- **GLD-P3.4** Hot-seat for 2–4 humans with private ledgers.
- **GLD-P3.5** Chronicle: per-game summary of key entries (largest trades, defaults, squeezes, and commissions).

```
GATE G3 — Content and Systems
Checks:
  [ ] Counts: 3 cities, 6 goods, 60 events, 20 policies, 10 traits, 12 commissions, 5 scenarios
  [ ] content-lint 0 errors; tutorial UI tests pass
Sign-off: GLM-SELF
```

### P4 AI Opponents

- **GLD-P4.1** LiquidityForecaster and SqueezeDetector with unit tests against crafted scenarios.
- **GLD-P4.2** Clerk, factor, and magnate tiers; personalities.
- **GLD-P4.3** `make balance` → `docs/BALANCE.md`.

```
GATE G4 — AI
Checks:
  [ ] 2,000 games per configuration: 0 crashes, 0 illegal actions; INV-5 (AI sees only Observation) enforced by API
  [ ] p95 think time within budgets (CI scaled)
  [ ] Targets in §6 met or documented
Sign-off: GLM-SELF
```

### P5 Meta and Replayability

- **GLD-P5.1** Scenario selection and unlocks (scenarios unlock by wins; all earnable).
- **GLD-P5.2** Weekly Ledger (ISO-week seed): a fixed scenario and deck vs magnate AIs; one ranked attempt.
- **GLD-P5.3** Stats: best net worth, squeezes executed and survived, defaults, and prestige.
- **GLD-P5.4** Export a finished game's full ledger as CSV (share sheet), a fitting extra for the audience.

```
GATE G5 — Meta and Replayability
Checks:
  [ ] Weekly seeds deterministic for 12 weeks ahead; CSV export balances (debits = credits) for 100 sim games
  [ ] All standard tests and coverage thresholds pass; docs/HANDOFF.md complete
Sign-off: GLM-SELF
```

### P6 Aesthetics and Audio Pass

- **GLD-P6.1** Marbled paper and ledger styling, ink-drawing animations for entries, wax seals, coin sprites.
- **GLD-P6.2** Harbor and city engravings; council chamber view.
- **GLD-P6.3** Consort music and ambience; SFX; haptics.
- **GLD-P6.4** GLM writes memo text for journal entries (period flavor, readable modern English).

```
GATE G6 — Aesthetics
Checks:
  [ ] Ledger readability: every entry in a sampled quarter's journal has a plain-language memo and an "explain this entry" view, verified by UI test; human readability check (playtest; `_CONVENTIONS.md` §8.2)
Sign-off: GLM-SELF
```

### P7 Platform Features

- **GLD-P7.1 Pencil.** Sign bills and letters with Pencil (the signature is cosmetic and stored with the save; signing is the confirm gesture alternative to the seal button); hover over an account shows its recent entries; squeeze opens the Forecast panel.
- **GLD-P7.2 Game Center.** Weekly leaderboard, achievements, challenges.
- **GLD-P7.3 iCloud** sync.
- **GLD-P7.4 Mac.** Multiple windows (ledger, journal, and council), keyboard navigation of desks and accounts, ⌘F to search the journal.

```
GATE G7 — Platform
Checks:
  [ ] Signature confirm produces the same Actions as the seal button
  [ ] Game Center sandbox and iCloud round trips; Mac multi-window
Sign-off: GLM-SELF
```

### P8 Polish, Accessibility, and Performance

- **GLD-P8.1** VoiceOver for every ledger table, bill card, and the forecast (with amounts read in lire).
- **GLD-P8.2** Dynamic Type throughout; a "modern numerals" toggle (decimal lire) on by default for accessibility.
- **GLD-P8.3** Debit and credit distinguished by column position and labels, not only red ink.
- **GLD-P8.4** Perf: magnate AI budget on A16.

```
GATE G8 — Polish
Checks:
  [ ] Accessibility audit clean; budgets met on real devices
Sign-off: GLM-SELF
```

### P9 Beta and TestFlight

```
GATE G9 — Beta
Checks:
  [ ] Internal TestFlight; crash-free ≥ 99.5%
  [ ] ≥ 60% of testers can explain a squeeze after the tutorial (survey drafted in `docs/release/`; playtest; `_CONVENTIONS.md` §8.2)
Sign-off: GLM-SELF
```

### P10 Release Prep

Standard P10 tasks; preview shows coins moving between accounts, a fair, and a squeeze at audit. Copy describes the setting as a fictional republic.

```
GATE G10 — Release
Checks:
  [ ] RC full CI green; metadata, privacy, and age-rating drafts reviewed
Sign-off: GLM-SELF
```

## 9. Fragile Areas and Priorities

- **Fragile areas:** cross-ledger consistency of bills (INV-2) during note transfers and bankruptcies; settlement ordering (R-42); Observation leaks (INV-5).
- **UX:** the ledger-as-board concept succeeds only if the journal is readable; both the SwiftUI layout and the memo voice need care.
- **Priorities for P6–P10:** ledger board ergonomics on iPhone compact width; squeeze balance and event deck tuning.

## 10. Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| Too dry for most players | High | Medium | Strong presentation, tutorials, forecast panel, chronicle; accept a niche audience | GLM |
| Accounting confuses players | Medium | High | Plain-language memos, debit/credit labels, "explain this entry" tap | GLM |
| Squeeze too strong or never used | Medium | Medium | Sims with predator personality; tunable thresholds | GLM |
| AI slow with sampled futures | Medium | Medium | Candidate pruning; adaptive sample counts | GLM |
| Historical inaccuracy complaints | Low | Low | Fictional republic; flavor inspired by history | GLM |

## 11. Out of Scope

- Online multiplayer.
- Real historical families or cities.
- Real-time trading.
- Full manual journal entry by the player (all entries are generated by actions).
- In-app purchases.

## 12. Effort Estimates

| Phase | Owner | Engineer-days |
| --- | --- | --- |
| P0 Setup | GLM | 2–3 |
| P1 Rules Engine | GLM | 12–16 |
| P2 Vertical Slice | GLM | 10–14 |
| P3 Content and Systems | GLM | 10–14 |
| P4 AI | GLM | 8–12 |
| P5 Meta | GLM | 3–5 |
| P6 Aesthetics and Audio | GLM | 10–14 |
| P7 Platform | GLM | 4–6 |
| P8 Polish | GLM | 5–7 |
| P9 Beta | GLM | 6–10 |
| P10 Release | GLM | 2–4 |
| **Total** | | **72–105** |

## 13. Open Questions

1. Period money (L/s/d) by default or decimal lire? **Default:** decimal lire by default, period money as an option.
2. Four houses by default? **Default:** yes (player + 3 AIs).
3. Include the CSV ledger export? **Default:** yes.
4. Hot-seat in v1.0? **Default:** yes.
5. Price? **Default:** the maintainer decides; GLM leaves the price unset.
