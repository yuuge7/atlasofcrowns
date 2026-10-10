/// Every tunable number of the game in one place.
abstract final class Rules {
  // Economy
  static const int unitCost = 4;
  static const int unitsPerUpkeepGold = 4;
  static const int baseIncome = 4;

  /// A province raises at most this many units per turn, plus its income.
  static const int recruitBase = 2;

  // Combat
  static const double defenseBonus = 1.5;
  static const double capitalBonus = 0.5;

  /// Locals who fight beside the garrison of their own province. They cannot
  /// be moved and are back at full strength every turn: this base, plus the
  /// province's income times [militiaPerIncome].
  static const int militiaBase = 2;
  static const double militiaPerIncome = 0.5;

  /// Each side's strength is scaled by a roll in [1 - spread, 1 + spread].
  static const double combatSpread = 0.15;

  // Diplomacy
  static const int truceTurns = 8;

  /// A peace offer stays on the table for this many end-of-turns.
  static const int peaceOfferTurns = 2;

  // Game setup
  static const double startArmyPerIncome = 1.6;
  static const int startArmyPerProvince = 1;
  static const int startGoldPerIncome = 2;
  static const double defaultWinFraction = 0.4;

  // AI
  static const double aiAttackMargin = 1.2;
  static const double aiWarRatio = 1.8;
  static const int aiMinWarTurns = 6;
  static const int aiStalemateTurns = 10;

  /// Every turn at peace makes the AI accept worse odds for its next war by
  /// this share of [aiWarRatio], down to [aiRestlessMax] of it. Without this
  /// two evenly matched empires would face each other in peace forever.
  static const double aiRestlessPerTurn = 0.02;
  static const double aiRestlessMax = 0.6;

  /// At peace the AI keeps its army at this share of what income can pay
  /// for, and at [aiWarArmy] once it is at war or sits on a full treasury.
  static const double aiPeaceArmy = 0.7;
  static const double aiWarArmy = 0.95;
  static const int aiFullTreasuryTurns = 8;
}
